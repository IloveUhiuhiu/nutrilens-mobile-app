class FoodAnalysis {
  const FoodAnalysis({
    required this.id,
    required this.imageUrl,
    required this.totalCalories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.items,
  });

  final String id;
  final String imageUrl;
  final double totalCalories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final List<FoodAnalysisItem> items;

  FoodAnalysis copyWith({
    String? id,
    String? imageUrl,
    double? totalCalories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    List<FoodAnalysisItem>? items,
  }) {
    return FoodAnalysis(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      totalCalories: totalCalories ?? this.totalCalories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      items: items ?? this.items,
    );
  }
}

class FoodAnalysisItem {
  const FoodAnalysisItem({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.mask,
    required this.depth,
    required this.volumeMl,
    required this.ingredients,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.weightGrams = 0,
  });

  final String label;
  final double confidence;
  final BoundingBox boundingBox;
  final SegmentationMask mask;
  final DepthEstimation depth;
  final double volumeMl;
  final List<IngredientNutrition> ingredients;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double weightGrams;

  FoodAnalysisItem copyWith({
    String? label,
    double? calories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    double? weightGrams,
  }) {
    return FoodAnalysisItem(
      label: label ?? this.label,
      confidence: confidence,
      boundingBox: boundingBox,
      mask: mask,
      depth: depth,
      volumeMl: volumeMl,
      ingredients: ingredients,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      weightGrams: weightGrams ?? this.weightGrams,
    );
  }
}

class BoundingBox {
  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

class SegmentationMask {
  const SegmentationMask({
    required this.width,
    required this.height,
    required this.encodedMask,
  });

  final int width;
  final int height;
  final String encodedMask;
}

class DepthEstimation {
  const DepthEstimation({
    required this.averageDepthMm,
    required this.depthMapUrl,
  });

  final double averageDepthMm;
  final String depthMapUrl;
}

class IngredientNutrition {
  const IngredientNutrition({
    required this.name,
    required this.grams,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.imageUrl,
  });

  final String name;
  final double grams;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String? imageUrl;
}
