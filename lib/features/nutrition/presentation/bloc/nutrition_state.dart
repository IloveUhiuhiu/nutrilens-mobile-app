import 'package:equatable/equatable.dart';

import '../../domain/entities/daily_nutrition.dart';
import '../../domain/entities/nutrition_advice.dart';

class NutritionState extends Equatable {
  const NutritionState({
    required this.dailyNutrition,
    this.advice,
    this.loading = false,
    this.errorMessage,
  });

  factory NutritionState.initial() {
    return const NutritionState(
      dailyNutrition: DailyNutrition(
        calories: 0,
        calorieGoal: 2000,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0,
        weightGrams: 0,
      ),
    );
  }

  final DailyNutrition dailyNutrition;
  final NutritionAdvice? advice;
  final bool loading;
  final String? errorMessage;

  NutritionState copyWith({
    DailyNutrition? dailyNutrition,
    NutritionAdvice? advice,
    bool clearAdvice = false,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NutritionState(
      dailyNutrition: dailyNutrition ?? this.dailyNutrition,
      advice: clearAdvice ? null : advice ?? this.advice,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [dailyNutrition, advice, loading, errorMessage];
}
