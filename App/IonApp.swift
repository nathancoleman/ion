import AppIntents
import BackgroundTasks
import SwiftUI

@main
struct IonApp: App {
    @State private var store = CarStore()
    @Environment(\.scenePhase) private var scenePhase
    nonisolated static let refreshTask = "com.nathancoleman.ion.refresh"

    var body: some Scene {
        WindowGroup {
            Group {
                // `-previewLogin` (debug launch argument) shows sign-in without signing out.
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-previewHistory") {
                    NavigationStack { ChargingHistoryView() }
                } else if args.contains("-previewCharging") {
                    ChargingSheet().task { await store.onAppear() }
                } else if args.contains("-previewClimate") {
                    ClimateSheet()
                } else if store.isSignedIn && !args.contains("-previewLogin") {
                    DashboardView()
                } else {
                    LoginView()
                }
            }
            .environment(store)
            // Sketch and Pastel are light themes; Ion follows the system setting.
            .ionAppearance()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Self.scheduleRefresh() }
        }
        // Reads Hyundai's cached status (never wakes the car) so charging
        // sessions and widgets stay current while the app is closed.
        .backgroundTask(.appRefresh(Self.refreshTask)) {
            Self.scheduleRefresh()
            _ = try? await MainActor.run { CarService.shared }.refreshStatus(cached: true)
        }
    }
}

extension IonApp {
    nonisolated static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

struct IonShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LockCarIntent(), phrases: ["Lock my car with \(.applicationName)"],
                    shortTitle: "Lock Car", systemImageName: "lock.fill")
        AppShortcut(intent: UnlockCarIntent(), phrases: ["Unlock my car with \(.applicationName)"],
                    shortTitle: "Unlock Car", systemImageName: "lock.open.fill")
        AppShortcut(intent: StartClimateIntent(), phrases: ["Warm up my car with \(.applicationName)",
                                                            "Start climate with \(.applicationName)"],
                    shortTitle: "Start Climate", systemImageName: "fan.fill")
        AppShortcut(intent: StopClimateIntent(), phrases: ["Stop climate with \(.applicationName)"],
                    shortTitle: "Stop Climate", systemImageName: "fan.slash")
    }
}


/// App background: a clean studio spotlight where the car sits (Ion), plain
/// paper (Sketch) or soft washes (Pastel).
struct PixelGridBackground: View {
    /// Vertical center of the clean, lit area (where the car is), as a fraction of the height.
    var focusY: Double = 0.42
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let pastel = Theme.isPastel
        let sketch = Theme.isSketch && !pastel
        let paper = Theme.background
        let spotlight = Theme.spotlight
        let background = Theme.background
        Canvas { context, size in
            // Soft spotlight behind the car
            let center = CGPoint(x: size.width * 0.5, y: size.height * focusY)
            if pastel {
                // Soft pastel washes: peach, lavender and mint, no grid.
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper))
                // Same washes at dusk in dark mode: plum, indigo and deep teal.
                let washes = colorScheme == .dark ? [
                    (0.15, 0.10, 0.75, Color(red: 0.42, green: 0.20, blue: 0.30)),
                    (0.85, focusY, 0.65, Color(red: 0.22, green: 0.20, blue: 0.48)),
                    (0.30, 0.95, 0.80, Color(red: 0.10, green: 0.30, blue: 0.30)),
                ] : [
                    (0.15, 0.10, 0.75, Color(red: 1.0, green: 0.84, blue: 0.78)),
                    (0.85, focusY, 0.65, Color(red: 0.84, green: 0.82, blue: 1.0)),
                    (0.30, 0.95, 0.80, Color(red: 0.80, green: 0.95, blue: 0.90)),
                ]
                for (x, y, radius, color) in washes {
                    let c = CGPoint(x: size.width * x, y: size.height * y)
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                        Gradient(colors: [color.opacity(0.55), color.opacity(0)]),
                        center: c, startRadius: 0, endRadius: size.width * radius))
                }
                return
            }
            if sketch {
                // Plain warm paper.
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper))
                return
            }
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    Gradient(colors: [spotlight, background]),
                    center: center, startRadius: 0, endRadius: max(size.width, size.height) * 0.55
                )
            )
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
