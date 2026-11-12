import BetterBlueKit
import CoreLocation
import Foundation
import WidgetKit

/// Thin wrapper over BetterBlueKit: owns the client and auth token, and
/// keeps the shared snapshot current. Used by the app, widget and intents.
@MainActor
final class CarService {
    static let shared = CarService()

    private var client: (any APIClientProtocol)?
    private var clientCredentials: Credentials?
    private var token: AuthToken?
    private let capture = ResponseCapture()

    var credentials: Credentials? { CredentialStore.loadCredentials() }

    // MARK: Session

    /// Validates credentials by logging in, then stores them.
    func signIn(_ credentials: Credentials) async throws {
        let client = try makeClient(credentials)
        let token = try await client.login()
        CredentialStore.saveCredentials(credentials)
        CredentialStore.saveToken(token)
        (self.client, self.clientCredentials, self.token) = (client, credentials, token)
    }

    func signOut() {
        CredentialStore.clear()
        SnapshotStore.clear()
        ChargeHistoryStore.clear()
        (client, clientCredentials, token) = (nil, nil, nil)
        reloadWidgets()
    }

    // MARK: Data

    /// Loads the first vehicle on the account and works out how it looks.
    func loadVehicle() async throws -> CarSnapshot {
        let vehicles = try await withSession { client, token in
            try await client.fetchVehicles(authToken: token)
        }
        guard let vehicle = vehicles.first else {
            throw APIError(message: "No vehicles on this Bluelink account", apiName: "Ion")
        }
        let previous = SnapshotStore.load()
        let appearance = await AppearanceResolver.resolve(
            vin: vehicle.vin,
            enrollmentJSON: capture.vehiclesBody,
            previous: previous?.vehicle.vin == vehicle.vin ? previous?.appearance : nil
        )
        var snapshot = CarSnapshot(
            vehicle: vehicle,
            status: previous?.vehicle.vin == vehicle.vin ? previous?.status : nil,
            appearance: appearance,
            fetchedAt: previous?.fetchedAt ?? .distantPast
        )
        SnapshotStore.save(snapshot)
        snapshot = try await refreshStatus(cached: true)
        return snapshot
    }

    /// The raw enrollment response from the last vehicle fetch, for Settings → Diagnostics.
    var lastEnrollmentJSON: String? { capture.vehiclesBody }

    /// `cached: true` reads Hyundai's server copy (instant, free). `false`
    /// wakes the car's modem for live data (slow, rate-limited, costs 12V).
    @discardableResult
    func refreshStatus(cached: Bool) async throws -> CarSnapshot {
        guard var snapshot = SnapshotStore.load() else { return try await loadVehicle() }
        let vehicle = snapshot.vehicle
        let status = try await withSession { client, token in
            try await client.fetchVehicleStatus(for: vehicle, authToken: token, cached: cached)
        }
        snapshot.status = status
        snapshot.fetchedAt = Date()
        SnapshotStore.save(snapshot)
        if let started = ChargeHistoryStore.record(status) { nameChargingPlace(started) }
        await ChargingLiveActivity.sync(snapshot)
        reloadWidgets()
        return snapshot
    }

    /// Sends a command. Returns once Hyundai's cloud accepts it; the car acts
    /// on it some seconds later.
    func send(_ command: VehicleCommand) async throws {
        guard let vehicle = SnapshotStore.load()?.vehicle else {
            throw APIError(message: "Open Ion once to load your car", apiName: "Ion")
        }
        try await withSession { client, token in
            try await client.sendCommand(for: vehicle, command: command, authToken: token)
        }
    }

    /// Flash the lights, or honk and flash. Demo mode just pretends.
    func signal(_ kind: SignalKind) async throws {
        guard let vehicle = SnapshotStore.load()?.vehicle, let credentials = CredentialStore.loadCredentials() else {
            throw APIError(message: "Open Ion once to load your car", apiName: "Ion")
        }
        if credentials.isDemo {
            try await Task.sleep(for: .seconds(1))
            return
        }
        try await withSession { _, token in
            try await SignalCommands.send(kind, vehicle: vehicle, token: token, credentials: credentials)
        }
    }

    /// Pulls Hyundai's billed charging sessions for the last year into history.
    func importChargeHistory() async throws {
        guard let vehicle = SnapshotStore.load()?.vehicle, let credentials = CredentialStore.loadCredentials(),
              !credentials.isDemo else { return }
        let end = Date().addingTimeInterval(86400)
        let start = Calendar.current.date(byAdding: .year, value: -1, to: end) ?? end
        let orders = try await withSession { _, token in
            try await HyundaiExtras.chargeOrders(from: start, to: end, vehicle: vehicle, token: token, credentials: credentials)
        }
        ChargeHistoryStore.importOrders(orders)
    }

