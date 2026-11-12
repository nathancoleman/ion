import Charts
import MapKit
import SwiftUI

/// Charging history: a spend summary across public and home charging, a
/// monthly energy chart, and a running list of every session.
struct ChargingHistoryView: View {
    @State private var sessions = ChargeHistoryStore.sessions()
    @State private var settings = ChargeHistoryStore.settings
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!
    @State private var selectedDay: Date?
    @State private var showSettings = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var spendRange: SpendRange = .year
    @State private var visibleCount = 20

    enum SpendRange: String, CaseIterable, Identifiable {
        case days30 = "30 days", year = "This year", all = "All time"
        var id: String { rawValue }
        func contains(_ date: Date) -> Bool {
            switch self {
            case .days30: date > Date().addingTimeInterval(-30 * 86400)
            case .year: Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
            case .all: true
            }
        }
    }

    static let acColor = Color(red: 0x22 / 255, green: 0xA2 / 255, blue: 0x74 / 255)
    static let dcColor = Color(red: 0x8A / 255, green: 0x7C / 255, blue: 0xFF / 255)

    private var monthSessions: [ChargeSession] { sessions.filter { month.contains($0.start) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isImporting {
                    Label("Loading Hyundai charge history…", systemImage: "arrow.down.circle")
                        .font(.caption).foregroundStyle(.secondary)
                } else if let importError {
                    Text(importError).font(.caption).foregroundStyle(.orange)
                }
                spendSummary
                chart
                sessionList
            }
            .padding(20)
        }
        .ionScreen(focusY: 0.2)
        .navigationTitle("Charging History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Rates", systemImage: "slider.horizontal.3") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            ChargeSettingsSheet(settings: $settings)
                .presentationDetents([.large])
                .ionAppearance()
        }
        .onChange(of: settings) { _, new in ChargeHistoryStore.settings = new }
        .task {
            sessions = ChargeHistoryStore.sessions()
            isImporting = true
            do {
                try await CarService.shared.importChargeHistory()
                importError = nil
            } catch {
                importError = "Couldn't load Hyundai's charge history: \(error.localizedDescription)"
            }
            isImporting = false
            sessions = ChargeHistoryStore.sessions()
        }
        .refreshable {
            try? await CarService.shared.importChargeHistory()
            sessions = ChargeHistoryStore.sessions()
        }
    }

    // MARK: Spend

    /// Public = sessions Hyundai billed (exact cost). Home & other = sessions
    /// Ion recorded itself, priced at your home rate.
    private var spendSummary: some View {
        let inRange = sessions.filter { spendRange.contains($0.start) }
        let publicSessions = inRange.filter(\.isBilled)
        let homeSessions = inRange.filter { !$0.isBilled }
        let publicCost = publicSessions.reduce(0) { $0 + $1.cost(settings) }
        let homeCost = homeSessions.reduce(0) { $0 + $1.cost(settings) }
        let publicKWh = publicSessions.reduce(0) { $0 + $1.energyKWh(settings) }
        let homeKWh = homeSessions.reduce(0) { $0 + $1.energyKWh(settings) }
        let total = publicCost + homeCost
        let totalKWh = publicKWh + homeKWh

        return VStack(alignment: .leading, spacing: 14) {
            Picker("Range", selection: $spendRange) {
                ForEach(SpendRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 2) {
                Text("Total spend").font(.caption).foregroundStyle(.secondary)
                Text(total.formatted(.currency(code: "USD")))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text("\(Int(totalKWh.rounded())) kWh · \(inRange.count) sessions" +
                     (totalKWh > 0 ? " · \((total / totalKWh).formatted(.currency(code: "USD")))/kWh avg" : ""))
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Share of spend, public vs home
            if total > 0 {
                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4).fill(Self.dcColor)
                            .frame(width: max(0, proxy.size.width * publicCost / total - 1))
                        RoundedRectangle(cornerRadius: 4).fill(Self.acColor)
                    }
                }
                .frame(height: 8)
            }

            HStack(alignment: .top, spacing: 12) {
                spendBreakdown("Public", color: Self.dcColor, cost: publicCost, kWh: publicKWh,
                               count: publicSessions.count, note: "Billed by Hyundai")
                spendBreakdown("Home & other", color: Self.acColor, cost: homeCost, kWh: homeKWh,
                               count: homeSessions.count,
                               note: settings.timeOfUse
                                   ? "Est. with off-peak rate"
                                   : "Est. at \(settings.homePricePerKWh.formatted(.currency(code: "USD")))/kWh")
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.hairline))
        .animation(.default, value: spendRange)
    }

    private func spendBreakdown(_ title: String, color: Color, cost: Double, kWh: Double, count: Int, note: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
                Text(title).font(.caption.weight(.semibold))
            }
            Text(cost.formatted(.currency(code: "USD"))).font(.headline).monospacedDigit()
            Text("\(Int(kWh.rounded())) kWh · \(count) sessions").font(.caption2).foregroundStyle(.secondary)
            Text(note).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shiftMonth(_ delta: Int) {
        guard let date = Calendar.current.date(byAdding: .month, value: delta, to: month.start),
              let interval = Calendar.current.dateInterval(of: .month, for: date) else { return }
        withAnimation { month = interval; selectedDay = nil }
    }

    // MARK: Chart

    private struct DayEnergy: Identifiable {
        let day: Date
        let kind: String
        let kWh: Double
        var id: String { "\(day.timeIntervalSince1970)-\(kind)" }
    }

    private var dailyEnergy: [DayEnergy] {
        let calendar = Calendar.current
        var buckets: [Date: (ac: Double, dc: Double)] = [:]
        for session in monthSessions {
            let day = calendar.startOfDay(for: session.start)
            var value = buckets[day] ?? (0, 0)
            if session.isDC { value.dc += session.energyKWh(settings) } else { value.ac += session.energyKWh(settings) }
            buckets[day] = value
        }
        return buckets.flatMap { day, v in
            [DayEnergy(day: day, kind: "Level 2", kWh: v.ac), DayEnergy(day: day, kind: "Fast charging", kWh: v.dc)]
                .filter { $0.kWh > 0 }
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                VStack(spacing: 1) {
                    Text(month.start, format: .dateTime.month(.wide).year()).font(.subheadline.weight(.semibold))
                    Text("\(Int(monthSessions.reduce(0) { $0 + $1.energyKWh(settings) }.rounded())) kWh")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(month.end > .now)
            }
            .buttonStyle(.plain)
            HStack(spacing: 12) {
                Text("Energy per day").font(.caption).foregroundStyle(.secondary)
                Spacer()
                legendItem("Level 2", Self.acColor)
                legendItem("Fast charging", Self.dcColor)
            }
            Chart {
                ForEach(dailyEnergy) { item in
                    BarMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("kWh", item.kWh)
                    )
                    .foregroundStyle(by: .value("Type", item.kind))
                    .cornerRadius(4)
                    .opacity(selectedDay == nil || Calendar.current.isDate(item.day, inSameDayAs: selectedDay!) ? 1 : 0.35)
                }
                if let selectedDay, let total = dayTotal(selectedDay) {
                    RuleMark(x: .value("Day", selectedDay, unit: .day))
                        .foregroundStyle(Color.primary.opacity(0.25))
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            VStack(spacing: 2) {
                                Text(selectedDay, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("\(total, specifier: "%.1f") kWh").font(.caption.weight(.semibold))
                            }
                            .padding(6)
                            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
                        }
                }
            }
            .chartForegroundStyleScale(["Level 2": Self.acColor, "Fast charging": Self.dcColor])
            .chartLegend(.hidden)
            .chartXScale(domain: month.start...month.end)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.day(), centered: true).foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel().foregroundStyle(.secondary)
                }
            }
            .chartXSelection(value: $selectedDay)
            .frame(height: 180)
            .overlay {
                if dailyEnergy.isEmpty {
                    Text("No charging this month").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.hairline))
    }

    private func dayTotal(_ day: Date) -> Double? {
        let total = dailyEnergy.filter { Calendar.current.isDate($0.day, inSameDayAs: day) }.reduce(0) { $0 + $1.kWh }
        return total > 0 ? total : nil
    }

    private func legendItem(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Sessions

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sessions").font(.subheadline.weight(.semibold))
                Spacer()
                if !sessions.isEmpty {
                    Text("\(sessions.count) total").font(.caption).foregroundStyle(.secondary)
                }
            }
            if sessions.isEmpty {
                Text("Ion records sessions from your car's status while it charges, and imports public charging billed by Hyundai.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(sessions.prefix(visibleCount)) { session in
                NavigationLink {
                    ChargeSessionDetail(session: session, settings: settings)
                } label: {
                    SessionRow(session: session, settings: settings)
                }
                .buttonStyle(.plain)
            }
            if sessions.count > visibleCount {
                Button {
                    withAnimation { visibleCount += 20 }
                } label: {
                    Text("Show \(min(20, sessions.count - visibleCount)) more")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

func hoursText(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}

struct StatTile: View {
    let title: String
    let value: String
    let unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(.title2, design: .rounded).weight(.semibold)).monospacedDigit()
                if let unit { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))
    }
}

