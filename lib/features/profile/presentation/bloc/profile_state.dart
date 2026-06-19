import 'package:equatable/equatable.dart';

import '../../data/models/activity_level.dart';
import '../../data/models/user_profile.dart';

class ProfileState extends Equatable {
  const ProfileState({
    required this.profile,
    this.loading = false,
    this.errorMessage,
    this.updateSucceeded = false,
    this.activityLevels = const [],
  });

  factory ProfileState.initial() {
    return ProfileState(profile: UserProfile.empty());
  }

  final UserProfile profile;
  final bool loading;
  final String? errorMessage;
  final bool updateSucceeded;
  final List<ActivityLevel> activityLevels;

  ProfileState copyWith({
    UserProfile? profile,
    bool? loading,
    String? errorMessage,
    bool? updateSucceeded,
    bool clearError = false,
    List<ActivityLevel>? activityLevels,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      updateSucceeded: updateSucceeded ?? this.updateSucceeded,
      activityLevels: activityLevels ?? this.activityLevels,
    );
  }

  @override
  List<Object?> get props => [profile, loading, errorMessage, updateSucceeded, activityLevels];
}
