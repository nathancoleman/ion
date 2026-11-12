import BetterBlueKit
import MapKit
import SwiftUI

struct DashboardView: View {
    @Environment(CarStore.self) private var store
    @State private var sheet: Sheet?
    @State private var carAngle: CarView.Angle = .front

    enum Sheet: String, Identifiable {
        case climate, charging, settings, surroundView
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    hero
                    cards.padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .refreshable { await store.refresh() }
            .ionScreen(focusY: 0.3)
            .overlay(alignment: .bottom) { PendingBanner(pending: store.pending) }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .task {
                // `-openSettings` (debug launch argument) opens Settings for screenshots.
                if ProcessInfo.processInfo.arguments.contains("-openSettings") { sheet = .settings }
                if ProcessInfo.processInfo.arguments.contains("-openSurround") { sheet = .surroundView }
                await store.onAppear()
            }
            .sheet(item: $sheet) { sheet in
                Group {
                    switch sheet {
                    case .climate: ClimateSheet()
                    case .charging: ChargingSheet()
                    case .settings: SettingsView()
                    case .surroundView: SurroundViewSheet()
                    }
                }
                .ionAppearance()
            }
            .alert("Bluelink", isPresented: errorBinding) {
                Button("OK") { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                (Text(modelParts.name).font(.system(size: 38, weight: .heavy, design: .rounded))
                 + Text(modelParts.number.isEmpty ? "" : " \(modelParts.number)")
                    .font(.system(size: 38, weight: .light, design: .rounded)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text([store.appearance.make, store.snapshot?.vehicle.model].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                CircleIconButton(systemImage: store.isWaking ? "hourglass" : "arrow.clockwise",
                                 label: "Wake car for live status") {
                    Task { await store.wake() }
                }
                .disabled(store.isWaking)
                CircleIconButton(systemImage: "gearshape.fill", label: "Settings") { sheet = .settings }
            }
            .padding(.top, 6)
        }
        .padding(.top, 8)
    }

    /// "IONIQ 5" → ("IONIQ", "5") for the heavy/light title treatment.
    private var modelParts: (name: String, number: String) {
        let model = store.appearance.model
        let words = model.split(separator: " ")
        guard words.count > 1, let last = words.last else { return (model, "") }
        return (words.dropLast().joined(separator: " "), String(last))
    }

    private var statusLine: String {
        guard let status = store.status else {
            return store.isRefreshing ? "Loading…" : store.appearance.title
        }
        var parts: [String] = []
        if let ev = status.evStatus, ev.charging {
            parts.append("Charging")
        } else if status.evStatus?.pluggedIn == true {
            parts.append("Plugged in")
        } else {
            parts.append("Parked")
        }
        if status.climateStatus.airControlOn { parts.append("Climate on") }
        parts.append(status.lockStatus == .unlocked ? "Unlocked" : "Locked")
        return parts.joined(separator: " · ")
    }

    // MARK: Hero

    private var hero: some View {
        let status = store.status
        let climateOn = status?.climateStatus.airControlOn ?? false
        let charging = status?.evStatus?.charging ?? false
        let plugged = status?.evStatus?.pluggedIn ?? false

        return VStack(spacing: 18) {
            carCarousel

            HStack(spacing: 12) {
                ControlTile(systemImage: "fan.fill",
                            title: climateOn ? "\(Int(status?.climateStatus.temperature.value ?? 72))°" : "Climate",
                            isActive: climateOn, isBusy: isBusy(.climateOn) || isBusy(.climateOff)) {
                    if climateOn { store.perform(.climateOff, .stopClimate) }
                    else { store.perform(.climateOn, .startClimate(ClimatePresets.load())) }
                }
                .contextMenu { Button("Climate settings…", systemImage: "slider.horizontal.3") { sheet = .climate } }
                ControlTile(systemImage: charging ? "bolt.fill" : "powerplug.portrait.fill",
                            title: charging ? "Charging" : plugged ? "Plugged in" : "Charge",
                            isActive: charging,
                            isBusy: isBusy(.chargeStart) || isBusy(.chargeStop)) {
                    if plugged { store.perform(charging ? .chargeStop : .chargeStart, charging ? .stopCharge : .startCharge) }
                    else { sheet = .charging }
                }
                .contextMenu { Button("Charge limits…", systemImage: "slider.horizontal.3") { sheet = .charging } }
                ControlTile(systemImage: "headlight.high.beam.fill", title: "Lights",
                            isActive: store.lightsFlashing,
                            isBusy: isBusy(.flashLights) || isBusy(.hornAndLights)) {
                    store.signal(.lights)
                }
                .contextMenu {
                    Button("Flash lights", systemImage: "headlight.high.beam.fill") { store.signal(.lights) }
                    Button("Honk & flash", systemImage: "horn.fill") { store.signal(.hornAndLights) }
                }
                ControlTile(systemImage: "car.top.radiowaves.rear.right", title: "Cameras", isActive: false) {
                    sheet = .surroundView
                }
            }
            .sensoryFeedback(.impact, trigger: store.pending?.action)
            .sensoryFeedback(.success, trigger: store.pending?.phase == .done)

            statsBar
        }
    }

    /// Swipe the car between front, side and rear views. Open parts and the
    /// tire ring show on the front; the rear view lights the charge port.
    private var carCarousel: some View {
        let status = store.status
        return VStack(spacing: 8) {
            TabView(selection: $carAngle) {
                CarView(paint: store.appearance.paint, chargePort: chargePortState, lightsOn: store.lightsFlashing,
                        climateOn: status?.climateStatus.airControlOn ?? false, openParts: CarPart.open(in: status))
                    .animation(.easeInOut(duration: 0.15), value: store.lightsFlashing)
                    .overlay { CarStateOverlay(status: status) }
                    .overlay { carCallouts }
                    .padding(.horizontal, 20)   // same margins as the rear view
                    .tag(CarView.Angle.front)
                CarView(paint: store.appearance.paint, view: .side)
                    .padding(.horizontal, 8)
                    .tag(CarView.Angle.side)
                CarView(paint: store.appearance.paint, view: .rear)
                    .overlay { rearChargeCallout }
                    .padding(.horizontal, 20)
                    .tag(CarView.Angle.rear)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 232)
            .padding(.horizontal, -20)
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(store.appearance.paint.color.opacity(Theme.isSketch ? 0 : 0.2))
                    .frame(height: 46)
                    .blur(radius: 28)
            }
            .sensoryFeedback(.selection, trigger: carAngle)

            HStack(spacing: 6) {
                ForEach(CarView.Angle.allCases, id: \.self) { angle in
                    Capsule()
                        .fill(angle == carAngle ? Theme.accent : Color.primary.opacity(0.2))
                        .frame(width: angle == carAngle ? 18 : 6, height: 6)
                        .onTapGesture { withAnimation { carAngle = angle } }
                }
            }
            .animation(.spring(duration: 0.3), value: carAngle)
        }
    }

    /// Charge port glow + battery tag on the rear view (port sits beside the tail light).
    private var rearChargeCallout: some View {
        GeometryReader { proxy in
            if let ev = store.status?.evStatus {
                let port = CGPoint(x: proxy.size.width * 0.515, y: proxy.size.height * 0.40)
                let glow = Theme.accent
                if ev.pluggedIn {
                    Circle()
                        .fill(RadialGradient(colors: [glow.opacity(0.85), glow.opacity(0)], center: .center,
                                             startRadius: 0, endRadius: 28))
                        .frame(width: 56, height: 56)
                        .position(port)
                        .blendMode(Theme.isSketch ? .normal : .screen)
                }
                HStack(spacing: 4) {
                    Image(systemName: ev.charging ? "bolt.fill" : ev.pluggedIn ? "powerplug.portrait.fill" : "battery.75percent")
                        .foregroundStyle(Theme.accent)
                    Text("\(Int(ev.evRange.percentage))%").monospacedDigit()
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Theme.hairline))
                .position(x: port.x - 60, y: port.y - 26)
            }
        }
        .allowsHitTesting(false)
    }

