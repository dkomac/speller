import Foundation
import Security

public protocol SecretStore: AnyObject {
    var apiKey: String { get set }
}

public final class InMemorySecretStore: SecretStore {
    public var apiKey: String
    public init(apiKey: String = "") { self.apiKey = apiKey }
}

public final class KeychainSecretStore: SecretStore {
    private let service = "io.beyondloops.speller"
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
