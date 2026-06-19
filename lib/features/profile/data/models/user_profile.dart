import '../../../../core/utils/image_url_utils.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.bmi,
    required this.bmr,
    required this.tdee,
    this.activityLevelId,
    this.avatarUrl,
    this.phoneNumber,
    this.gender,
    this.birthDate,
  });

  factory UserProfile.empty() {
    return const UserProfile(
      id: '',
      name: '',
      email: '',
      heightCm: 0,
      weightKg: 0,
      activityLevel: '',
      bmi: 0,
      bmr: 0,
      tdee: 0,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final activityLevelMap = json['activity_level'] is Map
        ? Map<String, dynamic>.from(json['activity_level'] as Map)
        : const <String, dynamic>{};

    final rawActivityId = activityLevelMap['id'];
    final activityLevelId = rawActivityId is int
        ? rawActivityId
        : int.tryParse('$rawActivityId');

    return UserProfile(
      id: '${json['id'] ?? ''}',
      name: '${json['full_name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      heightCm: _toDouble(json['height']),
      weightKg: _toDouble(json['current_weight']),
      activityLevel: '${activityLevelMap['level_name'] ?? ''}',
      activityLevelId: activityLevelId,
      bmi: _toDouble(json['bmi']),
      bmr: 0,
      tdee: _toDouble(json['tdee']),
      avatarUrl: ImageUrlUtils.resolveAbsolute(
        json['avatar_url'] ?? json['avatarUrl'],
      ),
      phoneNumber: _nullableText(json['phone_number']),
      gender: _nullableText(json['gender']),
      birthDate: _nullableText(json['birth_date']),
    );
  }

  final String id;
  final String name;
  final String email;
  final double heightCm;
  final double weightKg;
  final String activityLevel;
  final int? activityLevelId;
  final double bmi;
  final double bmr;
  final double tdee;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? gender;
  final String? birthDate;
}

String? _nullableText(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
