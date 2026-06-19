import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.weightKg,
    required this.heightCm,
    this.activityLevelId,
  });

  final String name;
  final String email;
  final String password;
  final double weightKg;
  final double heightCm;
  final String? activityLevelId;

  @override
  List<Object?> get props => [
        name,
        email,
        password,
        weightKg,
        heightCm,
        activityLevelId,
      ];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
