import Observation
import SwiftUI
import UIKit

/// The three looks. Each follows the system light/dark setting.
enum AccentOption: String, CaseIterable, Identifiable {
    case violet, sketch, pastel
    var id: String { rawValue }

    /// Illustrated car art for this theme (nil = the photo, recolored to the paint).
    var artStyle: String? { self == .sketch || self == .pastel ? rawValue : nil }
    var name: String { self == .violet ? "Ion" : rawValue.capitalized }

    /// Swatch shown in Settings.
    @MainActor var swatch: Color {
        switch self {
        case .violet: AppearanceSettings.shared.ionColor.color
        case .sketch: Theme.dynamic(light: UIColor(red: 0.17, green: 0.18, blue: 0.21, alpha: 1),
                                    dark: UIColor(red: 0.92, green: 0.91, blue: 0.88, alpha: 1))
        case .pastel: Theme.dynamic(light: UIColor(red: 0.45, green: 0.42, blue: 0.80, alpha: 1),
                                    dark: UIColor(red: 0.72, green: 0.69, blue: 1.0, alpha: 1))
        }
    }
}

/// Primary color for the Ion theme. `bright` is used in dark mode and for the
/// icon; `deep` is the same hue darkened so it reads on white in light mode.
enum IonColor: String, CaseIterable, Identifiable {
    case violet, amber, orange, pink, blueViolet, azure
    var id: String { rawValue }
    var name: String {
        switch self {
        case .violet: "Ion"
        case .amber: "Amber Gold"
        case .orange: "Blaze Orange"
        case .pink: "Neon Pink"
        case .blueViolet: "Blue Violet"
        case .azure: "Azure Blue"
        }
    }

    /// Dark mode and the icon. Amber Gold through Azure Blue are the
    /// "Vibrant Color Fiesta" palette (#FFBE0B #FB5607 #FF006E #8338EC #3A86FF).
    var bright: (Double, Double, Double) {
        switch self {
        case .violet: (0.66, 0.52, 1.00)
        case .amber: (1.00, 0.745, 0.043)
        case .orange: (0.984, 0.337, 0.027)
        case .pink: (1.00, 0.00, 0.431)
        case .blueViolet: (0.514, 0.220, 0.925)
        case .azure: (0.227, 0.525, 1.00)
        }
    }
    /// Light mode: the same hue, dark enough to read on white.
    var deep: (Double, Double, Double) {
        switch self {
        case .violet: (0.48, 0.33, 0.90)
        case .amber: (0.78, 0.53, 0.00)
        case .orange: (0.86, 0.29, 0.00)
        case .pink: (0.86, 0.00, 0.37)
        case .blueViolet: (0.47, 0.19, 0.88)
        case .azure: (0.13, 0.43, 0.92)
        }
    }
    var color: Color {
        Theme.dynamic(light: UIColor(red: deep.0, green: deep.1, blue: deep.2, alpha: 1),
                      dark: UIColor(red: bright.0, green: bright.1, blue: bright.2, alpha: 1))
    }
    /// Matching home screen icon (nil = the primary, violet icon).
    var iconName: String? { self == .violet ? nil : "AppIcon-Ion-\(rawValue.prefix(1).uppercased() + rawValue.dropFirst())" }
}

/// Alternate home screen icons that don't depend on the theme.
enum AppIconStyle: String, CaseIterable, Identifiable {
    case theme, headlights, taillights
    var id: String { rawValue }
    var name: String {
        switch self {
        case .theme: "Theme"
        case .headlights: "Headlights"
        case .taillights: "Tail Lights"
        }
    }
    var iconName: String? {
        switch self {
        case .theme: nil
        case .headlights: "AppIcon-Headlights"
        case .taillights: "AppIcon-Taillights"
        }
    }
    @MainActor func preview(for accent: AccentOption) -> String {
        guard self == .theme else { return "icon-preview-\(rawValue)" }
        if accent == .violet {
            let color = AppearanceSettings.shared.ionColor
            return color == .violet ? "icon-preview-ion" : "icon-preview-ion-\(color.rawValue)"
        }
        return "icon-preview-\(accent.rawValue)"
    }
}

