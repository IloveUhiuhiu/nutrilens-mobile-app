import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/daily_nutrition.dart';
import '../../domain/entities/nutrition_advice.dart';

class NutritionRepository {
  NutritionRepository(this._client);

  final DioClient _client;

  /// Fetches backend-evaluated nutrition advice for [date] (defaults to today).
  Future<NutritionAdvice?> fetchAdvice({DateTime? date}) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.nutritionAdvice,
      queryParameters: date == null ? null : {'date': _dateValue(date)},
    );
    final data = _asMap(response.data?['data']);
    if (data.isEmpty) return null;
    return NutritionAdvice.fromJson(data);
  }

  Future<DailyNutrition> fetchTodayNutrition({DateTime? date}) async {
    final dailyResponse = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.dailyLog,
      queryParameters: date == null ? null : {'date': _dateValue(date)},
    );
    final profileResponse = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.authProfile,
    );

    final daily = _asMap(dailyResponse.data?['data']);
    final profile = _asMap(profileResponse.data?['data']);
    final calorieGoal = _toDouble(profile['tdee']);

    return DailyNutrition(
      calories: _toDouble(daily['total_calories']),
      calorieGoal: calorieGoal > 0 ? calorieGoal : 2000,
      proteinGrams: _toDouble(daily['total_protein']),
      carbsGrams: _toDouble(daily['total_carbs']),
      fatGrams: _toDouble(daily['total_fat']),
      weightGrams: _toDouble(daily['total_weight']),
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  String _dateValue(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
