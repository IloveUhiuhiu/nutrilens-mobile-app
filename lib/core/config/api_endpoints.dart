import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  const ApiEndpoints._();

  static String get authLogin => _env(
        'NUTRILENS_AUTH_LOGIN_PATH',
        '/api/v1/accounts/login/',
      );
  static String get authTokenRefresh => _env(
        'NUTRILENS_AUTH_TOKEN_REFRESH_PATH',
        '/api/v1/accounts/token/refresh/',
      );
  static String get authRegister => _env(
        'NUTRILENS_AUTH_REGISTER_PATH',
        '/api/v1/accounts/register/',
      );
  static String get authProfile => _env(
        'NUTRILENS_AUTH_PROFILE_PATH',
        '/api/v1/accounts/profile/',
      );
  static String get authLogout => _env(
        'NUTRILENS_AUTH_LOGOUT_PATH',
        '/api/v1/accounts/logout/',
      );
  static String get otpRequest => _env(
        'NUTRILENS_AUTH_OTP_REQUEST_PATH',
        '/api/v1/accounts/otp/request/',
      );
  static String get otpVerify => _env(
        'NUTRILENS_AUTH_OTP_VERIFY_PATH',
        '/api/v1/accounts/otp/verify/',
      );
  static String get activityLevels => _env(
        'NUTRILENS_ACTIVITY_LEVELS_PATH',
        '/api/v1/accounts/activity-levels/',
      );
  static String get passwordChange => _env(
        'NUTRILENS_PASSWORD_CHANGE_PATH',
        '/api/v1/accounts/password/change/',
      );

  static String get inferenceCreate => _env(
        'NUTRILENS_INFERENCE_CREATE_PATH',
        '/api/v1/inference/image/',
      );
  static String inferenceJobDetail(String id) => _withId(
        _env(
          'NUTRILENS_INFERENCE_JOB_DETAIL_PATH',
          '/api/v1/inference/jobs/{id}/',
        ),
        id,
      );
  static String inferenceJobResult(String id) => _withId(
        _env(
          'NUTRILENS_INFERENCE_JOB_RESULT_PATH',
          '/api/v1/inference/jobs/{id}/result/',
        ),
        id,
      );
  static String inferenceFeedback(String id) => _withId(
        _env(
          'NUTRILENS_INFERENCE_FEEDBACK_PATH',
          '/api/v1/inference/jobs/{id}/feedback/',
        ),
        id,
      );

  static String get mealFromInference => _env(
        'NUTRILENS_MEAL_FROM_INFERENCE_PATH',
        '/api/v1/analysis/meals/from-inference/',
      );
  static String get mealList => _env(
        'NUTRILENS_MEAL_LIST_PATH',
        '/api/v1/analysis/meals/',
      );
  static String get dailyLog => _env(
        'NUTRILENS_DAILY_LOG_PATH',
        '/api/v1/analysis/logs/daily/',
      );
  static String get rangeLogs => _env(
        'NUTRILENS_RANGE_LOGS_PATH',
        '/api/v1/analysis/logs/range/',
      );
  static String get mealSearch => _env(
        'NUTRILENS_MEAL_SEARCH_PATH',
        '/api/v1/analysis/meals/search/top/',
      );
  static String get mealFromUsda => _env(
        'NUTRILENS_MEAL_FROM_USDA_PATH',
        '/api/v1/analysis/meals/from-usda/',
      );
  static String get mealManual => _env(
        'NUTRILENS_MEAL_MANUAL_PATH',
        '/api/v1/analysis/meals/manual/',
      );
  static String get mealBarcode => _env(
        'NUTRILENS_MEAL_BARCODE_PATH',
        '/api/v1/analysis/meals/barcode/',
      );
  static String get ingredients => _env(
        'NUTRILENS_INGREDIENTS_PATH',
        '/api/v1/nutrients/ingredients/',
      );
  static String get nutritionTrends => _env(
        'NUTRILENS_REPORTS_NUTRITION_TRENDS_PATH',
        '/api/v1/reports/nutrition/trends/',
      );
  static String get nutritionSummary => _env(
        'NUTRILENS_REPORTS_NUTRITION_SUMMARY_PATH',
        '/api/v1/reports/nutrition/summary/',
      );
  static String get nutritionAdvice => _env(
        'NUTRILENS_REPORTS_NUTRITION_ADVICE_PATH',
        '/api/v1/reports/nutrition/advice/',
      );
  static String get weightHistory => _env(
        'NUTRILENS_WEIGHT_HISTORY_PATH',
        '/api/v1/accounts/profile/weight-history/',
      );
  static String barcodeLookup(String barcode) => _env(
        'NUTRILENS_BARCODE_LOOKUP_PATH',
        '/api/v1/analysis/barcodes/{barcode}/',
      ).replaceAll('{barcode}', barcode);
  static String mealDetail(String id) => _withId(
        _env(
          'NUTRILENS_MEAL_DETAIL_PATH',
          '/api/v1/analysis/meals/{id}/',
        ),
        id,
      );
  static String packagedFood(String id) => _withId(
        _env(
          'NUTRILENS_PACKAGED_FOOD_PATH',
          '/api/v1/nutrients/packaged-foods/{id}/',
        ),
        id,
      );
  static String nutrientFood(String id) => _withId(
        _env(
          'NUTRILENS_NUTRIENT_FOOD_PATH',
          '/api/v1/nutrients/foods/{id}/',
        ),
        id,
      );

  static String _env(String key, String fallback) {
    try {
      return dotenv.env[key] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static String _withId(String path, String id) {
    return path.replaceAll('{id}', id);
  }
}
