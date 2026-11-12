import BetterBlueKit
import Foundation

/// One charging session, built up from status snapshots while the car reports
/// it's charging. Bluelink US has no charging-history endpoint, so Ion keeps
/// its own: sessions are only as complete as how often status is read (the
/// app, the widget and a background refresh all feed it).
struct ChargeSession: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var start: Date
    var end: Date?
    var startPercent: Double
    var endPercent: Double
    var isDC: Bool
    var peakKW: Double
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    /// Last time a snapshot extended this session.
    var lastSeen: Date
    /// Exact figures from Hyundai's billing record, when this session was
    /// imported from (or matched to) Hyundai's charge history.
    var billedKWh: Double?
    var billedCost: Double?
    var network: String?
    var hyundaiOrderID: String?
    /// False for imported sessions, where Hyundai doesn't report battery %.
    var hasPercent: Bool = true

    var isActive: Bool { end == nil }
    var duration: TimeInterval { (end ?? lastSeen).timeIntervalSince(start) }
    var percentAdded: Double { max(0, endPercent - startPercent) }

    /// Energy you paid for: billed kWh, or battery % added grossed up by the
    /// charging efficiency (wall energy, including losses).
    func energyKWh(_ settings: ChargeSettings) -> Double {
        billedKWh ?? percentAdded / 100 * settings.batteryKWh / max(settings.chargingEfficiency, 0.5)
    }
    func cost(_ settings: ChargeSettings) -> Double {
        if let billedCost { return billedCost }
        if isDC { return energyKWh(settings) * settings.fastPricePerKWh }
        guard settings.timeOfUse else { return energyKWh(settings) * settings.homePricePerKWh }
        // Assume steady power across the session and split energy by how much
        // of it fell inside the off-peak window.
        let offPeak = settings.offPeakFraction(from: start, to: end ?? lastSeen)
        return energyKWh(settings) * (offPeak * settings.offPeakPricePerKWh + (1 - offPeak) * settings.homePricePerKWh)
    }
    var isBilled: Bool { billedCost != nil }
    func averageKW(_ settings: ChargeSettings) -> Double {
        duration > 60 ? energyKWh(settings) / (duration / 3600) : 0
    }
}

struct ChargeSettings: Codable, Equatable, Sendable {
    /// Usable pack size. 2025+ IONIQ 5 Long Range ≈ 84 kWh, Standard ≈ 63 kWh.
    var batteryKWh = 84.0
    /// Home price, or the standard (non-discounted) price when time-of-use is on.
    var homePricePerKWh = 0.15
    var fastPricePerKWh = 0.48
    /// Utility time-of-use discount (e.g. a night EV rate).
    var timeOfUse = false
    var offPeakPricePerKWh = 0.096
    /// Minutes after midnight. The window may wrap past midnight.
    var offPeakStartMinute = 21 * 60
    var offPeakEndMinute = 5 * 60
    /// Share of wall energy that reaches the battery on home charging. The
    /// portable charger that ships with the car runs at ~1.3 kW, where fixed
    /// overhead makes it less efficient than a wall-mounted Level 2 charger.
    var chargingEfficiency = 0.85

    init() {}

    // Tolerates settings saved before new fields existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ChargeSettings()
        batteryKWh = try c.decodeIfPresent(Double.self, forKey: .batteryKWh) ?? d.batteryKWh
        homePricePerKWh = try c.decodeIfPresent(Double.self, forKey: .homePricePerKWh) ?? d.homePricePerKWh
        fastPricePerKWh = try c.decodeIfPresent(Double.self, forKey: .fastPricePerKWh) ?? d.fastPricePerKWh
        timeOfUse = try c.decodeIfPresent(Bool.self, forKey: .timeOfUse) ?? d.timeOfUse
        offPeakPricePerKWh = try c.decodeIfPresent(Double.self, forKey: .offPeakPricePerKWh) ?? d.offPeakPricePerKWh
        offPeakStartMinute = try c.decodeIfPresent(Int.self, forKey: .offPeakStartMinute) ?? d.offPeakStartMinute
        offPeakEndMinute = try c.decodeIfPresent(Int.self, forKey: .offPeakEndMinute) ?? d.offPeakEndMinute
        chargingEfficiency = try c.decodeIfPresent(Double.self, forKey: .chargingEfficiency) ?? d.chargingEfficiency
    }

    /// Share of [start, end] that falls inside the off-peak window.
    func offPeakFraction(from start: Date, to end: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return isOffPeak(start) ? 1 : 0 }
        let step: TimeInterval = 5 * 60
        var t = start, inside: TimeInterval = 0
        while t < end {
            let slice = min(step, end.timeIntervalSince(t))
            if isOffPeak(t.addingTimeInterval(slice / 2)) { inside += slice }
            t = t.addingTimeInterval(slice)
        }
        return inside / total
    }

    func isOffPeak(_ date: Date) -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return offPeakStartMinute <= offPeakEndMinute
            ? (minute >= offPeakStartMinute && minute < offPeakEndMinute)
            : (minute >= offPeakStartMinute || minute < offPeakEndMinute)
    }
}

enum ChargeHistoryStore {
    private static var defaults: UserDefaults { UserDefaults(suiteName: AppConfig.appGroup) ?? .standard }
    private static let sessionsKey = "chargeSessions.v1"
    private static let settingsKey = "chargeSettings.v1"

    static func sessions() -> [ChargeSession] {
        guard let data = defaults.data(forKey: sessionsKey),
              let list = try? JSONDecoder().decode([ChargeSession].self, from: data) else { return [] }
        return list.sorted { $0.start > $1.start }
    }

