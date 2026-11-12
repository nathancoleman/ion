import BetterBlueKit
import Foundation

/// Flash lights / horn and lights. BetterBlueKit doesn't wrap these, so this
/// sends the same requests the MyHyundai app does (endpoints and headers
/// match hyundai_kia_connect_api's HyundaiBlueLinkApiUSA).
enum SignalKind: String, Sendable {
    case lights, hornAndLights

    var path: String { self == .lights ? "ac/v2/rcs/rhl/light" : "ac/v2/rcs/rhl/hnl" }
}

enum SignalCommands {
    static func send(_ kind: SignalKind, vehicle: Vehicle, token: AuthToken, credentials: Credentials) async throws {
        let host = "api.telematics.hyundaiusa.com"
        guard let url = URL(string: "https://\(host)/\(kind.path)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        let headers: [String: String] = [
            "client_id": "m66129Bb-em93-SPAHYN-bZ91-am4540zp19920",
            "clientSecret": "v558o935-6nne-423i-baa8",
            "User-Agent": "okhttp/3.12.0",
            "Content-Type": "application/json",
            "Accept": "application/json, text/plain, */*",
            "accessToken": token.accessToken,
            "language": "0", "to": "ISS", "from": "SPA", "encryptFlag": "false",
            "offset": "-5", "brandIndicator": "H",
            "origin": "https://\(host)", "referer": "https://\(host)/login",
            "username": credentials.username,
            "blueLinkServicePin": credentials.pin,
            "refresh": "false",
            "gen": String(vehicle.generation),
            "registrationId": vehicle.regId,
            "vin": vehicle.vin,
            "APPCLOUD-VIN": vehicle.vin,
            "payloadGenerated": formatter.string(from: Date()),
            "includeNonConnectedVehicles": "Y",
        ]
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = try JSONSerialization.data(withJSONObject: ["userName": credentials.username, "vin": vehicle.vin])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["errorMessage"] as? String {
            throw APIError(message: message, code: status, apiName: "Ion")
        }
        guard (200...299).contains(status) else {
            if status == 401 { throw APIError.invalidCredentials("Session expired", apiName: "Ion") }
            throw APIError(message: "Bluelink returned HTTP \(status)", code: status, apiName: "Ion")
        }
    }
}
