import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/meal_history_repository.dart';
import 'meal_history_state.dart';

class MealHistoryCubit extends Cubit<MealHistoryState> {
  MealHistoryCubit(this._repository) : super(MealHistoryState.initial());

  final MealHistoryRepository _repository;

  Future<void> load({DateTime? date}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final entries = await _repository.fetchDailyMeals(date: date);
      emit(
        state.copyWith(entries: entries, loading: false, clearError: true),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Không thể tải lịch sử bữa ăn.',
        ),
      );
    }
  }
}
