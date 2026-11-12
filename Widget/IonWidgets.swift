import AppIntents
import BetterBlueKit
import SwiftUI
import WidgetKit

@main
struct IonWidgets: WidgetBundle {
    var body: some Widget {
        CarWidget()
        ClimateLiveActivityWidget()
        ChargingLiveActivityWidget()
        LockControl()
        ClimateControl()
    }
}

// MARK: - Timeline

struct CarEntry: TimelineEntry {
    let date: Date
    let snapshot: CarSnapshot?
}

struct CarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarEntry { CarEntry(date: .now, snapshot: nil) }

    func getSnapshot(in context: Context, completion: @escaping (CarEntry) -> Void) {
        completion(CarEntry(date: .now, snapshot: SnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarEntry>) -> Void) {
        nonisolated(unsafe) let done = completion
        Task { @MainActor in
            // Server-cached status only: never wake the car from a widget.
            let snapshot = (try? await CarService.shared.refreshStatus(cached: true)) ?? SnapshotStore.load()
            let entry = CarEntry(date: .now, snapshot: snapshot)
            done(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }
}

// MARK: - Home / Lock Screen widget

struct CarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CarWidget", provider: CarProvider()) { entry in
            CarWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(white: 0.07) }
        }
        .configurationDisplayName("Car")
        .description("Charge, range and lock state at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct CarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CarEntry

    private var status: VehicleStatus? { entry.snapshot?.status }
    private var percent: Int { Int(status?.evStatus?.evRange.percentage ?? 0) }
    private var range: String {
        guard let range = status?.evStatus?.evRange.range else { return "--" }
        return "\(Int(range.length)) \(range.units.abbreviation)"
    }
    private var locked: Bool { status?.lockStatus != .unlocked }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(percent), in: 0...100) {
                Image(systemName: locked ? "lock.fill" : "lock.open.fill")
            } currentValueLabel: {
                Text("\(percent)")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label(locked ? "Locked" : "Unlocked", systemImage: locked ? "lock.fill" : "lock.open.fill")
                    .font(.headline)
                Text("\(percent)% · \(range)")
                ProgressView(value: Double(percent), total: 100)
            }
        case .systemMedium:
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    stats
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Button(intent: WidgetLockIntent(lock: !locked)) {
                            Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                                .frame(width: 34, height: 34)
                        }
                        Button(intent: WidgetClimateIntent(on: !(status?.climateStatus.airControlOn ?? false))) {
                            Image(systemName: "fan.fill").frame(width: 34, height: 34)
                        }
                        .tint(status?.climateStatus.airControlOn == true ? Color.ionViolet : .gray)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
                car
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                car
                Spacer(minLength: 0)
                stats
            }
        }
    }

    private var car: some View {
        // Widgets have a small image budget; the thumbnail keeps it under.
        Image("car-thumb-\((entry.snapshot?.appearance.paint ?? .default).id)")
            .resizable()
            .scaledToFit()
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(percent)%").font(.title2.weight(.semibold))
                if status?.evStatus?.charging == true {
                    Image(systemName: "bolt.fill").foregroundStyle(Color.ionViolet)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                Text(range)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Control Center

struct LockControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LockControl", provider: LockValueProvider()) { locked in
            ControlWidgetToggle("Car Lock", isOn: locked, action: SetCarLockedIntent()) { isOn in
                Label(isOn ? "Locked" : "Unlocked", systemImage: isOn ? "lock.fill" : "lock.open.fill")
            }
            .tint(Color.ionViolet)
        }
        .displayName("Car Lock")
        .description("Lock or unlock your car.")
    }
}

struct LockValueProvider: ControlValueProvider {
    var previewValue: Bool { true }
    func currentValue() async throws -> Bool {
        SnapshotStore.load()?.status?.lockStatus != .unlocked
    }
}

struct ClimateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ClimateControl") {
            ControlWidgetButton(action: StartClimateIntent()) {
                Label("Start Climate", systemImage: "fan.fill")
            }
        }
        .displayName("Start Climate")
    }
}

extension Color {
    /// Ion's accent. Widgets can't read the app's theme without the App Group,
    /// so they use the default Ion violet.
    static let ionViolet = Color(red: 0.514, green: 0.220, blue: 0.925)  // Blue Violet
}
