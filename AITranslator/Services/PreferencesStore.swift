import Foundation

final class PreferencesStore: PreferencesPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "preferences.json") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> Preferences? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            let decoded = try JSONDecoder().decode(Preferences.self, from: data)
            return decoded
        } catch {
            return nil
        }
    }

    func save(_ preferences: Preferences) {
        do {
            let data = try JSONEncoder().encode(preferences)
            defaults.set(data, forKey: key)
        } catch {
            // no-op on failure; UI does not surface errors for persistence
        }
    }
}
