class InferenceJobStatus {
  const InferenceJobStatus({
    required this.id,
    required this.status,
    this.message,
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
      message: map['message']?.toString() ?? map['detail']?.toString(),
    );
  }

  final String id;
  final String status;
  final String? message;

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

  static String _normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return 'pending';
    return value;
  }
}
