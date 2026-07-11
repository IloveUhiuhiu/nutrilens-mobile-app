import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/platform/ar_capability_channel.dart';
import '../../../../core/theme/app_theme.dart';
import '../../capture_feature.dart';

/// Entry point of the food-capture flow (`/scan`).
///
/// Probes AR capability once and forwards to the appropriate capture screen:
///   * AR-capable + feature enabled + camera permission granted → `/scan/ar`
///     (CASE A — absolute depth)
///   * needs Google Play Services for AR installed first (Android only)  →
///     shows an install prompt in place, with an explicit skip to the plain
///     camera so the user is never blocked waiting on it
///   * otherwise                                                → `/scan/plain`
///     (CASE B — estimated depth)
///
/// The AR session (ArPlatformView/ArKitPlatformView) starts the camera
/// directly with no permission gate of its own — on denial it silently
/// streams "no distance yet" forever with no error surfaced, which looks
/// indistinguishable from "still searching for a surface". Requesting the
/// permission here, before ever entering `/scan/ar`, means a denied user is
/// routed straight to the plain camera path instead, which already shows a
/// clear "Ứng dụng chưa được cấp quyền camera." message via the `camera`
/// plugin's own permission handling.
///
/// The redirect uses [GoRouter.pushReplacement] so this transient gate is not
/// left on the navigation stack — pressing back from the camera returns to the
/// previous screen, not to a blank loader.
class CaptureGate extends StatefulWidget {
  const CaptureGate({super.key});

  @override
  State<CaptureGate> createState() => _CaptureGateState();
}

class _CaptureGateState extends State<CaptureGate> with WidgetsBindingObserver {
  final _capability = const ArCapabilityChannel();
  bool _showInstallPrompt = false;
  bool _installing = false;
  // Set right before launching the Play Store install flow so the lifecycle
  // callback below knows a resume is worth re-probing capability for,
  // instead of re-checking on every unrelated resume of this screen.
  bool _awaitingInstallResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingInstallResume) {
      _awaitingInstallResume = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final capability = await _capability.check();
    if (!mounted) return;

    // Safe fallback: AR disabled, or the device can never support it,
    // resolves straight to the plain camera so the user is never blocked.
    if (!kArCaptureEnabled || capability == ArCapability.unsupported) {
      context.pushReplacement('/scan/plain');
      return;
    }

    if (capability == ArCapability.needsInstall) {
      setState(() {
        _showInstallPrompt = true;
        _installing = false;
      });
      return;
    }

    final cameraStatus = await Permission.camera.request();
    if (!mounted) return;
    context.pushReplacement(cameraStatus.isGranted ? '/scan/ar' : '/scan/plain');
  }

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _awaitingInstallResume = true;
    });
    await _capability.requestInstall();
    // No further action here — _resolve() re-runs from
    // didChangeAppLifecycleState once the user returns from the Play Store.
  }

  void _skip() {
    _awaitingInstallResume = false;
    context.pushReplacement('/scan/plain');
  }

  @override
  Widget build(BuildContext context) {
    if (!_showInstallPrompt) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_outlined, color: Colors.white70, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Cần cài thêm một thành phần để đo chính xác hơn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thiết bị của bạn hỗ trợ đo bằng AR, nhưng cần cài "Dịch vụ Google Play dành cho AR" trước. '
                  'Bạn vẫn có thể quét bằng ảnh ngay nếu không muốn chờ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _installing ? null : _install,
                  icon: _installing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(_installing ? 'Đang mở Play Store…' : 'Cài đặt'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF2B1B00),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Quét bằng ảnh ngay',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
