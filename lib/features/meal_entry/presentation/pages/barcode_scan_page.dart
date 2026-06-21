import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/di/app_dependencies.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../../shared/widgets/search_skeleton_loader.dart';
import '../../../meal_history/presentation/bloc/meal_history_cubit.dart';
import '../../../nutrition/presentation/bloc/nutrition_cubit.dart';
import '../../../../core/utils/date_time_utils.dart';

class BarcodeScanPage extends StatefulWidget {
  const BarcodeScanPage({super.key});

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final _barcodeController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  late final MobileScannerController _scannerController;
  _BarcodeProduct? _product;
  String? _lastScannedBarcode;
  var _loading = false;
  var _servings = 1.0;
  var _scanLocked = false;
  var _resumeScannerAfterSheet = true;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.itf14,
      ],
      autoZoom: true,
      // Higher capture resolution helps detect small or distant barcodes that a
      // low-resolution preview would render too coarse to decode.
      cameraResolution: const Size(1920, 1080),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _barcodeController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _scannerController.stop();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _lookup({String? scannedBarcode}) async {
    final barcode = (scannedBarcode ?? _barcodeController.text).trim();
    if (barcode.isEmpty) {
      AppAlerts.showToast(
        context,
        message: 'Vui lòng nhập hoặc quét mã vạch.',
        type: AppAlertType.warning,
      );
      return;
    }

    setState(() {
      _loading = true;
      _scanLocked = true;
      _lastScannedBarcode = barcode;
      _barcodeController.text = barcode;
    });
    try {
      await _scannerController.stop();
      final response =
          await AppDependencies.dioClient.get<Map<String, dynamic>>(
        ApiEndpoints.barcodeLookup(barcode),
      );
      final data = response.data?['data'];
      if (data is! Map) {
        throw const FormatException('Invalid barcode response');
      }
      final product =
          _BarcodeProduct.fromJson(Map<String, dynamic>.from(data), barcode);
      if (!mounted) return;
      setState(() {
        _product = product;
        _servings = 1.0;
        _servingsController.text = _servingLabel(_servings);
      });
      await _showProductSheet(product);
    } catch (_) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Không tìm thấy sản phẩm từ mã vạch này.',
        type: AppAlertType.warning,
      );
      await _restartScanner();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _scanLocked = false;
        });
      }
    }
  }

  Future<void> _restartScanner() async {
    if (!mounted) return;
    setState(() {
      _scanLocked = false;
      _lastScannedBarcode = null;
    });
    try {
      await _scannerController.start();
    } catch (_) {
      // MobileScanner's errorBuilder surfaces camera permission/init failures.
    }
  }

  /// Lets the user pick a photo from the gallery and decodes any barcode it
  /// contains. Useful when live scanning fails (glare, focus, packaging shape).
  Future<void> _scanFromImage() async {
    if (_loading || _scanLocked) return;
    try {
      final image =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      setState(() => _loading = true);
      final capture = await _scannerController.analyzeImage(image.path);
      String? found;
      for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
        final value = barcode.rawValue?.trim();
        if (_isValidRetailBarcode(value)) {
          found = value;
          break;
        }
      }
      if (!mounted) return;
      if (found == null) {
        setState(() => _loading = false);
        AppAlerts.showToast(
          context,
          message:
              'Không đọc được mã vạch trong ảnh. Hãy chọn ảnh chụp cận cảnh, rõ nét, đủ sáng và không bị nghiêng.',
          type: AppAlertType.warning,
        );
        return;
      }
      await _lookup(scannedBarcode: found);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppAlerts.showToast(
        context,
        message: 'Không thể xử lý ảnh đã chọn.',
        type: AppAlertType.warning,
      );
    }
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_scanLocked || _loading) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (!_isValidRetailBarcode(rawValue)) continue;
      HapticFeedback.selectionClick();
      _lookup(scannedBarcode: rawValue);
      return;
    }
  }

  Future<void> _saveProduct(
    BuildContext sheetContext,
    _BarcodeProduct product,
  ) async {
    final nutritionCubit = context.read<NutritionCubit>();
    final mealHistoryCubit = context.read<MealHistoryCubit>();
    final targetDate = DateTime.now();
    setState(() => _loading = true);
    try {
      final response = await AppDependencies.dioClient.post<void>(
        ApiEndpoints.mealBarcode,
        data: {
          'barcode': product.barcode,
          'servings': _servings,
          'date': DateTimeUtils.formatDateKey(targetDate),
          'source_type': 'barcode',
        },
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw StateError('Unexpected barcode meal response');
      }
      if (!mounted) return;
      await _scannerController.stop();
      _resumeScannerAfterSheet = false;
      setState(() {
        _scanLocked = false;
        _lastScannedBarcode = null;
      });
      await Future.wait([
        nutritionCubit.load(),
        mealHistoryCubit.load(date: targetDate),
      ]);
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Ghi nhận món ăn thành công',
        type: AppAlertType.success,
      );
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
    } catch (_) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Không thể lưu sản phẩm.',
        type: AppAlertType.critical,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showProductSheet(_BarcodeProduct product) async {
    _resumeScannerAfterSheet = true;
    var sheetSaving = false;
    _servingsController.text = _servingLabel(_servings);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomPadding =
                MediaQuery.of(context).padding.bottom + AppTheme.spacingLg;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (product.brand.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.brand,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PremiumCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _MacroSummary(
                              label: 'Kcal',
                              value: product.calories,
                              color: AppTheme.primary,
                              suffix: '',
                            ),
                            _MacroSummary(
                              label: 'Đạm',
                              value: product.protein,
                              color: AppTheme.protein,
                            ),
                            _MacroSummary(
                              label: 'Carb',
                              value: product.carbs,
                              color: AppTheme.carb,
                            ),
                            _MacroSummary(
                              label: 'Béo',
                              value: product.fat,
                              color: AppTheme.fat,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Số khẩu phần',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const Spacer(),
                                Text(
                                  'x ${_servingSizeLabel(product)}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                IconButton.outlined(
                                  onPressed: _servings <= 0.25
                                      ? null
                                      : () {
                                          final next = (_servings - 0.25)
                                              .clamp(0.25, 99)
                                              .toDouble();
                                          setState(() => _servings = next);
                                          _servingsController.text =
                                              _servingLabel(_servings);
                                          setSheetState(() {});
                                        },
                                  icon: const Icon(Icons.remove),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _servingsController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      labelText: 'Số thực',
                                      hintText: '1.5',
                                    ),
                                    onChanged: (value) {
                                      final parsed = double.tryParse(
                                        value.replaceAll(',', '.'),
                                      );
                                      if (parsed == null || parsed <= 0) return;
                                      setState(() => _servings = parsed);
                                      setSheetState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: () {
                                    setState(() => _servings += 0.25);
                                    _servingsController.text =
                                        _servingLabel(_servings);
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tổng: ${_totalServingLabel(product, _servings)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 16),
                    child: FilledButton.icon(
                      onPressed: sheetSaving
                          ? null
                          : () async {
                              setSheetState(() => sheetSaving = true);
                              await _saveProduct(sheetContext, product);
                              if (context.mounted) {
                                setSheetState(() => sheetSaving = false);
                              }
                            },
                      icon: sheetSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Lưu vào nhật ký'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted && _resumeScannerAfterSheet) await _restartScanner();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      showTopBar: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _close,
                icon: const Icon(Icons.close),
                tooltip: 'Đóng',
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Quét mã vạch',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tra cứu sản phẩm đóng gói và lưu theo số khẩu phần.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          _BarcodeViewport(
            controller: _scannerController,
            scanLocked: _scanLocked,
            lastBarcode: _lastScannedBarcode,
            onDetect: _handleDetection,
            onRetry: _restartScanner,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _barcodeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _lookup(),
            decoration: const InputDecoration(
              labelText: 'Mã vạch',
              hintText: 'Ví dụ: 012345678905',
              prefixIcon: Icon(Icons.qr_code_scanner),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _lookup,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: const Text('Tra cứu sản phẩm'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading ? null : _scanFromImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Quét mã vạch từ ảnh'),
          ),
          const SizedBox(height: 14),
          const _ScanTipsCard(),
          if (_loading) ...[
            const SizedBox(height: 16),
            const SearchSkeletonLoader(),
          ],
          if (_product != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _showProductSheet(_product!),
              child: const Text('Mở lại thông tin sản phẩm'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarcodeViewport extends StatelessWidget {
  const _BarcodeViewport({
    required this.controller,
    required this.scanLocked,
    required this.lastBarcode,
    required this.onDetect,
    required this.onRetry,
  });

  final MobileScannerController controller;
  final bool scanLocked;
  final String? lastBarcode;
  final void Function(BarcodeCapture capture) onDetect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF101827),
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Widen the recognition area so a sharp barcode anywhere near the
            // centre is decoded — the previous thin band was the main cause of
            // missed scans even on clear images.
            final windowWidth = constraints.maxWidth - 48;
            final windowHeight = constraints.maxHeight * 0.62;
            final scanWindow = Rect.fromCenter(
              center:
                  Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
              width: windowWidth,
              height: windowHeight,
            );
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: MobileScanner(
                      controller: controller,
                      scanWindow: scanWindow,
                      onDetect: onDetect,
                      errorBuilder: (context, error) {
                        return _CameraMessage(
                          icon: Icons.videocam_off_outlined,
                          message:
                              'Không thể khởi tạo camera. Kiểm tra quyền camera rồi thử lại.',
                          actionLabel: 'Thử lại',
                          onTap: onRetry,
                        );
                      },
                      placeholderBuilder: (context) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scanLocked
                          ? Colors.black.withValues(alpha: 0.36)
                          : Colors.transparent,
                    ),
                  ),
                ),
                SizedBox(
                  width: windowWidth,
                  height: windowHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                  ),
                ),
                SizedBox(
                  width: windowWidth - 20,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.danger,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.danger.withValues(alpha: 0.65),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: ValueListenableBuilder<MobileScannerState>(
                    valueListenable: controller,
                    builder: (context, state, _) {
                      final available =
                          state.torchState != TorchState.unavailable;
                      final on = state.torchState == TorchState.on;
                      return IconButton.filledTonal(
                        onPressed:
                            available ? () => controller.toggleTorch() : null,
                        icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                        tooltip: 'Bật/tắt đèn flash',
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 16,
                  right: 16,
                  child: Text(
                    scanLocked && lastBarcode != null
                        ? 'Đã nhận mã $lastBarcode - đang tra cứu'
                        : 'Đưa mã vạch vào khung. Giữ máy cách 10–20cm, đủ sáng.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 34),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ScanTipsCard extends StatelessWidget {
  const _ScanTipsCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: AppTheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Quét không nhận? Thử các cách sau',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: 10),
          _TipLine(text: 'Bật đèn flash khi thiếu sáng hoặc mã bị bóng.'),
          _TipLine(text: 'Giữ máy cách mã 10–20cm và song song với mã vạch.'),
          _TipLine(
              text: 'Lau sạch ống kính, tránh phản chiếu trên bao bì bóng.'),
          _TipLine(
              text:
                  'Vẫn không được: chụp ảnh cận cảnh rồi dùng "Quét từ ảnh", hoặc nhập tay mã số.'),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: AppTheme.textSecondary)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroSummary extends StatelessWidget {
  const _MacroSummary({
    required this.label,
    required this.value,
    required this.color,
    this.suffix = 'g',
  });

  final String label;
  final double value;
  final Color color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color)),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(0)}$suffix',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _BarcodeProduct {
  const _BarcodeProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    required this.servingUnit,
  });

  factory _BarcodeProduct.fromJson(Map<String, dynamic> json, String barcode) {
    return _BarcodeProduct(
      barcode: barcode,
      name: _text(json, const ['name', 'product_name', 'title'], 'Sản phẩm'),
      brand: _text(json, const ['brand_name', 'brand', 'brandOwner'], ''),
      calories: _number(json, const ['calories', 'cal_per_serving', 'energy']),
      protein:
          _number(json, const ['protein', 'protein_g', 'protein_per_100g']),
      carbs: _number(json, const ['carbs', 'carbohydrate', 'carb_per_100g']),
      fat: _number(json, const ['fat', 'total_fat', 'fat_per_100g']),
      servingSize: _number(
        json,
        const ['serving_size', 'servingSize', 'serving_weight', 'quantity'],
        fallback: 1,
      ),
      servingUnit: _text(
        json,
        const ['serving_unit', 'servingUnit', 'unit', 'quantity_unit'],
        'serving',
      ),
    );
  }

  final String barcode;
  final String name;
  final String brand;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double servingSize;
  final String servingUnit;
}

String _text(Map<String, dynamic> json, List<String> keys, String fallback) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && '$value'.trim().isNotEmpty) return '$value';
  }
  return fallback;
}

double _number(
  Map<String, dynamic> json,
  List<String> keys, {
  double fallback = 0,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse('$value');
    if (parsed != null) return parsed;
  }
  return fallback;
}

bool _isValidRetailBarcode(String? value) {
  if (value == null || value.isEmpty) return false;
  final digitsOnly = RegExp(r'^\d+$').hasMatch(value);
  if (!digitsOnly) return false;
  return value.length == 8 ||
      value.length == 12 ||
      value.length == 13 ||
      value.length == 14;
}

String _servingLabel(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _servingSizeLabel(_BarcodeProduct product) {
  return '${_servingLabel(product.servingSize)}${product.servingUnit}';
}

String _totalServingLabel(_BarcodeProduct product, double servings) {
  final total = product.servingSize * servings;
  return '${_servingLabel(total)}${product.servingUnit}';
}
