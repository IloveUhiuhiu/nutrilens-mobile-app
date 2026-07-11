import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/idempotency.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../data/services/camera_intrinsics_service.dart';
import '../../domain/entities/food_image_metadata.dart';
import '../bloc/food_scan_bloc.dart';
import '../bloc/food_scan_event.dart';
import '../bloc/food_scan_state.dart';

class CameraScanPage extends StatefulWidget {
  const CameraScanPage({super.key});

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final CameraIntrinsicsService _intrinsicsService =
      const CameraIntrinsicsService();
  Future<void>? _initializeCameraFuture;
  String? _cameraError;
  bool _cameraPermissionDenied = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraFuture = _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraFuture = _initializeCamera();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocListener<FoodScanBloc, FoodScanState>(
        listener: (context, state) {
          if (state is FoodScanUploading || state is FoodScanProcessing) {
            context.go('/scan-processing');
          }
          if (state is FoodScanError) {
            AppAlerts.showToast(
              context,
              message: state.message,
              type: AppAlertType.critical,
            );
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildPreview()),
              Positioned(
                top: 24,
                left: 20,
                child: IconButton.filledTonal(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/');
                    }
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ViewfinderOverlayPainter(
                      frameSize: 288,
                      radius: 40,
                    ),
                  ),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: SizedBox(
                    width: 288,
                    height: 288,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(40)),
                        border: Border.all(
                          color: AppTheme.secondary.withValues(alpha: 0.9),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      onPressed:
                          _isCapturing ? null : () => _pickFromGallery(context),
                      icon: const Icon(Icons.photo_library),
                      tooltip: 'Chọn ảnh',
                    ),
                    FilledButton(
                      onPressed:
                          _isCapturing ? null : () => _captureImage(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: const Color(0xFF2B1B00),
                        shape: const CircleBorder(),
                        minimumSize: const Size(84, 84),
                      ),
                      child: _isCapturing
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : const Icon(Icons.center_focus_weak, size: 36),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 128,
                child: Text(
                  'Giữ máy song song với đĩa ăn',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return FutureBuilder<void>(
      future: _initializeCameraFuture,
      builder: (context, snapshot) {
        final controller = _controller;
        if (_cameraError != null) {
          return _CameraMessage(
            message: _cameraError!,
            onRetry: () {
              setState(() {
                _cameraError = null;
                _cameraPermissionDenied = false;
                _initializeCameraFuture = _initializeCamera();
              });
            },
            onOpenSettings:
                _cameraPermissionDenied ? () => openAppSettings() : null,
          );
        }
        if (snapshot.connectionState != ConnectionState.done ||
            controller == null ||
            !controller.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        return ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewSize = controller.value.previewSize!;
              final previewRatio = previewSize.height / previewSize.width;
              final screenRatio = constraints.maxWidth / constraints.maxHeight;
              final scale = previewRatio / screenRatio;

              return Transform.scale(
                scale: scale < 1 ? 1 / scale : scale,
                child: Center(child: CameraPreview(controller)),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _cameraError = 'Thiết bị không có camera khả dụng.';
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final previousController = _controller;
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      _controller = controller;
      _cameraError = null;
      _cameraPermissionDenied = false;
      await previousController?.dispose();
    } on CameraException catch (error) {
      _cameraPermissionDenied = error.code == 'CameraAccessDenied';
      _cameraError = _cameraPermissionDenied
          ? 'Ứng dụng chưa được cấp quyền camera.'
          : 'Không thể mở camera: ${error.description ?? error.code}.';
    }
  }

  Future<void> _captureImage(BuildContext context) async {
    if (_isCapturing) return;

    var controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      await _initializeCameraFuture;
      controller = _controller;
    }
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      if (Platform.isIOS) {
        await controller.dispose();
        _controller = null;

        final nativeCapture =
            await _intrinsicsService.captureBackCameraPhotoWithIntrinsics();
        if (nativeCapture != null) {
          await _submitImage(
            nativeCapture.imagePath,
            intrinsics: nativeCapture.intrinsics,
          );
          return;
        }

        _initializeCameraFuture = _initializeCamera();
        await _initializeCameraFuture;
        controller = _controller;
        if (controller == null || !controller.value.isInitialized) return;
      }

      final image = await controller.takePicture().timeout(
            const Duration(seconds: 5),
          );
      await _submitImage(image.path);
    } on CameraException catch (error) {
      if (!mounted) return;
      await _captureWithSystemCamera(this.context, fallbackError: error);
    } on TimeoutException {
      if (!mounted) return;
      await _captureWithSystemCamera(this.context);
    } catch (error) {
      if (context.mounted) {
        AppAlerts.showToast(
          context,
          message: 'Không thể xử lý ảnh vừa chụp.',
          type: AppAlertType.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _captureWithSystemCamera(
    BuildContext context, {
    CameraException? fallbackError,
  }) async {
    final controller = _controller;
    await controller?.dispose();
    _controller = null;

    var submitted = false;
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image == null) {
        if (context.mounted) {
          final description = fallbackError?.description ??
              fallbackError?.code ??
              'camera không phản hồi sau 5 giây';
          AppAlerts.showToast(
            context,
            message: 'Không thể chụp ảnh: $description',
            type: AppAlertType.warning,
          );
        }
        return;
      }

      await _submitImage(image.path);
      submitted = true;
    } finally {
      if (mounted && !submitted) {
        _initializeCameraFuture = _initializeCamera();
        setState(() {});
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // 2D analysis needs camera intrinsics (fx/fy/cx/cy). Prefer the device's
      // calibrated back-camera intrinsics; when the hardware does not expose
      // them (most phones don't report LENS_INTRINSIC_CALIBRATION), _buildMetadata
      // derives an estimate from the image size — the same fallback the
      // live-capture path uses. The in-app camera framing is fixed, so a gallery
      // photo from the same device is treated identically to a captured one.
      final metadata =
          await _buildMetadata(image.path, useDeviceIntrinsics: true);
      if (!context.mounted) return;

      context.read<FoodScanBloc>().add(
            FoodImagePicked(imagePath: image.path, metadata: metadata),
          );
    } catch (error) {
      if (context.mounted) {
        AppAlerts.showToast(
          context,
          message: 'Không thể chọn ảnh.',
          type: AppAlertType.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _submitImage(
    String imagePath, {
    CameraIntrinsics? intrinsics,
  }) async {
    final metadata = await _buildMetadata(imagePath, intrinsics: intrinsics);
    if (!mounted) return;

    context.read<FoodScanBloc>().add(
          FoodImagePicked(imagePath: imagePath, metadata: metadata),
        );
  }

  Future<FoodImageMetadata> _buildMetadata(
    String imagePath, {
    CameraIntrinsics? intrinsics,
    bool useDeviceIntrinsics = true,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(imagePath);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final fileName = imagePath.split(Platform.pathSeparator).last;
    // One key per capture; reused if the BLoC retries this same capture so the
    // backend dedupes them to a single inference job.
    final idempotencyKey = generateIdempotencyKey();
    final cameraIntrinsics = intrinsics ??
        (useDeviceIntrinsics
            ? await _intrinsicsService.getBackCameraIntrinsics()
            : null);
    if (cameraIntrinsics != null) {
      final scaleX = descriptor.width / cameraIntrinsics.sensorWidth;
      final scaleY = descriptor.height / cameraIntrinsics.sensorHeight;

      return FoodImageMetadata.fromCameraIntrinsics(
        fileName: fileName,
        width: descriptor.width,
        height: descriptor.height,
        orientation: 1,
        fx: cameraIntrinsics.fx * scaleX,
        fy: cameraIntrinsics.fy * scaleY,
        cx: cameraIntrinsics.cx * scaleX,
        cy: cameraIntrinsics.cy * scaleY,
        source: cameraIntrinsics.source,
        idempotencyKey: idempotencyKey,
      );
    }

    return FoodImageMetadata.fromImageSize(
      fileName: fileName,
      width: descriptor.width,
      height: descriptor.height,
      idempotencyKey: idempotencyKey,
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({
    required this.message,
    required this.onRetry,
    this.onOpenSettings,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF101A14), Color(0xFF263F31)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),
          if (onOpenSettings != null) ...[
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Mở cài đặt'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderOverlayPainter extends CustomPainter {
  const _ViewfinderOverlayPainter({
    required this.frameSize,
    required this.radius,
  });

  final double frameSize;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = frameSize / 2;

    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
        Radius.circular(radius),
      ));

    final overlay = Path.combine(PathOperation.difference, outerPath, innerPath);

    canvas.drawPath(
      overlay,
      Paint()..color = const Color(0xFF1B4332).withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_ViewfinderOverlayPainter old) =>
      old.frameSize != frameSize || old.radius != radius;
}
