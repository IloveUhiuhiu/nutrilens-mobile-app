class MealSearchResult {
  const MealSearchResult({
    required this.fdcId,
    required this.name,
    required this.brand,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  factory MealSearchResult.fromJson(Map<String, dynamic> json) {
    return MealSearchResult(
      fdcId: '${json['fdcId'] ?? json['fdc_id'] ?? json['id'] ?? ''}',
      name:
          '${json['vi_name'] ?? json['description_vi'] ?? json['description'] ?? json['name'] ?? json['food_name'] ?? 'Món ăn'}',
      brand: '${json['brandOwner'] ?? json['brand'] ?? ''}',
      calories: _nutrient(
        json,
        const ['cal_per_100g', 'calories', 'energy', 'Energy'],
      ),
      proteinGrams: _nutrient(
        json,
        const ['protein_per_100g', 'protein', 'Protein'],
      ),
      carbsGrams: _nutrient(
        json,
        const ['carb_per_100g', 'carbs', 'carbohydrate', 'Carbohydrate'],
      ),
      fatGrams: _nutrient(
        json,
        const ['fat_per_100g', 'fat', 'total_fat', 'Total lipid'],
      ),
    );
  }

  final String fdcId;
  final String name;
  final String brand;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
}

double _nutrient(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    final parsed = _toDouble(value);
    if (parsed > 0) return parsed;
  }

  final nutrients = json['foodNutrients'] ?? json['nutrients'];
  if (nutrients is List) {
    for (final item in nutrients) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final name = '${map['nutrientName'] ?? map['name'] ?? ''}'.toLowerCase();
      if (keys.any((key) => name.contains(key.toLowerCase()))) {
        return _toDouble(map['value'] ?? map['amount']);
      }
    }
  }

  return 0;
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
