import Foundation
import Security

struct Profile: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var configuration: String

    var interface: String {
        "lv" + id.uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(13)
    }
}

enum Profiles {
    private static let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.gmarques.lab-vpn.profiles",
        kSecAttrAccount as String: "profiles"
    ]

    static func load() throws -> [Profile] {
        var query = item
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        try check(status)
        guard let data = result as? Data else { throw VPNError("Could not read stored profiles.") }
        return try JSONDecoder().decode([Profile].self, from: data)
    }

    static func save(_ profiles: [Profile]) throws {
        let data = try JSONEncoder().encode(profiles)
        let values = [kSecValueData as String: data]
        let status = SecItemUpdate(item as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            try check(SecItemAdd(item.merging(values) { _, new in new } as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Error \(status)"
            throw VPNError("Keychain: \(message)")
        }
    }
}
