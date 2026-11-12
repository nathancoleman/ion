import ActivityKit
import SwiftUI
import WidgetKit

struct ChargingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChargingActivityAttributes.self) { context in
            ChargingLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(white: 0.06).opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let tint = context.attributes.tint
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(state.percent)%", systemImage: state.phase == .charging ? "bolt.fill" : "checkmark")
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if state.phase == .charging {
                        // Hours and minutes only; seconds aren't useful for a charge.
                        Text(.currentDate, format: .reference(to: state.readyAt, allowedFields: [.hour, .minute], maxFieldCount: 2))
                            .font(.headline)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ChargingProgress(state: state, tint: tint)
                }
            } compactLeading: {
                Image(systemName: "bolt.fill").foregroundStyle(tint)
            } compactTrailing: {
                Text("\(state.percent)%").monospacedDigit().foregroundStyle(tint)
            } minimal: {
                Image(systemName: "bolt.fill").foregroundStyle(tint)
            }
        }
    }
}

extension ChargingActivityAttributes {
    var tint: Color {
        accentRGB.count == 3 ? Color(red: accentRGB[0], green: accentRGB[1], blue: accentRGB[2]) : .white
    }
}

struct ChargingLockScreenView: View {
    let attributes: ChargingActivityAttributes
    let state: ChargingActivityAttributes.ContentState

    private var paint: PaintColor { PaintColor.find(id: attributes.paintID) ?? .default }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: state.phase == .charging ? "bolt.fill" : "checkmark.circle.fill")
                            .foregroundStyle(attributes.tint)
                        Text(headline).font(.headline)
                    }
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                // Live Activities can only draw small images, so use the thumbnail.
                Image("car-thumb-\(paint.id)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104)
            }
            ChargingProgress(state: state, tint: attributes.tint)
        }
        .padding(16)
        .foregroundStyle(.white)
    }

    private var headline: String {
        switch state.phase {
        case .charging: "Charging · \(state.percent)%"
        case .complete: "Charged to \(state.percent)%"
        case .stopped: "Charging stopped at \(state.percent)%"
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if state.phase == .charging, state.powerKW > 0 { parts.append(String(format: "%.1f kW", state.powerKW)) }
        parts.append("\(state.range) \(attributes.rangeUnit) range")
        return parts.joined(separator: " · ")
    }
}

/// Battery bar from the last reading toward the limit. Between refreshes the
/// fill keeps moving from the estimate, so it isn't frozen with the app closed.
struct ChargingProgress: View {
    let state: ChargingActivityAttributes.ContentState
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let start = Double(state.percent) / 100
                let end = max(Double(state.limit) / 100, start)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(tint).frame(width: width * start)
                    if state.phase == .charging, end > start {
                        // The estimated gain since the last refresh, filling over time.
                        ProgressView(timerInterval: state.updatedAt...max(state.readyAt, state.updatedAt.addingTimeInterval(60)),
                                     countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                            .progressViewStyle(.linear)
                            .tint(tint.opacity(0.55))
                            .frame(width: width * (end - start))
                            .offset(x: width * start)
                    }
                    Rectangle().fill(.white.opacity(0.7))
                        .frame(width: 2, height: 10)
                        .offset(x: width * end - 1)
                }
            }
            .frame(height: 6)
            HStack {
                if state.phase == .charging {
                    Text("\(state.limit)% \(Text(.currentDate, format: .reference(to: state.readyAt, allowedFields: [.hour, .minute], maxFieldCount: 2)))")
                } else {
                    Text("Limit \(state.limit)%")
                }
                Spacer()
                Text("Updated \(state.updatedAt, style: .relative) ago")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview("Lock Screen", as: .content, using: ChargingActivityAttributes(
    carName: "IONIQ 5", paintID: "cyber-gray", rangeUnit: "mi", accentRGB: [0.66, 0.52, 1.0])) {
    ChargingLiveActivityWidget()
} contentStates: {
    ChargingActivityAttributes.ContentState(phase: .charging, percent: 48, limit: 80, powerKW: 7.2, range: 151,
                                            updatedAt: .now, readyAt: .now.addingTimeInterval(4 * 3600))
}
