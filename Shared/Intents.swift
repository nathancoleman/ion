import AppIntents
import BetterBlueKit
import Foundation

/// Sends a command and updates the shared snapshot right away, so widgets
/// and the app show the expected state while the car catches up.
@MainActor
enum QuickCommands {
    static func run(_ command: VehicleCommand) async throws {
        try await CarService.shared.send(command)
        SnapshotStore.update { snapshot in
            guard var status = snapshot.status else { return }
            status.applyOptimistically(command)
            snapshot.status = status
        }
        CarService.shared.reloadWidgets()
    }
}

extension VehicleStatus {
    mutating func applyOptimistically(_ command: VehicleCommand) {
        switch command {
        case .lock: lockStatus = .locked
        case .unlock: lockStatus = .unlocked
        case .startClimate(let options):
            climateStatus.airControlOn = true
            climateStatus.temperature = options.temperature
        case .stopClimate: climateStatus.airControlOn = false
        case .startCharge: evStatus?.charging = true
        case .stopCharge: evStatus?.charging = false
        case .setTargetSOC(let ac, let dc):
            evStatus?.targetSocAC = Double(ac)
            evStatus?.targetSocDC = Double(dc)
        }
    }
}

struct LockCarIntent: AppIntent {
    static let title: LocalizedStringResource = "Lock Car"
    static let description = IntentDescription("Locks your car through Bluelink.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await QuickCommands.run(.lock)
        return .result(dialog: "Locking your car.")
    }
}

struct UnlockCarIntent: AppIntent {
    static let title: LocalizedStringResource = "Unlock Car"
    static let description = IntentDescription("Unlocks your car through Bluelink.")
    // Unlocking from the Lock Screen should require Face ID.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await QuickCommands.run(.unlock)
        return .result(dialog: "Unlocking your car.")
    }
}

/// A LiveActivityIntent runs in the app's process, so starting climate from
/// Siri or Control Center can also start the lock screen progress activity.
struct StartClimateIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Climate"
    static let description = IntentDescription("Pre-conditions the cabin.")

    @Parameter(title: "Temperature (°F)", default: 72, inclusiveRange: (62, 82))
    var temperature: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var options = ClimatePresets.load()
        options.temperature = Temperature(units: 1, value: String(temperature))
        await ClimateLiveActivity.start(options: options)
        do {
            try await QuickCommands.run(.startClimate(options))
            await ClimateLiveActivity.update(.running)
        } catch {
            await ClimateLiveActivity.update(.failed, message: error.localizedDescription)
            throw error
        }
        return .result(dialog: "Starting climate at \(temperature)°.")
    }
}

struct StopClimateIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Climate"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await QuickCommands.run(.stopClimate)
        return .result(dialog: "Stopping climate.")
    }
}

/// Backs the Control Center lock toggle. `value == true` means locked.
struct SetCarLockedIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Set Car Lock"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Locked")
    var value: Bool

    func perform() async throws -> some IntentResult {
        try await QuickCommands.run(value ? .lock : .unlock)
        return .result()
    }
}

/// Widget buttons can't show dialogs, so they use these plain variants.
struct WidgetLockIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Lock"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Lock")
    var lock: Bool

    init() {}
    init(lock: Bool) { self.lock = lock }

    func perform() async throws -> some IntentResult {
        try await QuickCommands.run(lock ? .lock : .unlock)
        return .result()
    }
}

struct WidgetClimateIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Climate"
    static let isDiscoverable = false

    @Parameter(title: "On")
    var on: Bool

    init() {}
    init(on: Bool) { self.on = on }

    func perform() async throws -> some IntentResult {
        try await QuickCommands.run(on ? .startClimate(ClimatePresets.load()) : .stopClimate)
        return .result()
    }
}
