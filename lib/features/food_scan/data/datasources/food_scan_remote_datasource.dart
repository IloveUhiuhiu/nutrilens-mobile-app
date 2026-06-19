import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/food_image_metadata.dart';
import '../models/food_analysis_model.dart';
import '../models/inference_job_status.dart';

abstract class FoodScanRemoteDataSource {
  Future<String> createInferenceJob(
    String imagePath,
    FoodImageMetadata metadata, {
    CancelToken? cancelToken,
  });
  Future<InferenceJobStatus> getJobStatus(
    String jobId, {
    CancelToken? cancelToken,
  });
  Future<FoodAnalysisModel> getJobResult(
    String jobId, {
    CancelToken? cancelToken,
  });
  Future<void> saveAnalysis(
    String analysisId, {
    Map<String, double>? nutritionOverrides,
  });

  Future<void> submitFeedback(
    String jobId, {
    required List<String> issueTypes,
    List<String> actualComponents,
    String notes,
  });
}

class FoodScanRemoteDataSourceImpl implements FoodScanRemoteDataSource {
  FoodScanRemoteDataSourceImpl(this._client);

  final DioClient _client;

  @override
  Future<String> createInferenceJob(
    String imagePath,
    FoodImageMetadata metadata, {
    CancelToken? cancelToken,
  }) async {
    final metadataFields = Map<String, dynamic>.from(metadata.toJson())
      ..remove('image');
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imagePath,
        filename: metadata.fileName,
      ),
      ...metadataFields,
      'camera_metadata': jsonEncode(metadata.toJson()),
    });

    final createResponse = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.inferenceCreate,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      cancelToken: cancelToken,
    );

    final jobId = _jobIdFromCreateResponse(createResponse.data);
    if (jobId.isEmpty) {
      throw const ApiException(
        message: 'Inference job id is missing from backend response.',
        statusCode: 500,
      );
    }
    return jobId;
  }

  @override
  Future<InferenceJobStatus> getJobStatus(
    String jobId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.inferenceJobDetail(jobId),
      cancelToken: cancelToken,
    );
    return InferenceJobStatus.fromJson(response.data ?? const {});
  }

  @override
  Future<FoodAnalysisModel> getJobResult(
    String jobId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.inferenceJobResult(jobId),
      cancelToken: cancelToken,
    );
    return FoodAnalysisModel.fromJson(response.data ?? const {});
  }

  String _jobIdFromCreateResponse(Map<String, dynamic>? responseData) {
    if (responseData == null) return '';

    final data = responseData['data'];
    if (data is Map) {
      final id = data['id'] ?? data['job_id'] ?? data['job'] ?? data['_id'];
      if (id != null && '$id'.isNotEmpty) return '$id';
    }

    final id = responseData['id'] ??
        responseData['job_id'] ??
        responseData['job'] ??
        responseData['_id'];
    return id == null ? '' : '$id';
  }

  @override
  Future<void> saveAnalysis(
    String analysisId, {
    Map<String, double>? nutritionOverrides,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.mealFromInference,
      data: {
        'job_id': analysisId,
        if (nutritionOverrides != null) ...nutritionOverrides,
      },
    );
  }

  @override
  Future<void> submitFeedback(
    String jobId, {
    required List<String> issueTypes,
    List<String> actualComponents = const [],
    String notes = '',
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.inferenceFeedback(jobId),
      data: {
        'issue_types': issueTypes,
        if (actualComponents.isNotEmpty) 'actual_components': actualComponents,
        if (notes.isNotEmpty) 'notes': notes,
      },
    );
  }
}
