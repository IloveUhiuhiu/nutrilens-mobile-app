import '../../../../core/utils/parsing.dart';
class ActivityLevel {
  const ActivityLevel({
    required this.id,
    required this.levelName,
    required this.description,
    required this.ratio,
  });

  factory ActivityLevel.fromJson(Map<String, dynamic> json) {
    return ActivityLevel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      levelName: '${json['level_name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      ratio: toDoubleOrZero(json['ratio']),
    );
  }

  final int id;
  final String levelName;
  final String description;
  final double ratio;
}

