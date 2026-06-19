import 'package:intl/intl.dart';

/// Regional date-time helpers for Asia/Ho_Chi_Minh (UTC+7) display.
class DateTimeUtils {
  const DateTimeUtils._();

  /// Parses an ISO-8601 timestamp and converts it to the device local zone.
  static DateTime? parseToLocal(Object? raw) {
    if (raw == null) return null;
    final text = '$raw'.trim();
    if (text.isEmpty || text == 'null') return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return parsed.toLocal();
  }

  /// Formats [date] as HH:mm in the device local timezone.
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date.toLocal());
  }

  /// Formats [date] as YYYY-MM-DD in local timezone.
  static String formatDateKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static DateTime normalizeDate(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
