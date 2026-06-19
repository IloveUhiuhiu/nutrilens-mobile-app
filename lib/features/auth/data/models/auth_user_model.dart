import '../../domain/entities/auth_user.dart';

class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.email,
    required super.name,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      email: '${json['email'] ?? ''}',
      name: '${json['name'] ?? json['fullName'] ?? ''}',
    );
  }
}
