import BetterBlueKit
import MapKit
import SwiftUI

/// Surround View: the bird's-eye image as the hero, the four cameras around
/// it in their positions on the car, full-screen zoomable camera views,
/// capture details, history, and a new capture that waits for the upload.
struct SurroundViewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var captures: [SurroundViewCapture] = []
    @State private var selectedID: String?
    @State private var isLoading = true
    @State private var capturing: Date?
    @State private var error: String?
    @State private var fullscreen: CameraFocus?

    struct CameraFocus: Identifiable {
        let captureID: String
        let position: SurroundViewCameraPosition
        var id: String { "\(captureID)-\(position.rawValue)" }
    }

    private var selected: SurroundViewCapture? {
        captures.first { $0.id == selectedID } ?? captures.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let capturing { CapturingBanner(startedAt: capturing) }

                    if isLoading && captures.isEmpty {
                        ProgressView("Loading captures…").frame(maxWidth: .infinity).padding(.top, 80)
                    } else if let capture = selected {
                        SurroundLayout(views: CameraViews(capture: capture)) { position in
                            fullscreen = CameraFocus(captureID: capture.id, position: position)
                        }
                        CaptureDetails(capture: capture)
                        if captures.count > 1 { history }
                    } else {
                        ContentUnavailableView(
                            "No captures yet",
                            systemImage: "camera.metering.unknown",
                            description: Text("Tap New Capture. The car wakes its cameras and uploads in a few minutes.")
                        )
                        .padding(.top, 40)
                    }

                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.warning)
                    }
                }
                .padding(20)
            }
            .ionScreen(focusY: 0.25)
            .navigationTitle("Surround View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Capture", systemImage: "camera.fill") { Task { await requestCapture() } }
                        .disabled(capturing != nil)
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .fullScreenCover(item: $fullscreen) { focus in
                if let capture = captures.first(where: { $0.id == focus.captureID }) {
                    CameraViewer(views: CameraViews(capture: capture), start: focus.position)
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Earlier captures")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(captures) { capture in
                        let views = CameraViews(capture: capture)
                        Button { withAnimation { selectedID = capture.id } } label: {
                            VStack(spacing: 4) {
                                (views.image(.topDown) ?? views.image(.composite)).map {
                                    Image(uiImage: $0).resizable().scaledToFill()
                                }
                                .frame(width: 72, height: 82)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(capture.id == selected?.id ? Theme.accent : Theme.hairline, lineWidth: 2))
                                Text(capture.capturedAt.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "--")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func load() async {
        defer { isLoading = false }
        do {
            captures = try await CarService.shared.surroundViewCaptures()
                .sorted { ($0.capturedAt ?? .distantPast) > ($1.capturedAt ?? .distantPast) }
            error = nil
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    /// Asks the car for a capture, then checks every 20 s (up to 6 min) until
    /// a capture newer than the request shows up.
    private func requestCapture() async {
        let started = Date()
        do {
            try await CarService.shared.requestSurroundView()
            capturing = started
            error = nil
            for _ in 0..<18 {
                try? await Task.sleep(for: .seconds(20))
                await load()
                if let newest = captures.first?.capturedAt, newest > started.addingTimeInterval(-60) {
                    selectedID = captures.first?.id
                    break
                }
            }
            if captures.first?.capturedAt.map({ $0 < started.addingTimeInterval(-60) }) ?? true {
                error = "The car hasn't uploaded the new capture yet. Pull to refresh in a few minutes."
            }
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
        capturing = nil
    }
}

/// Crops each camera out of a capture's frames using BetterBlueKit's tiles.
struct CameraViews {
    let capture: SurroundViewCapture
    private let images: [SurroundViewCameraPosition: UIImage]

    init(capture: SurroundViewCapture) {
        self.capture = capture
        let frames = capture.frames.map { UIImage(data: $0) }
        var images: [SurroundViewCameraPosition: UIImage] = [:]
        for tile in capture.tiles {
            guard tile.frameIndex < frames.count, let frame = frames[tile.frameIndex] else { continue }
            if let crop = tile.crop, let cg = frame.cgImage?.cropping(to: CGRect(
                x: crop.originX, y: crop.originY, width: crop.width, height: crop.height)) {
                images[tile.position] = UIImage(cgImage: cg)
            } else {
                images[tile.position] = frame
            }
        }
        if images.isEmpty, let first = frames.first ?? nil { images[.composite] = first }
        self.images = images
    }

    func image(_ position: SurroundViewCameraPosition) -> UIImage? { images[position] }

    /// Cameras in viewing order, for swiping in the full-screen viewer.
    var ordered: [SurroundViewCameraPosition] {
        [.topDown, .front, .right, .rear, .left, .composite].filter { images[$0] != nil }
    }
}

/// Bird's-eye view in the middle, each camera placed where it is on the car.
struct SurroundLayout: View {
    let views: CameraViews
    let onSelect: (SurroundViewCameraPosition) -> Void

    var body: some View {
        if views.image(.topDown) == nil {
            // Unknown layout: show whatever came back, full width.
            if let image = views.image(.composite) ?? views.ordered.first.flatMap(views.image) {
                Image(uiImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    .onTapGesture { onSelect(views.ordered.first ?? .composite) }
            }
        } else {
            VStack(spacing: 10) {
                camera(.front)
                HStack(spacing: 10) {
                    camera(.left).frame(maxWidth: .infinity)
                    if let top = views.image(.topDown) {
                        Button { onSelect(.topDown) } label: {
                            Image(uiImage: top).resizable().scaledToFit()
                                .frame(height: 230)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))
                                .overlay(alignment: .bottom) { label("Bird's-eye").padding(6) }
                        }
                        .buttonStyle(.plain)
                        .layoutPriority(1)
                    }
                    camera(.right).frame(maxWidth: .infinity)
                }
                .frame(height: 230)
                camera(.rear)
            }
        }
    }

    @ViewBuilder
    private func camera(_ position: SurroundViewCameraPosition) -> some View {
        if let image = views.image(position) {
            Button { onSelect(position) } label: {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: position == .front || position == .rear ? 120 : 230)
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline))
                    .overlay(alignment: .topLeading) { label(position.displayName).padding(6) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

/// When and where the capture was taken, and what was open at the time.
struct CaptureDetails: View {
    let capture: SurroundViewCapture

    var body: some View {
        GroupedSection(title: "Capture") {
            RowLabel(icon: "clock", title: capture.capturedAt.map {
                $0.formatted(.relative(presentation: .named)).capitalized
            } ?? "Unknown time", detail: capture.capturedAt?.formatted(date: .abbreviated, time: .shortened)) { EmptyView() }

            if let location = capture.location, location.hasCoordinates {
                Button {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude, longitude: location.longitude)))
                    item.name = "Car at capture"
                    item.openInMaps()
                } label: {
                    RowLabel(icon: "mappin.and.ellipse", title: "Location",
                             detail: capture.heading.map { "Facing \(compass($0)) · Open in Maps" } ?? "Open in Maps")
                }
                .buttonStyle(.plain)
            }

            RowLabel(icon: openSummary.isEmpty ? "checkmark.shield" : "exclamationmark.triangle",
                     tint: openSummary.isEmpty ? Theme.accent : Theme.warning,
                     title: openSummary.isEmpty ? "All closed" : "Open at capture",
                     detail: openSummary.isEmpty ? "Doors, liftgate and mirrors" : openSummary.joined(separator: ", ")) { EmptyView() }
        }
    }

    private var openSummary: [String] {
        var open: [String] = []
        if let doors = capture.doorOpen, doors.anyOpen { open.append("Doors (\(doors.openDoorsDescription))") }
        if capture.trunkOpen == true { open.append("Liftgate") }
        if capture.sideMirrorOpen == false { open.append("Mirrors folded") }
        return open
    }

    private func compass(_ degrees: Int) -> String {
        ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Int((Double(degrees % 360) + 22.5) / 45) % 8]
    }
}

/// Full-screen camera views: swipe between cameras, pinch or double-tap to zoom.
struct CameraViewer: View {
    let views: CameraViews
    @State var start: SurroundViewCameraPosition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $start) {
                ForEach(views.ordered, id: \.self) { position in
                    if let image = views.image(position) {
                        ZoomableImage(image: image)
                            .overlay(alignment: .bottom) {
                                Text(position == .topDown ? "Bird's-eye" : "\(position.displayName) camera")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(.bottom, 40)
                            }
                            .tag(position)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }
}

struct ZoomableImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { scale = max(1, min(lastScale * $0.magnification, 5)) }
                    .onEnded { _ in lastScale = scale; if scale == 1 { offset = .zero; lastOffset = .zero } }
                    .simultaneously(with: DragGesture()
                        .onChanged { value in
                            guard scale > 1 else { return }
                            offset = CGSize(width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height)
                        }
                        .onEnded { _ in lastOffset = offset })
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring) {
                    if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                    else { scale = 2.5; lastScale = 2.5 }
                }
            }
    }
}

struct CapturingBanner: View {
    let startedAt: Date

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text("Capturing…").font(.subheadline.weight(.semibold))
                Text("The car is waking its cameras and uploading. Usually 2–5 minutes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text(Duration.seconds(context.date.timeIntervalSince(startedAt)).formatted(.time(pattern: .minuteSecond)))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .surface()
    }
}
