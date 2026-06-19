import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/app_dependencies.dart';
import '../../../meal_history/data/models/meal_component_entry.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/image_url_utils.dart';
import '../../../../shared/widgets/absolute_network_image.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/ingredient_image.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../food_scan/domain/entities/food_analysis.dart';
import '../../../meal_detail/data/repositories/meal_detail_repository.dart';
import '../../../meal_history/data/models/meal_entry.dart';

class MealDetailPage extends StatefulWidget {
  const MealDetailPage({super.key, required this.mealId});

  final String mealId;

  @override
  State<MealDetailPage> createState() => _MealDetailPageState();
}

class _MealDetailPageState extends State<MealDetailPage> {
  final _repository = AppDependencies.mealDetailRepository;
  MealDetailBundle? _bundle;
  FoodAnalysis? _analysis;
  var _loading = true;
  var _showBoundingBoxes = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final bundle = await _repository.fetchDetail(widget.mealId);
      FoodAnalysis? analysis;
      final jobId = bundle.entry.inferenceJobId;
      if (bundle.entry.sourceType == 'image') {
        analysis = await _repository.fetchInferenceAnalysis(
          jobId ?? '',
          entry: bundle.entry,
          inferenceJob: bundle.inferenceJob,
        );
      }
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _analysis = analysis;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Không thể tải chi tiết bữa ăn.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => context.canPop() ? context.pop() : context.go('/diary'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Chi tiết bữa ăn',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Column(
                children: [
                  SkeletonBlock(height: 220),
                  SizedBox(height: 12),
                  SkeletonBlock(height: 140),
                  SizedBox(height: 12),
                  SkeletonBlock(height: 180),
                ],
              )
            else if (_errorMessage != null)
              PremiumCard(
                borderColor: AppTheme.danger.withValues(alpha: 0.35),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: AppTheme.danger),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_errorMessage!)),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                ),
              )
            else if (_bundle != null)
              _DetailBody(
                bundle: _bundle!,
                analysis: _analysis,
                inferenceJob: _bundle!.inferenceJob,
                showBoundingBoxes: _showBoundingBoxes,
                onToggleBoxes: () =>
                    setState(() => _showBoundingBoxes = !_showBoundingBoxes),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.bundle,
    required this.analysis,
    required this.inferenceJob,
    required this.showBoundingBoxes,
    required this.onToggleBoxes,
  });

  final MealDetailBundle bundle;
  final FoodAnalysis? analysis;
  final Map<String, dynamic>? inferenceJob;
  final bool showBoundingBoxes;
  final VoidCallback onToggleBoxes;

  @override
  Widget build(BuildContext context) {
    final entry = bundle.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SourceBadge(sourceType: entry.sourceType),
        const SizedBox(height: 12),
        Text(
          entry.title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        if (entry.sourceType == 'barcode' && entry.barcode != null) ...[
          const SizedBox(height: 4),
          Text(
            'Barcode: ${entry.barcode}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          '${entry.mealType} • ${DateTimeUtils.formatTime(entry.loggedAt)}',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _MacroSummaryCard(entry: entry),
        const SizedBox(height: 16),
        switch (entry.sourceType) {
          'barcode' => _BarcodeDetailView(
              entry: entry,
              packagedFood: bundle.packagedFood,
            ),
          'text' => _UsdaDetailView(
              entry: entry,
              nutrientFood: bundle.nutrientFood,
            ),
          'image' => _AiDetailView(
              entry: entry,
              analysis: analysis,
              inferenceJob: inferenceJob,
              showBoundingBoxes: showBoundingBoxes,
              onToggleBoxes: onToggleBoxes,
            ),
          _ => _GenericDetailView(entry: entry),
        },
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.sourceType});

  final String sourceType;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (sourceType) {
      case 'barcode':
        label = 'Tra Cứu Bằng Mã Vạch';
        color = AppTheme.mint;
      case 'text':
        label = 'Tra Cứu Hệ Thống Dinh Dưỡng';
        color = AppTheme.blueMint;
      case 'image':
        label = 'Phân Tích Bằng Trí Tuệ Nhân Tạo';
        color = AppTheme.accent;
      default:
        label = 'Nhập Món Ăn Thủ Công';
        color = AppTheme.outline;
    }
    return SourceBadge(label: label, icon: Icons.label_outline, color: color);
  }
}

