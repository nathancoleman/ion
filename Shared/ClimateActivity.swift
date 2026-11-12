import ActivityKit
import BetterBlueKit
import Foundation

/// Live Activity shown while pre-conditioning the cabin.
///
/// Bluelink doesn't report cabin temperature, so "progress" is an estimate:
/// how far the outside temperature is from the target sets the warm-up time,
/// and the timeline runs from when the car confirms climate is on.
struct ClimateActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable { case sending, waitingForCar, running, failed }
        var phase: Phase
        /// When the cabin started conditioning (car confirmed, or best guess).
        var startedAt: Date
        /// Estimated time the cabin reaches the target.
        var readyAt: Date
        /// When the car will switch climate off on its own.
        var endsAt: Date
        var outsideTemp: Int?
        var message: String?
    }

    var targetTemp: Int
    var carName: String
    var paintID: String
}

extension ClimateActivityAttributes.ContentState {
    var isHeating: Bool { (outsideTemp ?? 50) < 70 }
}

@MainActor
enum ClimateLiveActivity {
    private static var current: Activity<ClimateActivityAttributes>?

    /// Starts (or restarts) the activity. Safe to call from the app or a
    /// LiveActivityIntent; does nothing where Live Activities aren't allowed.
    static func start(options: ClimateOptions) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await endAll()

        let snapshot = SnapshotStore.load()
        let target = Int(options.temperature.units.convert(options.temperature.value, to: .fahrenheit).rounded())
        let outside = await outsideTemperature(snapshot?.status?.location)
        let now = Date()
        let state = estimate(phase: .sending, start: now, target: target, outside: outside, duration: options.duration)
        let attributes = ClimateActivityAttributes(
            targetTemp: target,
            carName: snapshot?.vehicle.model ?? "Car",
            paintID: snapshot?.appearance.paint.id ?? PaintColor.default.id
        )
        current = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: state.endsAt),
            pushType: nil
        )
    }

    static func update(_ phase: ClimateActivityAttributes.ContentState.Phase, message: String? = nil) async {
        guard let found = current ?? Activity<ClimateActivityAttributes>.activities.first else { return }
        // Activity is thread-safe; ActivityKit just doesn't mark it Sendable.
        nonisolated(unsafe) let activity = found
        var state = activity.content.state
        if phase == .running, state.phase != .running {
            // Re-anchor the timeline to when the car actually started.
            let duration = state.endsAt.timeIntervalSince(state.startedAt)
            let warmup = state.readyAt.timeIntervalSince(state.startedAt)
            state.startedAt = Date()
            state.readyAt = state.startedAt.addingTimeInterval(warmup)
            state.endsAt = state.startedAt.addingTimeInterval(duration)
        }
        state.phase = phase
        state.message = message
        let content = ActivityContent(state: state, staleDate: state.endsAt)
        switch phase {
        case .running:
            // End now but keep it on screen until the car's auto-off. The
            // timers keep counting without the app running.
            await activity.end(content, dismissalPolicy: .after(state.endsAt))
            current = nil
        case .failed:
            await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(30)))
            current = nil
        default:
            await activity.update(content)
        }
    }

    static func endAll() async {
        for activity in Activity<ClimateActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        current = nil
    }

    static func estimate(
        phase: ClimateActivityAttributes.ContentState.Phase,
        start: Date, target: Int, outside: Int?, duration: Int
    ) -> ClimateActivityAttributes.ContentState {
        // Rough heat-pump numbers: about 4°F of difference per minute, at least 3 min.
        let minutes: Double = outside.map { min(max(Double(abs(target - $0)) / 4, 3), Double(duration)) }
            ?? min(8, Double(duration))
        return .init(
            phase: phase,
            startedAt: start,
            readyAt: start.addingTimeInterval(minutes * 60),
            endsAt: start.addingTimeInterval(Double(duration) * 60),
            outsideTemp: outside
        )
    }

    /// Current outside temperature at the car from Open-Meteo (free, no key).
    /// Location is rounded to about 1 km.
    private static func outsideTemperature(_ location: VehicleStatus.Location?) async -> Int? {
        guard let location, location.hasCoordinates else { return nil }
        let lat = String(format: "%.2f", location.latitude), lon = String(format: "%.2f", location.longitude)
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m&temperature_unit=fahrenheit"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let temp = current["temperature_2m"] as? Double else { return nil }
        return Int(temp.rounded())
    }
}
