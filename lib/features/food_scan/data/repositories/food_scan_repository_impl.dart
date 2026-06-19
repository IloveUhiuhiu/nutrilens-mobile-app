import 'package:dio/dio.dart';

import '../../domain/entities/food_analysis.dart';
import '../../domain/entities/food_image_metadata.dart';
import '../../domain/repositories/food_scan_repository.dart';
import '../datasources/food_scan_remote_datasource.dart';
import '../models/inference_job_status.dart';

class FoodScanRepositoryImpl implements FoodScanRepository {
  FoodScanRepositoryImpl(this._remoteDataSource);

  final FoodScanRemoteDataSource _remoteDataSource;
  CancelToken _cancelToken = CancelToken();

  @override
  void cancelCurrentJob() {
    _cancelToken.cancel('Cancelled by user');
  }

  @override
  Future<String> createInferenceJob(
    String imagePath,
    FoodImageMetadata metadata,
  ) {
    // Fresh token for each new job so retries are not pre-cancelled.
    _cancelToken = CancelToken();
    return _remoteDataSource.createInferenceJob(
      imagePath,
      metadata,
      cancelToken: _cancelToken,
    );
  }

  @override
  Future<InferenceJobStatus> getJobStatus(String jobId) {
    return _remoteDataSource.getJobStatus(
      jobId,
      cancelToken: _cancelToken,
    );
  }

  @override
  Future<FoodAnalysis> getJobResult(String jobId) async {
    final model = await _remoteDataSource.getJobResult(
      jobId,
      cancelToken: _cancelToken,
    );
    return model;
  }

  @override
  Future<void> saveAnalysis(
    String analysisId, {
    Map<String, double>? nutritionOverrides,
  }) {
    return _remoteDataSource.saveAnalysis(
      analysisId,
      nutritionOverrides: nutritionOverrides,
    );
  }

  @override
  Future<void> submitFeedback(
    String jobId, {
    required List<String> issueTypes,
    List<String> actualComponents = const [],
    String notes = '',
  }) {
    return _remoteDataSource.submitFeedback(
      jobId,
      issueTypes: issueTypes,
      actualComponents: actualComponents,
      notes: notes,
    );
  }
}
