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
  });

  factory FoodImageMetadata.fromImageSize({
    required String fileName,
    required int width,
    required int height,
    int orientation = 1,
    double? fx,
    double? fy,
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
    };
  }
}