class _MacroSummaryCard extends StatelessWidget {
  const _MacroSummaryCard({required this.entry});

  final MealEntry entry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tổng năng lượng'),
                Text(
                  '${entry.calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          _MacroChip('P', entry.proteinGrams, AppTheme.protein),
          _MacroChip('C', entry.carbsGrams, AppTheme.carb),
          _MacroChip('F', entry.fatGrams, AppTheme.fat),
        ],
      ),
    );
  }
}

class _BarcodeDetailView extends StatelessWidget {
  const _BarcodeDetailView({
    required this.entry,
    required this.packagedFood,
  });

  final MealEntry entry;
  final Map<String, dynamic>? packagedFood;

  @override
  Widget build(BuildContext context) {
    final data = packagedFood ?? const <String, dynamic>{};
    final imageUrl = ImageUrlUtils.resolveAbsolute(
      data['image_url'] ?? data['image_path'] ?? entry.imageUrl,
    );
    final brand = _text(data['brand'] ?? data['brand_name'] ?? entry.brand);
    final servings = entry.servings ?? entry.servingAmount ?? 1;
    final servingSize = _number(
      data['serving_size'] ?? entry.servingSize,
      fallback: entry.weightGrams > 0 && servings > 0
          ? entry.weightGrams / servings
          : 1,
    );
    final servingUnit = _text(data['serving_unit'] ?? entry.servingUnit ?? 'g') ?? 'g';
    final calories = _number(
      data['cal_per_serving'] ?? data['calories'],
      fallback: servings > 0 ? entry.calories / servings : entry.calories,
    );
    final protein = _number(
      data['protein_per_serving'] ?? data['protein'] ?? data['protein_g'],
      fallback: servings > 0 ? entry.proteinGrams / servings : entry.proteinGrams,
    );
    final carbs = _number(
      data['carb_per_serving'] ?? data['carbs'] ?? data['carbohydrate'],
      fallback: servings > 0 ? entry.carbsGrams / servings : entry.carbsGrams,
    );
    final fat = _number(
      data['fat_per_serving'] ?? data['fat'] ?? data['total_fat'],
      fallback: servings > 0 ? entry.fatGrams / servings : entry.fatGrams,
    );
    final totalWeight = servingSize * servings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.4,
              child: AbsoluteNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: const _ImageFallback(),
              ),
            ),
          ),
        if (brand != null) ...[
          const SizedBox(height: 12),
          Text(
            brand,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 14),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lượng ghi nhận',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatQuantity(servings)} × ${_formatQuantity(servingSize)}$servingUnit',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Khối lượng: ${_formatQuantity(totalWeight)}$servingUnit',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Dinh dưỡng theo khẩu phần đã chọn',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _MacroRow(label: 'Calories', value: '${(calories * servings).toStringAsFixed(0)} kcal'),
              _MacroRow(label: 'Protein', value: '${(protein * servings).toStringAsFixed(1)} g'),
              _MacroRow(label: 'Carb', value: '${(carbs * servings).toStringAsFixed(1)} g'),
              _MacroRow(label: 'Fat', value: '${(fat * servings).toStringAsFixed(1)} g'),
            ],
          ),
        ),
      ],
    );
  }
}

class _UsdaDetailView extends StatelessWidget {
  const _UsdaDetailView({
    required this.entry,
    required this.nutrientFood,
  });

  final MealEntry entry;
  final Map<String, dynamic>? nutrientFood;

