import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/idempotency.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../../food_scan/domain/entities/food_image_metadata.dart';
import '../../../food_scan/presentation/bloc/food_scan_bloc.dart';
import '../../../food_scan/presentation/bloc/food_scan_event.dart';

/// AR capture screen (`/scan/ar`) — CASE A in the Hybrid Capture pipeline.
///
/// Hosts the native ARCore/ARKit camera preview (`nutrilens/ar/preview`), shows a
/// centre reticle + live camera-to-food distance, and only enables the shutter
/// once the distance reading is stable. Capturing returns an image plus camera
/// intrinsics and the absolute distance, which feed the inference job as
/// `has_absolute_depth = true`.
class ArCapturePage extends StatefulWidget {
  const ArCapturePage({super.key});

  @override
  State<ArCapturePage> createState() => _ArCapturePageState();
}

class _ArCapturePageState extends State<ArCapturePage> {
  static const _command = MethodChannel('nutrilens/ar');
  static const _distanceEvents = EventChannel('nutrilens/ar/distance');

  static const _minDistanceCm = 20.0;
  static const _maxDistanceCm = 40.0;

  StreamSubscription<dynamic>? _distanceSub;
  double? _distanceCm;
  // Normalized (0..1) position of the calibration point within the preview,
  // as found by the native anchor search (see ArKitPlatformView.swift /
  // ArPlatformView.kt) — no longer always the screen centre, since the
  // native side now hunts for whichever point currently lands on the
  // detected table/plate plane instead of trusting a fixed pixel.
  double? _anchorX;
  double? _anchorY;
  bool _stable = false;
  bool _capturing = false;
  // Set when the native AR session itself fails (see ArController.emitSessionError /
  // ArKitPlatformView.session(_:didFailWithError:)) — distinct from "still
  // searching for a surface", which is the same on-screen state the user
  // would otherwise see forever with no way to tell the two apart.
  String? _sessionError;
  // True once the user has spent too long without a stable reading (e.g. a
  // glass table, poor lighting, or just a slow surface) — surfaces a
  // non-judgemental escape hatch instead of leaving them stuck staring at
  // "move your phone" forever.
  bool _showFallbackSuggestion = false;
  Timer? _fallbackTimer;
  static const _fallbackSuggestionDelay = Duration(seconds: 8);
  // "lidar" | "ar_depth" | "none" — see ArKitPlatformView.swift /
  // ArPlatformView.kt. Purely informational; the actual depth-map upload
  // decision is driven by `depthMapPath` being non-null at capture time.
  String _depthSource = 'none';

  bool get _hasAnchor => _anchorX != null && _anchorY != null;
  bool get _tooClose => _distanceCm != null && _distanceCm! < _minDistanceCm;
  bool get _tooFar => _distanceCm != null && _distanceCm! > _maxDistanceCm;
  bool get _inRange => _distanceCm != null && !_tooClose && !_tooFar;
  bool get _canCapture => _stable && _inRange && _hasAnchor && !_capturing;

  @override
  void initState() {
    super.initState();
    _distanceSub = _distanceEvents.receiveBroadcastStream().listen(
      _onDistanceEvent,
      onError: (_) {
        if (mounted) setState(() => _distanceCm = null);
      },
    );
    _fallbackTimer = Timer(_fallbackSuggestionDelay, () {
      if (mounted && !_stable && _sessionError == null) {
        setState(() => _showFallbackSuggestion = true);
      }
    });
  }

  @override
  void dispose() {
    _distanceSub?.cancel();
    _fallbackTimer?.cancel();
    _command.invokeMethod('dispose');
    super.dispose();
  }

  void _onDistanceEvent(dynamic event) {
    if (event is! Map || !mounted) return;
    final error = event['error'] as String?;
    if (error != null) {
      debugPrint('[ArCapturePage] AR session error: $error');
      setState(() => _sessionError = error);
      return;
    }
    setState(() {
      _distanceCm = (event['distance'] as num?)?.toDouble();
      _anchorX = (event['anchorX'] as num?)?.toDouble();
      _anchorY = (event['anchorY'] as num?)?.toDouble();
      _stable = event['stable'] == true;
      _depthSource = event['depthSource'] as String? ?? 'none';
      if (_stable) _showFallbackSuggestion = false;
    });
  }

