import ARKit
import Flutter
import SceneKit
import UIKit

/// A Flutter platform view hosting a live ARKit session. Renders the camera feed
/// via `ARSCNView`, raycasts from the screen centre each frame to measure the
/// camera-to-food distance, and can capture a still frame with camera intrinsics.
final class ArKitPlatformView: NSObject, FlutterPlatformView, ARSessionDelegate {

    private let sceneView = ARSCNView()
    private weak var controller: ArController?
    private var distanceWindow: [Double] = []
    // Retained so resumeSession() can re-run the exact same configuration
    // after the app comes back from the background, instead of rebuilding it.
    private let configuration = ARWorldTrackingConfiguration()

    private let stabilityWindow = 8
    private let stabilityStdCm = 1.0

    // "Sticky" anchor point (view coordinates) — re-tested every frame before
    // falling back to a fresh search, so the on-screen dot doesn't jitter
    // between candidates while the same spot is still a valid plane hit.
    private var lastAnchorPoint: CGPoint?
    private static let anchorRingRadiusFractions: [CGFloat] = [0.15, 0.30, 0.45]
    private static let anchorRingAngleCount = 8

    // Set once at session start: ARKit only ever populates `sceneDepth` on
    // LiDAR-equipped devices, so unlike Android's ARCore Depth API this
    // maps to a specific, knowable sensor tier rather than "depth API
    // supported, hardware unknown".
    private let depthSource: String

    init(frame: CGRect, controller: ArController) {
        self.controller = controller
        let lidarAvailable = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        self.depthSource = lidarAvailable ? "lidar" : "none"
        super.init()

        sceneView.frame = frame
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true

        configuration.planeDetection = [.horizontal]
        if lidarAvailable {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        controller.attach(self)
    }

    func view() -> UIView { sceneView }

    func dispose() {
        sceneView.session.pause()
    }

    /// Called when the app is backgrounded mid-scan. Without this, the
    /// ARKit session (and the camera it holds) kept running even while the
    /// app wasn't visible.
    func pauseSession() {
        sceneView.session.pause()
    }

    /// Resumes with the same configuration, no reset — ARKit relocalizes
    /// automatically if tracking was lost while paused, which is preferable
    /// to throwing away the user's in-progress scan.
    func resumeSession() {
        sceneView.session.run(configuration, options: [])
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let anchor = findAnchorPoint(frame: frame) else {
            distanceWindow.removeAll()
            controller?.emitDistance(nil, stable: false, depthSource: depthSource, anchorX: nil, anchorY: nil)
            return
        }
        distanceWindow.append(anchor.distanceCm)
        if distanceWindow.count > stabilityWindow {
            distanceWindow.removeFirst(distanceWindow.count - stabilityWindow)
        }
        let mean = distanceWindow.reduce(0, +) / Double(distanceWindow.count)
        let variance = distanceWindow.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(distanceWindow.count)
        let stable = distanceWindow.count >= stabilityWindow && variance.squareRoot() < stabilityStdCm
        let bounds = sceneView.bounds
        let anchorX = bounds.width > 0 ? Double(anchor.point.x / bounds.width) : nil
        let anchorY = bounds.height > 0 ? Double(anchor.point.y / bounds.height) : nil
        controller?.emitDistance(mean, stable: stable, depthSource: depthSource, anchorX: anchorX, anchorY: anchorY)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        controller?.emitSessionError(error.localizedDescription)
    }

    // MARK: - Capture

    func capture() -> [String: Any]? {
        guard let frame = sceneView.session.currentFrame else { return nil }
        guard let imagePath = saveCapturedImage(frame.capturedImage) else { return nil }

        let intrinsics = frame.camera.intrinsics
        let resolution = frame.camera.imageResolution
        var payload: [String: Any] = [
            "imagePath": imagePath,
            "width": Int(resolution.width),
            "height": Int(resolution.height),
            "fx": Double(intrinsics.columns.0.x),
            "fy": Double(intrinsics.columns.1.y),
            "cx": Double(intrinsics.columns.2.x),
            "cy": Double(intrinsics.columns.2.y),
        ]
        // Gather every candidate that currently lands on the plane this
        // frame — not just one — since this side has no way to know which
        // screen pixel will turn out to overlap food once segmentation runs
        // server-side. Each candidate carries its own real measured
        // distance; the server picks whichever one doesn't land on food
        // after segmentation, in priority order (see candidateAnchorPoints).
        let candidates = allValidAnchorCandidates(frame: frame)
        if !candidates.isEmpty {
            payload["anchorCandidates"] = candidates.compactMap { candidate -> [String: Any]? in
                guard let pixel = imagePixel(forViewPoint: candidate.point, frame: frame) else { return nil }
                return [
                    "x": Double(pixel.x),
                    "y": Double(pixel.y),
                    "distanceCm": candidate.distanceCm,
                ]
            }
            // Legacy single-point fields, kept for older server builds /
            // rollback safety — first candidate is the highest-priority one.
            let first = candidates[0]
            payload["distanceCm"] = first.distanceCm
            if let pixel = imagePixel(forViewPoint: first.point, frame: frame) {
                payload["anchorPixelX"] = Double(pixel.x)
                payload["anchorPixelY"] = Double(pixel.y)
            }
        }
        // Tier 1 (LiDAR/ToF iPhones): a dense per-pixel depth map is
        // available straight from the sensor — far more accurate than the
        // single-point raycast distance, so use it directly. Tier 3
        // (no LiDAR) devices never populate `sceneDepth`; they fall back to
        // `distanceCm`-only anchoring, which is the existing behaviour above.
        if let sceneDepth = frame.sceneDepth,
           let depthPath = saveDepthAsNpyCm(depthMap: sceneDepth.depthMap, confidenceMap: sceneDepth.confidenceMap) {
            payload["depthMapPath"] = depthPath
            payload["depthUnit"] = "cm"
        }
        return payload
    }

    /// Reads ARKit's metric depth map (metres) — confidence-filtered against
    /// `confidenceMap` (low-confidence pixels are zeroed, the same invalid
    /// sentinel the rest of this pipeline already uses) — converts to
    /// centimetres and writes it as a .npy float32 array for the AI server's
    /// `load_client_depth_map`.
    private func saveDepthAsNpyCm(depthMap: CVPixelBuffer, confidenceMap: CVPixelBuffer?) -> String? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        var confidenceBase: UnsafeMutableRawPointer?
        var confidenceStride = 0
        if let confidenceMap = confidenceMap,
           CVPixelBufferGetWidth(confidenceMap) == width,
           CVPixelBufferGetHeight(confidenceMap) == height {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            confidenceBase = CVPixelBufferGetBaseAddress(confidenceMap)
            confidenceStride = CVPixelBufferGetBytesPerRow(confidenceMap)
        }
        defer {
            if let confidenceMap = confidenceMap, confidenceBase != nil {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
            }
        }

        var values = [Float](repeating: 0, count: width * height)
        for row in 0..<height {
            let rowPtr = base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: Float32.self)
            let confidenceRowPtr = confidenceBase?.advanced(by: row * confidenceStride).assumingMemoryBound(to: UInt8.self)
            for col in 0..<width {
                let meters = rowPtr[col]
                var cm: Float = meters.isFinite ? meters * 100.0 : 0
                // ARConfidenceLevel: 0 = low, 1 = medium, 2 = high. Drop low-
                // confidence pixels rather than feed noisy geometry forward.
                if let confidenceRowPtr = confidenceRowPtr, confidenceRowPtr[col] < 1 {
                    cm = 0
                }
                values[row * width + col] = cm
            }
        }

