import SwiftUI

/// Stylized side profile of an IONIQ 5 (passenger side, nose right), drawn
/// in code and tinted with the car's paint. Drop a bundled image named
/// `car-<paint id>` into the asset catalog to use real artwork instead.
struct CarView: View {
    enum ChargePort { case closed, plugged, charging }

    var paint: PaintColor
    var chargePort: ChargePort = .closed
    /// Lights up the pixel lamps (used to "flash" on lock/unlock).
    var lightsOn = false
    /// Tints the glass when climate is running.
    var climateOn = false
    /// Parts drawn swung open on the photo.
    var openParts: Set<CarPart> = []
    /// Which studio angle to show: front three-quarter (default) or side profile.
    var view: Angle = .front

    enum Angle: String, CaseIterable { case front, side, rear }

    /// Illustrated art style when the app uses one ("sketch", "pastel");
    /// set by the app's theme, widgets leave it nil and show the photo.
    var art: String? = CarView.artTheme
    nonisolated(unsafe) static var artTheme: String?

    @Environment(\.colorScheme) private var colorScheme

    private var imageName: String {
        Self.imageName(view: view, paint: paint, art: art, dark: colorScheme == .dark)
    }

    /// Sketch is one drawing (chalk-on-slate in dark mode); Pastel is painted
    /// in the car's own color; the photo is recolored per paint.
    static func imageName(view: Angle, paint: PaintColor, art: String?, dark: Bool) -> String {
        let prefix = switch view { case .front: "car"; case .side: "car-side"; case .rear: "car-rear" }
        switch art {
        case "pastel": return "\(prefix)-pastel-\(paint.id)"
        case "sketch": return "\(prefix)-sketch\(dark ? "-dark" : "")"
        case let art?: return "\(prefix)-\(art)"
        case nil: return "\(prefix)-\(paint.id)"
        }
    }

    var body: some View {
        if view != .front, let image = UIImage(named: imageName) {
            Image(uiImage: image).resizable().scaledToFit()
        } else if let image = UIImage(named: imageName) {
            // Photo of a real IONIQ 5, recolored per paint (see tools/recolor.py).
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay { OpenPartsLayer(image: image, openParts: openParts) }
                .overlay {
                    GeometryReader { proxy in
                        // Headlight positions in the photo, as fractions of its size.
                        ForEach([CGPoint(x: 0.55, y: 0.50), CGPoint(x: 0.95, y: 0.49)], id: \.x) { point in
                            Ellipse()
                                .fill(RadialGradient(colors: [.white.opacity(0.95), .white.opacity(0)],
                                                     center: .center, startRadius: 0, endRadius: proxy.size.width * 0.07))
                                .frame(width: proxy.size.width * 0.16, height: proxy.size.width * 0.07)
                                .position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
                                .blendMode(.screen)
                        }
                    }
                    .opacity(lightsOn ? 1 : 0)
                }
        } else {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .aspectRatio(240.0 / 100.0, contentMode: .fit)
        }
    }

