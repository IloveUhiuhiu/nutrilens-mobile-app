import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/meal_search_result.dart';

class MealSearchRepository {
  MealSearchRepository(this._client);

  final DioClient _client;

  Future<List<MealSearchResult>> search(String query) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.mealSearch,
      data: {
        'query': query,
        'source_type': 'text',
        'page_size': 5,
      },
    );
    final data = response.data?['data'];
    final results = _extractResults(data);
    return results
        .map((item) =>
            MealSearchResult.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((item) => item.fdcId.isNotEmpty)
        .toList();
  }

  Future<void> addFromUsda({
    required MealSearchResult result,
    required double grams,
    required String searchQuery,
  }) {
    return _client.post<void>(
      ApiEndpoints.mealFromUsda,
      data: {
        'fdc_id': result.fdcId,
        'grams': grams,
        'source_type': 'text',
        'search_query': searchQuery,
      },
    );
  }

  List _extractResults(Object? data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in const ['foods', 'results', 'items']) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    return const [];
  }
}
