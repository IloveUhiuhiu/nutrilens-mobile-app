import 'dart:math' as math;

class FoodImageMetadata {
  const FoodImageMetadata({
    required this.fileName,
    required this.width,
    required this.height,
    required this.orientation,
    required this.fx,
    required this.fy,
    required this.cx,
    required this.cy,
    required this.intrinsicsCalibrated,
    required this.intrinsicsSource,
    this.hasAbsoluteDepth = false,
    this.cameraToObjectDistanceCm,
    this.anchorPixelX,
    this.anchorPixelY,
    this.idempotencyKey = '',
    this.depthMapPath,
  });

  factory FoodImageMetadata.fromImageSize({
    required String fileName,
    required int width,
    required int height,
    int orientation = 1,
    double? fx,
    double? fy,
    String idempotencyKey = '',
  }) {
    final fallbackFocalLength = math.max(width, height) * 0.888;

    return FoodImageMetadata(
      fileName: fileName,
      width: width,
      height: height,
      orientation: orientation,
      fx: fx ?? fallbackFocalLength,
      fy: fy ?? fallbackFocalLength,
      cx: width / 2,
      cy: height / 2,
      intrinsicsCalibrated: false,
      intrinsicsSource: 'fallback_estimate',
      idempotencyKey: idempotencyKey,
    );
  }

  factory FoodImageMetadata.fromCameraIntrinsics({
    required String fileName,
    required int width,
    required int height,
    required int orientation,
    required double fx,
    required double fy,
    required double cx,
    required double cy,
    required String source,
    double? cameraToObjectDistanceCm,
    double? anchorPixelX,
    double? anchorPixelY,
    String idempotencyKey = '',
    String? depthMapPath,
  }) {
    return FoodImageMetadata(
      fileName: fileName,
      width: width,
      height: height,
      orientation: orientation,
      fx: fx,
      fy: fy,
      cx: cx,
      cy: cy,
      intrinsicsCalibrated: true,
      intrinsicsSource: source,
      // AR capture (ARCore/ARKit) supplies an absolute camera-to-plane
      // distance; its presence is what makes depth "absolute" rather than
      // estimated. Plain captures leave this null → hasAbsoluteDepth = false.
      hasAbsoluteDepth: cameraToObjectDistanceCm != null,
      cameraToObjectDistanceCm: cameraToObjectDistanceCm,
      anchorPixelX: anchorPixelX,
      anchorPixelY: anchorPixelY,
      idempotencyKey: idempotencyKey,
      depthMapPath: depthMapPath,
    );
  }

  final String fileName;
  final int width;
  final int height;
  final int orientation;
  final double fx;
  final double fy;
  final double cx;
  final double cy;
  final bool intrinsicsCalibrated;
  final String intrinsicsSource;

  /// True when the capture carries an absolute (AR-measured) camera-to-object
  /// distance, enabling absolute volume estimation on the backend (CASE A).
  /// False for plain camera captures that only have estimated depth (CASE B).
  final bool hasAbsoluteDepth;

  /// Absolute distance from camera to the food plane in centimetres, sampled
  /// via ARCore/ARKit raycasting. Null on non-AR devices (CASE B).
  final double? cameraToObjectDistanceCm;

  /// Pixel coordinates (in this image's own resolution) of the point the AR
  /// raycast actually measured — no longer always the image centre, since
  /// the native side now hunts each frame for whichever point currently
  /// lands on the detected table/plate plane (see ArKitPlatformView.swift /
  /// ArPlatformView.kt). Null when [cameraToObjectDistanceCm] is null, or on
  /// older app builds that didn't carry this through.
  final double? anchorPixelX;
  final double? anchorPixelY;

  /// Stable per-capture token sent as the `Idempotency-Key` header so the
  /// backend dedupes retries of the same capture to a single inference job.
  /// Carried on the metadata (not in [toJson]) so it survives BLoC-level
  /// retries that re-dispatch the same capture.
  final String idempotencyKey;

  /// Local file path of a dense per-pixel depth map (.npy, float32,
  /// centimetres) captured alongside the photo — only present on devices
  /// where ARCore's Depth API or ARKit's sceneDepth actually returned one
  /// (tier 1 ToF/LiDAR, or tier 2 ARCore depth-from-motion). Null elsewhere
  /// (tier 3 ARKit without LiDAR, or no AR at all), in which case the backend
  /// falls back to AI-estimated depth, optionally anchored by
  /// [cameraToObjectDistanceCm]. Sent as a separate multipart file, not
  /// included in [toJson].
  final String? depthMapPath;

  /// True only when real camera intrinsics (fx, fy, cx, cy) are present —
  /// i.e. not synthesised fallback estimates. Required for 2D analysis.
  bool get hasRequiredIntrinsics =>
      intrinsicsCalibrated && fx > 0 && fy > 0 && cx > 0 && cy > 0;

  Map<String, dynamic> toJson() {
    return {
      'image': fileName,
      'width': width,
      'height': height,
      'orientation': orientation,
      'fx': fx,
      'fy': fy,
      'cx': cx,
      'cy': cy,
      'intrinsics_calibrated': intrinsicsCalibrated,
      'intrinsics_source': intrinsicsSource,
      'has_absolute_depth': hasAbsoluteDepth,
      // Omitted (not sent as null) when absent so multipart FormData stays clean;
      // the backend treats a missing value as null (CASE B).
      if (cameraToObjectDistanceCm != null)
        'camera_to_object_distance': cameraToObjectDistanceCm,
      if (anchorPixelX != null && anchorPixelY != null) ...{
        'anchor_pixel_x': anchorPixelX,
        'anchor_pixel_y': anchorPixelY,
      },
    };
  }
}
