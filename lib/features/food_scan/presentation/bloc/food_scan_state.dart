import 'package:equatable/equatable.dart';

import '../../domain/entities/food_analysis.dart';

abstract class FoodScanState extends Equatable {
  const FoodScanState();

  @override
  List<Object?> get props => [];
}

class FoodScanIdle extends FoodScanState {
  const FoodScanIdle();
}

class FoodScanUploading extends FoodScanState {
  const FoodScanUploading(this.imagePath);

  final String imagePath;

  @override
  List<Object?> get props => [imagePath];
}

class FoodScanProcessing extends FoodScanState {
  const FoodScanProcessing({
    required this.imagePath,
    required this.jobId,
  });

  final String imagePath;
  final String jobId;

  @override
  List<Object?> get props => [imagePath, jobId];
}

class FoodScanPollingFailed extends FoodScanState {
  const FoodScanPollingFailed({
    required this.imagePath,
    required this.message,
    this.jobId,
    this.errorCode,
  });

  final String imagePath;
  final String? jobId;
  final String message;
  // Mã lỗi nghiệp vụ từ AI server (vd. no_food_detected) khi job thất bại do
  // status.isFailed — null cho các trường hợp timeout/stuck do mobile tự phát
  // hiện. Dùng để chọn icon/tiêu đề cụ thể trên UI thay vì luôn hiện chung.
  final String? errorCode;

  @override
  List<Object?> get props => [imagePath, jobId, message, errorCode];
}

class FoodScanResultReady extends FoodScanState {
  const FoodScanResultReady({
    required this.imagePath,
    required this.jobId,
    required this.analysis,
    this.saved = false,
  });

  final String imagePath;
  final String jobId;
  final FoodAnalysis analysis;
  final bool saved;

  @override
  List<Object?> get props => [imagePath, jobId, analysis, saved];
}

class FoodScanCancelled extends FoodScanState {
  const FoodScanCancelled();
}

class FoodScanError extends FoodScanState {
  const FoodScanError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
