import Darwin
import Foundation

let root = "/Library/PrivilegedHelperTools/com.gmarques.lab-vpn"
let tools = root + "/tools"

func serve() throws {
    var peer: uid_t = 0
    var group: gid_t = 0
    guard CommandLine.arguments.count == 2, let allowed = uid_t(CommandLine.arguments[1]),
          getpeereid(STDIN_FILENO, &peer, &group) == 0, peer == allowed, allowed != 0 else {
        throw VPNError("This account is not authorized to manage Lab VPN.")
    }
    TunnelRequest.setTimeout(STDIN_FILENO)
    let data = try TunnelRequest.read(STDIN_FILENO, limit: TunnelRequest.maximumSize)
    let request = try JSONDecoder().decode(TunnelRequest.self, from: data)
    guard request.validInterface else { throw VPNError("Invalid Lab VPN tunnel identifier.") }
    let lock = open(root + "/operations.lock", O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
    guard lock >= 0 else { throw VPNError("Could not open the tunnel lock.") }
    defer { close(lock) }
    guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw VPNError("Another tunnel operation is in progress.") }

    let configuration = try request.configuration.map(Configuration.validate) ?? "[Interface]\n"
    let directory = URL(fileURLWithPath: root).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                            attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent(request.interface + ".conf")
    guard FileManager.default.createFile(atPath: path.path, contents: Data(configuration.utf8),
                                         attributes: [.posixPermissions: 0o600]) else {
        throw VPNError("Could not stage the profile.")
    }
    let up = request.configuration != nil
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tools + "/bash")
    process.arguments = [tools + "/wg-quick", up ? "up" : "down", path.path]
    process.environment = ["PATH": tools + ":/usr/bin:/bin:/usr/sbin:/sbin", "HOME": "/var/root"]
    process.currentDirectoryURL = URL(fileURLWithPath: root)
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw VPNError("WireGuard could not \(up ? "bring up" : "bring down") this tunnel.")
    }
    if up {
        _ = chmod("/var/run/wireguard/\(request.interface).name", 0o644)
    }
}

do {
    try serve()
    try FileHandle.standardOutput.write(contentsOf: Data("OK".utf8))
} catch {
    let message = (error as? VPNError)?.errorDescription ?? "The Lab VPN helper could not process the request."
    try? FileHandle.standardOutput.write(contentsOf: Data(message.utf8))
}
