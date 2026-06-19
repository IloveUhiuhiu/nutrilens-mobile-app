import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/activity_level.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final DioClient _client;

  Future<UserProfile> fetchProfile() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.authProfile,
    );
    final data = response.data?['data'];
    if (data is! Map) {
      return UserProfile.empty();
    }
    return UserProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<UserProfile> updateProfile({
    required String name,
    required double heightCm,
    required double weightKg,
    String? phoneNumber,
    int? activityLevelId,
  }) async {
    final body = <String, dynamic>{
      'full_name': name,
      'height': heightCm,
      'weight': weightKg,
      'phone_number': phoneNumber,
    };
    if (activityLevelId != null) body['activity_level'] = activityLevelId;

    final response = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.authProfile,
      data: body,
    );
    // Parse updated profile from PATCH response directly to avoid a second GET.
    final data = response.data?['data'];
    if (data is! Map) return fetchProfile();
    return UserProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<ActivityLevel>> fetchActivityLevels() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.activityLevels,
    );
    final data = response.data?['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => ActivityLevel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<UserProfile> uploadAvatar(String imagePath) async {
    final fileName = imagePath.split('/').last;
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(imagePath, filename: fileName),
    });
    await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.authProfile,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return fetchProfile();
  }
}
