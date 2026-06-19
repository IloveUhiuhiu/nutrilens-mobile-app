import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/di/app_dependencies.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_url_utils.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/ingredient_image.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../meal_history/presentation/bloc/meal_history_cubit.dart';
import '../../../nutrition/presentation/bloc/nutrition_cubit.dart';

class ManualMealPage extends StatefulWidget {
  const ManualMealPage({super.key});

  @override
  State<ManualMealPage> createState() => _ManualMealPageState();
}

class _ManualMealPageState extends State<ManualMealPage> {
  final _titleController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _ingredientQueryController = TextEditingController();
  final _ingredients = <_Ingredient>[];
  final _selectedIngredients = <_SelectedIngredient>[];
  var _detailedMode = false;
  var _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _ingredientQueryController.dispose();
    super.dispose();
  }

  Future<void> _searchIngredients() async {
    final query = _ingredientQueryController.text.trim();
    if (query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final response =
          await AppDependencies.dioClient.get<Map<String, dynamic>>(
        ApiEndpoints.ingredients,
        queryParameters: {'search': query, 'q': query},
      );
      final data = response.data?['data'];
      final list = data is List
          ? data
          : data is Map && data['results'] is List
              ? data['results'] as List
              : const [];
      if (!mounted) return;
      setState(() {
        _ingredients
          ..clear()
          ..addAll(
            list.whereType<Map>().map((item) => _Ingredient.fromJson(
                  Map<String, dynamic>.from(item),
                )),
          );
      });
    } catch (_) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Không thể tìm nguyên liệu.',
        type: AppAlertType.warning,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppAlerts.showToast(
        context,
        message: 'Vui lòng nhập tên bữa ăn.',
        type: AppAlertType.warning,
      );
      return;
    }

    final payload =
        _detailedMode ? _detailedPayload(title) : _quickPayload(title);
    if (payload == null) return;

    setState(() => _loading = true);
    try {
      await AppDependencies.dioClient.post<void>(
        ApiEndpoints.mealManual,
        data: payload,
      );
      if (!mounted) return;
      await Future.wait([
        context.read<NutritionCubit>().load(),
        context.read<MealHistoryCubit>().load(),
      ]);
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Đã lưu bữa ăn thủ công.',
        type: AppAlertType.success,
      );
      _clearForm();
      // #2: return to the Nutrition Diary and let it refresh on entry.
      context.go('/diary');
    } on ApiException catch (error) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: error.message.isNotEmpty
            ? error.message
            : 'Không thể lưu bữa ăn thủ công.',
        type: AppAlertType.critical,
      );
    } catch (_) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Không thể lưu bữa ăn thủ công.',
        type: AppAlertType.critical,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _quickPayload(String title) {
    final calories = double.tryParse(_caloriesController.text.trim());
    final protein = double.tryParse(_proteinController.text.trim()) ?? 0;
    final carbs = double.tryParse(_carbsController.text.trim()) ?? 0;
    final fat = double.tryParse(_fatController.text.trim()) ?? 0;
    if (calories == null || calories <= 0) {
      AppAlerts.showToast(
        context,
        message: 'Vui lòng nhập calories lớn hơn 0.',
        type: AppAlertType.warning,
      );
      return null;
    }
    return {
      'name': title,
      'source_type': 'manual',
      'total_calories': calories,
      'total_protein': protein,
      'total_carbs': carbs,
      'total_fat': fat,
      'components': const [],
    };
  }

  Map<String, dynamic>? _detailedPayload(String title) {
    if (_selectedIngredients.isEmpty) {
      AppAlerts.showToast(
        context,
        message: 'Vui lòng thêm ít nhất một nguyên liệu.',
        type: AppAlertType.warning,
      );
      return null;
    }
    // Backend (ManualComponentInputSerializer) expects each component as
    // { physical_data: <IngredientPhysicalData id>, component_name, volume }
    // and recomputes macros server-side from the ingredient density.
    return {
      'name': title,
      'source_type': 'manual',
      'components': _selectedIngredients
          .map(
            (item) => {
              'physical_data': item.ingredient.id,
              'component_name': item.ingredient.name,
              'volume': item.volume,
            },
          )
          .toList(),
    };
  }

  void _clearForm() {
    setState(() {
      _titleController.clear();
      _caloriesController.clear();
      _proteinController.clear();
      _carbsController.clear();
      _fatController.clear();
      _ingredientQueryController.clear();
      _ingredients.clear();
      _selectedIngredients.clear();
    });
  }

  void _addIngredient(_Ingredient ingredient) {
    final volumeController = TextEditingController(text: '100');
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(ingredient.name),
          content: TextField(
            controller: volumeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Khối lượng / thể tích',
              suffixText: 'g/ml',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final volume =
                    double.tryParse(volumeController.text.trim()) ?? 0;
                if (volume <= 0) return;
                setState(() {
                  _selectedIngredients.add(
                    _SelectedIngredient(ingredient: ingredient, volume: volume),
                  );
                });
                Navigator.of(context).pop();
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = _SelectedIngredientTotals(_selectedIngredients);
    return AppShell(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Nhập bữa ăn thủ công',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ghi nhanh calories hoặc xây dựng bữa ăn từ nguyên liệu.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Nhập nhanh')),
              ButtonSegment(value: true, label: Text('Nguyên liệu')),
            ],
            selected: {_detailedMode},
            onSelectionChanged: (values) {
              setState(() => _detailedMode = values.first);
            },
          ),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tên bữa ăn',
                    prefixIcon: Icon(Icons.restaurant_menu),
                  ),
                ),
                const SizedBox(height: 14),
                if (_detailedMode)
                  _DetailedForm(
                    queryController: _ingredientQueryController,
                    ingredients: _ingredients,
                    selectedIngredients: _selectedIngredients,
                    totals: totals,
                    loading: _loading,
                    onSearch: _searchIngredients,
                    onAdd: _addIngredient,
                    onRemove: (item) {
                      setState(() => _selectedIngredients.remove(item));
                    },
                  )
                else
                  _QuickForm(
                    caloriesController: _caloriesController,
                    proteinController: _proteinController,
                    carbsController: _carbsController,
                    fatController: _fatController,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Lưu bữa ăn'),
          ),
        ],
      ),
    );
  }
}

