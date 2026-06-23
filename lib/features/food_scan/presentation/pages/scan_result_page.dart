import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/ingredient_image.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../meal_history/presentation/bloc/meal_history_cubit.dart';
import '../../domain/entities/food_analysis.dart';
import '../bloc/food_scan_bloc.dart';
import '../bloc/food_scan_event.dart';
import '../bloc/food_scan_state.dart';

class ScanResultPage extends StatelessWidget {
  const ScanResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: BlocConsumer<FoodScanBloc, FoodScanState>(
        listener: (context, state) {
          if (state is FoodScanResultReady && state.saved) {
            AppAlerts.showToast(
              context,
              message: 'Đã lưu kết quả vào nhật ký.',
              type: AppAlertType.success,
            );
            // Refresh diary so the new meal appears immediately.
            context.read<MealHistoryCubit>().load();
          }
          if (state is FoodScanError) {
            AppAlerts.showToast(
              context,
              message: state.message,
              type: AppAlertType.critical,
            );
          }
        },
        // A failed save briefly emits FoodScanError then re-emits the
        // previous FoodScanResultReady so the toast above can fire — without
        // this, the builder below would flash the "no result" empty state
        // for one frame in between, since FoodScanError isn't
        // FoodScanResultReady. listener still runs for every state either way.
        buildWhen: (previous, current) => current is FoodScanResultReady,
        builder: (context, state) {
          if (state is! FoodScanResultReady) {
            return _NoResultView(onBack: () => context.go('/scan'));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Kết quả phân tích',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              Text(
                'Phát hiện ${state.analysis.items.length} thành phần chính.',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(state.imagePath), fit: BoxFit.cover),
                      ...state.analysis.items.map(_DetectionOverlay.new),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              PremiumCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tổng năng lượng'),
                              Text(
                                '${state.analysis.totalCalories.toStringAsFixed(0)} Calo',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _MacroChip(
                            'P', state.analysis.proteinGrams, AppTheme.protein),
                        _MacroChip(
                            'C', state.analysis.carbsGrams, AppTheme.carb),
                        _MacroChip('F', state.analysis.fatGrams, AppTheme.fat),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => context.go(
                        '/scan-result/feedback',
                        extra: state.jobId,
                      ),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Báo lỗi nhận diện'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: AppTheme.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PremiumCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: const Text(
                      'Thành phần món ăn',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    children: state.analysis.items
                        .asMap()
                        .entries
                        .map((e) => _ComponentTile(item: e.value, index: e.key))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: state.saved
                    ? null
                    : () => context.read<FoodScanBloc>().add(
                          const FoodAnalysisSaveRequested(),
                        ),
                icon: const Icon(Icons.bookmark),
                label: Text(state.saved ? 'Đã lưu' : 'Lưu vào Nhật ký'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoResultView extends StatelessWidget {
  const _NoResultView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có kết quả phân tích',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Có thể bạn vừa quay lại màn hình này trực tiếp. Hãy quét lại món ăn để xem kết quả.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Quét món ăn'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionOverlay extends StatelessWidget {
  const _DetectionOverlay(this.item);

  final FoodAnalysisItem item;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: item.boundingBox.x,
      top: item.boundingBox.y,
      width: item.boundingBox.width,
      height: item.boundingBox.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.16),
          border: Border.all(color: AppTheme.accent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                item.label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
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
      padding: const EdgeInsets.only(left: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              Text(label, style: TextStyle(color: color)),
              Text(
                '${value.toStringAsFixed(0)}g',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({required this.item, required this.index});

  final FoodAnalysisItem item;
  final int index;

  Future<void> _openEditSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: context.read<FoodScanBloc>(),
        child: _EditItemSheet(item: item, index: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSubIngredients = item.ingredients.length > 1;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: hasSubIngredients
          ? ExpansionTile(
              leading: IngredientImage(imageUrl: _componentImageUrl(item), label: item.label),
              title: Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_ingredientSubtitle(item)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${item.calories.toStringAsFixed(0)} kcal'),
                  IconButton(
                    onPressed: () => _openEditSheet(context),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Chỉnh khẩu phần',
                  ),
                ],
              ),
              children: item.ingredients
                  .map(
                    (ing) => ListTile(
                      contentPadding:
                          const EdgeInsets.only(left: 56, right: 16),
                      leading: IngredientImage(
                        imageUrl: ing.imageUrl,
                        size: 32,
                        label: ing.name,
                      ),
                      title: Text(
                        ing.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: Text(
                        '${ing.grams.toStringAsFixed(0)}g · '
                        '${ing.calories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            )
          : ListTile(
              leading: IngredientImage(imageUrl: _componentImageUrl(item), label: item.label),
              title: Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_ingredientSubtitle(item)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${item.calories.toStringAsFixed(0)} kcal'),
                  IconButton(
                    onPressed: () => _openEditSheet(context),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Chỉnh khẩu phần',
                  ),
                ],
              ),
            ),
    );
  }
}

/// Returns the best available image URL for a detected food component.
/// Priority: ingredient thumbnail → depth map URL (fallback visual).
String? _componentImageUrl(FoodAnalysisItem item) {
  for (final ingredient in item.ingredients) {
    final url = ingredient.imageUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
  }
  final depthUrl = item.depth.depthMapUrl.trim();
  if (depthUrl.isNotEmpty) return depthUrl;
  return null;
}

String _ingredientSubtitle(FoodAnalysisItem item) {
  if (item.ingredients.isEmpty) {
    return '${item.weightGrams.toStringAsFixed(0)}g · ${item.volumeMl.toStringAsFixed(0)} ml';
  }
  return item.ingredients
      .take(2)
      .map((ing) => '${ing.name} ${ing.grams.toStringAsFixed(0)}g')
      .join(' · ');
}

class _EditItemSheet extends StatefulWidget {
  const _EditItemSheet({required this.item, required this.index});

  final FoodAnalysisItem item;
  final int index;

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _caloriesCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _labelCtrl = TextEditingController(text: it.label);
    _weightCtrl = TextEditingController(text: it.weightGrams.toStringAsFixed(1));
    _caloriesCtrl = TextEditingController(text: it.calories.toStringAsFixed(1));
    _proteinCtrl = TextEditingController(text: it.proteinGrams.toStringAsFixed(1));
    _carbsCtrl = TextEditingController(text: it.carbsGrams.toStringAsFixed(1));
    _fatCtrl = TextEditingController(text: it.fatGrams.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _weightCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final calories = double.tryParse(_caloriesCtrl.text) ?? widget.item.calories;
    final protein = double.tryParse(_proteinCtrl.text) ?? widget.item.proteinGrams;
    final carbs = double.tryParse(_carbsCtrl.text) ?? widget.item.carbsGrams;
    final fat = double.tryParse(_fatCtrl.text) ?? widget.item.fatGrams;
    final weight = double.tryParse(_weightCtrl.text) ?? widget.item.weightGrams;
    final label = _labelCtrl.text.trim().isEmpty ? widget.item.label : _labelCtrl.text.trim();

    context.read<FoodScanBloc>().add(FoodAnalysisItemEdited(
      index: widget.index,
      label: label,
      calories: calories,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      weightGrams: weight,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chỉnh sửa thành phần',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _labelCtrl,
            decoration: const InputDecoration(labelText: 'Tên món'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _weightCtrl,
                  decoration: const InputDecoration(labelText: 'Khối lượng (g)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _caloriesCtrl,
                  decoration: const InputDecoration(labelText: 'Calo (kcal)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _proteinCtrl,
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _carbsCtrl,
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _fatCtrl,
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }
}