    /// Range, battery and cabin temperature, with the lock as the primary action.
    private var statsBar: some View {
        let status = store.status
        let locked = status?.lockStatus != .unlocked
        let range = status?.evStatus?.evRange.range
        let percent = Int(status?.evStatus?.evRange.percentage ?? 0)
        let temp = status?.climateStatus.temperature

        return VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 18) {
                Button {
                    store.perform(locked ? .unlock : .lock, locked ? .unlock : .lock)
                } label: {
                    Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 54, height: 54)
                        .background(locked ? Theme.accent : Theme.warning, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(locked ? "Unlock" : "Lock")
                Stat(value: range.map { "\(Int($0.length))" } ?? "--", unit: range?.units.abbreviation ?? "mi", label: "Range")
                Stat(value: "\(percent)", unit: "%", label: status?.evStatus?.charging == true ? "Charging" : "Battery")
                Stat(value: temp.map { "\(Int($0.value))" } ?? "--", unit: temp?.units.symbol ?? "°F", label: "Cabin set")
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: proxy.size.width * Double(percent) / 100)
                    if let limit = status?.evStatus?.targetSocAC {
                        Rectangle().fill(Color.primary.opacity(0.6)).frame(width: 1.5)
                            .offset(x: proxy.size.width * limit / 100)
                    }
                }
            }
            .frame(height: 6)
            .animation(.spring, value: percent)
            if let updated = status?.lastUpdated {
                HStack(spacing: 6) {
                    Text("Updated \(updated, format: .relative(presentation: .named))")
                    if store.isRefreshing || store.isWaking { ProgressView().controlSize(.mini) }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .surface()
    }

    /// Status tags pinned to the car (not controls): battery at the charge port.
    private var carCallouts: some View {
        GeometryReader { proxy in
            if let ev = store.status?.evStatus, ev.pluggedIn {
                HStack(spacing: 4) {
                    Image(systemName: ev.charging ? "bolt.fill" : "powerplug.portrait.fill")
                        .foregroundStyle(ev.charging ? Theme.accent : .secondary)
                    Text("\(Int(ev.evRange.percentage))%").monospacedDigit()
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Theme.hairline))
                // Charge port sits at ~10% of the photo; keep the tag on screen
                // since the car bleeds off the leading edge.
                .position(x: max(proxy.size.width * 0.12, 84), y: proxy.size.height * 0.22)
            }
        }
        .allowsHitTesting(false)
    }

