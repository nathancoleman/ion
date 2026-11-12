import ActivityKit
import BetterBlueKit
import Foundation

/// Live Activity for a charging session: battery level, power, and an
/// estimated finish that counts down on its own between refreshes.
struct ChargingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable { case charging, complete, stopped }
        var phase: Phase
        /// Battery level at the last refresh.
        var percent: Int
        var limit: Int
        var powerKW: Double
        var range: Int
        /// When the last refresh happened; the countdown and bar run from here.
        var updatedAt: Date
        /// Estimated time the battery reaches the limit.
        var readyAt: Date
    }

    var carName: String
    var paintID: String
    var rangeUnit: String
    /// Theme accent at start, so the activity matches the app.
    var accentRGB: [Double]
}

@MainActor
enum ChargingLiveActivity {
    /// Set by the app from its theme (the lock screen is always dark, so
    /// this is the theme's bright variant).
    static var accentRGB: [Double] = [0.514, 0.220, 0.925]

    /// Starts, updates or ends the activity to match the latest status.
    /// Called after every status refresh (app, widget intents, background).
    static func sync(_ snapshot: CarSnapshot) async {
        guard let ev = snapshot.status?.evStatus else { return }
        let existing = Activity<ChargingActivityAttributes>.activities.first { $0.activityState == .active }
        let limit = Int(ev.targetSocAC ?? 100)
        let percent = Int(ev.evRange.percentage.rounded())
        let seconds = Double(ev.chargeTime.components.seconds)
        let now = Date()
        let state = ChargingActivityAttributes.ContentState(
            phase: ev.charging ? .charging : percent >= limit - 1 ? .complete : .stopped,
            percent: percent, limit: limit, powerKW: ev.chargeSpeed,
            range: Int(ev.evRange.range.length), updatedAt: now,
            readyAt: now.addingTimeInterval(seconds > 0 ? seconds : 3600)
        )

        if ev.charging {
            let content = ActivityContent(state: state, staleDate: state.readyAt.addingTimeInterval(15 * 60))
            if let existing {
                nonisolated(unsafe) let activity = existing
                await activity.update(content)
            } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                let attributes = ChargingActivityAttributes(
                    carName: snapshot.vehicle.model,
                    paintID: snapshot.appearance.paint.id,
                    rangeUnit: ev.evRange.range.units.abbreviation,
                    accentRGB: accentRGB
                )
                _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
            }
        } else if let existing {
            // Show how it ended for a few minutes, then go away.
            nonisolated(unsafe) let activity = existing
            await activity.end(ActivityContent(state: state, staleDate: nil),
                               dismissalPolicy: .after(now.addingTimeInterval(15 * 60)))
        }
    }
}
