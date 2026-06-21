import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/image_url_utils.dart';
import 'meal_component_entry.dart';
import '../../../../core/utils/parsing.dart';

class MealEntry {
  const MealEntry({
    required this.id,
    required this.title,
    required this.mealType,
    required this.calories,
    required this.loggedAt,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.weightGrams,
    required this.sourceType,
    this.imageUrl,
    this.packagedFoodId,
    this.foodId,
    this.inferenceJobId,
    this.barcode,
    this.brand,
    this.fdcId,
    this.servings,
    this.servingSize,
    this.servingUnit,
    this.servingAmount,
    this.searchQuery,
    this.components = const [],
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    final food = _asMap(json['food']);
    final packagedFood = _asMap(json['packaged_food']);
    final rawComponents =
        json['components'] is List ? json['components'] as List : const [];
    final parsedComponents = rawComponents
        .map((item) => MealComponentEntry.fromJson(_asMap(item)))
        .toList();
    final loggedAt = DateTimeUtils.parseToLocal(json['meal_time']) ??
        DateTimeUtils.parseToLocal(json['logged_at']) ??
        DateTimeUtils.parseToLocal(json['created_at']) ??
        DateTimeUtils.parseToLocal(json['measured_at']) ??
        DateTimeUtils.parseToLocal(json['date']);
    final sourceType = '${json['source_type'] ?? ''}';

    return MealEntry(
      id: '${json['id'] ?? ''}',
      title: _titleFromMeal(
        packagedFood: packagedFood,
        food: food,
        components: parsedComponents,
        searchQuery: json['search_query'],
      ),
      mealType: _mealTypeLabel(json['meal_type'] ?? json['meal_period']),
      calories: toDoubleOrZero(json['total_calories']),
      proteinGrams: toDoubleOrZero(json['total_protein']),
      carbsGrams: toDoubleOrZero(json['total_carbs']),
      fatGrams: toDoubleOrZero(json['total_fat']),
      weightGrams: toDoubleOrZero(json['total_weight']),
      loggedAt: loggedAt ?? DateTime.now().toLocal(),
      sourceType: sourceType,
      imageUrl: ImageUrlUtils.resolveAbsolute(
        json['image_url'] ??
            json['image_path'] ??
            json['imageUrl'] ??
            packagedFood['image_url'] ??
            food['image_url'],
      ),
      packagedFoodId: _nullableText(
        packagedFood['id'] ?? json['packaged_food_id'],
      ),
      foodId: _nullableText(food['id'] ?? json['food_id']),
      inferenceJobId: _nullableText(
        json['job_id'] ?? json['inference_job_id'] ?? json['job'],
      ),
      barcode: _nullableText(
        json['barcode'] ?? packagedFood['barcode'] ?? json['barcode_value'],
      ),
      brand: _nullableText(
        packagedFood['brand'] ??
            packagedFood['brand_name'] ??
            food['brand'] ??
            json['brand'],
      ),
      fdcId: _nullableText(food['fdc_id'] ?? json['fdc_id']),
      servings: _toNullableDouble(
        json['servings'] ?? json['serving_amount'],
      ),
      servingSize: _toNullableDouble(
        packagedFood['serving_size'] ?? json['serving_size'],
      ),
      servingUnit: _nullableText(
        packagedFood['serving_unit'] ??
            json['serving_unit'] ??
            json['serving_unit_label'],
      ),
      servingAmount: _toNullableDouble(json['serving_amount']),
      searchQuery: _nullableText(json['search_query']),
      components: parsedComponents,
    );
  }

  final String id;
  final String title;
  final String mealType;
  final double calories;
  final DateTime loggedAt;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double weightGrams;
  final String sourceType;
  final String? imageUrl;
  final String? packagedFoodId;
  final String? foodId;
  final String? inferenceJobId;
  final String? barcode;
  final String? brand;
  final String? fdcId;
  final double? servings;
  final double? servingSize;
  final String? servingUnit;
  final double? servingAmount;
  final String? searchQuery;
  final List<MealComponentEntry> components;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String _firstText(List<Object?> values, {required String fallback}) {
  for (final value in values) {
    final text = _nullableText(value);
    if (text != null) return text;
  }
  return fallback;
}

String? _nullableText(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

String _mealTypeLabel(Object? value) {
  final text = _nullableText(value);
  if (text == null) return 'Bữa ăn';
  final normalized = text.toLowerCase();
  if (normalized.contains('breakfast') || normalized.contains('sáng')) {
    return 'Bữa sáng';
  }
  if (normalized.contains('lunch') || normalized.contains('trưa')) {
    return 'Bữa trưa';
  }
  if (normalized.contains('dinner') || normalized.contains('tối')) {
    return 'Bữa tối';
  }
  if (normalized.contains('snack') ||
      normalized.contains('nhẹ') ||
      normalized.contains('phụ') ||
      normalized.contains('vặt')) {
    return 'Ăn nhẹ';
  }
  return text;
}

double? _toNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

String _titleFromMeal({
  required Map<String, dynamic> packagedFood,
  required Map<String, dynamic> food,
  required List<MealComponentEntry> components,
  Object? searchQuery,
}) {
  final baseTitle = _firstText([
    packagedFood['name'],
    food['vi_name'],
    food['name'],
  ], fallback: '');

  if (baseTitle.isNotEmpty) return baseTitle;

  final componentNames = components
      .map((c) => _firstText([
            c.physicalDataName,
            c.componentName,
          ], fallback: ''))
      .where((name) => name.isNotEmpty)
      .toList();

  if (componentNames.isEmpty) {
    return _firstText([searchQuery], fallback: 'Bữa ăn');
  }

  final firstThree = componentNames.take(3).join(', ');

  // Nếu 3 component quá dài thì chỉ hiển thị 2 component
  if (firstThree.length > 36 && componentNames.length >= 2) {
    return componentNames.take(2).join(', ');
  }

  return firstThree;
}