    private var rangeText: String {
        guard let range = store.status?.evStatus?.evRange.range else { return "--" }
        return "\(Int(range.length))"
    }

    private var chargePortState: CarView.ChargePort {
        guard let ev = store.status?.evStatus else { return .closed }
        return ev.charging ? .charging : ev.pluggedIn ? .plugged : .closed
    }

    private func isBusy(_ action: CarAction) -> Bool {
        guard let pending = store.pending, pending.action == action else { return false }
        return pending.phase == .sending || pending.phase == .waitingForCar
    }

    // MARK: Cards

    private var cards: some View {
        VStack(spacing: 24) {
            GroupedSection(title: "Energy") {
                Button { sheet = .climate } label: {
                    RowLabel(icon: "fan.fill", title: "Climate", detail: climateDetail)
                }
                Button { sheet = .charging } label: {
                    RowLabel(icon: "bolt.fill", title: "Charging", detail: chargingDetail)
                }
                NavigationLink { ChargingHistoryView() } label: {
                    RowLabel(icon: "chart.bar.fill", title: "Charging History", detail: historyDetail)
                }
            }
            .buttonStyle(.plain)

            GroupedSection(title: "Vehicle") {
                ValetRow()
                Button { sheet = .surroundView } label: {
                    RowLabel(icon: "car.top.radiowaves.rear.right", title: "Surround View", detail: "360° camera snapshots")
                }
                RowLabel(icon: "battery.75percent", title: "12V battery",
                         detail: nil) { valueText(store.status?.battery12V.map { "\($0)%" }) }
                RowLabel(icon: "gauge.with.dots.needle.33percent", title: "Odometer",
                         detail: nil) { valueText(odometerText) }
            }
            .buttonStyle(.plain)

            if let location = store.status?.location, location.hasCoordinates {
                VStack(spacing: 8) {
                    SectionHeader(title: "Location")
                    LocationCard(location: location, paint: store.appearance.paint)
                }
            }
        }
    }

    private var climateOn: Bool { store.status?.climateStatus.airControlOn ?? false }
    private var charging: Bool { store.status?.evStatus?.charging ?? false }
    private var odometerText: String? {
        (store.status?.odometer ?? store.snapshot?.vehicle.odometer).map { "\(Int($0.length).formatted()) \($0.units.abbreviation)" }
    }

    private func valueText(_ value: String?) -> some View {
        Text(value ?? "--").font(.body.monospacedDigit()).foregroundStyle(.secondary)
    }

    private var historyDetail: String {
        let settings = ChargeHistoryStore.settings
        let month = Calendar.current.dateInterval(of: .month, for: .now)!
        let sessions = ChargeHistoryStore.sessions().filter { month.contains($0.start) }
        guard !sessions.isEmpty else { return "Sessions are recorded as you charge" }
        let kWh = sessions.reduce(0) { $0 + $1.energyKWh(settings) }
        return "\(Int(kWh.rounded())) kWh this month · \(sessions.count) sessions"
    }

    private var climateDetail: String {
        guard let climate = store.status?.climateStatus else { return "--" }
        let temperature = "\(Int(climate.temperature.value))\(climate.temperature.units.symbol)"
        return climate.airControlOn ? "On · \(temperature)" : "Off · set to \(temperature)"
    }

