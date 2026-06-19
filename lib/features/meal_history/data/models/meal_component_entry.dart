import '../../../../core/utils/image_url_utils.dart';

class MealComponentEntry {
  const MealComponentEntry({
    required this.id,
    required this.componentName,
    required this.physicalDataName,
    required this.volume,
    required this.calculatedWeight,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.imageUrl,
  });

  factory MealComponentEntry.fromJson(Map<String, dynamic> json) {
    return MealComponentEntry(
      id: '${json['id'] ?? ''}',
      componentName: '${json['component_name'] ?? ''}',
      physicalDataName: '${json['physical_data_name'] ?? ''}',
      volume: _toDouble(json['volume']),
      calculatedWeight: _toDouble(json['calculated_weight'] ?? json['weight']),
      calories: _toDouble(json['calories']),
      proteinGrams: _toDouble(json['protein']),
      carbsGrams: _toDouble(json['carbs']),
      fatGrams: _toDouble(json['fat']),
      imageUrl: ImageUrlUtils.resolveAbsolute(
        json['image_url'] ?? json['imageUrl'] ?? json['thumbnail_url'],
      ),
    );
  }

  final String id;
  final String componentName;
  final String physicalDataName;
  final double volume;
  final double calculatedWeight;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String? imageUrl;

  String get displayName {
    if (physicalDataName.isNotEmpty) return physicalDataName;
    return componentName;
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
