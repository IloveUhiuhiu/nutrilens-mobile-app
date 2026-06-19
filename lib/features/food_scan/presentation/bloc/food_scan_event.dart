import 'package:equatable/equatable.dart';

import '../../domain/entities/food_image_metadata.dart';

abstract class FoodScanEvent extends Equatable {
  const FoodScanEvent();

  @override
  List<Object?> get props => [];
}

class FoodImagePicked extends FoodScanEvent {
  const FoodImagePicked({
    required this.imagePath,
    required this.metadata,
  });

  final String imagePath;
  final FoodImageMetadata metadata;

  @override
  List<Object?> get props => [imagePath, metadata];
}

class FoodScanRetryRequested extends FoodScanEvent {
  const FoodScanRetryRequested({
    required this.imagePath,
    this.jobId,
    this.metadata,
  });

  final String imagePath;
  final String? jobId;
  final FoodImageMetadata? metadata;

  @override
  List<Object?> get props => [imagePath, jobId, metadata];
}

class FoodScanCancelRequested extends FoodScanEvent {
  const FoodScanCancelRequested();
}

class FoodAnalysisSaveRequested extends FoodScanEvent {
  const FoodAnalysisSaveRequested();
}

class FoodAnalysisItemEdited extends FoodScanEvent {
  const FoodAnalysisItemEdited({
    required this.index,
    required this.label,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.weightGrams,
  });

  final int index;
  final String label;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double weightGrams;

  @override
  List<Object?> get props =>
      [index, label, calories, proteinGrams, carbsGrams, fatGrams, weightGrams];
}

class FeedbackSubmitRequested extends FoodScanEvent {
  const FeedbackSubmitRequested({
    required this.jobId,
    required this.issueTypes,
    this.actualComponents = const [],
    this.notes = '',
  });

  final String jobId;
  final List<String> issueTypes;
  final List<String> actualComponents;
  final String notes;

  @override
  List<Object?> get props => [jobId, issueTypes, actualComponents, notes];
}
