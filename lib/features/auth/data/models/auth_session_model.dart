import '../../domain/entities/auth_session.dart';
import 'auth_user_model.dart';

class AuthSessionModel extends AuthSession {
  const AuthSessionModel({
    required AuthUserModel super.user,
    required super.accessToken,
    required super.refreshToken,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] ?? json);
    final userJson = (data['user'] ?? data) as Map?;

    return AuthSessionModel(
      user: AuthUserModel.fromJson(
        Map<String, dynamic>.from(userJson ?? const <String, dynamic>{}),
      ),
      accessToken: '${data['access'] ?? data['accessToken'] ?? ''}',
      refreshToken: '${data['refresh'] ?? data['refreshToken'] ?? ''}',
    );
  }
}
