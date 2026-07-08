import Foundation

public enum Defaults {
    public static let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    public static let model = "meta-llama/llama-3.3-70b-instruct:free"
}

public protocol SettingsStore: AnyObject {
    var endpoint: String { get set }
    var model: String { get set }
    var useContext: Bool { get set }
}

public final class InMemorySettings: SettingsStore {
    public var endpoint: String
    public var model: String
    public var useContext: Bool
    public init(endpoint: String = Defaults.endpoint, model: String = Defaults.model,
                useContext: Bool = true) {
        self.endpoint = endpoint
        self.model = model
        self.useContext = useContext
    }
}

public final class UserDefaultsSettings: SettingsStore {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var endpoint: String {
        get { defaults.string(forKey: "endpoint") ?? Defaults.endpoint }
        set { defaults.set(newValue, forKey: "endpoint") }
    }
    public var model: String {
        get { defaults.string(forKey: "model") ?? Defaults.model }
        set { defaults.set(newValue, forKey: "model") }
    }
    public var useContext: Bool {
        // `object(forKey:)` (not `bool(forKey:)`) so an absent key defaults to true.
        get { defaults.object(forKey: "useContext") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "useContext") }
    }
}
