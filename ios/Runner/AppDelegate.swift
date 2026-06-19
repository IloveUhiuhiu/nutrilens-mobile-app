import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nativePhotoCapture: NativePhotoCapture?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CameraIntrinsics") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "nutrilens/camera_intrinsics",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getBackCameraIntrinsics":
        result(FlutterError(
          code: "unavailable",
          message: "iOS camera intrinsics are delivered with AVCapturePhotoOutput captures.",
          details: nil
        ))
      case "captureBackCameraPhotoWithIntrinsics":
        self?.captureBackCameraPhotoWithIntrinsics(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func captureBackCameraPhotoWithIntrinsics(result: @escaping FlutterResult) {
    let permission = AVCaptureDevice.authorizationStatus(for: .video)
    if permission == .denied || permission == .restricted {
      result(FlutterError(
        code: "permission_denied",
        message: "Camera permission is not granted.",
        details: nil
      ))
      return
    }

    let startCapture = { [weak self] in
      let capture = NativePhotoCapture()
      self?.nativePhotoCapture = capture
      capture.capture { [weak self] captureResult in
        self?.nativePhotoCapture = nil
        result(captureResult)
      }
    }

    if permission == .notDetermined {
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          if granted {
            startCapture()
          } else {
            result(FlutterError(
              code: "permission_denied",
              message: "Camera permission is not granted.",
              details: nil
            ))
          }
        }
      }
      return
    }

    startCapture()
  }
}

private final class NativePhotoCapture: NSObject, AVCapturePhotoCaptureDelegate {
  private let session = AVCaptureSession()
  private let output = AVCapturePhotoOutput()
  private var completion: FlutterResult?

  func capture(completion: @escaping FlutterResult) {
    self.completion = completion

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try self.configureSession()
        self.session.startRunning()

        let settings = AVCapturePhotoSettings(format: [
          AVVideoCodecKey: AVVideoCodecType.jpeg
        ])
        settings.isHighResolutionPhotoEnabled = self.output.isHighResolutionCaptureEnabled
        if self.output.isCameraCalibrationDataDeliverySupported {
          settings.isCameraCalibrationDataDeliveryEnabled = true
        }

        self.output.capturePhoto(with: settings, delegate: self)
      } catch {
        self.finish(error: FlutterError(
          code: "capture_error",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }

  private func configureSession() throws {
    session.beginConfiguration()
    session.sessionPreset = .photo

    guard let device = AVCaptureDevice.default(
      .builtInWideAngleCamera,
      for: .video,
      position: .back
    ) else {
      throw NativeCaptureError.cameraUnavailable
    }

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input), session.canAddOutput(output) else {
      throw NativeCaptureError.sessionConfigurationFailed
    }

    session.addInput(input)
    session.addOutput(output)
    output.isHighResolutionCaptureEnabled = true
    session.commitConfiguration()
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    if let error {
      finish(error: FlutterError(
        code: "capture_error",
        message: error.localizedDescription,
        details: nil
      ))
      return
    }

    guard let data = photo.fileDataRepresentation() else {
      finish(error: FlutterError(
        code: "capture_error",
        message: "Captured photo data is empty.",
        details: nil
      ))
      return
    }

    guard let calibration = photo.cameraCalibrationData else {
      finish(error: FlutterError(
        code: "calibration_unavailable",
        message: "Camera calibration data is not available for this capture.",
        details: nil
      ))
      return
    }

    do {
      let imagePath = try savePhoto(data: data)
      let matrix = calibration.intrinsicMatrix
      let dimensions = calibration.intrinsicMatrixReferenceDimensions

      finish(value: [
        "imagePath": imagePath,
        "fx": Double(matrix.columns.0.x),
        "fy": Double(matrix.columns.1.y),
        "cx": Double(matrix.columns.2.x),
        "cy": Double(matrix.columns.2.y),
        "sensorWidth": Int(dimensions.width),
        "sensorHeight": Int(dimensions.height),
        "source": "ios_av_camera_calibration_data"
      ])
    } catch {
      finish(error: FlutterError(
        code: "capture_error",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private func savePhoto(data: Data) throws -> String {
    let fileName = "nutrilens-\(UUID().uuidString).jpg"
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    try data.write(to: url, options: .atomic)
    return url.path
  }

  private func finish(value: Any) {
    session.stopRunning()
    DispatchQueue.main.async {
      self.completion?(value)
      self.completion = nil
    }
  }

  private func finish(error: FlutterError) {
    session.stopRunning()
    DispatchQueue.main.async {
      self.completion?(error)
      self.completion = nil
    }
  }
}

private enum NativeCaptureError: LocalizedError {
  case cameraUnavailable
  case sessionConfigurationFailed

  var errorDescription: String? {
    switch self {
    case .cameraUnavailable:
      return "Back camera is not available."
    case .sessionConfigurationFailed:
      return "Unable to configure native camera session."
    }
  }
}
