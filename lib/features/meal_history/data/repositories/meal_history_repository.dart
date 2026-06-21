import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/meal_entry.dart';
import '../../../../core/utils/date_time_utils.dart';

class MealHistoryRepository {
  MealHistoryRepository(this._client);

  final DioClient _client;

  Future<List<MealEntry>> fetchDailyMeals({DateTime? date}) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.mealList,
      queryParameters: date == null ? null : {'date': DateTimeUtils.formatDateKey(date)},
    );
    final data = response.data?['data'];
    final meals = _extractMeals(data ?? response.data);
    if (meals.isEmpty) {
      return const [];
    }

    final entries = <MealEntry>[];
    for (final item in meals) {
      if (item is! Map) continue;
      try {
        entries.add(MealEntry.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip malformed records instead of crashing the diary view.
      }
    }
    final filtered = date == null
        ? entries
        : entries.where((entry) => _isSameDate(entry.loggedAt, date)).toList();
    return filtered..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
  }

  List _extractMeals(Object? payload) {
    if (payload is List) return payload;
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      for (final key in const ['meals', 'results', 'items', 'data']) {
        final value = map[key];
        if (value is List) return value;
        if (value is Map) {
          final nested = _extractMeals(value);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return const [];
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
