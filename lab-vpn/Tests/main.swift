import Foundation

let key = "y1TYBKKa2SJsy/MpnKQX0nS8UpJkKXqW3V5wE9VopQ0="
let config = "[Interface]\nPrivateKey = \(key)\nAddress = 10.150.99.3/32\n[Peer]\nPublicKey = \(key)\nAllowedIPs = 10.150.0.0/16\nEndpoint = 192.168.150.3:51820"
let validated = try Configuration.validate(config)
precondition(validated.contains("Address = 10.150.99.3/32"))
precondition(Configuration.privateKey(in: validated) == key)
for directive in ["PreUp", "pOsTuP", "PreDown", "PostDown", "SaveConfig", "Table"] {
    precondition((try? Configuration.validate(config.replacingOccurrences(of: "[Peer]", with: "\(directive) = true\n[Peer]"))) == nil)
}
precondition((try? Configuration.validate(config.replacingOccurrences(of: "10.150.99.3/32", with: "-invalid"))) == nil)
precondition((try? Configuration.validate(config.replacingOccurrences(of: "PrivateKey = \(key)", with: ""))) == nil)
let privateKey = try WireGuard.generateKey()
let publicKey = try WireGuard.publicKey(privateKey)
precondition(privateKey != publicKey && Data(base64Encoded: publicKey)?.count == 32)
print("Profile validation and Homebrew key generation passed")

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
defer { try? FileManager.default.removeItem(at: directory) }
let backup = directory.appendingPathComponent("test.conf.enc")
let encryption = Process()
let fixture = Pipe()
encryption.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
encryption.arguments = ["enc", "-aes-256-cbc", "-pbkdf2", "-iter", "600000", "-md", "sha256",
                        "-pass", "pass:fixture-only", "-out", backup.path]
encryption.standardInput = fixture
try encryption.run()
try fixture.fileHandleForWriting.write(contentsOf: Data(config.utf8))
try fixture.fileHandleForWriting.close()
encryption.waitUntilExit()
precondition(encryption.terminationStatus == 0)
let restored = try WireGuard.restoreBackup(backup, passphrase: "fixture-only")
precondition(restored == validated)
precondition((try? WireGuard.restoreBackup(backup, passphrase: "incorrect")) == nil)
print("Encrypted backup restore and incorrect passphrase checks passed")
