/// Enforces absolute, fully-qualified image URLs from the backend.
///
/// Relative paths and local prefix concatenation are intentionally rejected so
/// the client never mutates server-provided image addresses.
class ImageUrlUtils {
  const ImageUrlUtils._();

  /// Returns [raw] only when it is a valid `http` or `https` absolute URL.
  static String? resolveAbsolute(Object? raw) {
    if (raw == null) return null;
    final text = '$raw'.trim();
    if (text.isEmpty || text == 'null') return null;

    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (!uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;

    return uri.toString();
  }

  static bool isAbsoluteNetworkUrl(Object? raw) => resolveAbsolute(raw) != null;

  /// Local device file paths (camera capture) — not server-relative paths.
  static bool isLocalFilePath(String? path) {
    if (path == null) return false;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;
    if (isAbsoluteNetworkUrl(trimmed)) return false;
    final uri = Uri.tryParse(trimmed);
    return uri?.scheme == 'file' || trimmed.startsWith('/');
  }
}
