import BetterBlueKit
import Foundation

/// Offline stand-in for Bluelink (sign in as "demo"). Mimics the real
/// latency: commands are accepted after ~1s and show up in status a few
/// seconds later.
@MainActor
final class DemoAPIClient: APIClientProtocol {
    private static var status: VehicleStatus?
    private static var pendingUntil: Date = .distantPast
    private static var pending: ((inout VehicleStatus) -> Void)?

    private let accountId: UUID
    static let vin = "KM8KRDDF0TU000001"

    init(accountId: UUID) { self.accountId = accountId }

    func login() async throws -> AuthToken {
        AuthToken(accessToken: "demo", refreshToken: "demo", expiresAt: .now.addingTimeInterval(3600))
    }

    func fetchVehicles(authToken: AuthToken) async throws -> [Vehicle] {
        [Vehicle(
            vin: Self.vin, regId: "demo", model: "My IONIQ 5", accountId: accountId,
            fuelType: .electric, generation: 3,
            odometer: Distance(length: 12_480, units: .miles), modelYear: 2026
        )]
    }

    func fetchVehicleStatus(for vehicle: Vehicle, authToken: AuthToken, cached: Bool) async throws -> VehicleStatus {
        try await Task.sleep(for: .milliseconds(cached ? 200 : 2500))
        var status = Self.status ?? Self.initialStatus
        // `-demoOpenParts` (debug launch argument) shows open-part highlighting.
        if ProcessInfo.processInfo.arguments.contains("-demoOpenParts") {
            status.doorOpen = .init(frontLeft: false, frontRight: true, backLeft: false, backRight: false)
            status.hoodOpen = true
            status.trunkOpen = true
            status.tirePressureWarning = .init(frontLeft: false, frontRight: true, rearLeft: false, rearRight: false, all: false)
        }
        if let pending = Self.pending, Date() >= Self.pendingUntil {
            pending(&status)
            Self.pending = nil
        }
        status.lastUpdated = Date()
        Self.status = status
        return status
    }

    func sendCommand(for vehicle: Vehicle, command: VehicleCommand, authToken: AuthToken) async throws {
        try await Task.sleep(for: .seconds(1))
        Self.pendingUntil = Date().addingTimeInterval(4)
        Self.pending = { status in
            switch command {
            case .lock: status.lockStatus = .locked
            case .unlock: status.lockStatus = .unlocked
            case .startClimate(let options):
                status.climateStatus.airControlOn = true
                status.climateStatus.temperature = options.temperature
            case .stopClimate: status.climateStatus.airControlOn = false
            case .startCharge: status.evStatus?.charging = true; status.evStatus?.chargeSpeed = 10.9
            case .stopCharge: status.evStatus?.charging = false; status.evStatus?.chargeSpeed = 0
            case .setTargetSOC(let ac, let dc):
                status.evStatus?.targetSocAC = Double(ac)
                status.evStatus?.targetSocDC = Double(dc)
            }
        }
    }

    private static let initialStatus = VehicleStatus(
        vin: vin,
        evStatus: .init(
            charging: false, chargeSpeed: 0,
            evRange: .init(range: Distance(length: 214, units: .miles), percentage: 72),
            plugType: .acCharger, chargeTime: .seconds(0),
            targetSocAC: 80, targetSocDC: 90
        ),
        location: .init(latitude: 37.3349, longitude: -122.0090),
        lockStatus: .locked,
        climateStatus: .init(
            defrostOn: false, airControlOn: false, steeringWheelHeatingOn: false,
            temperature: Temperature(units: 1, value: "70")
        ),
        odometer: Distance(length: 12_480, units: .miles),
        battery12V: 86,
        doorOpen: .init(frontLeft: false, frontRight: false, backLeft: false, backRight: false),
        trunkOpen: false, hoodOpen: false,
        tirePressureWarning: .init(frontLeft: false, frontRight: false, rearLeft: false, rearRight: false, all: false)
    )
}
