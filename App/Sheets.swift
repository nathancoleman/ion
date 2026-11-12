import BetterBlueKit
import SwiftUI

struct ClimateSheet: View {
    @Environment(CarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var options = ClimatePresets.load()

    private var isOn: Bool { store.status?.climateStatus.airControlOn ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Button { adjust(-1) } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text("\(Int(options.temperature.value))°")
                            .font(.system(size: 64, weight: .light, design: .rounded))
                            .contentTransition(.numericText())
                        Spacer()
                        Button { adjust(1) } label: { Image(systemName: "chevron.right") }
                    }
                    .font(.title)
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                }

                Section {
                    ComfortPanel(options: $options)
                        .listRowInsets(EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12))
                    Stepper("Run for \(options.duration) min", value: $options.duration, in: 5...30, step: 5)
                } header: {
                    Text("Comfort")
                } footer: {
                    Text("Tap a seat to cycle heat high, medium, low, off, like the buttons in the car.")
                }

                Section {
                    VStack(spacing: 10) {
                        Button(isOn ? "Update & keep running" : "Start climate") {
                            save()
                            store.perform(.climateOn, .startClimate(options))
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        if isOn {
                            Button("Stop climate", role: .destructive) {
                                store.perform(.climateOff, .stopClimate)
                                dismiss()
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text("These settings are also used by the Climate button, widget and Siri.")
                }
            }
            .ionForm()
            .navigationTitle("Climate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { save(); dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func adjust(_ delta: Double) {
        withAnimation {
            options.temperature = Temperature(
                units: 1,
                value: String(Int(min(max(options.temperature.value + delta, 62), 82)))
            )
        }
    }

    private func save() { ClimatePresets.save(options) }
}

struct ChargingSheet: View {
    @Environment(CarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var acLimit = 80.0
    @State private var dcLimit = 90.0
    @State private var preconditionMessage: String?

    private func precondition(_ on: Bool) {
        preconditionMessage = on ? "Sending…" : "Stopping…"
        Task {
            do {
                try await CarService.shared.setBatteryPreconditioning(on)
                preconditionMessage = on ? "Preconditioning requested." : "Preconditioning stopped."
            } catch {
                preconditionMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
        }
    }

    var body: some View {
        let ev = store.status?.evStatus
        NavigationStack {
            Form {
                Section {
                    ChargeHero(ev: ev, paint: store.appearance.paint, limit: acLimit)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    NavigationLink { ChargingHistoryView() } label: {
                        Label("Charging History", systemImage: "chart.bar.fill")
                    }
                }

                Section("Charge limit") {
                    limitSlider("AC (home, Level 2)", value: $acLimit)
                    limitSlider("DC fast charging", value: $dcLimit)
                    Button("Set limits") {
                        store.perform(.chargeLimit, .setTargetSOC(acLevel: Int(acLimit), dcLevel: Int(dcLimit)))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
                }

                Section {
                    HStack {
                        Button("Precondition battery", systemImage: "thermometer.sun") { precondition(true) }
                        Spacer()
                        Button("Stop") { precondition(false) }.foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    if let preconditionMessage {
                        Text(preconditionMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Warms the battery so it fast-charges at full speed.")
                }

                if ev?.pluggedIn == true {
                    Section {
                        if ev?.charging == true {
                            Button("Stop charging", role: .destructive) {
                                store.perform(.chargeStop, .stopCharge); dismiss()
                            }
                        } else {
                            Button("Start charging") {
                                store.perform(.chargeStart, .startCharge); dismiss()
                            }
                        }
                    }
                }
            }
            .ionForm()
            .navigationTitle("Charging")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .onAppear {
                if let ac = ev?.targetSocAC { acLimit = ac }
                if let dc = ev?.targetSocDC { dcLimit = dc }
            }
        }
    }

    private func limitSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))%").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: 50...100, step: 10)
        }
    }
}

// MARK: - Car-style comfort buttons

/// Seat, steering wheel and defrost controls laid out like the IONIQ 5's
/// climate panel: driver on the left, passenger on the right.
struct ComfortPanel: View {
    @Binding var options: ClimateOptions

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                SeatControls(side: "Driver", leftSide: true,
                             level: $options.frontLeftSeat, cooling: $options.frontLeftVentilationEnabled)
                CarButton(
                    systemImage: "steeringwheel",
                    caption: "Wheel",
                    bars: 1, lit: options.steeringWheel > 0 ? 1 : 0, color: .orange
                ) { options.steeringWheel = options.steeringWheel > 0 ? 0 : 1 }
                SeatControls(side: "Passenger", leftSide: false,
                             level: $options.frontRightSeat, cooling: $options.frontRightVentilationEnabled)
            }
            HStack(spacing: 10) {
                CarButton(systemImage: "windshield.front.and.heat.waves", caption: "Front defrost",
                          bars: 1, lit: options.defrost ? 1 : 0, color: .orange) { options.defrost.toggle() }
                CarButton(systemImage: "windshield.rear.and.heat.waves", caption: "Rear defrost",
                          bars: 1, lit: options.rearDefrostEnabled ? 1 : 0, color: .orange) {
                    options.rearDefrostEnabled.toggle()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: [options.frontLeftSeat, options.frontRightSeat, options.steeringWheel])
    }
}

/// A seat heat button and a seat ventilation button. Each tap steps
/// 3 → 2 → 1 → off; heat and ventilation can't both be on.
struct SeatControls: View {
    let side: String
    let leftSide: Bool
    @Binding var level: Int
    @Binding var cooling: Bool

    var body: some View {
        HStack(spacing: 6) {
            CarButton(
                systemImage: leftSide ? "carseat.left.fill" : "carseat.right.fill",
                badge: "heat.waves",
                caption: "\(side) heat",
                bars: 3, lit: cooling ? 0 : level, color: .orange
            ) { step(cool: false) }
            CarButton(
                systemImage: leftSide ? "carseat.left.fill" : "carseat.right.fill",
                badge: "fan.fill",
                caption: "\(side) vent",
                bars: 3, lit: cooling ? level : 0, color: .cyan
            ) { step(cool: true) }
        }
    }

    private func step(cool: Bool) {
        let current = cooling == cool ? level : 0
        let next = current == 0 ? 3 : current - 1
        cooling = cool && next > 0
        level = next
    }
}

/// A square button with indicator bars underneath, like the car's switches.
struct CarButton: View {
    var systemImage: String
    var badge: String? = nil
    var caption: String
    var bars: Int
    var lit: Int
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(lit > 0 ? color : Color.primary.opacity(0.85))
                        .frame(maxWidth: .infinity, minHeight: 34)
                    if let badge {
                        Image(systemName: badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(lit > 0 ? color : .secondary)
                            .offset(x: -2, y: 2)
                    }
                }
                HStack(spacing: 3) {
                    ForEach(0..<bars, id: \.self) { index in
                        Capsule()
                            .fill(index < lit ? color : Color.primary.opacity(0.15))
                            .frame(height: 3)
                            .shadow(color: index < lit ? color : .clear, radius: 3)
                    }
                }
                .frame(width: bars == 1 ? 18 : 30)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
            .animation(.easeOut(duration: 0.15), value: lit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(caption)
        .accessibilityValue(lit == 0 ? "Off" : bars == 1 ? "On" : "Level \(lit)")
    }
}


/// Rear three-quarter view with the charge port lit, battery % beside it.
struct ChargeHero: View {
    let ev: VehicleStatus.EVStatus?
    let paint: PaintColor
    @Environment(\.colorScheme) private var colorScheme
    let limit: Double
    @State private var pulse = false

    // Charge port door, as a fraction of the rear photo.
    private let port = CGPoint(x: 0.515, y: 0.40)

    var body: some View {
        let percent = ev?.evRange.percentage ?? 0
        let charging = ev?.charging ?? false
        let plugged = ev?.pluggedIn ?? false
        let glow = Theme.accent

        VStack(spacing: 14) {
            if let image = UIImage(named: CarView.imageName(view: .rear, paint: paint, art: CarView.artTheme,
                                                            dark: colorScheme == .dark))
                ?? UIImage(named: "car-rear-cyber-gray") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        GeometryReader { proxy in
                            let center = CGPoint(x: proxy.size.width * port.x, y: proxy.size.height * port.y)
                            if plugged {
                                Circle()
                                    .fill(RadialGradient(colors: [glow.opacity(0.85), glow.opacity(0)],
                                                         center: .center, startRadius: 0, endRadius: 34))
                                    .frame(width: 68, height: 68)
                                    .scaleEffect(pulse ? 1.15 : 0.85)
                                    .position(center)
                                    .blendMode(.screen)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .background(alignment: .bottom) {
                        Ellipse().fill(paint.color.opacity(0.2)).frame(height: 40).blur(radius: 24)
                    }
            }

            VStack(spacing: 6) {
                Text("\(charging ? "Charging" : plugged ? "Plugged in" : "Not plugged in") · \(Int(percent))%")
                    .font(.headline)
                if charging, let ev {
                    let minutes = Int(ev.chargeTime.components.seconds / 60)
                    Text([ev.chargeSpeed > 0 ? String(format: "%.1f kW", ev.chargeSpeed) : nil,
                          minutes > 0 ? "\(minutes / 60)h \(minutes % 60)m to \(Int(limit))%" : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule().fill(Theme.accent)
                            .frame(width: proxy.size.width * percent / 100)
                        Rectangle().fill(Color.primary.opacity(0.6)).frame(width: 1.5)
                            .offset(x: proxy.size.width * limit / 100)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 40)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