    // All geometry is on a 240×100 grid and scaled to fit.
    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width / 240, size.height / 100)
        context.translateBy(x: (size.width - 240 * scale) / 2, y: (size.height - 100 * scale) / 2)
        context.scaleBy(x: scale, y: scale)

        let rearWheel = CGPoint(x: 44, y: 76), frontWheel = CGPoint(x: 196, y: 76)

        // Ground shadow
        context.fill(
            Path(ellipseIn: CGRect(x: 10, y: 90, width: 224, height: 10)),
            with: .radialGradient(
                Gradient(colors: [.black.opacity(0.6), .black.opacity(0)]),
                center: CGPoint(x: 122, y: 95), startRadius: 0, endRadius: 112
            )
        )

        // Body
        let body = bodyPath(rearWheel: rearWheel, frontWheel: frontWheel)
        let base = paint.color
        let contrast = paint.finish == .matte ? 0.10 : 0.22
        context.fill(body, with: .linearGradient(
            Gradient(stops: [
                .init(color: base.mix(with: .white, by: contrast), location: 0),
                .init(color: base, location: 0.5),
                .init(color: base.mix(with: .black, by: 0.4), location: 1),
            ]),
            startPoint: CGPoint(x: 0, y: 14), endPoint: CGPoint(x: 0, y: 80)
        ))
        // Shoulder highlight (subtle on matte)
        if paint.finish != .matte {
            var highlight = Path()
            highlight.move(to: CGPoint(x: 10, y: 46))
            highlight.addLine(to: CGPoint(x: 214, y: 48))
            context.stroke(highlight, with: .color(.white.opacity(paint.finish == .gloss ? 0.35 : 0.28)), lineWidth: 1.2)
        }
        // Black lower cladding between the arches
        var cladding = Path()
        cladding.move(to: CGPoint(x: 68, y: 71))
        cladding.addLine(to: CGPoint(x: 172, y: 71))
        cladding.addLine(to: CGPoint(x: 173, y: 77))
        cladding.addLine(to: CGPoint(x: 67, y: 77))
        cladding.closeSubpath()
        context.fill(cladding, with: .color(.black.opacity(0.55)))

        // Greenhouse: black pillars, then glass
        var greenhouse = Path()
        // Rear edge slants forward: the body-colored C-pillar is an IONIQ 5 signature.
        greenhouse.move(to: CGPoint(x: 40, y: 18))
        greenhouse.addLine(to: CGPoint(x: 139, y: 15.5))
        greenhouse.addQuadCurve(to: CGPoint(x: 180, y: 39.5), control: CGPoint(x: 162, y: 21))
        greenhouse.addLine(to: CGPoint(x: 31, y: 41))
        greenhouse.closeSubpath()
        context.fill(greenhouse, with: .color(Color(white: 0.06)))
        // Silver window surround
        var trim = Path()
        trim.move(to: CGPoint(x: 31, y: 41))
        trim.addLine(to: CGPoint(x: 40, y: 18))
        trim.addLine(to: CGPoint(x: 139, y: 15.5))
        trim.addQuadCurve(to: CGPoint(x: 180, y: 39.5), control: CGPoint(x: 162, y: 21))
        context.stroke(trim, with: .color(Color(white: 0.78)), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))

        let glassTint: Color = climateOn ? Color(red: 0.25, green: 0.45, blue: 0.6) : Color(white: 0.22)
        for window in windowPaths() {
            context.fill(window, with: .linearGradient(
                Gradient(colors: [glassTint.opacity(0.95), Color(white: 0.04)]),
                startPoint: CGPoint(x: 0, y: 18), endPoint: CGPoint(x: 40, y: 41)
            ))
        }

        // Door seams, Z-line crease, flush handles, mirror
        var seams = Path()
        seams.move(to: CGPoint(x: 100, y: 41)); seams.addLine(to: CGPoint(x: 100, y: 77))
        seams.move(to: CGPoint(x: 177, y: 41.5)); seams.addLine(to: CGPoint(x: 171, y: 71))
        context.stroke(seams, with: .color(.black.opacity(0.35)), lineWidth: 0.5)

        var crease = Path()
        crease.move(to: CGPoint(x: 170, y: 65))
        crease.addLine(to: CGPoint(x: 72, y: 50))
        context.stroke(crease, with: .color(.black.opacity(0.25)), lineWidth: 0.6)
        context.stroke(crease.offsetBy(dx: 0, dy: -0.8), with: .color(.white.opacity(0.12)), lineWidth: 0.5)

        for x in [78.0, 132.0] {
            context.fill(Path(roundedRect: CGRect(x: x, y: 45, width: 10, height: 1.7), cornerRadius: 0.8),
                         with: .color(.black.opacity(0.4)))
        }
        var mirror = Path()
        mirror.move(to: CGPoint(x: 172, y: 36.5))
        mirror.addLine(to: CGPoint(x: 182, y: 35))
        mirror.addLine(to: CGPoint(x: 184.5, y: 40.5))
        mirror.addLine(to: CGPoint(x: 175, y: 41))
        mirror.closeSubpath()
        context.fill(mirror, with: .color(Color(white: 0.08)))

        drawLamps(in: &context)
        drawChargePort(in: &context)
        drawWheel(in: &context, center: rearWheel)
        drawWheel(in: &context, center: frontWheel)
    }

    private func bodyPath(rearWheel: CGPoint, frontWheel: CGPoint) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 78))
        path.addLine(to: CGPoint(x: 7, y: 66))
        path.addLine(to: CGPoint(x: 7, y: 44))
        path.addQuadCurve(to: CGPoint(x: 16, y: 15), control: CGPoint(x: 8, y: 21))
        path.addLine(to: CGPoint(x: 140, y: 12.5))
        path.addQuadCurve(to: CGPoint(x: 185, y: 40.5), control: CGPoint(x: 166, y: 18))
        path.addLine(to: CGPoint(x: 221, y: 47))
        path.addQuadCurve(to: CGPoint(x: 236, y: 59), control: CGPoint(x: 234, y: 50))
        path.addLine(to: CGPoint(x: 235.5, y: 73))
        path.addLine(to: CGPoint(x: 231, y: 78))
        path.addLine(to: CGPoint(x: frontWheel.x + 23, y: 78))
        addArch(to: &path, center: frontWheel)
        path.addLine(to: CGPoint(x: rearWheel.x + 23, y: 78))
        addArch(to: &path, center: rearWheel)
        path.closeSubpath()
        return path
    }

    /// Wheel arch from the front edge, over the top, to the rear edge.
    private func addArch(to path: inout Path, center: CGPoint, radius: Double = 23) {
        for step in 0...24 {
            let angle = Double.pi * Double(step) / 24
            path.addLine(to: CGPoint(x: center.x + radius * cos(angle), y: center.y + 2 - radius * sin(angle)))
        }
    }

    private func windowPaths() -> [Path] {
        // Rear quarter, rear door, front door
        let shapes: [[CGPoint]] = [
            [.init(x: 42, y: 19.8), .init(x: 98, y: 18.4), .init(x: 98, y: 39.6), .init(x: 34, y: 39.8)],
            [.init(x: 102, y: 18.3), .init(x: 137, y: 17.6), .init(x: 172, y: 38.8), .init(x: 102, y: 39.5)],
        ]
        return shapes.map { points in
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            return path
        }
    }

    private func drawLamps(in context: inout GraphicsContext) {
        // Parametric pixel lamps: a little grid of squares at each end.
        let tail = Color(red: 0.95, green: 0.12, blue: 0.15)
        let head = Color(white: 0.97)
        let dim = 0.45
        for row in 0..<3 {
            for col in 0..<2 {
                let rect = CGRect(x: 8.5 + Double(col) * 2.6, y: 28 + Double(row) * 2.6, width: 2, height: 2)
                context.fill(Path(rect), with: .color(tail.opacity(lightsOn ? 1 : dim)))
            }
        }
        for col in 0..<4 {
            let rect = CGRect(x: 221 + Double(col) * 2.6, y: 52.5, width: 2, height: 1.6)
            context.fill(Path(rect), with: .color(head.opacity(lightsOn ? 1 : dim)))
        }
        if lightsOn {
            for (center, color) in [(CGPoint(x: 11, y: 31), tail), (CGPoint(x: 225.5, y: 53), head)] {
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 8, width: 20, height: 16)),
                    with: .radialGradient(Gradient(colors: [color.opacity(0.6), color.opacity(0)]),
                                          center: center, startRadius: 0, endRadius: 10)
                )
            }
        }
    }

    private func drawChargePort(in context: inout GraphicsContext) {
        // IONIQ 5 charge port: passenger-side rear fender.
        let rect = CGRect(x: 14, y: 47, width: 9, height: 6)
        let door = Path(roundedRect: rect, cornerRadius: 1)
        switch chargePort {
        case .closed:
            context.stroke(door, with: .color(.black.opacity(0.3)), lineWidth: 0.4)
        case .plugged, .charging:
            let glow = chargePort == .charging ? Color(red: 0.3, green: 0.95, blue: 0.55) : Color(red: 0.35, green: 0.6, blue: 1)
            context.fill(
                Path(ellipseIn: rect.insetBy(dx: -8, dy: -8)),
                with: .radialGradient(Gradient(colors: [glow.opacity(0.7), glow.opacity(0)]),
                                      center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: 12)
            )
            context.fill(door, with: .color(Color(white: 0.05)))
            context.stroke(door, with: .color(glow), lineWidth: 0.7)
        }
    }

    private func drawWheel(in context: inout GraphicsContext, center: CGPoint) {
        func circle(_ radius: Double) -> Path {
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        context.fill(circle(19), with: .color(Color(white: 0.07)))
        context.fill(circle(14), with: .linearGradient(
            Gradient(colors: [Color(white: 0.62), Color(white: 0.28)]),
            startPoint: CGPoint(x: center.x, y: center.y - 14), endPoint: CGPoint(x: center.x, y: center.y + 14)
        ))
        // Aero "pixel" wheel: rings of small squares cut into the rim face.
        for ring in [(radius: 10.5, count: 14, size: 2.4), (radius: 6.5, count: 9, size: 2.0)] {
            for index in 0..<ring.count {
                let angle = 2 * Double.pi * Double(index) / Double(ring.count)
                let point = CGPoint(x: center.x + ring.radius * cos(angle), y: center.y + ring.radius * sin(angle))
                let square = Path(CGRect(x: point.x - ring.size / 2, y: point.y - ring.size / 2,
                                         width: ring.size, height: ring.size))
                context.fill(square, with: .color(Color(white: 0.1)))
            }
        }
        context.fill(circle(2.4), with: .color(Color(white: 0.75)))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(PaintColor.all) { paint in
                VStack {
                    CarView(paint: paint, chargePort: .charging, lightsOn: paint.id == "atlas-white")
                    Text(paint.name).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    .background(Color(white: 0.08))
}

/// Draws open parts: a dark opening where the part was, then the part itself
/// (cut from the same photo) rotated on its hinge.
struct OpenPartsLayer: View {
    let image: UIImage
    let openParts: Set<CarPart>

    var body: some View {
        ZStack {
            ForEach(CarPart.allCases.filter { !$0.outline.isEmpty }, id: \.self) { part in
                let open = openParts.contains(part)
                let swing = part.swing
                ZStack {
                    // Cabin / cargo opening behind the part
                    PartShape(points: part.outline)
                        .fill(LinearGradient(colors: [Color(white: 0.02), Color(white: 0.09)],
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(open ? 1 : 0)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .mask(PartShape(points: part.outline))
                        .shadow(color: .black.opacity(open ? 0.55 : 0), radius: 10, x: -4, y: 6)
                        .modifier(SwingEffect(progress: open ? 1 : 0, closed: swing.closed, open: swing.open))
                        .opacity(open ? 1 : 0)
                }
            }
        }
        .animation(.spring(duration: 0.7, bounce: 0.15), value: openParts)
        .allowsHitTesting(false)
    }
}
