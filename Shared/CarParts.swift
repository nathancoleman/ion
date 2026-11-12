import BetterBlueKit
import SwiftUI

/// Outlines of the car's openable parts on the photo, in percent of the image
/// (passenger side is visible, so either side's doors light the visible ones).
enum CarPart: CaseIterable {
    case frontDoor, rearDoor, frunk, liftgate

    /// Outline in percent of the photo (studio front three-quarter, mirrored
    /// so the nose points right). Doors include their window frame. The
    /// liftgate isn't visible from this angle, so it has no outline.
    var outline: [CGPoint] {
        let points: [(Double, Double)] = switch self {
        case .frontDoor: [(19, 6), (29, 4.5), (32, 28), (34, 40), (31, 52), (30, 76), (17, 70), (16.5, 28)]
        case .rearDoor: [(9.5, 9), (19, 6), (16.5, 28), (17, 70), (9, 63), (6, 48), (5, 30)]
        case .frunk: [(31, 29), (73, 28), (96, 38), (98, 46), (45, 47), (36, 40)]
        case .liftgate: []
        }
        return points.map { CGPoint(x: $0.0 / 100, y: $0.1 / 100) }
    }

    /// Four reference points on the part (fractions of the photo) and where
    /// they land when it's open. Two sit on the hinge and stay put; the free
    /// edge swings out toward the camera.
    var swing: (closed: [CGPoint], open: [CGPoint]) {
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
        switch self {
        case .frontDoor:
            return ([p(0.32, 0.28), p(0.31, 0.72), p(0.17, 0.70), p(0.19, 0.06)],
                    [p(0.32, 0.28), p(0.31, 0.72), p(0.05, 0.84), p(0.06, 0.02)])
        case .rearDoor:
            return ([p(0.17, 0.28), p(0.17, 0.70), p(0.09, 0.63), p(0.095, 0.09)],
                    [p(0.17, 0.28), p(0.17, 0.70), p(0.00, 0.74), p(0.01, 0.08)])
        case .frunk:
            return ([p(0.31, 0.29), p(0.73, 0.28), p(0.98, 0.46), p(0.45, 0.47)],
                    [p(0.31, 0.29), p(0.73, 0.28), p(0.92, 0.06), p(0.42, 0.10)])
        case .liftgate:
            return ([], [])
        }
    }

    static func open(in status: VehicleStatus?) -> Set<CarPart> {
        guard let status else { return [] }
        var parts = Set<CarPart>()
        if let doors = status.doorOpen {
            if doors.frontLeft || doors.frontRight { parts.insert(.frontDoor) }
            if doors.backLeft || doors.backRight { parts.insert(.rearDoor) }
        }
        if status.hoodOpen == true { parts.insert(.frunk) }
        if status.trunkOpen == true { parts.insert(.liftgate) }
        return parts
    }
}

struct PartShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
        path.closeSubpath()
        return path
    }
}


/// Orange ring around a wheel with a tire-pressure warning.
struct CarStateOverlay: View {
    let status: VehicleStatus?
    @State private var pulse = false

    private var tireRings: [CGPoint] {
        guard let tires = status?.tirePressureWarning, tires.hasWarning else { return [] }
        var rings: [CGPoint] = []
        if tires.all || tires.rearLeft || tires.rearRight { rings.append(CGPoint(x: 0.05, y: 0.72)) }
        if tires.all || tires.frontLeft || tires.frontRight { rings.append(CGPoint(x: 0.385, y: 0.76)) }
        return rings
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(tireRings, id: \.x) { center in
                    Ellipse()
                        .stroke(Color.orange, lineWidth: 2.5)
                        .shadow(color: .orange, radius: pulse ? 8 : 3)
                        .frame(width: proxy.size.width * 0.15, height: proxy.size.height * 0.36)
                        .position(x: proxy.size.width * center.x, y: proxy.size.height * center.y)
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

/// Warps a view so four reference points move to new positions (a
/// perspective "swing"), animatable from closed (0) to open (1).
struct SwingEffect: GeometryEffect {
    var progress: Double
    let closed: [CGPoint]
    let open: [CGPoint]

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard progress > 0.001 else { return ProjectionTransform() }
        let src = closed.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let dst = zip(closed, open).map { c, o in
            CGPoint(x: (c.x + (o.x - c.x) * progress) * size.width, y: (c.y + (o.y - c.y) * progress) * size.height)
        }
        return Homography.transform(from: src, to: dst) ?? ProjectionTransform()
    }
}

enum Homography {
    /// Solves the 3×3 perspective transform mapping four points onto four others.
    static func transform(from src: [CGPoint], to dst: [CGPoint]) -> ProjectionTransform? {
        // 8 unknowns (h33 = 1): for each pair, two linear equations.
        var a = [[Double]](repeating: [Double](repeating: 0, count: 9), count: 8)
        for i in 0..<4 {
            let x = Double(src[i].x), y = Double(src[i].y), u = Double(dst[i].x), v = Double(dst[i].y)
            a[2 * i] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u]
            a[2 * i + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v]
        }
        // Gaussian elimination with partial pivoting.
        for col in 0..<8 {
            guard let pivot = (col..<8).max(by: { abs(a[$0][col]) < abs(a[$1][col]) }), abs(a[pivot][col]) > 1e-12
            else { return nil }
            a.swapAt(col, pivot)
            for row in 0..<8 where row != col {
                let f = a[row][col] / a[col][col]
                for k in col..<9 { a[row][k] -= f * a[col][k] }
            }
        }
        let h = (0..<8).map { a[$0][8] / a[$0][$0] }
        // ProjectionTransform uses row vectors ([x y 1] · M), so transpose.
        var t = ProjectionTransform()
        t.m11 = h[0]; t.m21 = h[1]; t.m31 = h[2]
        t.m12 = h[3]; t.m22 = h[4]; t.m32 = h[5]
        t.m13 = h[6]; t.m23 = h[7]; t.m33 = 1
        return t
    }
}