struct SessionRow: View {
    let session: ChargeSession
    let settings: ChargeSettings

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.isDC ? "bolt.fill" : "house.fill")
                .foregroundStyle(session.isDC ? ChargingHistoryView.dcColor : ChargingHistoryView.acColor)
                .frame(width: 34, height: 34)
                .background(Theme.surfaceRaised, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.placeName ?? (session.isDC ? "Fast charger" : "Level 2"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if session.isActive {
                        Text("LIVE").font(.caption2.weight(.bold)).padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Theme.accent.opacity(0.18), in: Capsule()).foregroundStyle(Theme.accent)
                    }
                }
                Text(session.start, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.energyKWh(settings), specifier: "%.1f") kWh").font(.subheadline.weight(.medium))
                Text(session.hasPercent
                     ? "+\(Int(session.percentAdded))% · \(hoursText(session.duration))"
                     : "\(session.cost(settings).formatted(.currency(code: "USD"))) · \(hoursText(session.duration))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))
    }
}

struct ChargeSessionDetail: View {
    let session: ChargeSession
    let settings: ChargeSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let lat = session.latitude, let lon = session.longitude {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 1200))) {
                        Marker(session.placeName ?? "Charging", systemImage: "bolt.fill", coordinate: coordinate)
                            .tint(session.isDC ? ChargingHistoryView.dcColor : ChargingHistoryView.acColor)
                    }
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if session.hasPercent {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(Int(session.startPercent))%").monospacedDigit()
                        Spacer()
                        Text("\(Int(session.endPercent))%").monospacedDigit()
                    }
                    .font(.headline)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surfaceRaised)
                            Capsule()
                                .fill(session.isDC ? ChargingHistoryView.dcColor : ChargingHistoryView.acColor)
                                .frame(width: proxy.size.width * session.endPercent / 100)
                            Capsule()
                                .fill(Color.primary.opacity(0.35))
                                .frame(width: proxy.size.width * session.startPercent / 100)
                        }
                    }
                    .frame(height: 8)
                    Text("Battery added").font(.caption).foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.hairline))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(title: "Energy", value: String(format: "%.1f", session.energyKWh(settings)), unit: "kWh")
                    StatTile(title: session.isBilled ? "Cost" : "Est. cost",
                             value: session.cost(settings).formatted(.currency(code: "USD")), unit: nil)
                    StatTile(title: "Duration", value: hoursText(session.duration), unit: nil)
                    StatTile(title: "Type", value: session.isDC ? "DC fast" : "Level 2", unit: nil)
                    StatTile(title: "Average", value: String(format: "%.1f", session.averageKW(settings)), unit: "kW")
                    if session.hasPercent {
                        StatTile(title: "Peak seen", value: String(format: "%.0f", session.peakKW), unit: "kW")
                    }
                    if let network = session.network {
                        StatTile(title: "Network", value: network, unit: nil)
                    }
                }

                Text(session.isBilled
                     ? "Energy and cost are from Hyundai's billing record for this session."
                     : "Energy is estimated from battery % added, a \(Int(settings.batteryKWh)) kWh pack and \(Int(settings.chargingEfficiency * 100))% charging efficiency, so it reflects what came from the wall. Peak is the highest power Ion saw while checking status.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .ionScreen(focusY: 0.2)
        .navigationTitle(session.start.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ChargeSettingsSheet: View {
    @Binding var settings: ChargeSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Battery", selection: $settings.batteryKWh) {
                        Text("Long Range · 84 kWh").tag(84.0)
                        Text("Standard · 63 kWh").tag(63.0)
                    }
                    Picker("Home charger", selection: $settings.chargingEfficiency) {
                        Text("Portable (came with car) · 85%").tag(0.85)
                        Text("Wall-mounted Level 2 · 90%").tag(0.90)
                    }
                } footer: {
                    Text("Ion turns battery % into the energy you pay for: % × pack size ÷ charger efficiency (losses in the cable and car).")
                }
                Section {
                    Toggle("Time-of-use discount", isOn: $settings.timeOfUse)
                    if settings.timeOfUse {
                        rateField("Off-peak", value: $settings.offPeakPricePerKWh)
                        DatePicker("Off-peak starts", selection: minuteBinding($settings.offPeakStartMinute),
                                   displayedComponents: .hourAndMinute)
                        DatePicker("Off-peak ends", selection: minuteBinding($settings.offPeakEndMinute),
                                   displayedComponents: .hourAndMinute)
                        rateField("Other hours", value: $settings.homePricePerKWh)
                    } else {
                        rateField("Home", value: $settings.homePricePerKWh)
                    }
                } header: {
                    Text("Home electricity")
                } footer: {
                    Text(settings.timeOfUse
                         ? "Home sessions are priced by how much of each charge fell inside the off-peak window. Use the hours and prices on your utility bill or EV rate."
                         : "Turn on if your utility discounts certain hours, like an overnight EV rate.")
                }
                Section {
                    rateField("Fast charging", value: $settings.fastPricePerKWh)
                } header: {
                    Text("Public charging")
                } footer: {
                    Text("Only used for fast charges Hyundai didn't bill. Billed sessions use their actual price.")
                }
            }
            .ionForm()
            .navigationTitle("Rates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(minutes.wrappedValue * 60)) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func rateField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0.15", value: value, format: .currency(code: "USD").precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text("/kWh").foregroundStyle(.secondary)
        }
    }
}
