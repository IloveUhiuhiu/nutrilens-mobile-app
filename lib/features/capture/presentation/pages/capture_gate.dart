import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/ar_capability_channel.dart';
import '../../capture_feature.dart';

/// Entry point of the food-capture flow (`/scan`).
///
/// Probes AR capability once and forwards to the appropriate capture screen:
///   * AR-capable + feature enabled → `/scan/ar`   (CASE A — absolute depth)
///   * otherwise                    → `/scan/plain` (CASE B — estimated depth)
///
/// The redirect uses [GoRouter.pushReplacement] so this transient gate is not
/// left on the navigation stack — pressing back from the camera returns to the
/// previous screen, not to a blank loader.
class CaptureGate extends StatefulWidget {
  const CaptureGate({super.key});

  @override
  State<CaptureGate> createState() => _CaptureGateState();
}

class _CaptureGateState extends State<CaptureGate> {
  final _capability = const ArCapabilityChannel();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final capability = await _capability.check();
    if (!mounted) return;
    // Safe fallback: any non-supported result, or the AR path being disabled,
    // resolves to the plain camera so the user is never blocked.
    final useAr =
        kArCaptureEnabled && capability == ArCapability.supported;
    context.pushReplacement(useAr ? '/scan/ar' : '/scan/plain');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
