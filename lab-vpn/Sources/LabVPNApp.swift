import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class VPNModel: ObservableObject {
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var active: Set<UUID> = []
    @Published private(set) var working = false
    @Published private(set) var ready = false
    @Published private(set) var helperEnabled = HelperClient.installed
    @Published var error: String?
    @Published private var selectedID = UserDefaults.standard.string(forKey: "selectedProfile") ?? ""

    init() {
        reload()
    }

    func reload() {
        do {
            var saved = try Profiles.load()
            let renamed = saved.indices.filter { saved[$0].name == "Grove Lab" }
            for index in renamed {
                saved[index].name = "Home Lab"
            }
            if !renamed.isEmpty { try Profiles.save(saved) }
            profiles = saved
            ready = true
            error = nil
            refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    var selected: Profile? {
        profiles.first { $0.id.uuidString == selectedID } ?? profiles.first
    }

    func select(_ profile: Profile) {
        selectedID = profile.id.uuidString
        UserDefaults.standard.set(selectedID, forKey: "selectedProfile")
    }

    func refresh() {
        let current = Set(profiles.filter { WireGuard.isActive($0.interface) }.map(\.id))
        if active != current { active = current }
    }

    func save(_ profile: Profile) throws {
        guard ready, !working, !WireGuard.isActive(profile.interface) else {
            throw VPNError("Disconnect this tunnel before changing its profile.")
        }
        var updated = profile
        updated.name = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.name.isEmpty else { throw VPNError("Enter a profile name.") }
        updated.configuration = try Configuration.validate(updated.configuration)
        var next = profiles
        if let index = next.firstIndex(where: { $0.id == updated.id }) {
            next[index] = updated
        } else {
            next.append(updated)
        }
        try Profiles.save(next)
        profiles = next
        select(updated)
    }

    func remove(_ profile: Profile) {
        do {
            guard ready, !working, !WireGuard.isActive(profile.interface) else {
                throw VPNError("Disconnect this tunnel before deleting its profile.")
            }
            let next = profiles.filter { $0.id != profile.id }
            try Profiles.save(next)
            profiles = next
        } catch {
            self.error = error.localizedDescription
        }
    }

    func enableHelper() {
        guard !working, !helperEnabled else { return }
        working = true
        error = nil
        Task {
            defer { working = false }
            do {
                try await Task.detached { try WireGuard.enableHelper() }.value
                helperEnabled = true
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func toggle() {
        refresh()
        guard ready, !working, let profile = selected else { return }
        let connect = !active.contains(profile.id)
        guard !connect || active.isEmpty else {
            error = "Disconnect the active Lab VPN tunnel before connecting another profile."
            return
        }
        working = true
        Task {
            defer {
                refresh()
                working = false
            }
            do {
                try await Task.detached { try WireGuard.change(profile, connect: connect) }.value
                refresh()
                guard active.contains(profile.id) == connect else {
                    throw VPNError("The tunnel did not report the expected state after the operation.")
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

@main
struct LabVPNApp: App {
    @StateObject private var model = VPNModel()

    var body: some Scene {
        MenuBarExtra {
            TunnelMenu(model: model)
        } label: {
            Image(systemName: model.active.isEmpty ? "shield" : "checkmark.shield.fill")
                .accessibilityLabel("Lab VPN")
        }
        .menuBarExtraStyle(.window)

        Window("Lab VPN Profiles", id: "profiles") {
            ProfileManager(model: model)
        }
        .defaultSize(width: 720, height: 470)
    }
}

private struct TunnelMenu: View {
    @ObservedObject var model: VPNModel
    @Environment(\.openWindow) private var openWindow
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lab VPN").font(.headline)
                Spacer()
                if model.working { ProgressView().controlSize(.small) }
            }
            if let selected = model.selected {
                Picker("Profile", selection: Binding(
                    get: { selected.id },
                    set: { id in
                        if let profile = model.profiles.first(where: { $0.id == id }) { model.select(profile) }
                    }
                )) {
                    ForEach(model.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                let active = model.active.contains(selected.id)
                Label(active ? "Tunnel up" : "Tunnel down", systemImage: active ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(active ? Color.green : Color.secondary)
                Button(active ? "Disconnect" : "Connect") { model.toggle() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.working)
            } else {
                Text(model.ready ? "No tunnel profiles yet." : "Profiles unavailable.")
                    .foregroundStyle(.secondary)
            }
            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Divider()
            if !model.helperEnabled {
                Button("Enable Password-Free Controls…") { model.enableHelper() }
                    .disabled(model.working)
            }
            HStack {
                Button("Manage Profiles…") {
                    openWindow(id: "profiles")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.disabled(model.working)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { model.refresh() }
        .onReceive(timer) { _ in model.refresh() }
    }
}

private final class ProfileEditor: ObservableObject {
    @Published var selection: UUID?
    @Published var draft: Profile?
    @Published var confirmation: Bool = false
    @Published var publicKey: String?
    @Published var message: String?
    @Published var editingConfiguration: Bool = false
}

private struct ProfileManager: View {
    @ObservedObject var model: VPNModel
    @StateObject private var editor = ProfileEditor()

    private var selection: UUID? {
        get { editor.selection }
        nonmutating set { editor.selection = newValue }
    }

    private var draft: Profile? {
        get { editor.draft }
        nonmutating set { editor.draft = newValue }
    }

    private var confirmation: Bool {
        get { editor.confirmation }
        nonmutating set { editor.confirmation = newValue }
    }

    private var publicKey: String? {
        get { editor.publicKey }
        nonmutating set { editor.publicKey = newValue }
    }

    private var message: String? {
        get { editor.message }
        nonmutating set { editor.message = newValue }
    }

    private var editingConfiguration: Bool {
        get { editor.editingConfiguration }
        nonmutating set { editor.editingConfiguration = newValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                List(model.profiles, selection: $editor.selection) { profile in
                    Label(profile.name, systemImage: model.active.contains(profile.id) ? "checkmark.shield" : "shield")
                        .tag(profile.id)
                }
                HStack {
                    Menu("Add") {
                        Button("Home Lab") { create(grove: true) }
                        Button("Empty Profile") { create(grove: false) }
                        Button("Import WireGuard File…") { importFile() }
                        Button("Restore Home Lab Backup…") { restoreHomeLab() }
                    }
                    .disabled(!model.ready || model.working)
                    Button("Delete…") { confirmation = true }
                        .disabled(model.working || selection == nil || draft?.id != selection ||
                                  selection.map { model.active.contains($0) } == true)
                }
                .padding([.horizontal, .bottom], 12)
            }
            .frame(width: 215)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if draft != nil {
                    let active = draft.map { model.active.contains($0.id) } ?? false
                    TextField("Profile name", text: Binding(
                        get: { draft?.name ?? "" }, set: { draft?.name = $0 }
                    ))
                    .font(.title2)
                    .disabled(active || model.working)
                    HStack {
                        Button("Copy Public Key") { copyPublicKey() }
                        Toggle("Show Configuration", isOn: $editor.editingConfiguration)
                    }
                    if editingConfiguration {
                        TextEditor(text: Binding(
                            get: { draft?.configuration ?? "" }, set: { draft?.configuration = $0; publicKey = nil }
                        ))
                        .font(.system(.body, design: .monospaced))
                        .border(Color.secondary.opacity(0.3))
                        .accessibilityLabel("WireGuard configuration")
                        .disabled(active || model.working)
                    } else {
                        Text("The configuration contains the private key and is hidden by default.")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    if let publicKey {
                        Text(publicKey).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                    HStack {
                        if active { Text("Disconnect this tunnel to edit it.").foregroundStyle(.secondary) }
                        Spacer()
                        Button("Save Profile") { save() }
                            .buttonStyle(.borderedProminent)
                            .disabled(active || model.working)
                    }
                } else {
                    Text("Tunnel Profiles").font(.title2)
                    Text("Select a profile or add one to get started.").foregroundStyle(.secondary)
                    if !model.ready { Button("Retry Keychain") { model.reload() } }
                    Spacer()
                }
                if let message { Text(message).font(.caption).textSelection(.enabled) }
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            .padding(20)
            .frame(minWidth: 425, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 380)
        .onAppear {
            model.refresh()
            if selection == nil { selection = model.selected?.id }
        }
        .onChange(of: selection) { id in
            draft = model.profiles.first { $0.id == id }
            publicKey = nil
            message = nil
            editingConfiguration = false
            model.error = nil
        }
        .confirmationDialog("Delete this profile and its stored key?", isPresented: $editor.confirmation) {
            Button("Delete Profile", role: .destructive) {
                guard let profile = model.profiles.first(where: { $0.id == selection }) else { return }
                model.remove(profile)
                if !model.profiles.contains(where: { $0.id == profile.id }) {
                    selection = nil
                    draft = nil
                }
            }
        }
    }

    private func create(grove: Bool) {
        do {
            let key = try WireGuard.generateKey()
            let config = grove ? Configuration.grove(privateKey: key) :
                "[Interface]\nPrivateKey = \(key)\nAddress = \n\n[Peer]\nPublicKey = \nAllowedIPs = \nEndpoint = \n"
            showDraft(Profile(id: UUID(), name: grove ? "Home Lab" : "New Tunnel", configuration: config))
            editingConfiguration = !grove
        } catch {
            model.error = error.localizedDescription
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.title = "Import WireGuard Configuration"
        panel.allowedContentTypes = [UTType(filenameExtension: "conf") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let configuration = try Configuration.validate(String(contentsOf: url, encoding: .utf8))
            showDraft(Profile(id: UUID(), name: url.deletingPathExtension().lastPathComponent, configuration: configuration))
        } catch {
            model.error = error.localizedDescription
        }
    }

    private func restoreHomeLab() {
        let existing = model.profiles.first { $0.name == "Home Lab" }
        if let existing, model.active.contains(existing.id) {
            model.error = "Disconnect Home Lab before restoring its profile."
            return
        }
        let panel = NSOpenPanel()
        panel.title = "Open Encrypted Home Lab Backup"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("OneDrive/lab-vpn", isDirectory: true)
        panel.allowedContentTypes = [UTType(filenameExtension: "enc") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let alert = NSAlert()
        alert.messageText = "Restore Home Lab"
        alert.informativeText = "Enter the passphrase you chose for the OneDrive backup."
        alert.addButton(withTitle: "Decrypt")
        alert.addButton(withTitle: "Cancel")
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let passphrase = field.stringValue
        field.stringValue = ""
        do {
            let config = try WireGuard.restoreBackup(url, passphrase: passphrase)
            showDraft(Profile(id: existing?.id ?? UUID(), name: "Home Lab", configuration: config))
            message = "Backup decrypted. Save Profile to use this key in Home Lab."
        } catch {
            model.error = error.localizedDescription
        }
    }

    private func showDraft(_ profile: Profile) {
        draft = profile
        publicKey = nil
        editingConfiguration = false
        message = "Save this profile to add it to the menu."
        model.error = nil
    }

    private func copyPublicKey() {
        do {
            // Derive the key from the interface even while the remaining fields are being edited.
            guard let text = draft?.configuration, let key = Configuration.privateKey(in: text),
                  Data(base64Encoded: key)?.count == 32 else {
                throw VPNError("Enter a valid interface private key first.")
            }
            let derived = try WireGuard.publicKey(key)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(derived, forType: .string)
            publicKey = derived
            message = "Client public key copied."
            model.error = nil
        } catch {
            model.error = error.localizedDescription
        }
    }

    private func save() {
        guard let draft else { return }
        do {
            try model.save(draft)
            selection = draft.id
            self.draft = model.selected
            model.error = nil
            message = "Profile saved."
        } catch {
            model.error = error.localizedDescription
        }
    }
}
