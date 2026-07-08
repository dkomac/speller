import Foundation
import Security

public protocol SecretStore: AnyObject {
    var apiKey: String { get set }
}

public final class InMemorySecretStore: SecretStore {
    public var apiKey: String
    public init(apiKey: String = "") { self.apiKey = apiKey }
}

/// Stores the key in a plain, owner-only-readable file (default:
/// ~/Library/Application Support/Speller/openrouter.key). No Keychain, so no
/// permission prompts. The trade-off is the key sits in plaintext on disk —
/// acceptable for a low-value free-tier key on a personal machine.
public final class FileSecretStore: SecretStore {
    private let url: URL

    public init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Speller", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.url = dir.appendingPathComponent("openrouter.key")
        }
    }

    public var apiKey: String {
        get {
            (try? String(contentsOf: url, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        set {
            try? newValue.write(to: url, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                                    ofItemAtPath: url.path)
        }
    }
}

public final class KeychainSecretStore: SecretStore {
    private let service = "speller"
    private let account = "openrouter-api-key"

    public init() {}

    public var apiKey: String {
        get { read() ?? "" }
        set { write(newValue) }
    }

    private func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String) {
        let data = Data(value.utf8)
        SecItemDelete(baseQuery() as CFDictionary)
        var query = baseQuery()
        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }
}