        return writeNpyFloat32(values, rows: height, cols: width)
    }

    /// Minimal NPY v1.0 writer (float32, C-order) — avoids the bit-depth /
    /// codec ambiguity an image format would introduce for raw depth.
    private func writeNpyFloat32(_ values: [Float], rows: Int, cols: Int) -> String? {
        let headerDict = "{'descr': '<f4', 'fortran_order': False, 'shape': (\(rows), \(cols)), }"
        let preHeaderLen = 6 + 2 + 2
        let totalLen = preHeaderLen + headerDict.count + 1
        let pad = (64 - (totalLen % 64)) % 64
        let header = headerDict + String(repeating: " ", count: pad) + "\n"
        guard let headerBytes = header.data(using: .ascii) else { return nil }

        var data = Data([0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59]) // \x93NUMPY
        data.append(1) // major version
        data.append(0) // minor version
        var headerLen = UInt16(headerBytes.count).littleEndian
        withUnsafeBytes(of: &headerLen) { data.append(contentsOf: $0) }
        data.append(headerBytes)
        for v in values {
            var le = v.bitPattern.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        let fileName = "ar_depth_\(UUID().uuidString).npy"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }

    // MARK: - Internals

    /// Raycasts a single view-space point against the detected horizontal
    /// plane (extrapolated, like the old fixed-centre version) and returns
    /// the camera-to-hit distance if it lands on the plane.
    private func raycastDistanceCm(at point: CGPoint, frame: ARFrame) -> Double? {
        guard sceneView.bounds.width > 0,
              let query = sceneView.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .horizontal),
              let result = sceneView.session.raycast(query).first
        else { return nil }

        let camera = frame.camera.transform.columns.3
        let hit = result.worldTransform.columns.3
        let dx = camera.x - hit.x
        let dy = camera.y - hit.y
        let dz = camera.z - hit.z
        let meters = (dx * dx + dy * dy + dz * dz).squareRoot()
        return Double(meters) * 100.0
    }

    /// Candidate points for the anchor search: rings from the outer edge
    /// inward (up to 90% of the half-extent, leaving a ~10% margin near the
    /// edges where lens distortion is worst), screen centre tried *last*.
    /// The user always frames the food near the centre, so the centre point
    /// is the single most likely candidate to land on food once segmented —
    /// trying it last (rather than first, as before) means the ring search
    /// only falls back to it when nothing further out hit the plane.
    private func candidateAnchorPoints(in bounds: CGRect) -> [CGPoint] {
        let cx = bounds.midX
        let cy = bounds.midY
        let halfW = bounds.width / 2
        let halfH = bounds.height / 2
        var points: [CGPoint] = []
        for radiusFraction in Self.anchorRingRadiusFractions.reversed() {
            for i in 0..<Self.anchorRingAngleCount {
                let angle = (CGFloat(i) / CGFloat(Self.anchorRingAngleCount)) * 2 * .pi
                let dx = cos(angle) * radiusFraction * halfW
                let dy = sin(angle) * radiusFraction * halfH
                points.append(CGPoint(x: cx + dx, y: cy + dy))
            }
        }
        points.append(CGPoint(x: cx, y: cy))
        return points
    }

    /// All candidate points that currently land on the plane this frame, in
    /// the same outside-in priority order as `candidateAnchorPoints` — used
    /// at capture time so the server has multiple options to choose from
    /// once it knows where food actually is (this side can't know that).
    private func allValidAnchorCandidates(frame: ARFrame) -> [(point: CGPoint, distanceCm: Double)] {
        guard sceneView.bounds.width > 0, sceneView.bounds.height > 0 else { return [] }
        return candidateAnchorPoints(in: sceneView.bounds).compactMap { candidate in
            guard let distance = raycastDistanceCm(at: candidate, frame: frame) else { return nil }
            return (candidate, distance)
        }
    }

    /// Finds a screen point that currently lands on the detected horizontal
    /// plane — preferring the previous frame's point (`lastAnchorPoint`) to
    /// keep the on-screen dot stable, only searching a fresh ring of
    /// candidates when that point stops being valid (e.g. the user moved the
    /// phone). Unlike a fixed centre point, this naturally avoids food (never
    /// tracked as part of the plane) and glossy/textureless plate surfaces
    /// (rarely tracked either), since both are excluded from the plane's
    /// observed geometry rather than guessed around.
    private func findAnchorPoint(frame: ARFrame) -> (point: CGPoint, distanceCm: Double)? {
        guard sceneView.bounds.width > 0, sceneView.bounds.height > 0 else { return nil }

        if let sticky = lastAnchorPoint, let distance = raycastDistanceCm(at: sticky, frame: frame) {
            return (sticky, distance)
        }
        for candidate in candidateAnchorPoints(in: sceneView.bounds) {
            if let distance = raycastDistanceCm(at: candidate, frame: frame) {
                lastAnchorPoint = candidate
                return (candidate, distance)
            }
        }
        lastAnchorPoint = nil
        return nil
    }

    /// Maps a view-space point to the matching pixel in the *captured*
    /// image (`frame.capturedImage`'s resolution) — the space the depth map
    /// and camera intrinsics operate in. Needed because the anchor point is
    /// no longer always the image centre, so the backend can no longer
    /// assume anchor pixel == (cx, cy). `displayTransform` is ARKit's own
    /// API for the inverse mapping (image -> view, used to overlay UI on the
    /// camera feed); inverting it gives view -> image.
    private func imagePixel(forViewPoint point: CGPoint, frame: ARFrame) -> CGPoint? {
        let bounds = sceneView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let orientation = sceneView.window?.windowScene?.interfaceOrientation ?? .portrait
        let displayTransform = frame.displayTransform(for: orientation, viewportSize: bounds.size)
        let inverse = displayTransform.inverted()
        let normalizedView = CGPoint(x: point.x / bounds.width, y: point.y / bounds.height)
        let normalizedImage = normalizedView.applying(inverse)
        let resolution = frame.camera.imageResolution
        return CGPoint(x: normalizedImage.x * resolution.width, y: normalizedImage.y * resolution.height)
    }

    private func saveCapturedImage(_ pixelBuffer: CVPixelBuffer) -> String? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: 0.95) else { return nil }
        let fileName = "ar_capture_\(UUID().uuidString).jpg"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }
}

/// Factory that produces `ArKitPlatformView` instances for the
/// `nutrilens/ar/preview` view type.
final class ArKitViewFactory: NSObject, FlutterPlatformViewFactory {
    private let controller: ArController

    init(controller: ArController) {
        self.controller = controller
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        ArKitPlatformView(frame: frame, controller: controller)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
