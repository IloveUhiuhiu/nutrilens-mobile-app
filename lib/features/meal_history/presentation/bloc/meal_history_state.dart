import 'package:equatable/equatable.dart';

import '../../data/models/meal_entry.dart';

class MealHistoryState extends Equatable {
  const MealHistoryState({
    required this.entries,
    this.loading = false,
    this.errorMessage,
  });

  factory MealHistoryState.initial() {
    return const MealHistoryState(entries: []);
  }

  final List<MealEntry> entries;
  final bool loading;
  final String? errorMessage;

  MealHistoryState copyWith({
    List<MealEntry>? entries,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MealHistoryState(
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [entries, loading, errorMessage];
}
