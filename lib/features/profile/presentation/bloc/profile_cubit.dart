import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(ProfileState.initial());

  final ProfileRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(
        loading: true, clearError: true, updateSucceeded: false));
    try {
      final profile = await _repository.fetchProfile();
      emit(state.copyWith(
        profile: profile,
        loading: false,
        clearError: true,
      ));
      // Load activity levels lazily (non-blocking after profile is shown).
      if (state.activityLevels.isEmpty) {
        unawaited(_repository
            .fetchActivityLevels()
            .then((levels) => emit(state.copyWith(activityLevels: levels)))
            .catchError((_) {}));
      }
    } on ApiException catch (error) {
      debugPrint('[ProfileCubit] fetchProfile failed: HTTP ${error.statusCode} – ${error.message}');
      emit(state.copyWith(loading: false, errorMessage: 'Không thể tải hồ sơ.'));
    } catch (error) {
      debugPrint('[ProfileCubit] fetchProfile unexpected error: $error');
      emit(state.copyWith(loading: false, errorMessage: 'Không thể tải hồ sơ.'));
    }
  }

  Future<void> loadActivityLevels() async {
    if (state.activityLevels.isNotEmpty) return;
    try {
      final levels = await _repository.fetchActivityLevels();
      emit(state.copyWith(activityLevels: levels));
    } catch (_) {}
  }

  Future<void> updateProfile({
    required String name,
    required double heightCm,
    required double weightKg,
    String? phoneNumber,
    int? activityLevelId,
  }) async {
    emit(state.copyWith(
        loading: true, clearError: true, updateSucceeded: false));
    try {
      final profile = await _repository.updateProfile(
        name: name,
        heightCm: heightCm,
        weightKg: weightKg,
        phoneNumber: phoneNumber,
        activityLevelId: activityLevelId,
      );
      emit(state.copyWith(
        profile: profile,
        loading: false,
        clearError: true,
        updateSucceeded: true,
      ));
    } on ApiException catch (error) {
      debugPrint('[ProfileCubit] updateProfile failed: HTTP ${error.statusCode} – ${error.message}');
      emit(state.copyWith(loading: false, errorMessage: 'Không thể cập nhật hồ sơ.'));
    } catch (error) {
      debugPrint('[ProfileCubit] updateProfile unexpected error: $error');
      emit(state.copyWith(loading: false, errorMessage: 'Không thể cập nhật hồ sơ.'));
    }
  }

  Future<void> uploadAvatar(String imagePath) async {
    emit(state.copyWith(
        loading: true, clearError: true, updateSucceeded: false));
    try {
      final profile = await _repository.uploadAvatar(imagePath);
      emit(state.copyWith(
        profile: profile,
        loading: false,
        clearError: true,
        updateSucceeded: true,
      ));
    } on ApiException catch (error) {
      debugPrint('[ProfileCubit] uploadAvatar failed: HTTP ${error.statusCode} – ${error.message}');
      emit(state.copyWith(loading: false, errorMessage: 'Không thể cập nhật ảnh đại diện.'));
    } catch (error) {
      debugPrint('[ProfileCubit] uploadAvatar unexpected error: $error');
      emit(state.copyWith(loading: false, errorMessage: 'Không thể cập nhật ảnh đại diện.'));
    }
  }
}
