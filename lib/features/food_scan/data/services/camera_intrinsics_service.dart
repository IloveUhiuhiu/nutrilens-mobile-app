import 'dart:io';

import 'package:flutter/services.dart';

class CameraIntrinsics {
  const CameraIntrinsics({
    required this.fx,
    required this.fy,
    required this.cx,
    required this.cy,
    required this.sensorWidth,
    required this.sensorHeight,
    required this.source,
  });

  factory CameraIntrinsics.fromMap(Map<dynamic, dynamic> value) {
    return CameraIntrinsics(
      fx: _doubleValue(value['fx']),
      fy: _doubleValue(value['fy']),
      cx: _doubleValue(value['cx']),
      cy: _doubleValue(value['cy']),
      sensorWidth: _intValue(value['sensorWidth']),
      sensorHeight: _intValue(value['sensorHeight']),
      source: '${value['source'] ?? 'camera_calibration'}',
    );
  }

  final double fx;
  final double fy;
  final double cx;
  final double cy;
  final int sensorWidth;
  final int sensorHeight;
  final String source;

  static double _doubleValue(Object? value) {
    return switch (value) {
      final int number => number.toDouble(),
      final double number => number,
      _ => 0,
    };
  }

  static int _intValue(Object? value) {
    return switch (value) {
      final int number => number,
      final double number => number.round(),
      _ => 0,
    };
  }
}

class CameraCaptureResult {
  const CameraCaptureResult({
    required this.imagePath,
    required this.intrinsics,
  });

  factory CameraCaptureResult.fromMap(Map<dynamic, dynamic> value) {
    return CameraCaptureResult(
      imagePath: '${value['imagePath'] ?? ''}',
      intrinsics: CameraIntrinsics.fromMap(value),
    );
  }

  final String imagePath;
  final CameraIntrinsics intrinsics;
}

class CameraIntrinsicsService {
  const CameraIntrinsicsService();

  static const _channel = MethodChannel('nutrilens/camera_intrinsics');

  Future<CameraIntrinsics?> getBackCameraIntrinsics() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;

    try {
      final value = await _channel.invokeMapMethod<String, dynamic>(
        'getBackCameraIntrinsics',
      );
      if (value == null) return null;

      final intrinsics = CameraIntrinsics.fromMap(value);
      if (intrinsics.fx <= 0 ||
          intrinsics.fy <= 0 ||
          intrinsics.cx <= 0 ||
          intrinsics.cy <= 0 ||
          intrinsics.sensorWidth <= 0 ||
          intrinsics.sensorHeight <= 0) {
        return null;
      }

      return intrinsics;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<CameraCaptureResult?> captureBackCameraPhotoWithIntrinsics() async {
    if (!Platform.isIOS) return null;

    try {
      final value = await _channel.invokeMapMethod<String, dynamic>(
        'captureBackCameraPhotoWithIntrinsics',
      );
      if (value == null) return null;

      final capture = CameraCaptureResult.fromMap(value);
      if (capture.imagePath.isEmpty) return null;

      return capture;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
