import ARKit
import Flutter
import Foundation

/// Bridges the Flutter `nutrilens/ar` MethodChannel + `nutrilens/ar/distance`
/// EventChannel to the live `ArKitPlatformView`.
final class ArController: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private weak var view: ArKitPlatformView?

    init(messenger: FlutterBinaryMessenger) {
        super.init()

        let methodChannel = FlutterMethodChannel(name: "nutrilens/ar", binaryMessenger: messenger)
        methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        let eventChannel = FlutterEventChannel(name: "nutrilens/ar/distance", binaryMessenger: messenger)
        eventChannel.setStreamHandler(self)
    }

    func attach(_ view: ArKitPlatformView) {
        self.view = view
    }

    /// No-ops if no AR view is currently active — safe to call unconditionally
    /// from scene lifecycle callbacks regardless of which screen is showing.
    func pauseActiveSession() {
        view?.pauseSession()
    }

    func resumeActiveSession() {
        view?.resumeSession()
    }

    func emitDistance(_ distanceCm: Double?, stable: Bool, depthSource: String) {
        guard let sink = eventSink else { return }
        var payload: [String: Any] = ["stable": stable, "depthSource": depthSource]
        if let distanceCm = distanceCm {
            payload["distance"] = distanceCm
        }
        DispatchQueue.main.async { sink(payload) }
    }

    /// Reports that the ARKit session itself failed (`ARSessionDelegate.session(_:didFailWithError:)`),
    /// e.g. camera permission revoked at the OS level despite the Dart-side
    /// pre-check. Without this, a session failure was previously dropped
    /// entirely — the UI kept showing "still searching for a surface" with
    /// no way to tell the user was stuck for a reason that camera-shake
    /// would never fix.
    func emitSessionError(_ message: String) {
        guard let sink = eventSink else { return }
        let payload: [String: Any] = ["stable": false, "depthSource": "none", "error": message]
        DispatchQueue.main.async { sink(payload) }
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Method handling

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkCapability":
            result(ARWorldTrackingConfiguration.isSupported ? "supported" : "unsupported")
        case "captureFrame":
            // ARSCNView must be accessed on the main thread.
            DispatchQueue.main.async { [weak self] in
                guard let captured = self?.view?.capture() else {
                    result(FlutterError(code: "capture_failed", message: "Could not capture AR frame.", details: nil))
                    return
                }
                result(captured)
            }
        case "dispose":
            view = nil
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
