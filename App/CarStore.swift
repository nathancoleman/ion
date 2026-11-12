import BetterBlueKit
import Foundation
import Observation
import UIKit

enum CarAction: String, Sendable {
    case lock, unlock, climateOn, climateOff, chargeStart, chargeStop, chargeLimit
    case flashLights, hornAndLights

    var pendingLabel: String {
        switch self {
        case .lock: "Locking"
        case .unlock: "Unlocking"
        case .climateOn: "Starting climate"
        case .climateOff: "Stopping climate"
        case .chargeStart: "Starting charge"
        case .chargeStop: "Stopping charge"
        case .chargeLimit: "Setting charge limit"
        case .flashLights: "Flashing lights"
        case .hornAndLights: "Honking and flashing"
        }
    }

    var doneLabel: String {
        switch self {
        case .lock: "Locked"
        case .unlock: "Unlocked"
        case .climateOn: "Climate on"
        case .climateOff: "Climate off"
        case .chargeStart: "Charging"
        case .chargeStop: "Charging stopped"
        case .chargeLimit: "Charge limit set"
        case .flashLights: "Lights flashed"
        case .hornAndLights: "Honked and flashed"
        }
    }

    /// Whether a status shows the car has carried out this action.
    func isReflected(in status: VehicleStatus, command: VehicleCommand) -> Bool {
        switch (self, command) {
        case (.lock, _): status.lockStatus == .locked
        case (.unlock, _): status.lockStatus == .unlocked
        case (.climateOn, _): status.climateStatus.airControlOn
        case (.climateOff, _): !status.climateStatus.airControlOn
        case (.chargeStart, _): status.evStatus?.charging == true
        case (.chargeStop, _): status.evStatus?.charging == false
        case (.chargeLimit, .setTargetSOC(let ac, _)): status.evStatus?.targetSocAC == Double(ac)
        default: true
        }
    }
}

struct PendingCommand: Equatable {
    enum Phase: Equatable { case sending, waitingForCar, done, unconfirmed, failed(String) }
    var action: CarAction
    var phase: Phase
    var startedAt = Date()
}

@MainActor
@Observable
final class CarStore {
    private(set) var snapshot: CarSnapshot?
    private(set) var isSignedIn = CredentialStore.loadCredentials() != nil
    private(set) var isRefreshing = false
    private(set) var isWaking = false
    private(set) var pending: PendingCommand?
    /// Pulses the car's lamps when a lock/unlock lands, like a real key fob.
    private(set) var lightsFlashing = false
    var errorMessage: String?

    private let service = CarService.shared
    private var commandTask: Task<Void, Never>?

    var status: VehicleStatus? { snapshot?.status }
    var appearance: CarAppearance { snapshot?.appearance ?? CarAppearance() }

    init() {
        snapshot = SnapshotStore.load()
    }

    // MARK: Session

    func signIn(username: String, password: String, pin: String) async throws {
        let credentials = Credentials(username: username, password: password, pin: pin)
        try await service.signIn(credentials)
        if credentials.isDemo { ChargeHistoryStore.seedDemo() }
        isSignedIn = true
        await loadVehicle()
    }

    func signOut() {
        service.signOut()
        snapshot = nil
        isSignedIn = false
    }

    // MARK: Data

    /// Shows the cached snapshot immediately, then refreshes from Hyundai's server copy.
    func onAppear() async {
        snapshot = SnapshotStore.load()
        guard isSignedIn else { return }
        if CredentialStore.loadCredentials()?.isDemo == true { ChargeHistoryStore.seedDemo() }
        if snapshot == nil { await loadVehicle() } else { await refresh() }
    }

