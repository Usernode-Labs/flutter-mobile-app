import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('usernode/DeepLink');

/// Listens for `usernode-zk://callback` deep links.
///
/// Currently future-ready infrastructure — ZKPassport does not send redirects
/// back to our app, but when/if the bridge adds support, this service will
/// trigger ZK session recovery automatically.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  bool _initialized = false;
  StreamSubscription<Uri>? _sub;
  VoidCallback? _onZkCallback;

  void initialize({required VoidCallback onZkCallback}) {
    if (_initialized) return;
    _initialized = true;
    _onZkCallback = onZkCallback;

    final appLinks = AppLinks();

    // Check cold-start initial link
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    }).catchError((Object e) {
      _log.warn('Failed to get initial deep link: $e');
    });

    // Listen for warm-start links
    _sub = appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object e) {
        _log.warn('Deep link stream error: $e');
      },
    );
  }

  void _handleUri(Uri uri) {
    _log.info('Deep link received: $uri');
    if (uri.scheme == 'usernode-zk') {
      _log.info('ZK callback deep link matched, triggering recovery');
      _onZkCallback?.call();
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _onZkCallback = null;
    _initialized = false;
  }
}
