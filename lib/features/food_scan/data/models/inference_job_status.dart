class InferenceJobStatus {
  const InferenceJobStatus({
    required this.id,
    required this.status,
    this.message,
    this.errorCode,
  });

  factory InferenceJobStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : Map<String, dynamic>.from(json);
    final rawStatus = map['status'] ??
        map['state'] ??
        map['job_status'] ??
        map['processing_status'] ??
        '';
    return InferenceJobStatus(
      id: '${map['id'] ?? map['job_id'] ?? map['job'] ?? ''}',
      status: _normalizeStatus('$rawStatus'),
      // job_detail (InferenceJobSerializer) trả field `error_message`, không
      // phải `message`/`detail` — giữ cả 2 fallback cũ để tương thích các
      // endpoint khác có thể trả `message`/`detail`.
      message: map['message']?.toString() ??
          map['detail']?.toString() ??
          map['error_message']?.toString(),
      errorCode: map['error_code']?.toString(),
    );
  }

  final String id;
  final String status;
  final String? message;
  // Mã lỗi nghiệp vụ cụ thể từ AI server, đi qua backend (vd. no_food_detected,
  // no_ingredients_identified, no_segments_produced, depth_estimation_failed...).
  // Dùng để hiển thị thông báo cụ thể cho người dùng thay vì chỉ "thử lại" chung.
  final String? errorCode;

  bool get isPending =>
      status == 'pending' ||
      status == 'queued' ||
      status == 'uploaded' ||
      status == 'created' ||
      status == 'waiting';

  bool get isProcessing =>
      status == 'processing' ||
      status == 'running' ||
      status == 'in_progress' ||
      status == 'analyzing' ||
      status == 'inferring';

  bool get isCompleted =>
      status == 'succeeded' ||  // ← backend Django dùng "succeeded"
      status == 'completed' ||
      status == 'success' ||
      status == 'done' ||
      status == 'complete' ||
      status == 'finished' ||
      status == 'ready' ||
      status == 'result_ready';

  bool get isFailed =>
      status == 'failed' ||
      status == 'error' ||
      status == 'timeout' ||
      status == 'cancelled' ||
      status == 'rejected';

  /// True khi status không khớp bất kỳ nhóm nào đã biết.
  /// Mobile sẽ thử probe kết quả thay vì chờ thêm.
  bool get isUnknown => !isPending && !isProcessing && !isCompleted && !isFailed;

  /// Thông báo cụ thể hiển thị cho người dùng khi job thất bại — ưu tiên map
  /// theo [errorCode] nghiệp vụ (no_food_detected, no_ingredients_identified,
  /// no_segments_produced, depth_estimation_failed...) trước khi rơi về
  /// [message] thô từ backend, rồi mới tới thông báo chung "thử lại".
  /// Tránh tình huống mọi lỗi AI đều hiện cùng 1 câu "Vui lòng thử lại".
  String get failureMessage =>
      aiErrorMessages[errorCode] ?? message ?? defaultFailureMessage;

  static String _normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return 'pending';
    return value;
  }
}

/// Thông báo mặc định khi không có errorCode hay message cụ thể nào từ server.
const defaultFailureMessage = 'Quá trình phân tích thất bại hoặc hết thời gian chờ.';

/// Map error_code nghiệp vụ (AI server -> backend -> mobile) sang thông báo
/// tiếng Việt cụ thể, đủ để người dùng biết nên làm gì tiếp theo thay vì chỉ
/// "Vui lòng thử lại" mơ hồ. Các code này khớp với error_code mà AI server
/// (nutrilens-ai-server) trả về, đã được backend chuẩn hóa qua InferenceJob.error_code.
const Map<String, String> aiErrorMessages = {
  'no_food_detected':
      'Không tìm thấy món ăn trong ảnh. Vui lòng chụp rõ phần thức ăn và thử lại.',
  'no_plate_detected':
      'Không tìm thấy đĩa/bát chứa thức ăn trong ảnh. Vui lòng đặt món ăn lên đĩa hoặc bát rõ ràng rồi chụp lại.',
  'no_ingredients_identified':
      'Không thể xác định được thành phần của món ăn. Vui lòng chụp lại ở góc rõ hơn, đủ sáng.',
  'no_segments_produced':
      'Không thể phân tách các thành phần trong ảnh. Vui lòng chụp lại gần hơn và đủ sáng.',
  'depth_estimation_failed':
      'Không thể ước tính khoảng cách của món ăn. Vui lòng giữ điện thoại ổn định, chụp thẳng từ trên xuống và thử lại.',
};
