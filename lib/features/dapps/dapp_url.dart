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
