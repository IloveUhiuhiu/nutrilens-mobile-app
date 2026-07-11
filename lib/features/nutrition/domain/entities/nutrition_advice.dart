import 'package:equatable/equatable.dart';
import '../../../../core/utils/parsing.dart';

/// Nutrition advice evaluated by the backend (reports/nutrition/advice/).
///
/// All wording (title/message) and the alert level are produced server-side
/// from the configured HealthAdviceRule records, so the app only renders it.
class NutritionAdvice extends Equatable {
  const NutritionAdvice({
    required this.status,
    required this.title,
    required this.message,
    required this.ratio,
  });

  factory NutritionAdvice.fromJson(Map<String, dynamic> json) {
    final status =
        (json['status'] ?? json['alert_level'] ?? 'normal').toString();
    final percent = json['tdee_percent'];
    final ratio = json['ratio'] != null
        ? toDoubleOrZero(json['ratio'])
        : (percent is num ? percent.toDouble() / 100 : 0.0);
    return NutritionAdvice(
      status: status.isEmpty ? 'normal' : status,
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? json['advice_content'] ?? '').toString(),
      ratio: ratio,
    );
  }

  /// `normal` | `warning` | `danger`
  final String status;
  final String title;
  final String message;
  final double ratio;

  bool get isEmpty => title.isEmpty && message.isEmpty;

  @override
  List<Object?> get props => [status, title, message, ratio];
}

