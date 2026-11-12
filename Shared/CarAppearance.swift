import Foundation
import SwiftUI

/// What the car looks like, for rendering. Filled from the Bluelink
/// enrollment response, a VIN decode, and anything the user overrides.
struct CarAppearance: Codable, Sendable, Equatable {
    var make: String = "Hyundai"
    var model: String = "IONIQ 5"
    var year: Int?
    var trim: String?
    /// Raw color string the API reported, if any. Kept for display and debugging.
    var reportedColor: String?
    /// Chosen paint. Nil until detected or picked.
    var paintID: String?
    /// Set when the user picks a paint by hand, so a refresh won't override it.
    var paintIsUserChosen = false

    var paint: PaintColor { PaintColor.find(id: paintID) ?? .default }

    var title: String {
        [year.map(String.init), make, model].compactMap { $0 }.joined(separator: " ")
    }
}

struct PaintColor: Identifiable, Sendable, Hashable {
    enum Finish: String, Sendable { case gloss, metallic, pearl, matte }

    let id: String
    let name: String
    let hex: UInt32
    let finish: Finish

    var color: Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// IONIQ 5 palette. Cyber Gray, Lucid Blue, Digital Teal and Gravity Gold
    /// are matched against real photos (Wikimedia Commons); the rest are
    /// estimates and unverified.
    static let all: [PaintColor] = [
        .init(id: "abyss-black", name: "Abyss Black Pearl", hex: 0x16181C, finish: .pearl),
        .init(id: "atlas-white", name: "Atlas White", hex: 0xE9EAE7, finish: .gloss),
        .init(id: "cyber-gray", name: "Cyber Gray Metallic", hex: 0x8D9196, finish: .metallic),
        .init(id: "ecotronic-gray", name: "Ecotronic Gray Pearl", hex: 0x4B4F53, finish: .pearl),
        .init(id: "shooting-star", name: "Shooting-Star Gray Matte", hex: 0x6F7377, finish: .matte),
        .init(id: "gravity-gold", name: "Gravity Gold Matte", hex: 0x5E5A53, finish: .matte),
        .init(id: "lucid-blue", name: "Lucid Blue Pearl", hex: 0x586C7E, finish: .pearl),
        .init(id: "digital-teal", name: "Digital Teal Green Pearl", hex: 0x3C5457, finish: .pearl),
        .init(id: "mystic-olive", name: "Mystic Olive Pearl", hex: 0x5A6150, finish: .pearl),
        .init(id: "ultimate-red", name: "Ultimate Red Metallic", hex: 0x8E1C22, finish: .metallic),
        .init(id: "biophilic-blue", name: "Biophilic Blue Pearl", hex: 0x2F4A57, finish: .pearl),
    ]

    static let `default` = all[2]

    static func find(id: String?) -> PaintColor? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// Fuzzy-matches a color string from the API ("CYBER GRAY", "Abyss Black
    /// Pearl", "C5G Cyber Gray Metallic") to a palette entry.
    static func match(_ raw: String?) -> PaintColor? {
        guard let raw, !raw.isEmpty else { return nil }
        let words = Set(raw.lowercased().split { !$0.isLetter }.map(String.init))
        let ignored: Set<String> = ["pearl", "metallic", "matte", "gray", "grey", "blue"]
        // Prefer a distinctive word ("abyss", "lucid"); fall back to any overlap.
        let scored = all.map { paint -> (PaintColor, Int) in
            let paintWords = Set(paint.name.lowercased().split { !$0.isLetter }.map(String.init))
            let distinctive = paintWords.subtracting(ignored).intersection(words).count
            let any = paintWords.intersection(words).count
            return (paint, distinctive * 10 + any)
        }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 >= 10 else { return nil }
        return best.0
    }
}