@MainActor
@Observable
final class AppearanceSettings {
    static let shared = AppearanceSettings()

    var accent: AccentOption {
        didSet {
            UserDefaults.standard.set(accent.rawValue, forKey: "accent")
            CarView.artTheme = accent.artStyle
            applyIcon()
        }
    }

    /// Home screen icon: the theme's own, or one of the lamp icons.
    var icon: AppIconStyle {
        didSet {
            UserDefaults.standard.set(icon.rawValue, forKey: "appIcon")
            applyIcon()
        }
    }

    /// Primary color when the Ion theme is on.
    var ionColor: IonColor {
        didSet {
            UserDefaults.standard.set(ionColor.rawValue, forKey: "ionColor")
            applyIcon()
        }
    }

    private var themeIconName: String? {
        switch accent {
        case .violet: ionColor.iconName
        case .sketch: "AppIcon-Sketch"
        case .pastel: "AppIcon-Pastel"
        }
    }

    /// Theme accent for Live Activities (lock screen is dark, so the bright variant).
    private func syncActivityAccent() {
        let rgb: (Double, Double, Double) = switch accent {
        case .violet: ionColor.bright
        case .sketch: (0.92, 0.91, 0.88)
        case .pastel: (0.72, 0.69, 1.0)
        }
        ChargingLiveActivity.accentRGB = [rgb.0, rgb.1, rgb.2]
    }

    private func applyIcon() {
        syncActivityAccent()
        let name = icon == .theme ? themeIconName : icon.iconName
        if UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != name {
            UIApplication.shared.setAlternateIconName(name)
        }
    }

    private init() {
        accent = AccentOption(rawValue: UserDefaults.standard.string(forKey: "accent") ?? "") ?? .violet
        icon = AppIconStyle(rawValue: UserDefaults.standard.string(forKey: "appIcon") ?? "") ?? .theme
        ionColor = IonColor(rawValue: UserDefaults.standard.string(forKey: "ionColor") ?? "") ?? .violet
        CarView.artTheme = accent.artStyle
        syncActivityAccent()
    }
}

/// Ion's design tokens and building blocks. Every screen uses these so the
/// app reads as one product: one accent (the icon's violet), one surface
/// style, one type scale.
enum Theme {
    @MainActor private static var settings: AppearanceSettings { AppearanceSettings.shared }

    /// The theme's primary color (the Ion color, graphite, or periwinkle).
    @MainActor static var accent: Color { settings.accent == .violet ? settings.ionColor.color : settings.accent.swatch }
    @MainActor static var accentRGB: (Double, Double, Double) { settings.ionColor.bright }
    static let warning = Color.orange

    @MainActor static var isSketch: Bool { settings.accent == .sketch || settings.accent == .pastel }
    @MainActor static var isPastel: Bool { settings.accent == .pastel }
    /// A color that follows the system light/dark setting.
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    /// Text/icons drawn on top of the accent color.
    static var onAccent: Color { dynamic(light: .white, dark: .black) }

    /// The soft glow behind the car on the Ion theme, tinted by the Ion color.
    @MainActor static var spotlight: Color {
        let (r, g, b) = settings.ionColor.bright
        return dynamic(light: rgb(0.88 + r * 0.1, 0.88 + g * 0.1, 0.88 + b * 0.1),
                       dark: rgb(0.03 + r * 0.15, 0.03 + g * 0.12, 0.04 + b * 0.15))
    }

