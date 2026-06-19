import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/food_scan_bloc.dart';
import '../bloc/food_scan_event.dart';
import '../bloc/food_scan_state.dart';

class ScanProcessingPage extends StatefulWidget {
  const ScanProcessingPage({super.key});

  @override
  State<ScanProcessingPage> createState() => _ScanProcessingPageState();
}

class _ScanProcessingPageState extends State<ScanProcessingPage> {
  static const _cancelButtonDelay = Duration(seconds: 5);

  bool _showCancelButton = false;
  Timer? _cancelButtonTimer;

  @override
  void initState() {
    super.initState();
    _cancelButtonTimer = Timer(_cancelButtonDelay, () {
      if (mounted) setState(() => _showCancelButton = true);
    });
  }

  @override
  void dispose() {
    _cancelButtonTimer?.cancel();
    super.dispose();
  }

  void _onCancel(BuildContext context) {
    context.read<FoodScanBloc>().add(const FoodScanCancelRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: BlocConsumer<FoodScanBloc, FoodScanState>(
        listener: (context, state) {
          if (state is FoodScanResultReady) {
            context.go('/scan-result');
          }
          if (state is FoodScanCancelled) {
            context.go('/scan');
          }
        },
        builder: (context, state) {
          if (state is FoodScanPollingFailed) {
            return _FailureView(
              message: state.message,
              onRetry: () {
                setState(() => _showCancelButton = false);
                _cancelButtonTimer?.cancel();
                _cancelButtonTimer = Timer(_cancelButtonDelay, () {
                  if (mounted) setState(() => _showCancelButton = true);
                });
                context.read<FoodScanBloc>().add(
                      FoodScanRetryRequested(
                        imagePath: state.imagePath,
                        jobId: state.jobId,
                      ),
                    );
              },
              onBack: () => context.go('/scan'),
            );
          }

          if (state is FoodScanError) {
            return _FailureView(
              message: state.message,
              onRetry: () => context.go('/scan'),
              onBack: () => context.go('/scan'),
            );
          }

          final imagePath = switch (state) {
            FoodScanUploading(:final imagePath) => imagePath,
            FoodScanProcessing(:final imagePath) => imagePath,
            _ => null,
          };
          final isProcessing = state is FoodScanProcessing;

          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (imagePath != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: isProcessing ? 6 : 2,
                                      sigmaY: isProcessing ? 6 : 2,
                                    ),
                                    child: Image.file(
                                      File(imagePath),
                                      width: 220,
                                      height: 220,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(24),
                                    ),
                                  ),
                                  child: SizedBox(width: 220, height: 220),
                                ),
                              if (isProcessing)
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: const _ScanLaserOverlay(),
                                  ),
                                ),
                              if (!isProcessing)
                                const CircularProgressIndicator(
                                  strokeWidth: 7,
                                  color: AppTheme.primary,
                                ),
                              if (isProcessing)
                                const Icon(
                                  Icons.auto_awesome,
                                  color: AppTheme.accent,
                                  size: 42,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          isProcessing
                              ? 'Trí tuệ nhân tạo đang bóc tách'
                              : 'Đang tải ảnh lên',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isProcessing
                              ? 'Đang phân tích thành phần món ăn...'
                              : 'Đang tải ảnh lên máy chủ AI...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: _showCancelButton
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: AnimatedOpacity(
                                    opacity: _showCancelButton ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: OutlinedButton.icon(
                                      onPressed: () => _onCancel(context),
                                      icon: const Icon(Icons.close),
                                      label: const Text('Dừng quá trình phân tích'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.danger,
                                        side: const BorderSide(
                                          color: AppTheme.danger,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScanLaserOverlay extends StatefulWidget {
  const _ScanLaserOverlay();

  @override
  State<_ScanLaserOverlay> createState() => _ScanLaserOverlayState();
}

class _ScanLaserOverlayState extends State<_ScanLaserOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
              ),
              child: const SizedBox.expand(),
            ),
            Align(
              alignment: Alignment(0, -1 + (_controller.value * 2)),
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondary.withValues(alpha: 0.75),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.danger.withValues(alpha: 0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.danger,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Phân tích thất bại',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.danger,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại / Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onBack,
                    child: const Text('Quay lại camera'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
