import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/image_url_utils.dart';
import '../../../food_scan/data/models/food_analysis_model.dart';
import '../../../meal_history/data/models/meal_entry.dart';

class MealDetailBundle {
  const MealDetailBundle({
    required this.entry,
    this.packagedFood,
    this.nutrientFood,
    this.inferenceJob,
  });

  final MealEntry entry;
  final Map<String, dynamic>? packagedFood;
  final Map<String, dynamic>? nutrientFood;
  final Map<String, dynamic>? inferenceJob;
}

class MealDetailRepository {
  MealDetailRepository(this._client);

  final DioClient _client;

  Future<MealDetailBundle> fetchDetail(String mealId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.mealDetail(mealId),
    );
    final payload = _unwrap(response.data);
    final entry = MealEntry.fromJson(payload);

    Map<String, dynamic>? packagedFood;
    Map<String, dynamic>? nutrientFood;
    Map<String, dynamic>? inferenceJob;

    if (entry.sourceType == 'barcode') {
      final packagedId = entry.packagedFoodId;
      if (packagedId != null && packagedId.isNotEmpty) {
        packagedFood = await _fetchMap(ApiEndpoints.packagedFood(packagedId));
      }
    } else if (entry.sourceType == 'text') {
      final foodId = entry.foodId;
      if (foodId != null && foodId.isNotEmpty) {
        nutrientFood = await _fetchMap(ApiEndpoints.nutrientFood(foodId));
      }
    } else if (entry.sourceType == 'image') {
      final jobId = entry.inferenceJobId;
      if (jobId != null && jobId.isNotEmpty) {
        inferenceJob = await _fetchMap(ApiEndpoints.inferenceJobDetail(jobId));
      }
    }

    return MealDetailBundle(
      entry: entry,
      packagedFood: packagedFood,
      nutrientFood: nutrientFood,
      inferenceJob: inferenceJob,
    );
  }

  Future<FoodAnalysisModel?> fetchInferenceAnalysis(
    String jobId, {
    MealEntry? entry,
    Map<String, dynamic>? inferenceJob,
  }) async {
    if (jobId.isNotEmpty) {
      try {
        final response = await _client.get<Map<String, dynamic>>(
          ApiEndpoints.inferenceJobResult(jobId),
        );
        final model = FoodAnalysisModel.fromJson(response.data ?? const {});
        return _mergeJobImage(model, entry, inferenceJob);
      } catch (_) {
        return _analysisFromMealEntry(entry, inferenceJob);
      }
    }
    return _analysisFromMealEntry(entry, inferenceJob);
  }

  FoodAnalysisModel _mergeJobImage(
    FoodAnalysisModel model,
    MealEntry? entry,
    Map<String, dynamic>? inferenceJob,
  ) {
    final jobImage = ImageUrlUtils.resolveAbsolute(inferenceJob?['image']);
    final entryImage = entry?.imageUrl;
    final resolvedImage = model.imageUrl.isNotEmpty
        ? model.imageUrl
        : (entryImage ?? jobImage ?? '');
    if (resolvedImage == model.imageUrl) return model;
    return FoodAnalysisModel(
      id: model.id,
      imageUrl: resolvedImage,
      totalCalories: model.totalCalories,
      proteinGrams: model.proteinGrams,
      carbsGrams: model.carbsGrams,
      fatGrams: model.fatGrams,
      items: model.items,
    );
  }

  FoodAnalysisModel? _analysisFromMealEntry(
    MealEntry? entry,
    Map<String, dynamic>? inferenceJob,
  ) {
    if (entry == null || entry.components.isEmpty) return null;
    final jobImage = ImageUrlUtils.resolveAbsolute(inferenceJob?['image']);
    final items = entry.components
        .map(
          (component) => FoodAnalysisItemModel.fromJson({
            'component_name': component.componentName,
            'physical_data_name': component.physicalDataName,
            'volume': component.volume,
            'calculated_weight': component.calculatedWeight,
            'calories': component.calories,
            'protein': component.proteinGrams,
            'carbs': component.carbsGrams,
            'fat': component.fatGrams,
            'image_url': component.imageUrl,
          }),
        )
        .toList();
    return FoodAnalysisModel(
      id: entry.inferenceJobId ?? entry.id,
      imageUrl: entry.imageUrl ?? jobImage ?? '',
      totalCalories: entry.calories,
      proteinGrams: entry.proteinGrams,
      carbsGrams: entry.carbsGrams,
      fatGrams: entry.fatGrams,
      items: items,
    );
  }

  Future<Map<String, dynamic>?> _fetchMap(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      return _unwrap(response.data);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? payload) {
    if (payload == null) return const {};
    final data = payload['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(payload);
  }
}
