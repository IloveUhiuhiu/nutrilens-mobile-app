import 'dart:math';

/// Generates a random 32-hex-char idempotency token (no extra dependency).
///
/// Used as a stable per-capture key sent in the `Idempotency-Key` header so the
/// backend dedupes retries of the same capture to a single inference job.
String generateIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
