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

  StreamSubscription<dynamic>? _distanceSub;
  double? _distanceCm;
  bool _stable = false;
  bool _capturing = false;
  // "lidar" | "ar_depth" | "none" — see ArKitPlatformView.swift /
  // ArPlatformView.kt. Purely informational; the actual depth-map upload
  // decision is driven by `depthMapPath` being non-null at capture time.
  String _depthSource = 'none';

  @override
  void initState() {
    super.initState();
    _distanceSub = _distanceEvents.receiveBroadcastStream().listen(
      _onDistanceEvent,
      onError: (_) {
        if (mounted) setState(() => _distanceCm = null);
      },
    );
  }

  @override
  void dispose() {
    _distanceSub?.cancel();
    _command.invokeMethod('dispose');
    super.dispose();
  }

  void _onDistanceEvent(dynamic event) {
    if (event is! Map || !mounted) return;
    setState(() {
      _distanceCm = (event['distance'] as num?)?.toDouble();
      _stable = event['stable'] == true;
      _depthSource = event['depthSource'] as String? ?? 'none';
    });
  }

  Future<void> _capture() async {
    if (!_stable || _capturing) return;
    setState(() => _capturing = true);
    try {
      final result = await _command.invokeMapMethod<String, dynamic>('captureFrame');
      if (result == null || !mounted) return;

      final imagePath = result['imagePath'] as String;
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: _preview()),
            _Reticle(active: _stable),
            if (_distanceCm != null)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.30,
                child: _DistancePill(cm: _distanceCm!, stable: _stable),
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
              child: Text(
                _distanceCm == null
                    ? 'Rê máy chậm trên đĩa ăn để dò mặt phẳng'
                    : _stable
                        ? 'Giữ yên — chạm để chụp'
                        : 'Đang ổn định khoảng cách…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              bottom: 32,
              child: FilledButton(
                onPressed: _stable && !_capturing ? _capture : null,
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
  const _DistancePill({required this.cm, required this.stable});

  final double cm;
  final bool stable;

  @override
  Widget build(BuildContext context) {
    final color = stable ? AppTheme.secondary : AppTheme.accent;
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
