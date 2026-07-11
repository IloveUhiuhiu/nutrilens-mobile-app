import '../../../../core/utils/image_url_utils.dart';
import '../../domain/entities/food_analysis.dart';
import '../../../../core/utils/parsing.dart';

class FoodAnalysisModel extends FoodAnalysis {
  const FoodAnalysisModel({
    required super.id,
    required super.imageUrl,
    required super.totalCalories,
    required super.proteinGrams,
    required super.carbsGrams,
    required super.fatGrams,
    required super.items,
  });

  factory FoodAnalysisModel.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] ?? json);
    final nutrition = Map<String, dynamic>.from(data['nutrition'] ?? data);
    final rawItems = (data['items'] ??
        data['detections'] ??
        data['components'] ??
        const []) as List;

    return FoodAnalysisModel(
      id: '${data['job'] ?? data['job_id'] ?? data['id'] ?? data['_id'] ?? ''}',
      imageUrl: ImageUrlUtils.resolveAbsolute(
            data['image_url'] ??
                data['image_path'] ??
                data['imageUrl'] ??
                data['image'],
          ) ??
          '',
      totalCalories: toDoubleOrZero(
        nutrition['totalCalories'] ??
            nutrition['total_calories'] ??
            nutrition['calories'],
      ),
      proteinGrams: toDoubleOrZero(
        nutrition['proteinGrams'] ??
            nutrition['total_protein'] ??
            nutrition['protein'],
      ),
      carbsGrams: toDoubleOrZero(
        nutrition['carbsGrams'] ??
            nutrition['total_carbs'] ??
            nutrition['carbs'],
      ),
      fatGrams: toDoubleOrZero(
        nutrition['fatGrams'] ?? nutrition['total_fat'] ?? nutrition['fat'],
      ),
      items: rawItems
          .map((item) => FoodAnalysisItemModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }
}

class FoodAnalysisItemModel extends FoodAnalysisItem {
  const FoodAnalysisItemModel({
    required super.label,
    required super.confidence,
    required super.boundingBox,
    required super.mask,
    required super.depth,
    required super.volumeMl,
    required super.ingredients,
    required super.calories,
    super.proteinGrams,
    super.carbsGrams,
    super.fatGrams,
    super.weightGrams,
  });

  factory FoodAnalysisItemModel.fromJson(Map<String, dynamic> json) {
    final rawIngredients = (json['ingredients'] ?? const []) as List;
    final proteinGrams = toDoubleOrZero(
      json['proteinGrams'] ?? json['protein'] ?? json['total_protein'],
    );
    final carbsGrams = toDoubleOrZero(
      json['carbsGrams'] ?? json['carbs'] ?? json['total_carbs'],
    );
    final fatGrams = toDoubleOrZero(
      json['fatGrams'] ?? json['fat'] ?? json['total_fat'],
    );
    final weightGrams = toDoubleOrZero(
      json['weightGrams'] ?? json['weight'] ?? json['calculated_weight'],
    );
    final calories = toDoubleOrZero(json['calories']);
    final label = '${json['physical_data_name'] ?? json['component_name'] ?? json['label'] ?? json['name'] ?? ''}';

    var ingredients = rawIngredients
        .map((item) => IngredientNutritionModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();

    if (ingredients.isEmpty &&
        (proteinGrams > 0 ||
            carbsGrams > 0 ||
            fatGrams > 0 ||
            calories > 0 ||
            weightGrams > 0)) {
      ingredients = [
        IngredientNutritionModel(
          name: label,
          grams: weightGrams,
          calories: calories,
          proteinGrams: proteinGrams,
          carbsGrams: carbsGrams,
          fatGrams: fatGrams,
          imageUrl: ImageUrlUtils.resolveAbsolute(
            json['image_url'] ?? json['imageUrl'] ?? json['thumbnail_url'],
          ),
        ),
      ];
    }

    return FoodAnalysisItemModel(
      label: label,
      confidence: toDoubleOrZero(json['confidence']),
      boundingBox: BoundingBoxModel.fromJson(
        Map<String, dynamic>.from(json['boundingBox'] ?? json['bbox'] ?? {}),
      ),
      mask: SegmentationMaskModel.fromJson(
        Map<String, dynamic>.from(
          json['mask'] ??
              json['segmentationMask'] ??
              {'encodedMask': json['mask_path']},
        ),
      ),
      depth: DepthEstimationModel.fromJson(
        Map<String, dynamic>.from(
            json['depth'] ?? json['depthEstimation'] ?? {}),
      ),
      volumeMl: toDoubleOrZero(json['volumeMl'] ?? json['volume']),
      calories: calories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      weightGrams: weightGrams,
      ingredients: ingredients,
    );
  }

  factory FoodAnalysisItemModel.fromMealComponent(Map<String, dynamic> json) {
    return FoodAnalysisItemModel.fromJson(json);
  }
}

class BoundingBoxModel extends BoundingBox {
  const BoundingBoxModel({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
  });

  factory BoundingBoxModel.fromJson(Map<String, dynamic> json) {
    return BoundingBoxModel(
      x: toDoubleOrZero(json['x']),
      y: toDoubleOrZero(json['y']),
      width: toDoubleOrZero(json['width'] ?? json['w']),
      height: toDoubleOrZero(json['height'] ?? json['h']),
    );
  }
}

class SegmentationMaskModel extends SegmentationMask {
  const SegmentationMaskModel({
    required super.width,
    required super.height,
    required super.encodedMask,
  });

  factory SegmentationMaskModel.fromJson(Map<String, dynamic> json) {
    return SegmentationMaskModel(
      width: _toInt(json['width']),
      height: _toInt(json['height']),
      encodedMask: '${json['encodedMask'] ?? json['rle'] ?? ''}',
    );
  }
}

class DepthEstimationModel extends DepthEstimation {
  const DepthEstimationModel({
    required super.averageDepthMm,
    required super.depthMapUrl,
  });

  factory DepthEstimationModel.fromJson(Map<String, dynamic> json) {
    return DepthEstimationModel(
      averageDepthMm: toDoubleOrZero(json['averageDepthMm'] ?? json['averageDepth']),
      depthMapUrl: ImageUrlUtils.resolveAbsolute(
            json['depth_map_url'] ?? json['depthMapUrl'],
          ) ??
          '',
    );
  }
}

class IngredientNutritionModel extends IngredientNutrition {
  const IngredientNutritionModel({
    required super.name,
    required super.grams,
    required super.calories,
    required super.proteinGrams,
    required super.carbsGrams,
    required super.fatGrams,
    super.imageUrl,
  });

  factory IngredientNutritionModel.fromJson(Map<String, dynamic> json) {
    return IngredientNutritionModel(
      name: '${json['name'] ?? ''}',
      grams: toDoubleOrZero(json['grams']),
      calories: toDoubleOrZero(json['calories']),
      proteinGrams: toDoubleOrZero(json['proteinGrams'] ?? json['protein']),
      carbsGrams: toDoubleOrZero(json['carbsGrams'] ?? json['carbs']),
      fatGrams: toDoubleOrZero(json['fatGrams'] ?? json['fat']),
      imageUrl: ImageUrlUtils.resolveAbsolute(
        json['image_url'] ??
            json['imageUrl'] ??
            json['thumbnail_url'] ??
            json['image'],
      ),
    );
  }
}

int _toInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