    func loadVehicle() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do { snapshot = try await service.loadVehicle() } catch { report(error) }
    }

    /// Cheap refresh from the server cache.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do { snapshot = try await service.refreshStatus(cached: true) } catch { report(error) }
    }

    /// Wakes the car for live data. Slow, and rate limited by Hyundai.
    func wake() async {
        isWaking = true
        defer { isWaking = false }
        do { snapshot = try await service.refreshStatus(cached: false) } catch { report(error) }
    }

    func setPaint(_ paint: PaintColor) {
        service.updateAppearance {
            $0.paintID = paint.id
            $0.paintIsUserChosen = true
        }
        snapshot = SnapshotStore.load()
    }

    func redetectAppearance() async {
        service.updateAppearance { $0.paintIsUserChosen = false }
        await loadVehicle()
    }

    var lastEnrollmentJSON: String? { service.lastEnrollmentJSON }

    // MARK: Commands

    func perform(_ action: CarAction, _ command: VehicleCommand) {
        commandTask?.cancel()
        let before = snapshot
        pending = PendingCommand(action: action, phase: .sending)
        // Optimistic: show the end state now; revert if Hyundai rejects it.
        if var status = snapshot?.status {
            status.applyOptimistically(command)
            snapshot?.status = status
        }

        // Keep running briefly if the phone is locked right after tapping, so
        // the car's confirmation still lands (and updates the Live Activity).
        let background = UIApplication.shared.beginBackgroundTask(withName: action.rawValue)
        commandTask = Task {
            defer { UIApplication.shared.endBackgroundTask(background) }
            if case .startClimate(let options) = command { await ClimateLiveActivity.start(options: options) }
            if action == .climateOff { await ClimateLiveActivity.endAll() }
            do {
                try await service.send(command)
                pending?.phase = .waitingForCar
                if action == .climateOn { await ClimateLiveActivity.update(.waitingForCar) }
                let confirmed = await waitForCar(action, command)
                guard !Task.isCancelled else { return }
                pending?.phase = confirmed ? .done : .unconfirmed
                if action == .climateOn {
                    // Unconfirmed usually still means it's running; keep the estimate going.
                    await ClimateLiveActivity.update(.running, message: confirmed ? nil : "Not yet confirmed by the car")
                }
                if confirmed, action == .lock || action == .unlock { await flashLights() }
                try? await Task.sleep(for: .seconds(2.5))
                if pending?.action == action { pending = nil }
            } catch {
                snapshot = before
                pending?.phase = .failed(error.localizedDescription)
                if action == .climateOn { await ClimateLiveActivity.update(.failed, message: error.localizedDescription) }
                try? await Task.sleep(for: .seconds(4))
                if pending?.action == action { pending = nil }
            }
        }
    }

    /// Polls the cheap cached status until it reflects the command. Hyundai
    /// updates its copy once the car reports back, typically 10–30 seconds.
    private func waitForCar(_ action: CarAction, _ command: VehicleCommand) async -> Bool {
        let deadline = Date().addingTimeInterval(75)
        try? await Task.sleep(for: .seconds(3))
        while Date() < deadline, !Task.isCancelled {
            if let fresh = try? await service.refreshStatus(cached: true), let status = fresh.status {
                if action.isReflected(in: status, command: command) {
                    snapshot = fresh
                    return true
                }
                // Keep showing the optimistic state while waiting.
                var optimistic = status
                optimistic.applyOptimistically(command)
                snapshot = fresh
                snapshot?.status = optimistic
            }
            try? await Task.sleep(for: .seconds(4))
        }
        return false
    }

    /// Lights / horn: nothing to verify in status, so done once Hyundai accepts it.
    func signal(_ kind: SignalKind) {
        let action: CarAction = kind == .lights ? .flashLights : .hornAndLights
        pending = PendingCommand(action: action, phase: .sending)
        Task {
            do {
                try await service.signal(kind)
                pending?.phase = .done
                await flashLights()
            } catch {
                pending?.phase = .failed((error as? APIError)?.message ?? error.localizedDescription)
            }
            try? await Task.sleep(for: .seconds(2.5))
            if pending?.action == action { pending = nil }
        }
    }

    private func flashLights() async {
        for _ in 0..<2 {
            lightsFlashing = true
            try? await Task.sleep(for: .milliseconds(220))
            lightsFlashing = false
            try? await Task.sleep(for: .milliseconds(180))
        }
    }

    private func report(_ error: Error) {
        errorMessage = (error as? APIError)?.message ?? error.localizedDescription
    }
}
