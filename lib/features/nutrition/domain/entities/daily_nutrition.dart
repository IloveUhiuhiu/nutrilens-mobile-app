class DailyNutrition {
  const DailyNutrition({
    required this.calories,
    required this.calorieGoal,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.weightGrams,
  });

  final double calories;
  final double calorieGoal;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double weightGrams;

  double get progress => calorieGoal == 0 ? 0 : calories / calorieGoal;
}
