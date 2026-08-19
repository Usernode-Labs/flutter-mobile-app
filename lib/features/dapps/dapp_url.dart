import 'package:flutter/foundation.dart';

/// Parses a raw URL string into a [Uri], prepending `http://` if no scheme
/// is present, and remapping localhost to `10.0.2.2` on Android emulator.
Uri parseDappUrl(String raw) {
  final withScheme = raw.contains('://') ? raw : 'http://$raw';
  final uri = Uri.tryParse(withScheme) ?? Uri.parse('http://localhost:8000');

  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
    return uri.replace(host: '10.0.2.2');
  }

  return uri;
}

/// Whether two web URLs belong to the same origin.
///
/// [Uri.port] normalizes default ports, so `https://example.com` and
/// `https://example.com:443` compare equal while different explicit ports do
/// not. Callers remain responsible for any policy around allowed schemes.
bool isSameWebOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

/// Whether navigating from [current] to [next] only changes the fragment.
bool isSameWebDocument(Uri current, Uri next) =>
    isSameWebOrigin(current, next) &&
    (current.path.isEmpty ? '/' : current.path) ==
        (next.path.isEmpty ? '/' : next.path) &&
    current.query == next.query;
