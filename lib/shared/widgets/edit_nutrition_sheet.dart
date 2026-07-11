import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'nutrient_badges.dart';

class EditedNutrition {
  const EditedNutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

/// Bottom sheet for editing a meal's nutrition totals directly — used for
/// source types (AI image, manual) that have no single per-unit quantity to
/// scale a serving from, unlike barcode/USDA which use
/// [showQuantityInputSheet] instead.
Future<EditedNutrition?> showEditNutritionSheet({
  required BuildContext context,
  required double initialCalories,
  required double initialProtein,
  required double initialCarbs,
  required double initialFat,
}) {
  return showModalBottomSheet<EditedNutrition>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _EditNutritionSheet(
        initialCalories: initialCalories,
        initialProtein: initialProtein,
        initialCarbs: initialCarbs,
        initialFat: initialFat,
      );
    },
  );
}

class _EditNutritionSheet extends StatefulWidget {
  const _EditNutritionSheet({
    required this.initialCalories,
    required this.initialProtein,
    required this.initialCarbs,
    required this.initialFat,
  });

  final double initialCalories;
  final double initialProtein;
  final double initialCarbs;
  final double initialFat;

  @override
  State<_EditNutritionSheet> createState() => _EditNutritionSheetState();
}

class _EditNutritionSheetState extends State<_EditNutritionSheet> {
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  @override
  void initState() {
    super.initState();
    _caloriesController =
        TextEditingController(text: widget.initialCalories.toStringAsFixed(0));
    _proteinController =
        TextEditingController(text: widget.initialProtein.toStringAsFixed(1));
    _carbsController =
        TextEditingController(text: widget.initialCarbs.toStringAsFixed(1));
    _fatController =
        TextEditingController(text: widget.initialFat.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController controller) {
    return double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
  }

  void _save() {
    Navigator.of(context).pop(
      EditedNutrition(
        calories: _parse(_caloriesController),
        protein: _parse(_proteinController),
        carbs: _parse(_carbsController),
        fat: _parse(_fatController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + AppTheme.spacingLg;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sửa dinh dưỡng',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Nhập số liệu mới cho bữa ăn này.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          _NutrientField(
            icon: nutrientIcon('calories'),
            label: 'Calories (kcal)',
            color: AppTheme.primary,
            controller: _caloriesController,
          ),
          const SizedBox(height: 12),
          _NutrientField(
            icon: nutrientIcon('protein'),
            label: 'Protein (g)',
            color: AppTheme.protein,
            controller: _proteinController,
          ),
          const SizedBox(height: 12),
          _NutrientField(
            icon: nutrientIcon('carb'),
            label: 'Carb (g)',
            color: AppTheme.carb,
            controller: _carbsController,
          ),
          const SizedBox(height: 12),
          _NutrientField(
            icon: nutrientIcon('fat'),
            label: 'Fat (g)',
            color: AppTheme.fat,
            controller: _fatController,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _NutrientField extends StatelessWidget {
  const _NutrientField({
    required this.icon,
    required this.label,
    required this.color,
    required this.controller,
  });

  final IconData icon;
  final String label;
  final Color color;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: color, size: 20),
        labelText: label,
      ),
    );
  }
}
