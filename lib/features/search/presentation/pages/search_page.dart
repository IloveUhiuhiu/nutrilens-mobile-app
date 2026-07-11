import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/app_dependencies.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/nutrient_badges.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../../shared/widgets/quantity_input_sheet.dart';
import '../../../../shared/widgets/search_skeleton_loader.dart';
import '../../../meal_history/presentation/bloc/meal_history_cubit.dart';
import '../../../nutrition/presentation/bloc/nutrition_cubit.dart';
import '../../data/models/meal_search_result.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _repository = AppDependencies.mealSearchRepository;
  var _results = const <MealSearchResult>[];
  var _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await _repository.search(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể tìm món ăn.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMeal(MealSearchResult result) async {
    final grams = await _askGrams(result);
    if (grams == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _repository.addFromUsda(
        result: result,
        grams: grams,
        searchQuery: _controller.text.trim(),
      );
      if (!mounted) return;
      final nutritionCubit = context.read<NutritionCubit>();
      final mealHistoryCubit = context.read<MealHistoryCubit>();
      await Future.wait([
        nutritionCubit.load(),
        mealHistoryCubit.load(),
      ]);
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Đã thêm bữa ăn vào nhật ký.',
        type: AppAlertType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể thêm món ăn.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<double?> _askGrams(MealSearchResult result) async {
    final value = await showQuantityInputSheet(
      context: context,
      title: 'Khối lượng',
      subtitle: 'Nhập số gram để lưu vào nhật ký.',
      initialValue: 100,
      step: 10,
      min: 1,
      formatLabel: (v) => v.toStringAsFixed(0),
      confirmLabel: 'Thêm',
      previewBuilder: (grams) => _NutritionPreview(result: result, grams: grams),
    );
    if (value == null || value <= 0) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tra cứu Hệ Thống Dinh Dưỡng',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tìm món ăn từ Hệ thống dinh dưỡng USDA FoodData Central và lưu khẩu phần theo gram.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          PremiumCard(
            padding: const EdgeInsets.all(18),
            borderColor: AppTheme.primary.withValues(alpha: 0.18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppTheme.primaryContainer,
                      child: Icon(Icons.manage_search, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kho dữ liệu thực phẩm',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Nhập tên món ăn',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SourceBadge(
                      label: _results.isEmpty
                          ? 'USDA'
                          : '${_results.length} kết quả',
                      icon: Icons.verified_outlined,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton.filled(
                      onPressed: _loading ? null : _search,
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: const Color(0xFF2B1B00),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    hintText: 'Ví dụ: chicken breast, phở, banana...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const SearchSkeletonLoader()
          else if (_errorMessage != null)
            PremiumCard(
              borderColor: AppTheme.danger.withValues(alpha: 0.35),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: AppTheme.danger),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_errorMessage!)),
                ],
              ),
            ),
          if (!_loading && _results.isEmpty && _errorMessage == null)
            PremiumCard(
              backgroundColor: AppTheme.surfaceContainer,
              child: Column(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AppTheme.primary,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sẵn sàng tìm món ăn',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nhập từ khóa ở ô tìm kiếm phía trên để lấy danh sách thực phẩm từ Hệ thống dinh dưỡng USDA FoodData Central.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ..._results.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumCard(
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppTheme.primaryContainer,
                      child: Icon(Icons.restaurant, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          if (result.brand.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              result.brand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '${result.calories.toStringAsFixed(0)} kcal / 100g',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MacroLine(result: result),
                          const SizedBox(height: 8),
                          _MacroDistribution(result: result),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _loading ? null : () => _addMeal(result),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: const Color(0xFF2B1B00),
                      ),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroDistribution extends StatelessWidget {
  const _MacroDistribution({required this.result});

  final MealSearchResult result;

  @override
  Widget build(BuildContext context) {
    final total = result.proteinGrams + result.carbsGrams + result.fatGrams;
    final protein = total <= 0 ? 0.0 : result.proteinGrams / total;
    final carbs = total <= 0 ? 0.0 : result.carbsGrams / total;
    final fat = total <= 0 ? 0.0 : result.fatGrams / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            Expanded(
              flex: (protein * 100).round().clamp(1, 100),
              child: const ColoredBox(color: AppTheme.protein),
            ),
            Expanded(
              flex: (carbs * 100).round().clamp(1, 100),
              child: const ColoredBox(color: AppTheme.carb),
            ),
            Expanded(
              flex: (fat * 100).round().clamp(1, 100),
              child: const ColoredBox(color: AppTheme.fat),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lives inside the quantity bottom sheet — shows what the chosen gram
/// amount works out to in calories/protein/carb/fat, scaled from the
/// per-100g values already on [result], without saving anything.
class _NutritionPreview extends StatelessWidget {
  const _NutritionPreview({required this.result, required this.grams});

  final MealSearchResult result;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final scale = grams / 100;
    return PremiumCard(
      backgroundColor: AppTheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MacroIconRow(
            icon: nutrientIcon('calories'),
            label: 'Calories',
            value: '${(result.calories * scale).toStringAsFixed(0)} kcal',
            color: AppTheme.primary,
          ),
          MacroIconRow(
            icon: nutrientIcon('protein'),
            label: 'Protein',
            value: '${(result.proteinGrams * scale).toStringAsFixed(1)} g',
            color: AppTheme.protein,
          ),
          MacroIconRow(
            icon: nutrientIcon('carb'),
            label: 'Carb',
            value: '${(result.carbsGrams * scale).toStringAsFixed(1)} g',
            color: AppTheme.carb,
          ),
          MacroIconRow(
            icon: nutrientIcon('fat'),
            label: 'Fat',
            value: '${(result.fatGrams * scale).toStringAsFixed(1)} g',
            color: AppTheme.fat,
          ),
        ],
      ),
    );
  }
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({required this.result});

  final MealSearchResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MacroPill(
            label: 'P', value: result.proteinGrams, color: AppTheme.protein),
        const SizedBox(width: 6),
        _MacroPill(label: 'C', value: result.carbsGrams, color: AppTheme.carb),
        const SizedBox(width: 6),
        _MacroPill(label: 'F', value: result.fatGrams, color: AppTheme.fat),
      ],
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '$label ${value.toStringAsFixed(0)}g',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
