import BetterBlueKit
import UIKit

/// Fake surround-view captures for the demo account: one composite JPEG in
/// Hyundai's layout (four 960×720 cameras + a 632×720 bird's-eye view).
enum DemoSurroundView {
    static func captures() -> [SurroundViewCapture] {
        let layout = [4472, 720, 960, 720, 632, 720]
        let frame = composite()
        let tiles = SurroundViewDecoder.tiles(imageSize: layout, frameCount: 1)
        return [0, 1, 3].map { daysAgo in
            SurroundViewCapture(
                vin: "DEMO", capturedAt: Date.now.addingTimeInterval(Double(-daysAgo * 86_400 - 1_500)),
                location: .init(latitude: 37.3349, longitude: -122.0090), heading: 135,
                doorOpen: .init(frontLeft: false, frontRight: false, backLeft: false, backRight: false),
                trunkOpen: false, sideMirrorOpen: true, frames: [frame], tiles: tiles)
        }
    }

    private static func composite() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4472, height: 720),
                                               format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let names = ["FRONT", "REAR", "LEFT", "RIGHT"]
            let skies: [UIColor] = [.systemTeal, .systemIndigo, .systemOrange, .systemGreen]
            for i in 0..<4 {
                let rect = CGRect(x: i * 960, y: 0, width: 960, height: 720)
                cg.saveGState()
                cg.clip(to: rect)
                UIColor.black.setFill(); cg.fill(rect)
                // Fisheye circle: sky over pavement.
                let lens = UIBezierPath(ovalIn: rect.insetBy(dx: 30, dy: -60))
                lens.addClip()
                skies[i].withAlphaComponent(0.55).setFill()
                cg.fill(CGRect(x: rect.minX, y: 0, width: 960, height: 330))
                UIColor(white: 0.32, alpha: 1).setFill()
                cg.fill(CGRect(x: rect.minX, y: 330, width: 960, height: 390))
                UIColor(white: 0.9, alpha: 0.8).setStroke()
                for x in stride(from: -400.0, through: 1400, by: 360) {
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: rect.minX + 480, y: 330))
                    path.addLine(to: CGPoint(x: rect.minX + x, y: 720))
                    path.lineWidth = 10; path.stroke()
                }
                (names[i] as NSString).draw(at: CGPoint(x: rect.minX + 400, y: 120), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 56, weight: .heavy), .foregroundColor: UIColor.white])
                cg.restoreGState()
            }
            // Bird's-eye: pavement, parking lines, car from above.
            let top = CGRect(x: 3840, y: 0, width: 632, height: 720)
            UIColor(white: 0.3, alpha: 1).setFill(); cg.fill(top)
            UIColor(white: 0.92, alpha: 0.9).setFill()
            cg.fill(CGRect(x: top.minX + 60, y: 0, width: 12, height: 720))
            cg.fill(CGRect(x: top.maxX - 72, y: 0, width: 12, height: 720))
            let car = CGRect(x: top.midX - 120, y: top.midY - 250, width: 240, height: 500)
            UIColor(white: 0.62, alpha: 1).setFill()
            UIBezierPath(roundedRect: car, cornerRadius: 60).fill()
            UIColor(white: 0.12, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: car.minX + 28, y: car.minY + 110, width: 184, height: 90), cornerRadius: 24).fill()
            UIBezierPath(roundedRect: CGRect(x: car.minX + 28, y: car.maxY - 150, width: 184, height: 70), cornerRadius: 20).fill()
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
