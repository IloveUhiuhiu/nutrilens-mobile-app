import '../../data/models/inference_job_status.dart';
import '../entities/food_analysis.dart';
import '../entities/food_image_metadata.dart';

abstract class FoodScanRepository {
  Future<String> createInferenceJob(
    String imagePath,
    FoodImageMetadata metadata,
  );
  Future<InferenceJobStatus> getJobStatus(String jobId);
  Future<FoodAnalysis> getJobResult(String jobId);
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

  /// Cancels any in-flight inference job requests.
  void cancelCurrentJob();
}
