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
      ratio: _toDouble(json['ratio']),
    );
  }

  final int id;
  final String levelName;
  final String description;
  final double ratio;
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
