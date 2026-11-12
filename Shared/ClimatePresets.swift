import BetterBlueKit
import Foundation

/// The climate settings used by the one-tap Climate button, widget and Siri.
enum ClimatePresets {
    private static let key = "climate.v1"
    private static var defaults: UserDefaults { UserDefaults(suiteName: AppConfig.appGroup) ?? .standard }

    static func load() -> ClimateOptions {
        guard let data = defaults.data(forKey: key),
              let options = try? JSONDecoder().decode(ClimateOptions.self, from: data)
        else { return ClimateOptions(preferredUnits: .fahrenheit) }
        return options
    }

    static func save(_ options: ClimateOptions) {
        guard let data = try? JSONEncoder().encode(options) else { return }
        defaults.set(data, forKey: key)
    }
}
