import Foundation

enum WireGuard {
    static func generateKey() throws -> String {
        try keyCommand("genkey")
    }

    static func publicKey(_ privateKey: String) throws -> String {
        try keyCommand("pubkey", input: privateKey + "\n")
    }

    private static func tool(_ name: String) throws -> String {
        for prefix in ["/opt/homebrew/bin", "/usr/local/bin"] {
            let path = "\(prefix)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        throw VPNError("Homebrew’s \(name) is missing. Install it with brew install wireguard-tools.")
    }

    private static func keyCommand(_ argument: String, input: String? = nil) throws -> String {
        let process = Process()
        let output = Pipe()
        let stdin = Pipe()
        process.executableURL = URL(fileURLWithPath: try tool("wg"))
        process.arguments = [argument]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = stdin
        try process.run()
        if let input { try stdin.fileHandleForWriting.write(contentsOf: Data(input.utf8)) }
        try stdin.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let key = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, Data(base64Encoded: key)?.count == 32 else {
            throw VPNError("WireGuard could not generate or derive the key.")
        }
        return key
    }

    static func restoreBackup(_ url: URL, passphrase: String) throws -> String {
        guard !passphrase.isEmpty, !passphrase.contains(where: { $0.isNewline }) else {
            throw VPNError("Enter the backup passphrase on a single line.")
        }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard (1...65600).contains(size) else { throw VPNError("The backup file has an unexpected size.") }
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = ["enc", "-d", "-aes-256-cbc", "-pbkdf2", "-iter", "600000",
                             "-md", "sha256", "-pass", "stdin", "-in", url.path]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        try input.fileHandleForWriting.write(contentsOf: Data((passphrase + "\n").utf8))
        try input.fileHandleForWriting.close()
        let decrypted = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let text = String(data: decrypted, encoding: .utf8) else {
            throw VPNError("Could not decrypt the backup. Check the passphrase and file.")
        }
        return try Configuration.validate(text)
    }

    static func isActive(_ interface: String) -> Bool {
        let directory = URL(fileURLWithPath: "/var/run/wireguard")
        let marker = directory.appendingPathComponent("\(interface).name")
        guard FileManager.default.fileExists(atPath: marker.path) else { return false }
        // Older versions left the marker readable only by root.
        guard let record = try? String(contentsOf: marker, encoding: .utf8) else { return true }
        let device = record.trimmingCharacters(in: .whitespacesAndNewlines)
        guard device.range(of: "^utun[0-9]+$", options: .regularExpression) != nil else { return false }
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(device).sock").path)
    }

    static func change(_ profile: Profile, connect: Bool) throws {
        if HelperClient.installed {
            let configuration = connect ? try Configuration.validate(profile.configuration) : nil
            try HelperClient.perform(TunnelRequest(interface: profile.interface, configuration: configuration))
            return
        }

        let quick = try tool("wg-quick")
        _ = try tool("wireguard-go")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LabVPN-\(UUID())")
        let config = directory.appendingPathComponent("\(profile.interface).conf")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let text = connect ? try Configuration.validate(profile.configuration) : "[Interface]\n"
        guard FileManager.default.createFile(atPath: config.path, contents: Data(text.utf8),
                                             attributes: [.posixPermissions: 0o600]) else {
            throw VPNError("Could not stage the tunnel configuration.")
        }

        let prefix = URL(fileURLWithPath: quick).deletingLastPathComponent().path
        // Validate the root-owned snapshot before invoking wg-quick, which supports shell hooks.
        let shell = """
        set -eu
        umask 077
        scratch=$(/usr/bin/mktemp -d /private/tmp/labvpn.XXXXXXXX)
        trap '/bin/rm -rf "$scratch"' EXIT
        config="$scratch/\(profile.interface).conf"
        /bin/cat \(quote(config.path)) > "$config"
        LC_ALL=C /usr/bin/awk '
            /^$/ || /^\\[(Interface|Peer)\\]$/ { next }
            /^(PrivateKey|Address|DNS|ListenPort|MTU|PublicKey|PresharedKey|AllowedIPs|Endpoint|PersistentKeepalive) = [A-Za-z0-9+\\/=. :,\\[\\]-]+$/ { next }
            { exit 1 }
        ' "$config"
        umask 022
        PATH=\(quote(prefix + ":/usr/bin:/bin:/usr/sbin:/sbin")) \(quote(quick)) \(connect ? "up" : "down") "$config" >/dev/null 2>&1
        \(connect ? "/bin/chmod 644 /var/run/wireguard/\(profile.interface).name" : ":")
        """
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "on run argv", "-e",
                             "do shell script (item 1 of argv) with administrator privileges",
                             "-e", "end run", shell]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = output
        try process.run()
        let diagnostic = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            if diagnostic.contains("(-128)") { throw VPNError("Administrator authorization was canceled.") }
            throw VPNError("WireGuard could not \(connect ? "bring up" : "bring down") this tunnel. Check Homebrew and the profile settings.")
        }
    }

    static func enableHelper() throws {
        guard let payload = Bundle.main.resourceURL?.appendingPathComponent("Helper") else {
            throw VPNError("The helper installation files are missing.")
        }
        let installer = payload.appendingPathComponent("install-service.sh").path
        let command = "/bin/bash " + quote(installer) + " " + quote(payload.path) + " " + String(getuid())
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "on run argv", "-e",
                             "do shell script (item 1 of argv) with administrator privileges",
                             "-e", "end run", command]
        let errors = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        let diagnostic = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0, HelperClient.installed else {
            if diagnostic.contains("(-128)") { throw VPNError("Administrator authorization was canceled.") }
            throw VPNError("macOS could not install the Lab VPN service.")
        }
    }

    private static func quote(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
