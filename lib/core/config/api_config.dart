import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  const ApiConfig._();

  static String get baseUrl {
    const dartDefineValue = String.fromEnvironment('NUTRILENS_API_BASE_URL');
    if (dartDefineValue.isNotEmpty) {
      return dartDefineValue;
    }

    try {
      return dotenv.env['NUTRILENS_API_BASE_URL'] ?? 'http://localhost:3000';
    } catch (_) {
      return 'http://localhost:3000';
    }
  }

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}