class _QuickForm extends StatelessWidget {
  const _QuickForm({
    required this.caloriesController,
    required this.proteinController,
    required this.carbsController,
    required this.fatController,
  });

  final TextEditingController caloriesController;
  final TextEditingController proteinController;
  final TextEditingController carbsController;
  final TextEditingController fatController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: caloriesController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Calories'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: proteinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Đạm g'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Carb g'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: fatController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Béo g'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailedForm extends StatelessWidget {
  const _DetailedForm({
    required this.queryController,
    required this.ingredients,
    required this.selectedIngredients,
    required this.totals,
    required this.loading,
    required this.onSearch,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController queryController;
  final List<_Ingredient> ingredients;
  final List<_SelectedIngredient> selectedIngredients;
  final _SelectedIngredientTotals totals;
  final bool loading;
  final VoidCallback onSearch;
  final ValueChanged<_Ingredient> onAdd;
  final ValueChanged<_SelectedIngredient> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: queryController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            labelText: 'Tìm nguyên liệu',
            suffixIcon: IconButton(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (ingredients.isNotEmpty)
          ...ingredients.take(4).map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IngredientImage(imageUrl: item.imageUrl, label: item.name),
                  title: Text(item.name),
                  subtitle:
                      Text('${item.calories.toStringAsFixed(0)} kcal / 100g'),
                  trailing: IconButton.filledTonal(
                    onPressed: () => onAdd(item),
                    icon: const Icon(Icons.add),
                  ),
                ),
              ),
        if (selectedIngredients.isNotEmpty) ...[
          const Divider(height: 24),
          ...selectedIngredients.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IngredientImage(imageUrl: item.ingredient.imageUrl, label: item.ingredient.name),
              title: Text(item.ingredient.name),
              subtitle: Text('${item.volume.toStringAsFixed(0)} g/ml'),
              trailing: IconButton(
                onPressed: () => onRemove(item),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          PremiumCard(
            backgroundColor: AppTheme.surfaceContainer,
            child: Row(
              children: [
                _Total(label: 'Kcal', value: totals.calories),
                _Total(label: 'Đạm', value: totals.protein),
                _Total(label: 'Carb', value: totals.carbs),
                _Total(label: 'Béo', value: totals.fat),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(
            value.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _Ingredient {
  const _Ingredient({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.imageUrl,
  });

  factory _Ingredient.fromJson(Map<String, dynamic> json) {
    return _Ingredient(
      id: '${json['id'] ?? json['ingredient_id'] ?? json['fdc_id'] ?? ''}',
      name:
          '${json['name'] ?? json['vi_name'] ?? json['en_name'] ?? 'Nguyên liệu'}',
      calories: _number(json, const ['calories', 'cal_per_100g', 'energy']),
      protein: _number(json, const ['protein', 'protein_per_100g']),
      carbs: _number(json, const ['carbs', 'carb_per_100g', 'carbohydrate']),
      fat: _number(json, const ['fat', 'fat_per_100g', 'total_fat']),
      imageUrl: ImageUrlUtils.resolveAbsolute(
        json['image_url'] ??
            json['imageUrl'] ??
            json['thumbnail_url'] ??
            json['image'],
      ),
    );
  }

  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? imageUrl;
}

class _SelectedIngredient {
  const _SelectedIngredient({
    required this.ingredient,
    required this.volume,
  });

  final _Ingredient ingredient;
  final double volume;

  double get _ratio => volume / 100;
  double get calories => ingredient.calories * _ratio;
  double get protein => ingredient.protein * _ratio;
  double get carbs => ingredient.carbs * _ratio;
  double get fat => ingredient.fat * _ratio;
}

class _SelectedIngredientTotals {
  const _SelectedIngredientTotals(this.items);

  final List<_SelectedIngredient> items;

  double get calories => items.fold(0, (sum, item) => sum + item.calories);
  double get protein => items.fold(0, (sum, item) => sum + item.protein);
  double get carbs => items.fold(0, (sum, item) => sum + item.carbs);
  double get fat => items.fold(0, (sum, item) => sum + item.fat);
}

double _number(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse('$value');
    if (parsed != null) return parsed;
  }
  return 0;
}