    static func save(_ sessions: [ChargeSession]) {
        if let data = try? JSONEncoder().encode(sessions) { defaults.set(data, forKey: sessionsKey) }
    }

    static var settings: ChargeSettings {
        get {
            defaults.data(forKey: settingsKey).flatMap { try? JSONDecoder().decode(ChargeSettings.self, from: $0) }
                ?? ChargeSettings()
        }
        set { if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: settingsKey) } }
    }

    static func clear() {
        defaults.removeObject(forKey: sessionsKey)
    }

    /// Folds a new status snapshot into the history. Returns the session that
    /// was just started, if any, so the caller can look up its place name.
    @discardableResult
    static func record(_ status: VehicleStatus) -> ChargeSession? {
        guard let ev = status.evStatus else { return nil }
        let now = status.syncDate ?? status.lastUpdated
        let percent = ev.evRange.percentage
        var list = sessions()
        let activeIndex = list.firstIndex { $0.isActive }
        var started: ChargeSession?

        if ev.charging {
            if let i = activeIndex, now.timeIntervalSince(list[i].lastSeen) < 6 * 3600 {
                list[i].endPercent = max(list[i].endPercent, percent)
                list[i].peakKW = max(list[i].peakKW, ev.chargeSpeed)
                list[i].isDC = list[i].isDC || ev.plugType == .dcCharger
                list[i].lastSeen = max(list[i].lastSeen, now)
            } else {
                if let i = activeIndex { list[i].end = list[i].lastSeen } // stale; close it
                let location = status.location.hasCoordinates ? status.location : nil
                let session = ChargeSession(
                    start: now, startPercent: percent, endPercent: percent,
                    isDC: ev.plugType == .dcCharger, peakKW: ev.chargeSpeed,
                    latitude: location?.latitude, longitude: location?.longitude, lastSeen: now
                )
                list.append(session)
                started = session
            }
        } else if let i = activeIndex {
            list[i].endPercent = max(list[i].endPercent, percent)
            list[i].end = max(list[i].lastSeen, min(now, list[i].lastSeen.addingTimeInterval(3600)))
            if list[i].percentAdded < 1 { list.remove(at: i) } // a blip, not a session
        }
        save(list)
        return started
    }

    /// Folds Hyundai's billed charging sessions into the history. A billed
    /// session that overlaps one Ion recorded is merged into it (Ion keeps the
    /// battery %, Hyundai supplies exact kWh and cost); the rest are added.
    static func importOrders(_ orders: [HyundaiExtras.ChargeOrder]) {
        var list = sessions()
        for order in orders {
            if list.contains(where: { $0.hyundaiOrderID == order.id }) { continue }
            let avgKW = order.kWh / max(order.stop.timeIntervalSince(order.start) / 3600, 1.0 / 60)
            let place = [order.street, order.city].compactMap { $0 }.joined(separator: ", ")
            if let i = list.firstIndex(where: { recorded in
                recorded.hyundaiOrderID == nil &&
                    recorded.start < order.stop.addingTimeInterval(1800) &&
                    (recorded.end ?? recorded.lastSeen) > order.start.addingTimeInterval(-1800)
            }) {
                list[i].billedKWh = order.kWh
                list[i].billedCost = order.price
                list[i].network = order.network
                list[i].hyundaiOrderID = order.id
                if list[i].placeName == nil, !place.isEmpty { list[i].placeName = place }
            } else {
                list.append(ChargeSession(
                    start: order.start, end: order.stop, startPercent: 0, endPercent: 0,
                    isDC: avgKW > 20, peakKW: avgKW,
                    placeName: place.isEmpty ? order.station : place,
                    lastSeen: order.stop,
                    billedKWh: order.kWh, billedCost: order.price, network: order.network,
                    hyundaiOrderID: order.id, hasPercent: false
                ))
            }
        }
        save(list)
    }

    static func setPlaceName(_ name: String, for id: UUID) {
        var list = sessions()
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        list[i].placeName = name
        save(list)
    }

    /// Plausible sample sessions for the demo account.
    static func seedDemo() {
        guard sessions().isEmpty else { return }
        var list: [ChargeSession] = []
        let calendar = Calendar.current
        var rng = SystemRandomNumberGenerator()
        for daysAgo in stride(from: 58, through: 1, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            let roll = Double.random(in: 0...1, using: &rng)
            if roll < 0.08 {
                // Road-trip fast charge in the afternoon
                let start = calendar.date(bySettingHour: Int.random(in: 11...16), minute: Int.random(in: 0...59), second: 0, of: day)!
                let from = Double(Int.random(in: 12...28)), to = Double(Int.random(in: 78...84))
                let minutes = (to - from) * 0.33 + Double.random(in: 2...6)
                list.append(.init(start: start, end: start.addingTimeInterval(minutes * 60), startPercent: from,
                                  endPercent: to, isDC: true, peakKW: Double(Int.random(in: 168...232)),
                                  placeName: ["Highway Fast Charger", "Travel Plaza DC", "Mall Fast Charge"].randomElement(),
                                  lastSeen: start.addingTimeInterval(minutes * 60)))
            } else if roll < 0.42 {
                // Overnight at home on Level 2
                let start = calendar.date(bySettingHour: Int.random(in: 19...22), minute: Int.random(in: 0...59), second: 0, of: day)!
                let from = Double(Int.random(in: 28...62)), to = 80.0
                let hours = (to - from) / 100 * 84 / 10.5
                list.append(.init(start: start, end: start.addingTimeInterval(hours * 3600), startPercent: from,
                                  endPercent: to, isDC: false, peakKW: Double.random(in: 10.4...10.9),
                                  placeName: "Home", lastSeen: start.addingTimeInterval(hours * 3600)))
            }
        }
        save(list)
    }
}
