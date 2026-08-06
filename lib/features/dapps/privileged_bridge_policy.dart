import 'dart:convert';
import 'dart:math';

/// Owns the privileged WebView bridge boundary for one WebView instance.
///
/// Android exposes JavaScript channels to child frames without reporting the
/// sending frame's origin. A trusted main frame therefore bootstraps a random
/// capability after each navigation and includes it in privileged envelopes.
/// Cross-origin children cannot read the top frame's bootstrap response, and
/// a full main-frame navigation immediately revokes the previous capability.
class PrivilegedBridgePolicy {
  PrivilegedBridgePolicy({
    required Uri? trustedOrigin,
    required bool allowLocalDevelopment,
    String Function()? capabilityFactory,
  })  : _trustedOrigin = _originOf(trustedOrigin),
        _allowLocalDevelopment = allowLocalDevelopment,
        _capabilityFactory = capabilityFactory ?? _randomCapability;

  static const privilegedMethods = <String>{
    'addHomeScreenShortcut',
    'getHomeScreenShortcuts',
    'removeHomeScreenShortcut',
    'reorderHomeScreenShortcuts',
    'openNativeScreen',
    'getProfileInfo',
    'getSettingsState',
    'setNodeSleepEnabled',
    'setDebugMode',
    'setFacematchStrict',
    'resetZkChallenge',
    'requestPermissions',
    'openBatterySettings',
    'beginSessionHandoff',
    'enterAnonymousSession',
    'completeLogin',
    'startNode',
    'stopNode',
    'getAuthStatus',
    'logout',
    'getSocialPushState',
    'setSocialPushEnabled',
    'claimPendingSocialNotification',
    'ackPendingSocialNotification',
  };

  final Uri? _trustedOrigin;
  final bool _allowLocalDevelopment;
  final String Function() _capabilityFactory;

  Uri? _activeMainFrame;
  String? _capability;

  bool requiresCapability(String method) => privilegedMethods.contains(method);

  bool get hasActiveCapability => _capability != null;

  /// Revokes the current page before a requested main-frame navigation can
  /// begin. The next document must bootstrap a fresh capability.
  void beginMainFrameNavigation() => revoke();

  /// Activates the document that has actually started loading, but only when
  /// its origin is in the release-safe allowlist.
  void activateMainFrame(Uri? uri) {
    revoke();
    if (uri == null || !_allows(uri)) return;
    _activeMainFrame = uri;
    _capability = _capabilityFactory();
  }

  /// Observes redirects and SPA URL changes. Same-origin path/hash changes
  /// preserve the page's capability; leaving the allowlist revokes it.
  void observeMainFrameUrl(Uri? uri) {
    final active = _activeMainFrame;
    if (active == null || uri == null || !_allows(uri)) {
      revoke();
      return;
    }
    if (!_sameOrigin(active, uri)) {
      revoke();
      return;
    }
    _activeMainFrame = uri;
  }

  /// Returned only through the top-frame promise resolver. A child-frame
  /// bootstrap request receives its response in the top frame and therefore
  /// cannot observe this value.
  String? bootstrapCapability() => _capability;

  bool authorizes(Object? presentedCapability) =>
      presentedCapability is String &&
      presentedCapability.isNotEmpty &&
      presentedCapability == _capability;

  void revoke() {
    _activeMainFrame = null;
    _capability = null;
  }

  bool _allows(Uri uri) {
    if (!_isWebUri(uri)) return false;
    if (_isLocalDevelopmentHost(uri.host)) {
      return _allowLocalDevelopment;
    }
    final trusted = _trustedOrigin;
    return uri.scheme == 'https' &&
        trusted != null &&
        trusted.scheme == 'https' &&
        _sameOrigin(uri, trusted);
  }

  static Uri? _originOf(Uri? uri) {
    if (uri == null || uri.host.isEmpty || !_isWebUri(uri)) return null;
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
  }

  static bool _isWebUri(Uri uri) =>
      uri.host.isNotEmpty && (uri.scheme == 'https' || uri.scheme == 'http');

  static bool _sameOrigin(Uri a, Uri b) =>
      a.scheme == b.scheme && a.host == b.host && a.port == b.port;

  static bool _isLocalDevelopmentHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '10.0.2.2';
  }

  static String _randomCapability() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