  @override
  Widget build(BuildContext context) {
    final data = nutrientFood ?? const <String, dynamic>{};
    final fdcId = _text(data['fdc_id'] ?? entry.fdcId);
    final loggedGrams = entry.servingAmount ?? entry.weightGrams;
    final per100Calories = _number(
      data['cal_per_100g'] ?? data['calories_per_100g'] ?? data['calories'],
    );
    final per100Protein = _number(
      data['protein_per_100g'] ?? data['protein'],
    );
    final per100Carbs = _number(
      data['carb_per_100g'] ?? data['carbs_per_100g'] ?? data['carbs'],
    );
    final per100Fat = _number(
      data['fat_per_100g'] ?? data['fat'],
    );
    final ratio = loggedGrams > 0 ? loggedGrams / 100 : 0.0;
    final maxMacro = [per100Protein, per100Carbs, per100Fat, 1.0].reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bảng dinh dưỡng / 100g',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _MacroRow(label: 'Calories', value: '${per100Calories.toStringAsFixed(0)} kcal'),
              const SizedBox(height: 12),
              _AnalyticBar(
                label: 'Protein',
                value: per100Protein,
                max: maxMacro,
                color: AppTheme.protein,
              ),
              const SizedBox(height: 8),
              _AnalyticBar(
                label: 'Carb',
                value: per100Carbs,
                max: maxMacro,
                color: AppTheme.carb,
              ),
              const SizedBox(height: 8),
              _AnalyticBar(
                label: 'Fat',
                value: per100Fat,
                max: maxMacro,
                color: AppTheme.fat,
              ),
              if (fdcId != null) ...[
                const SizedBox(height: 14),
                Text(
                  'USDA FDC ID: $fdcId',
                  style: const TextStyle(
                    color: AppTheme.blueMint,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (loggedGrams > 0) ...[
          const SizedBox(height: 12),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Khẩu phần ghi nhận',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Khối lượng: ${_formatQuantity(loggedGrams)}g',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hệ số quy đổi: ${_formatQuantity(ratio)}× (so với 100g)',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (entry.searchQuery != null) ...[
          const SizedBox(height: 12),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Từ khóa tra cứu',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.searchQuery!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AiDetailView extends StatelessWidget {
  const _AiDetailView({
    required this.entry,
    required this.analysis,
    required this.inferenceJob,
    required this.showBoundingBoxes,
    required this.onToggleBoxes,
  });

  final MealEntry entry;
  final FoodAnalysis? analysis;
  final Map<String, dynamic>? inferenceJob;
  final bool showBoundingBoxes;
  final VoidCallback onToggleBoxes;

  @override
  Widget build(BuildContext context) {
    final absoluteImageUrl = ImageUrlUtils.resolveAbsolute(
      analysis?.imageUrl ?? entry.imageUrl ?? inferenceJob?['image'],
    );
    final localImagePath = absoluteImageUrl == null &&
            ImageUrlUtils.isLocalFilePath(entry.imageUrl)
        ? entry.imageUrl!.trim()
        : null;
    final items = analysis?.items ?? const <FoodAnalysisItem>[];

    // Build a name → imageUrl map from the history-API component entries so
    // it can fill in thumbnails that the inference-job result omits.
    final componentImageByName = <String, String?>{};
    for (final comp in entry.components) {
      final url = comp.imageUrl;
      if (url != null) {
        componentImageByName[comp.displayName.toLowerCase()] = url;
        if (comp.componentName.isNotEmpty) {
          componentImageByName[comp.componentName.toLowerCase()] = url;
        }
      }
    }

    // True when the analysis result has no items but the history API did
    // provide component data (with imageUrls) for this meal.
    final useComponentFallback =
        items.isEmpty && entry.components.isNotEmpty;

    final componentCount =
        items.isNotEmpty ? items.length : entry.components.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (absoluteImageUrl != null || localImagePath != null)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (absoluteImageUrl != null)
                          AbsoluteNetworkImage(
                            imageUrl: absoluteImageUrl,
                            fit: BoxFit.cover,
                          )
                        else
                          Image.file(
                            File(localImagePath!),
                            fit: BoxFit.cover,
                          ),
                        if (showBoundingBoxes)
                          ...items.map(
                            (item) => _BoundingBoxOverlay(item: item),
                          ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ảnh món ăn đã quét',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    FilterChip(
                      selected: showBoundingBoxes,
                      onSelected: (_) => onToggleBoxes(),
                      label: Text(showBoundingBoxes ? 'Ẩn khung' : 'Hiện khung'),
                      selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Thành phần phát hiện',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  if (componentCount > 0)
                    SourceBadge(
                      label: '$componentCount món',
                      icon: Icons.auto_awesome,
                      color: AppTheme.accent,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (items.isEmpty && entry.components.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Chưa có dữ liệu thành phần từ AI.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              else if (useComponentFallback)
                // Inference analysis unavailable — render MealComponentEntry
                // objects directly; these carry imageUrls from the history API.
                ...entry.components.map(
                  (comp) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ComponentEntryCard(component: comp),
                  ),
                )
              else
                // Full inference analysis available — use FoodAnalysisItem data.
                // Pass a fallback URL from the history-API component map so the
                // thumbnail shows even when the job result omits per-ingredient
                // image URLs.
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DetectedIngredientCard(
                      item: item,
                      fallbackImageUrl:
                          componentImageByName[item.label.toLowerCase()],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.go('/scan-result/feedback'),
          icon: const Icon(Icons.report_problem_outlined),
          label: const Text('Báo lỗi nhận diện AI'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.danger,
            side: const BorderSide(color: AppTheme.danger),
          ),
        ),
      ],
    );
  }
}

class _GenericDetailView extends StatelessWidget {
  const _GenericDetailView({required this.entry});

  final MealEntry entry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MacroRow(
            label: 'Khối lượng',
            value: '${entry.weightGrams.toStringAsFixed(0)} g',
          ),
          _MacroRow(label: 'Loại bữa', value: entry.mealType),
        ],
      ),
    );
  }
}

class _BoundingBoxOverlay extends StatelessWidget {
  const _BoundingBoxOverlay({required this.item});

