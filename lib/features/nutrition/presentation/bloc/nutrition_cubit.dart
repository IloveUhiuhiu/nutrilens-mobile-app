import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/nutrition_advice.dart';
import '../../data/repositories/nutrition_repository.dart';
import 'nutrition_state.dart';

class NutritionCubit extends Cubit<NutritionState> {
  NutritionCubit(this._repository) : super(NutritionState.initial());

  final NutritionRepository _repository;

  Future<void> load({DateTime? date}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final nutrition = await _repository.fetchTodayNutrition(date: date);

      // Advice is best-effort: a failure (e.g. no rules configured, or the
      // request is forbidden) must not break the dashboard.
      NutritionAdvice? advice;
      try {
        advice = await _repository.fetchAdvice(date: date);
      } catch (error) {
        debugPrint('[NutritionCubit] fetchAdvice failed: $error');
        advice = null;
      }

      emit(
        state.copyWith(
          dailyNutrition: nutrition,
          advice: advice,
          clearAdvice: advice == null,
          loading: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Không thể tải dữ liệu dinh dưỡng.',
        ),
      );
    }
  }
}