    func valetActive() async throws -> Bool {
        guard let vehicle = SnapshotStore.load()?.vehicle, let credentials = CredentialStore.loadCredentials() else { return false }
        if credentials.isDemo { return false }
        return try await withSession { _, token in
            try await HyundaiExtras.valetActive(vehicle: vehicle, token: token, credentials: credentials)
        }
    }

    func setValet(_ on: Bool) async throws {
        guard let vehicle = SnapshotStore.load()?.vehicle, let credentials = CredentialStore.loadCredentials() else { return }
        if credentials.isDemo { try await Task.sleep(for: .seconds(1)); return }
        try await withSession { _, token in
            try await HyundaiExtras.setValet(on, vehicle: vehicle, token: token, credentials: credentials)
        }
    }

    func setBatteryPreconditioning(_ on: Bool) async throws {
        guard let vehicle = SnapshotStore.load()?.vehicle, let credentials = CredentialStore.loadCredentials() else { return }
        if credentials.isDemo { try await Task.sleep(for: .seconds(1)); return }
        try await withSession { _, token in
            try await HyundaiExtras.setBatteryPreconditioning(on, vehicle: vehicle, token: token, credentials: credentials)
        }
    }

    /// Surround-view stills Hyundai already holds, newest first.
    func surroundViewCaptures() async throws -> [SurroundViewCapture] {
        if CredentialStore.loadCredentials()?.isDemo == true { return DemoSurroundView.captures() }
        guard let vehicle = SnapshotStore.load()?.vehicle else { return [] }
        return try await withSession { client, token in
            try await client.fetchSurroundViewCaptures(for: vehicle, authToken: token)
        }
    }

    /// Asks the car to take a new surround-view capture (takes a few minutes).
    func requestSurroundView() async throws {
        guard let vehicle = SnapshotStore.load()?.vehicle else { return }
        try await withSession { client, token in
            try await client.requestSurroundViewCapture(for: vehicle, authToken: token)
        }
    }

    /// Labels a new charging session with a short place name ("Home" if it's
    /// where the car has charged most often, otherwise the street/POI name).
    private func nameChargingPlace(_ session: ChargeSession) {
        guard let lat = session.latitude, let lon = session.longitude else { return }
        let here = CLLocation(latitude: lat, longitude: lon)
        let pastAtThisSpot = ChargeHistoryStore.sessions().filter { other in
            guard other.id != session.id, let la = other.latitude, let lo = other.longitude else { return false }
            return CLLocation(latitude: la, longitude: lo).distance(from: here) < 150
        }
        if let known = pastAtThisSpot.compactMap(\.placeName).first {
            ChargeHistoryStore.setPlaceName(known, for: session.id)
            return
        }
        Task {
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(here).first
            let name = placemark?.areasOfInterest?.first ?? placemark?.name ?? placemark?.locality
            if let name { ChargeHistoryStore.setPlaceName(name, for: session.id) }
        }
    }

    func updateAppearance(_ change: (inout CarAppearance) -> Void) {
        SnapshotStore.update { change(&$0.appearance) }
        reloadWidgets()
    }

    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }

    // MARK: Plumbing

    private func withSession<T>(
        _ body: @MainActor (any APIClientProtocol, AuthToken) async throws -> T
    ) async throws -> T {
        guard let credentials = CredentialStore.loadCredentials() else {
            throw APIError.invalidCredentials("Not signed in", apiName: "Ion")
        }
        if client == nil || clientCredentials != credentials {
            client = try makeClient(credentials)
            clientCredentials = credentials
            token = CredentialStore.loadToken()
        }
        guard let client else { fatalError("unreachable") }

        if token?.isValid != true { try await relogin(client) }
        do {
            return try await body(client, token!)
        } catch let error as APIError
            where [.invalidCredentials, .invalidVehicleSession].contains(error.errorType) {
            // Token went stale server-side; log in again once.
            try await relogin(client)
            return try await body(client, token!)
        }
    }

    private func relogin(_ client: any APIClientProtocol) async throws {
        let fresh = try await client.login()
        token = fresh
        CredentialStore.saveToken(fresh)
    }

    private func makeClient(_ credentials: Credentials) throws -> any APIClientProtocol {
        if credentials.isDemo { return DemoAPIClient(accountId: credentials.accountId) }
        let capture = self.capture
        let configuration = APIClientConfiguration(
            region: .usa,
            brand: .hyundai,
            username: credentials.username,
            password: credentials.password,
            pin: credentials.pin,
            accountId: credentials.accountId,
            // Only used to read the enrollment response for color/trim; kept in memory.
            logSink: { log in
                if log.requestType == .fetchVehicles, let body = log.responseBody {
                    capture.vehiclesBody = body
                }
            },
            redactPII: false
        )
        return try createBetterBlueKitAPIClient(configuration: configuration)
    }
}

/// Holds raw response bodies handed over by BetterBlueKit's log sink.
private final class ResponseCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var _vehiclesBody: String?
    var vehiclesBody: String? {
        get { lock.withLock { _vehiclesBody } }
        set { lock.withLock { _vehiclesBody = newValue } }
    }
}