  final FoodAnalysisItem item;

  @override
  Widget build(BuildContext context) {
    final box = item.boundingBox;
    return Positioned(
      left: box.x,
      top: box.y,
      width: box.width,
      height: box.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.accent, width: 2),
          color: AppTheme.accent.withValues(alpha: 0.12),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            color: AppTheme.accent,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              item.label,
              style: const TextStyle(
                color: Color(0xFF2B1B00),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticBar extends StatelessWidget {
  const _AnalyticBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = (value / max).clamp(0.04, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${value.toStringAsFixed(1)} g'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '$label ${value.toStringAsFixed(0)}g',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _DetectedIngredientCard extends StatelessWidget {
  const _DetectedIngredientCard({
    required this.item,
    this.fallbackImageUrl,
  });

  final FoodAnalysisItem item;

  /// Image URL sourced from the meal-history API component entry, used when
  /// the inference job result does not carry per-ingredient thumbnails.
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    final profile = _IngredientMacroProfile.fromItem(
      item,
      fallbackImageUrl: fallbackImageUrl,
    );
    final thumbnailUrl = profile.thumbnailUrl;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IngredientImage(imageUrl: thumbnailUrl, size: 56, label: item.label),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _VolumeMarker(label: profile.volumeLabel),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _IngredientCalorieRow(calories: profile.calories),
                  const SizedBox(height: 10),
                  _IngredientMacroBadgeRow(
                    protein: profile.proteinGrams,
                    carbs: profile.carbsGrams,
                    fat: profile.fatGrams,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for a component sourced directly from the meal-history API.
/// Used when the full inference-job analysis is unavailable.
class _ComponentEntryCard extends StatelessWidget {
  const _ComponentEntryCard({required this.component});

  final MealComponentEntry component;

  @override
  Widget build(BuildContext context) {
    final weightLabel = component.calculatedWeight > 0
        ? '${component.calculatedWeight.toStringAsFixed(0)}g'
        : component.volume > 0
            ? '${component.volume.toStringAsFixed(0)} cm³'
            : '—';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shimmer while loading, leaf fallback when URL is absent/broken.
            IngredientImage(imageUrl: component.imageUrl, size: 56, label: component.displayName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          component.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _VolumeMarker(label: weightLabel),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _IngredientCalorieRow(calories: component.calories),
                  const SizedBox(height: 10),
                  _IngredientMacroBadgeRow(
                    protein: component.proteinGrams,
                    carbs: component.carbsGrams,
                    fat: component.fatGrams,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientMacroProfile {
  const _IngredientMacroProfile({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.volumeLabel,
    this.thumbnailUrl,
  });

  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String volumeLabel;
  final String? thumbnailUrl;

  factory _IngredientMacroProfile.fromItem(
    FoodAnalysisItem item, {
    String? fallbackImageUrl,
  }) {
    var protein = item.proteinGrams;
    var carbs = item.carbsGrams;
    var fat = item.fatGrams;
    var grams = item.weightGrams;
    String? thumbnail;

    if (protein <= 0 && carbs <= 0 && fat <= 0) {
      protein = 0;
      carbs = 0;
      fat = 0;
      for (final ingredient in item.ingredients) {
        protein += ingredient.proteinGrams;
        carbs += ingredient.carbsGrams;
        fat += ingredient.fatGrams;
      }
    }

    if (grams <= 0) {
      for (final ingredient in item.ingredients) {
        grams += ingredient.grams;
      }
    }

    // Prefer per-ingredient thumbnails from the inference result; fall back to
    // the image URL that the meal-history API stored for this component.
    for (final ingredient in item.ingredients) {
      thumbnail ??= ImageUrlUtils.resolveAbsolute(ingredient.imageUrl);
    }
    thumbnail ??= ImageUrlUtils.resolveAbsolute(fallbackImageUrl);

    final calories = item.calories > 0
        ? item.calories
        : item.ingredients.fold<double>(0, (sum, i) => sum + i.calories);

    final volumeLabel = item.volumeMl > 0
        ? '${item.volumeMl.toStringAsFixed(0)} cm³'
        : grams > 0
            ? '${grams.toStringAsFixed(0)}g'
            : '—';

    return _IngredientMacroProfile(
      calories: calories,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      volumeLabel: volumeLabel,
      thumbnailUrl: thumbnail,
    );
  }
}

class _VolumeMarker extends StatelessWidget {
  const _VolumeMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _IngredientCalorieRow extends StatelessWidget {
  const _IngredientCalorieRow({required this.calories});

  final double calories;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department,
              color: AppTheme.accent,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '${calories.toStringAsFixed(0)} kcal',
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Năng lượng',
              style: TextStyle(
                color: AppTheme.textSecondary,
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

class _IngredientMacroBadgeRow extends StatelessWidget {
  const _IngredientMacroBadgeRow({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _MacroCapsuleBadge(
          label: 'P',
          value: protein,
          suffix: 'g',
          color: AppTheme.protein,
        ),
        _MacroCapsuleBadge(
          label: 'C',
          value: carbs,
          suffix: 'g',
          color: AppTheme.carb,
        ),
        _MacroCapsuleBadge(
          label: 'F',
          value: fat,
          suffix: 'g',
          color: AppTheme.mint,
        ),
      ],
    );
  }
}

class _MacroCapsuleBadge extends StatelessWidget {
  const _MacroCapsuleBadge({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
  });

  final String label;
  final double value;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label ${value.toStringAsFixed(0)}$suffix',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.primaryContainer,
      child: Center(
        child: Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 48),
      ),
    );
  }
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

double _number(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

String _formatQuantity(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