    private var chargingDetail: String {
        guard let ev = store.status?.evStatus else { return "--" }
        var parts: [String] = []
        if ev.charging {
            if ev.chargeSpeed > 0 { parts.append(String(format: "%.1f kW", ev.chargeSpeed)) }
            let minutes = Int(ev.chargeTime.components.seconds / 60)
            if minutes > 0 { parts.append("\(minutes / 60)h \(minutes % 60)m left") }
        } else {
            parts.append(ev.pluggedIn ? "Plugged in" : "Not plugged in")
        }
        if let limit = ev.targetSocAC { parts.append("Limit \(Int(limit))%") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Components

struct BatteryBar: View {
    var percent: Double
    var limit: Double?
    var charging: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceRaised)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: proxy.size.width * min(max(percent, 0), 100) / 100)
                if let limit {
                    Rectangle()
                        .fill(Color.primary.opacity(0.7))
                        .frame(width: 1.5)
                        .offset(x: proxy.size.width * limit / 100)
                }
            }
        }
        .frame(height: 6)
        .overlay(alignment: .trailing) {
            Text("\(Int(percent))%")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize()
                .offset(x: 40)
        }
        .animation(.spring, value: percent)
    }
}

struct LocationCard: View {
    var location: VehicleStatus.Location
    var paint: PaintColor

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    var body: some View {
        Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 800))) {
            Annotation("", coordinate: coordinate) {
                Circle()
                    .fill(paint.color)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 18, height: 18)
                    .shadow(radius: 4)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.hairline))
        .onTapGesture {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = "My Car"
            item.openInMaps()
        }
    }
}

struct PendingBanner: View {
    var pending: PendingCommand?

    var body: some View {
        Group {
            if let pending {
                HStack(spacing: 10) {
                    switch pending.phase {
                    case .sending, .waitingForCar: ProgressView().tint(.primary)
                    case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    case .unconfirmed: Image(systemName: "clock.badge.questionmark").foregroundStyle(.yellow)
                    case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title(pending)).font(.subheadline.weight(.semibold))
                        if let subtitle = subtitle(pending) {
                            Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    if pending.phase == .waitingForCar {
                        TimelineView(.periodic(from: pending.startedAt, by: 1)) { context in
                            Text("\(Int(context.date.timeIntervalSince(pending.startedAt)))s")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: pending)
    }

    private func title(_ pending: PendingCommand) -> String {
        switch pending.phase {
        case .sending, .waitingForCar: "\(pending.action.pendingLabel)…"
        case .done: pending.action.doneLabel
        case .unconfirmed: "Sent, not yet confirmed"
        case .failed: "\(pending.action.pendingLabel) failed"
        }
    }

    private func subtitle(_ pending: PendingCommand) -> String? {
        switch pending.phase {
        case .sending: "Sending to Hyundai"
        case .waitingForCar: "Waiting for the car to respond"
        case .done: nil
        case .unconfirmed: "The car may still carry it out. Pull to refresh."
        case .failed(let message): message
        }
    }
}

/// Frosted round button pinned onto the car photo.
struct PartControl: View {
    var title: String
    var systemImage: String
    var isActive: Bool
    var tint: Color
    var isBusy: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(isActive ? tint.opacity(0.28) : .black.opacity(0.25)))
                        .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 0.5))
                        .frame(width: 42, height: 42)
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isActive ? tint : .primary)
                        .contentTransition(.symbolEffect(.replace))
                    if isBusy {
                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 42, height: 42)
                            .rotationEffect(.degrees(isBusy ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isBusy)
                    }
                }
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 3)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
    }
}

/// Valet mode on/off. Status comes from Bluelink's valet report.
struct ValetRow: View {
    @State private var isOn = false
    @State private var isBusy = true
    @State private var message: String?

    var body: some View {
        RowLabel(icon: "person.badge.key.fill", title: "Valet Mode",
                 detail: message ?? (isOn ? "On · personal info hidden" : "Off"),
                 detailTint: message == nil ? .secondary : Theme.warning) {
            if isBusy {
                ProgressView()
            } else {
                Toggle("Valet Mode", isOn: Binding(get: { isOn }, set: { set($0) }))
                    .labelsHidden()
                    .tint(Theme.warning)
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        isBusy = true
        do { isOn = try await CarService.shared.valetActive(); message = nil }
        catch { message = "Couldn't read valet status" }
        isBusy = false
    }

    private func set(_ on: Bool) {
        isBusy = true
        message = on ? "Turning on…" : "Turning off…"
        Task {
            do {
                try await CarService.shared.setValet(on)
                try? await Task.sleep(for: .seconds(2))
                await refresh()
            } catch {
                message = (error as? APIError)?.message ?? error.localizedDescription
                isBusy = false
            }
        }
    }
}

/// Large rounded-square control, tinted when its feature is on.
struct ControlTile: View {
    var systemImage: String
    var title: String
    var isActive: Bool
    var tint: Color = Theme.accent
    var isBusy: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isActive ? tint.opacity(0.2) : Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isActive ? tint.opacity(0.45) : Theme.hairline))
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                        .contentTransition(.symbolEffect(.replace))
                    if isBusy {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .trim(from: 0, to: 0.22)
                            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(isBusy ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isBusy)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isActive)
    }
}

struct Stat: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                Text(unit).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CircleIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
