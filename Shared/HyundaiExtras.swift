import BetterBlueKit
import Foundation

/// Bluelink US requests that BetterBlueKit doesn't wrap, found by watching
/// the MyHyundai app. They take the same login token BetterBlueKit issues.
enum HyundaiExtras {
    static let host = "api.telematics.hyundaiusa.com"

    /// One charging session billed through Hyundai's charging network.
    struct ChargeOrder: Sendable {
        let id: String
        let start: Date
        let stop: Date
        let kWh: Double
        let price: Double
        let currency: String
        let station: String
        let network: String?
        let street: String?
        let city: String?
    }

    /// Hyundai's charge history (`msa/iac/orderInfo`) for a date range.
    static func chargeOrders(from start: Date, to end: Date, vehicle: Vehicle, token: AuthToken,
                             credentials: Credentials) async throws -> [ChargeOrder] {
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyyMMdd"
        let body: [String: Any] = [
            "startDate": day.string(from: start), "endDate": day.string(from: end),
            "profileId": credentials.username, "brandIndicator": "H",
        ]
        let headers = [
            "VIN": vehicle.vin, "userId": credentials.username, "brand": "H", "driver": "1",
            "TID": UUID().uuidString, "Date": day.string(from: Date()),
        ]
        let json = try await post("ac/v2/msa/iac/orderInfo", body: body, extraHeaders: headers, token: token)
        guard let rows = json["resultData"] as? [[String: Any]] else { return [] }

        let iso = ISO8601DateFormatter()
        return rows.compactMap { row in
            guard (row["ordStatCd"] as? String) == "SUCCESS",
                  let start = (row["startDateTime"] as? String).flatMap(iso.date(from:)),
                  let stop = (row["stopDateTime"] as? String).flatMap(iso.date(from:)) else { return nil }
            func number(_ key: String) -> Double { (row[key] as? Double) ?? Double(row[key] as? String ?? "") ?? 0 }
            let rawName = row["ordNm"] as? String ?? "Charging station"
            return ChargeOrder(
                id: row["trId"] as? String ?? row["ordNo"] as? String ?? UUID().uuidString,
                start: start, stop: stop,
                kWh: number("totalEnergy"), price: number("totalPrice"),
                currency: row["curr"] as? String ?? "USD",
                station: rawName.replacingOccurrences(of: "[Charging Station] ", with: ""),
                network: row["merchantNm"] as? String,
                street: row["addrStreet"] as? String,
                city: row["addrCity"] as? String
            )
        }
    }

    /// Battery preconditioning on/off (`ts/ev/rbc`), as MyHyundai sends it.
    static func setBatteryPreconditioning(_ on: Bool, vehicle: Vehicle, token: AuthToken,
                                          credentials: Credentials) async throws {
        let headers = [
            "vin": vehicle.vin, "APPCLOUD-VIN": vehicle.vin, "registrationId": vehicle.regId,
            "gen": String(vehicle.generation), "username": credentials.username, "brandIndicator": "H",
            "To": "ISS",
        ]
        _ = try await post("ac/v2/ts/ev/rbc", body: ["batteryConditioning": on ? 1 : 0],
                           extraHeaders: headers, token: token)
    }

    // MARK: Valet mode

    /// Valet status (`alerts/valet/report`): true when valet mode is on.
    static func valetActive(vehicle: Vehicle, token: AuthToken, credentials: Credentials) async throws -> Bool {
        let json = try await send("GET", "ac/v2/alerts/valet/report", body: nil,
                                  extraHeaders: valetHeaders(vehicle, credentials), token: token)
        return (json["valetParkingStatus"] as? String)?.uppercased() == "ACTIVE"
    }

    /// Turns valet mode on/off. MyHyundai authorizes this with a separate PIN
    /// token; Ion sends the Bluelink PIN header that its other commands use.
    static func setValet(_ on: Bool, vehicle: Vehicle, token: AuthToken, credentials: Credentials) async throws {
        _ = try await send("POST", on ? "ac/v2/alerts/valet/activate" : "ac/v2/alerts/valet/deactivate",
                           body: [:], extraHeaders: valetHeaders(vehicle, credentials), token: token)
    }

    private static func valetHeaders(_ vehicle: Vehicle, _ credentials: Credentials) -> [String: String] {
        [
            "vin": vehicle.vin, "APPCLOUD-VIN": vehicle.vin, "registrationId": vehicle.regId,
            "gen": String(vehicle.generation), "username": credentials.username, "userId": credentials.username,
            "login_id": credentials.username, "brandIndicator": "H", "To": "ISS",
            "blueLinkServicePin": credentials.pin,
        ]
    }

    private static func post(_ path: String, body: [String: Any], extraHeaders: [String: String],
                             token: AuthToken) async throws -> [String: Any] {
        try await send("POST", path, body: body, extraHeaders: extraHeaders, token: token)
    }

    private static func send(_ method: String, _ path: String, body: [String: Any]?, extraHeaders: [String: String],
                             token: AuthToken) async throws -> [String: Any] {
        guard let url = URL(string: "https://\(host)/\(path)") else { return [:] }
        var request = URLRequest(url: url)
        request.httpMethod = method
        var headers: [String: String] = [
            "client_id": "m66129Bb-em93-SPAHYN-bZ91-am4540zp19920",
            "client_secret": "v558o935-6nne-423i-baa8",
            "access_token": token.accessToken,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "from": "SPA", "language": "0",
            "offset": String(TimeZone.current.secondsFromGMT() / 3600),
        ]
        headers.merge(extraHeaders) { $1 }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if status == 401 { throw APIError.invalidCredentials("Session expired", apiName: "Ion") }
        guard (200...299).contains(status) else {
            let message = json["errorMessage"] as? String ?? json["errorMsg"] as? String ?? "HTTP \(status)"
            throw APIError(message: message, code: status, apiName: "Ion")
        }
        if let code = json["code"] as? Int, code != 0 {
            throw APIError(message: json["errorMsg"] as? String ?? "Bluelink error \(code)", code: code, apiName: "Ion")
        }
        return json
    }
}