    @MainActor static var background: Color {
        switch settings.accent {
        case .pastel: dynamic(light: rgb(0.985, 0.955, 0.94), dark: rgb(0.095, 0.085, 0.12))
        case .sketch: dynamic(light: rgb(0.965, 0.955, 0.93), dark: rgb(0.105, 0.11, 0.115))
        case .violet: dynamic(light: rgb(0.965, 0.96, 0.975), dark: rgb(0.035, 0.03, 0.045))
        }
    }
    @MainActor static var surface: Color {
        switch settings.accent {
        case .pastel: dynamic(light: rgb(1, 0.99, 0.985), dark: rgb(0.15, 0.135, 0.18))
        case .sketch: dynamic(light: rgb(1, 0.995, 0.985), dark: rgb(0.15, 0.155, 0.16))
        case .violet: dynamic(light: .white, dark: rgb(0.085, 0.08, 0.1))
        }
    }
    @MainActor static var surfaceRaised: Color {
        switch settings.accent {
        case .pastel: dynamic(light: rgb(0.95, 0.925, 0.93), dark: rgb(0.2, 0.18, 0.24))
        case .sketch: dynamic(light: rgb(0.93, 0.92, 0.895), dark: rgb(0.2, 0.205, 0.21))
        case .violet: dynamic(light: rgb(0.93, 0.925, 0.95), dark: rgb(0.12, 0.115, 0.145))
        }
    }
    static var hairline: Color {
        dynamic(light: UIColor.black.withAlphaComponent(0.08), dark: UIColor.white.withAlphaComponent(0.08))
    }
    /// Kept for older call sites.
    @MainActor static var card: Color { surface }

    static let radius: CGFloat = 20
    static let rowHeight: CGFloat = 56
}

// MARK: - Surfaces

struct SurfaceStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.hairline))
    }
}

/// Theme light/dark mode and accent. Applied at the app root AND on every
/// sheet, because sheets don't pick up appearance changes from the screen
/// that presented them while they're open.
struct IonAppearance: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(Theme.accent)
            .animation(.easeInOut(duration: 0.25), value: AppearanceSettings.shared.accent)
            .animation(.easeInOut(duration: 0.25), value: AppearanceSettings.shared.ionColor)
    }
}

extension View {
    func ionAppearance() -> some View { modifier(IonAppearance()) }

    func surface(padding: CGFloat = 16) -> some View { modifier(SurfaceStyle(padding: padding)) }

    /// Grid background for full screens.
    func ionScreen(focusY: Double = 0.4) -> some View {
        background(PixelGridBackground(focusY: focusY))
            .toolbarBackground(Theme.background.opacity(0.85), for: .navigationBar)
    }

    /// Forms and lists styled like the rest of the app instead of stock gray.
    func ionForm() -> some View {
        scrollContentBackground(.hidden)
            .background(PixelGridBackground(focusY: 0.24))
            .listRowBackground(Theme.surface)
            .tint(Theme.accent)
    }
}

// MARK: - Sections and rows

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

/// A titled group of rows sharing one surface, separated by hairlines.
struct GroupedSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 8) {
            if let title { SectionHeader(title: title) }
            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.offset) { index, subview in
                        subview
                        if index < subviews.count - 1 {
                            Divider().overlay(Theme.hairline).padding(.leading, 60)
                        }
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.hairline))
        }
    }
}

/// Icon tile + title/detail + trailing accessory. Used for every list row.
struct RowLabel<Trailing: View>: View {
    let icon: String
    var tint: Color = Theme.accent
    let title: String
    var detail: String?
    var detailTint: Color = .secondary
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body.weight(.medium))
                if let detail {
                    Text(detail).font(.subheadline).foregroundStyle(detailTint).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Theme.rowHeight)
        .contentShape(Rectangle())
    }
}

extension RowLabel where Trailing == RowChevron {
    init(icon: String, tint: Color = Theme.accent, title: String, detail: String? = nil, detailTint: Color = .secondary) {
        self.init(icon: icon, tint: tint, title: title, detail: detail, detailTint: detailTint) { RowChevron() }
    }
}

struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
    }
}

/// Small status capsule, e.g. "Locked", "Charging".
struct StatusPill: View {
    let icon: String
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint == .secondary ? Color.primary.opacity(0.75) : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((tint == .secondary ? Color.primary : tint).opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Theme.hairline))
    }
}

/// The four-pixel mark from the app icon.
struct IonMark: View {
    var size: CGFloat = 14
    var body: some View {
        HStack(spacing: size * 0.85) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.87, green: 0.77, blue: 1), Theme.accent],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: size, height: size)
                    .shadow(color: Theme.accent.opacity(0.8), radius: size * 0.5)
            }
        }
    }
}

/// Primary call-to-action button style.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.accent.opacity(isEnabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
