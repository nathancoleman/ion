import Foundation

/// Works out make, model, year, trim and paint for a vehicle.
///
/// 1. The Bluelink enrollment response (`enrollment/details`) reliably has
///    `modelYear`, `modelCode` and `trim`. Color fields aren't documented, so
///    every string value whose key mentions color/colour/paint is checked
///    against the palette.
/// 2. NHTSA's public VIN decoder fills in make/model/trim. It never has color.
/// 3. Anything still missing is left for the user to pick in Settings.
enum AppearanceResolver {
    struct EnrollmentDetails: Sendable {
        var fields: [String: String] = [:]
        var colorCandidates: [String] = []
    }

    static func resolve(
        vin: String,
        enrollmentJSON: String?,
        previous: CarAppearance?
    ) async -> CarAppearance {
        var appearance = previous ?? CarAppearance()
        let details = enrollmentJSON.flatMap { parseEnrollment($0, vin: vin) }

        if let details {
            if let year = details.fields["modelYear"].flatMap(Int.init) { appearance.year = year }
            if let trim = details.fields["trim"], !trim.isEmpty { appearance.trim = trim }
            if let reported = details.colorCandidates.first { appearance.reportedColor = reported }
            if !appearance.paintIsUserChosen,
               let paint = details.colorCandidates.lazy.compactMap(PaintColor.match).first {
                appearance.paintID = paint.id
            }
        }

        if let decoded = await decodeVIN(vin) {
            if let make = decoded["Make"], !make.isEmpty { appearance.make = make.capitalized }
            if let model = decoded["Model"], !model.isEmpty { appearance.model = model.uppercased() }
            if appearance.year == nil, let year = decoded["ModelYear"].flatMap(Int.init) { appearance.year = year }
            if appearance.trim == nil, let trim = decoded["Trim"], !trim.isEmpty { appearance.trim = trim }
        }
        return appearance
    }

    /// Flattens the matching vehicle's `vehicleDetails` (and any sibling
    /// objects such as `additionalVehicleDetails`) into string fields.
    static func parseEnrollment(_ json: String, vin: String) -> EnrollmentDetails? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["enrolledVehicleDetails"] as? [[String: Any]] else { return nil }

        let entry = entries.first { ($0["vehicleDetails"] as? [String: Any])?["vin"] as? String == vin }
            ?? entries.first
        guard let entry else { return nil }

        var result = EnrollmentDetails()
        func walk(_ value: Any, key: String) {
            switch value {
            case let dict as [String: Any]:
                for (k, v) in dict { walk(v, key: k) }
            case let array as [Any]:
                for v in array { walk(v, key: key) }
            case let string as String:
                if result.fields[key] == nil { result.fields[key] = string }
                let lower = key.lowercased()
                if (lower.contains("color") || lower.contains("colour") || lower.contains("paint")),
                   !string.isEmpty, !string.hasPrefix("http") {
                    result.colorCandidates.append(string)
                }
            case let number as NSNumber:
                if result.fields[key] == nil { result.fields[key] = number.stringValue }
            default:
                break
            }
        }
        walk(entry, key: "")
        return result
    }

    /// NHTSA vPIC decode. Sends only the VIN.
    static func decodeVIN(_ vin: String) async -> [String: String]? {
        guard vin.count == 17,
              let url = URL(string: "https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/\(vin)?format=json")
        else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (root["Results"] as? [[String: Any]])?.first else { return nil }
        return first.compactMapValues { $0 as? String }
    }
}