  Future<void> _capture() async {
    if (!_canCapture) return;
    setState(() => _capturing = true);
    try {
      final result = await _command.invokeMapMethod<String, dynamic>('captureFrame');
      if (result == null || !mounted) return;

      final imagePath = result['imagePath'] as String;
      final rawCandidates = result['anchorCandidates'] as List<dynamic>?;
      final anchorCandidates = rawCandidates
          ?.map((entry) => AnchorCandidate.fromMap(entry as Map<dynamic, dynamic>))
          .toList();
      final metadata = FoodImageMetadata.fromCameraIntrinsics(
        fileName: imagePath.split('/').last,
        width: (result['width'] as num).toInt(),
        height: (result['height'] as num).toInt(),
        orientation: 1,
        fx: (result['fx'] as num).toDouble(),
        fy: (result['fy'] as num).toDouble(),
        cx: (result['cx'] as num).toDouble(),
        cy: (result['cy'] as num).toDouble(),
        source: 'arcore_arkit',
        cameraToObjectDistanceCm: (result['distanceCm'] as num?)?.toDouble(),
        anchorPixelX: (result['anchorPixelX'] as num?)?.toDouble(),
        anchorPixelY: (result['anchorPixelY'] as num?)?.toDouble(),
        anchorCandidates: anchorCandidates,
        idempotencyKey: generateIdempotencyKey(),
        // Present only on tier-1 ToF/LiDAR (and tier-2 ARCore
        // depth-from-motion) devices — see ArPlatformView.kt /
        // ArKitPlatformView.swift. Null elsewhere; the distance-anchored
        // estimate above still applies in that case.
        depthMapPath: result['depthMapPath'] as String?,
      );

      context.read<FoodScanBloc>().add(
            FoodImagePicked(imagePath: imagePath, metadata: metadata),
          );
      context.go('/scan-processing');
    } catch (_) {
      if (mounted) {
        AppAlerts.showToast(
          context,
          message: 'Không thể chụp khung hình AR.',
          type: AppAlertType.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _sessionError != null
            ? _SessionErrorView(
                onRetry: () => context.pushReplacement('/scan/ar'),
                onFallback: () => context.pushReplacement('/scan/plain'),
              )
            : Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: _preview()),
            // The reticle tracks the native anchor search (see
            // ArKitPlatformView.swift / ArPlatformView.kt) — it's no longer
            // fixed at screen centre, since that's typically where the food
            // sits. The native side hunts each frame for whichever point
            // currently lands on the detected table/plate plane, so the dot
            // moves to wherever that is.
            if (_hasAnchor)
              Positioned(
                left: MediaQuery.of(context).size.width * _anchorX! - 32,
                top: MediaQuery.of(context).size.height * _anchorY! - 32,
                child: _Reticle(active: _stable && _inRange),
              ),
            if (_distanceCm != null)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.30,
                child: _DistancePill(cm: _distanceCm!, stable: _stable, inRange: _inRange),
              ),
            Positioned(
              top: 16,
              left: 16,
              child: IconButton.filledTonal(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/scan/plain'),
                icon: const Icon(Icons.close),
              ),
            ),
            Positioned(
              top: 24,
              right: 16,
              child: _DepthSourceBadge(source: _depthSource),
            ),
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _distanceCm == null
                        ? 'Di chuyển máy đến khi xuất hiện điểm trên mặt bàn trống'
                        : _tooFar
                            ? 'Quá xa — lại gần đĩa ăn hơn'
                            : _tooClose
                                ? 'Quá gần — ra xa đĩa ăn một chút'
                                : _stable
                                    ? 'Giữ yên — chạm để chụp'
                                    : 'Đang ổn định khoảng cách…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_showFallbackSuggestion && !_stable) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => context.pushReplacement('/scan/plain'),
                      icon: const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 18),
                      label: const Text(
                        'Không sao, bạn vẫn có thể quét bằng ảnh',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              bottom: 32,
              child: FilledButton(
                onPressed: _canCapture ? _capture : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: const Color(0xFF2B1B00),
                  shape: const CircleBorder(),
                  minimumSize: const Size(84, 84),
                ),
                child: _capturing
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(Icons.center_focus_strong, size: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    const viewType = 'nutrilens/ar/preview';
    if (Platform.isAndroid) {
      return const AndroidView(
        viewType: viewType,
        creationParamsCodec: StandardMessageCodec(),
      );
    }
    if (Platform.isIOS) {
      return const UiKitView(
        viewType: viewType,
        creationParamsCodec: StandardMessageCodec(),
      );
    }
    return const ColoredBox(color: Colors.black);
  }
}

class _Reticle extends StatelessWidget {
  const _Reticle({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.secondary : Colors.white70;
    return IgnorePointer(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      ),
    );
  }
}

/// Shows which depth source the current device is actually using for this
/// capture, so the user isn't silently given a lower-accuracy estimate
/// without knowing it. Purely informational — see `_depthSource` in
/// [_ArCapturePageState] for how the value arrives from native code.
class _DepthSourceBadge extends StatelessWidget {
  const _DepthSourceBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    // Lead with what the user actually cares about — how trustworthy the
    // measurement will be — not the underlying mechanism name. "none" still
    // means a real AR-measured scalar distance (the raycast anchor) is in
    // use, just no dense depth map; it's a normal operating mode on
    // non-LiDAR devices, not a problem to fix, so it stays neutral rather
    // than alarming. Colors reuse this screen's existing "ready" (secondary)
    // / "neutral" (white70) language from the reticle and instruction text.
    final (label, icon, color) = switch (source) {
      'lidar' => ('Độ chính xác cao · LiDAR', Icons.sensors, AppTheme.secondary),
      'ar_depth' => ('Độ chính xác cao · AR', Icons.sensors, AppTheme.secondary),
      _ => ('Độ chính xác tiêu chuẩn', Icons.straighten, Colors.white70),
    };
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistancePill extends StatelessWidget {
  const _DistancePill({required this.cm, required this.stable, required this.inRange});

  final double cm;
  final bool stable;
  final bool inRange;

  @override
  Widget build(BuildContext context) {
    final color = !inRange ? AppTheme.danger : (stable ? AppTheme.secondary : AppTheme.accent);
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          '${cm.toStringAsFixed(1)} cm',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Shown when the native AR session itself failed to start — distinct from
/// the normal "still searching for a surface" state, which looked
/// identical on screen before this existed (see `_sessionError`).
class _SessionErrorView extends StatelessWidget {
  const _SessionErrorView({required this.onRetry, required this.onFallback});

  final VoidCallback onRetry;
  final VoidCallback onFallback;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Không thể khởi động chế độ đo AR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Không sao, bạn vẫn có thể quét món ăn bằng ảnh.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onFallback,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Chụp ảnh thay thế'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: const Color(0xFF2B1B00),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Thử lại',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
