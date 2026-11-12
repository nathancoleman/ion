import ActivityKit
import SwiftUI
import WidgetKit

struct ClimateLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClimateActivityAttributes.self) { context in
            ClimateLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(white: 0.06).opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let tint = state.isHeating ? Color.orange : Color.cyan
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.attributes.targetTemp)°", systemImage: state.isHeating ? "heat.waves" : "snowflake")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if state.phase == .running {
                        Text(timerInterval: Date.now...max(state.readyAt, .now), countsDown: true)
                            .font(.title2.monospacedDigit())
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ClimateProgress(state: state, tint: tint)
                }
            } compactLeading: {
                Image(systemName: state.isHeating ? "heat.waves" : "snowflake").foregroundStyle(tint)
            } compactTrailing: {
                if state.phase == .running {
                    Text(timerInterval: Date.now...max(state.readyAt, .now), countsDown: true)
                        .monospacedDigit()
                        .frame(width: 42)
                } else {
                    ProgressView().controlSize(.mini)
                }
            } minimal: {
                Image(systemName: state.isHeating ? "heat.waves" : "snowflake").foregroundStyle(tint)
            }
        }
    }
}

struct ClimateLockScreenView: View {
    let attributes: ClimateActivityAttributes
    let state: ClimateActivityAttributes.ContentState

    private var tint: Color { state.isHeating ? .orange : .cyan }
    private var paint: PaintColor { PaintColor.find(id: attributes.paintID) ?? .default }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                // Live Activities can only draw small images, so use the thumbnail.
                Image("car-thumb-\(paint.id)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104)
            }
            ClimateProgress(state: state, tint: tint)
        }
        .padding(16)
        .foregroundStyle(.white)
    }

    private var headline: String {
        switch state.phase {
        case .sending: "Sending to \(attributes.carName)…"
        case .waitingForCar: "Waiting for the car…"
        case .running: "\(state.isHeating ? "Warming" : "Cooling") to \(attributes.targetTemp)°"
        case .failed: "Climate didn't start"
        }
    }

    private var subtitle: String {
        if let message = state.message { return message }
        let outside = state.outsideTemp.map { "\($0)° outside · " } ?? ""
        return outside + "Auto-off at \(state.endsAt.formatted(date: .omitted, time: .shortened))"
    }
}

/// Estimated progress bar plus "ready in" countdown. Both animate on their
/// own from the timestamps, so they keep moving with the app closed.
struct ClimateProgress: View {
    let state: ClimateActivityAttributes.ContentState
    let tint: Color

    var body: some View {
        if state.phase == .failed {
            EmptyView()
        } else if state.phase == .running {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(timerInterval: state.startedAt...state.readyAt, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(tint)
                HStack {
                    Text("Est. ready")
                    Text(timerInterval: state.startedAt...state.readyAt, countsDown: true)
                        .monospacedDigit()
                    Spacer()
                    Text("Off in")
                    Text(timerInterval: state.startedAt...state.endsAt, countsDown: true)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else {
            ProgressView().progressViewStyle(.linear).tint(tint)
        }
    }
}

#Preview("Lock Screen", as: .content, using: ClimateActivityAttributes(targetTemp: 72, carName: "My IONIQ 5", paintID: "cyber-gray")) {
    ClimateLiveActivityWidget()
} contentStates: {
    ClimateLiveActivity.estimate(phase: .running, start: .now, target: 72, outside: 34, duration: 15)
}
