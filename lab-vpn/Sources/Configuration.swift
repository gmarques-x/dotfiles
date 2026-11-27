import Foundation

struct VPNError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

enum Configuration {
    private static let interfaceFields = ["PrivateKey", "Address", "DNS", "ListenPort", "MTU"]
    private static let peerFields = ["PublicKey", "PresharedKey", "AllowedIPs", "Endpoint", "PersistentKeepalive"]

    static func grove(privateKey: String) -> String {
        """
        [Interface]
        PrivateKey = \(privateKey)
        Address = 10.150.99.3/32

        [Peer]
        PublicKey = y1TYBKKa2SJsy/MpnKQX0nS8UpJkKXqW3V5wE9VopQ0=
        Endpoint = 192.168.150.3:51820
        AllowedIPs = 10.150.0.0/16
        PersistentKeepalive = 25
        """
    }

    static func validate(_ text: String) throws -> String {
        guard text.utf8.count <= 65536 else { throw VPNError("The configuration exceeds 64 KB.") }
        var output: [String] = []
        var fields: Set<String> = []
        var section = ""
        for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
            let line = raw.prefix(while: { $0 != "#" }).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.caseInsensitiveCompare("[Interface]") == .orderedSame && section.isEmpty {
                section = "Interface"
                output.append("[Interface]")
                continue
            }
            if line.caseInsensitiveCompare("[Peer]") == .orderedSame {
                let required = section == "Interface" ? "PrivateKey" : "PublicKey"
                guard fields.contains(required) else { throw VPNError("A WireGuard section is missing its \(required).") }
                section = "Peer"
                fields.removeAll()
                output.append("\n[Peer]")
                continue
            }
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            let allowed = section == "Interface" ? interfaceFields : section == "Peer" ? peerFields : []
            guard parts.count == 2,
                  let field = allowed.first(where: { $0.caseInsensitiveCompare(parts[0]) == .orderedSame }),
                  fields.insert(field).inserted else {
                throw VPNError("Unsupported, repeated, or misplaced setting on line \(index + 1).")
            }
            let value = parts[1]
            let pattern: String
            switch field {
            case "PrivateKey", "PublicKey", "PresharedKey":
                guard Data(base64Encoded: value)?.count == 32 else {
                    throw VPNError("Invalid WireGuard key on line \(index + 1).")
                }
                pattern = "^[A-Za-z0-9+/]{43}=$"
            case "Address", "AllowedIPs":
                pattern = "^[a-fA-F0-9:.]+(/[0-9]{1,3})( *, *[a-fA-F0-9:.]+/[0-9]{1,3})*$"
            case "DNS":
                pattern = "^[A-Za-z0-9:.][A-Za-z0-9:.-]*( *, *[A-Za-z0-9:.][A-Za-z0-9:.-]*)*$"
            case "Endpoint":
                pattern = "^([A-Za-z0-9][A-Za-z0-9.-]*|\\[[A-Fa-f0-9:.]+\\]):[0-9]{1,5}$"
            default:
                pattern = "^[0-9]{1,5}$"
            }
            guard value.range(of: pattern, options: .regularExpression) != nil else {
                throw VPNError("Invalid \(field) on line \(index + 1).")
            }
            output.append("\(field) = \(value)")
        }
        guard section == "Peer", fields.contains("PublicKey") else {
            throw VPNError("Add a peer with its public key.")
        }
        return output.joined(separator: "\n") + "\n"
    }

    static func privateKey(in configuration: String) -> String? {
        configuration.split(separator: "\n")
            .first { $0.hasPrefix("PrivateKey = ") }
            .map { String($0.dropFirst("PrivateKey = ".count)) }
    }
}
