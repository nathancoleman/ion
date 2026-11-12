import SwiftUI

struct SettingsView: View {
    @Environment(CarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmSignOut = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        let appearance = store.appearance
        NavigationStack {
            Form {
                Section {
                    CarView(paint: appearance.paint, view: .side)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 8)
                }

                Section("Vehicle") {
                    LabeledContent("Model", value: appearance.title)
                    LabeledContent("Trim", value: appearance.trim ?? "--")
                    LabeledContent("VIN", value: store.snapshot?.vehicle.vin ?? "--")
                        .textSelection(.enabled)
                    LabeledContent("Bluelink reported color", value: appearance.reportedColor ?? "Not provided")
                }

                Section {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(PaintColor.all) { paint in
                            Button { store.setPaint(paint) } label: {
                                VStack(spacing: 4) {
                                    // Always the real paint, even in illustrated themes.
                                    CarView(paint: paint, view: .side, art: nil)
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(paint == appearance.paint ? Theme.accent : .clear, lineWidth: 2)
                                        )
                                    Text(paint.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                    Button("Detect from Bluelink again") {
                        Task { await store.redetectAppearance() }
                    }
                } header: {
                    Text("Paint")
                } footer: {
                    Text(appearance.paintIsUserChosen
                         ? "Picked by you."
                         : appearance.reportedColor != nil ? "Detected from Bluelink." : "Bluelink didn't report a color, so pick yours.")
                }

                Section {
                    HStack(spacing: 0) {
                        ForEach(AccentOption.allCases) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) { AppearanceSettings.shared.accent = option }
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(option.swatch.gradient)
                                        .frame(width: 34, height: 34)
                                        .overlay {
                                            if AppearanceSettings.shared.accent == option {
                                                Circle().stroke(Color.primary, lineWidth: 2.5).padding(-4)
                                                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Theme.onAccent)
                                            }
                                        }
                                    Text(option.name).font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.name)
                        }
                    }
                    .padding(.vertical, 8)
                    .sensoryFeedback(.selection, trigger: AppearanceSettings.shared.accent)

                    if AppearanceSettings.shared.accent == .violet {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Color").font(.subheadline).foregroundStyle(.secondary)
                            HStack(spacing: 0) {
                                ForEach(IonColor.allCases) { color in
                                    let selected = AppearanceSettings.shared.ionColor == color
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.25)) { AppearanceSettings.shared.ionColor = color }
                                    } label: {
                                        Circle()
                                            .fill(color.color.gradient)
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                if selected {
                                                    Circle().stroke(Color.primary, lineWidth: 2).padding(-4)
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(color.name)
                                    .accessibilityAddTraits(selected ? .isSelected : [])
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .sensoryFeedback(.selection, trigger: AppearanceSettings.shared.ionColor)
                    }
                } header: {
                    Text("Theme")
                } footer: {
                    Text("Every theme follows your light/dark setting. In dark mode Sketch is chalk on slate and Pastel sits on a dusk wash.")
                }

                Section {
                    HStack(spacing: 0) {
                        ForEach(AppIconStyle.allCases) { style in
                            let selected = AppearanceSettings.shared.icon == style
                            Button {
                                AppearanceSettings.shared.icon = style
                            } label: {
                                VStack(spacing: 6) {
                                    Image(style.preview(for: AppearanceSettings.shared.accent))
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                                .stroke(selected ? Theme.accent : .clear, lineWidth: 2.5)
                                                .padding(-4)
                                        }
                                    Text(style.name).font(.caption2).foregroundStyle(selected ? .primary : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(style.name) icon")
                        }
                    }
                    .padding(.vertical, 8)
                    .sensoryFeedback(.selection, trigger: AppearanceSettings.shared.icon)
                } header: {
                    Text("App Icon")
                } footer: {
                    Text("Theme matches the icon to your theme. Headlights and Tail Lights are drawn from the IONIQ 5's pixel lamps.")
                }

                Section("Diagnostics") {
                    NavigationLink("Bluelink vehicle details") {
                        ScrollView {
                            Text(prettyJSON(store.lastEnrollmentJSON) ?? "Refresh the vehicle to capture this.")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .navigationTitle("Vehicle details")
                    }
                }

                Section {
                    Text("Car artwork is made from studio photos of the IONIQ 5 you provided, recolored to your paint and illustrated for the Sketch and Pastel themes. For personal use.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Credits")
                }

                Section {
                    Button("Sign out", role: .destructive) { confirmSignOut = true }
                }
            }
            .ionForm()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Sign out of Bluelink?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    dismiss()
                    store.signOut()
                }
            }
        }
    }

    private func prettyJSON(_ raw: String?) -> String? {
        guard let raw, let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        else { return raw }
        return String(data: pretty, encoding: .utf8)
    }
}
