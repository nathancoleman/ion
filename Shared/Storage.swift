import BetterBlueKit
import Foundation
import Security

enum AppConfig {
    /// Shared by the app and widget for both UserDefaults and the keychain.
    static let appGroup = "group.com.nathancoleman.ion"
    /// Signing in with this username uses the built-in demo car instead of Bluelink.
    static let demoUsername = "demo"
}

// MARK: - Credentials (keychain)

struct Credentials: Codable, Sendable, Equatable {
    var username: String
    var password: String
    var pin: String
    var accountId: UUID = UUID()

    var isDemo: Bool { username.lowercased() == AppConfig.demoUsername }
}

enum CredentialStore {
    private static let service = "com.nathancoleman.ion"

    static func loadCredentials() -> Credentials? { read("credentials") }
    static func saveCredentials(_ value: Credentials) { write(value, account: "credentials") }

    static func loadToken() -> AuthToken? { read("token") }
    static func saveToken(_ value: AuthToken) { write(value, account: "token") }

    static func clear() {
        for account in ["credentials", "token"] {
            SecItemDelete(baseQuery(account) as CFDictionary)
        }
    }

    /// App groups double as keychain access groups, so the widget and intents
    /// can read what the app saved. Builds signed without the App Group
    /// capability fall back to the app's private keychain.
    private static let useSharedGroup: Bool = {
        #if targetEnvironment(simulator)
        return false
        #else
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "probe",
            kSecAttrAccessGroup as String: AppConfig.appGroup,
        ]
        return SecItemCopyMatching(probe as CFDictionary, nil) != errSecMissingEntitlement
        #endif
    }()

    private static func baseQuery(_ account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if useSharedGroup { query[kSecAttrAccessGroup as String] = AppConfig.appGroup }
        return query
    }

    private static func read<T: Decodable>(_ account: String) -> T? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, account: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let query = baseQuery(account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // Widgets and Control Center run while the phone is locked.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }
}

// MARK: - Snapshot cache (app group defaults)

/// The last known car state, shared with the widget so everything renders
/// instantly without waking the car.
struct CarSnapshot: Codable, Sendable {
    var vehicle: Vehicle
    var status: VehicleStatus?
    var appearance: CarAppearance
    var fetchedAt: Date
}

enum SnapshotStore {
    private static let key = "snapshot.v1"
    private static var defaults: UserDefaults { UserDefaults(suiteName: AppConfig.appGroup) ?? .standard }

    static func load() -> CarSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CarSnapshot.self, from: data)
    }

    static func save(_ snapshot: CarSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func update(_ change: (inout CarSnapshot) -> Void) {
        guard var snapshot = load() else { return }
        change(&snapshot)
        save(snapshot)
    }

    static func clear() { defaults.removeObject(forKey: key) }
}
