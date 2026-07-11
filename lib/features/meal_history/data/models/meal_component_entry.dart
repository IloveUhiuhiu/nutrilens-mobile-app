import '../../../../core/utils/image_url_utils.dart';
import '../../../../core/utils/parsing.dart';

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
      volume: toDoubleOrZero(json['volume']),
      calculatedWeight: toDoubleOrZero(json['calculated_weight'] ?? json['weight']),
      calories: toDoubleOrZero(json['calories']),
      proteinGrams: toDoubleOrZero(json['protein']),
      carbsGrams: toDoubleOrZero(json['carbs']),
      fatGrams: toDoubleOrZero(json['fat']),
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

