import 'package:flutter/services.dart';

/// Result of probing the device for AR support.
///
/// * [supported]    – ARCore (Android) / ARWorldTracking (iOS) is ready to use.
/// * [needsInstall] – AR is supported but Google Play Services for AR must be
///                    installed/updated first (Android only).
/// * [unsupported]  – Device cannot run AR; the app must fall back to the plain
///                    camera capture path (CASE B).
enum ArCapability { supported, needsInstall, unsupported }

/// Thin Dart facade over the native `nutrilens/ar` method channel.
///
/// Mirrors the existing `nutrilens/camera_intrinsics` channel pattern. The
/// native side answers `checkCapability` using:
///   * Android: `ArCoreApk.getInstance().checkAvailability(context)`
///   * iOS:     `ARWorldTrackingConfiguration.isSupported`
///
/// Every failure path resolves to [ArCapability.unsupported] so the caller can
/// always fall back to the non-AR pipeline without special-casing errors.
class ArCapabilityChannel {
  const ArCapabilityChannel();

  static const MethodChannel _channel = MethodChannel('nutrilens/ar');

  Future<ArCapability> check() async {
    try {
      final value = await _channel.invokeMethod<String>('checkCapability');
      return switch (value) {
        'supported' => ArCapability.supported,
        'needsInstall' => ArCapability.needsInstall,
        _ => ArCapability.unsupported,
      };
    } on PlatformException {
      return ArCapability.unsupported;
    } on MissingPluginException {
      // Native handler not registered yet (e.g. AR build flavour disabled).
      return ArCapability.unsupported;
    }
  }

  /// Launches the Play Store "Google Play Services for AR" install/update
  /// flow (Android only — a no-op on iOS, which never reports [ArCapability.needsInstall]
  /// in the first place). Must only be called in direct response to an
  /// explicit user tap, per ARCore's own contract.
  ///
  /// This doesn't return whether installation succeeded — the host Activity
  /// pauses while the user is in the Play Store, so the caller should
  /// re-probe [check] once the app resumes instead of awaiting a result here.
  Future<void> requestInstall() async {
    try {
      await _channel.invokeMethod('requestInstall');
    } on PlatformException {
      // Nothing actionable — the resume-triggered re-check falls back to
      // the plain camera regardless.
    } on MissingPluginException {
      // ignore
    }
  }
}
