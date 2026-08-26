import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:crypto_mobile_app/features/dapps/dapp_url.dart';

/// Authority granted to one executing top-frame JavaScript realm.
///
/// The native response path must present this lease again. Delivery then checks
/// the realm marker and calls the page resolver in one JavaScript evaluation,
/// so navigation cannot move a secret or privileged response into a replacement
/// document between authorization and resolution.
final class PrivilegedBridgeLease {
  const PrivilegedBridgeLease._({
    required this.marker,
    required this.capability,
  });

  final String marker;
  final String capability;
}

/// Result of probing one privileged request's executing top-frame realm.
final class PrivilegedBridgeAuthorization {
  const PrivilegedBridgeAuthorization._({
    required this.lease,
    required this.authorized,
  });

  final PrivilegedBridgeLease lease;
  final bool authorized;
}

/// Carries one privileged request's realm lease through async handlers.
///
/// JavaScript-channel callbacks may overlap. A Zone is async-context-local, so
/// an earlier request that completes after a later request still resolves into
/// its own realm. Passing a null lease deliberately shadows any parent context
/// and keeps unprivileged requests on the ordinary response path.
final class PrivilegedBridgeRequestContext {
  PrivilegedBridgeRequestContext._();

  static final Object _leaseKey = Object();

  static PrivilegedBridgeLease? get currentLease =>
      Zone.current[_leaseKey] as PrivilegedBridgeLease?;

  static Future<T> run<T>({
    required PrivilegedBridgeLease? lease,
    required Future<T> Function() body,
  }) =>
      runZoned(body, zoneValues: <Object?, Object?>{_leaseKey: lease});
}

/// Owns the privileged WebView bridge boundary for one WebView instance.
///
/// Android exposes JavaScript channels to child frames without reporting the
/// sender's origin. A trusted top frame therefore bootstraps an opaque token
/// and includes it in privileged request envelopes. Cross-origin children
/// cannot read the token because native promise resolution executes in the top
/// frame and is bound to the requesting top-frame realm.
///
/// WebView navigation callbacks do not define a portable document lifecycle:
/// Android reports `onPageFinished` for some History API changes and cancelled
/// loads, while neither platform exposes a navigation identity through
/// `webview_flutter`. Security therefore does not depend on those callbacks.
/// Each call probes the executing top-frame realm. Native installs a random,
/// non-configurable marker in that realm and derives its token from the marker
/// and a WebView-only HMAC key. History API changes preserve the token, full
/// document replacements rotate it, and BFCache restoration revives only the
/// original realm's deterministic token.
class PrivilegedBridgePolicy {
  PrivilegedBridgePolicy({
    required Uri? trustedOrigin,
    required bool allowLocalDevelopment,
    required Future<Object?> Function(String script) evaluateTopFrame,
    String Function()? secretFactory,
    this.probeTimeout = const Duration(seconds: 2),
  })  : _trustedOrigin = _originOf(trustedOrigin),
        _allowLocalDevelopment = allowLocalDevelopment,
        _evaluateTopFrame = evaluateTopFrame,
        _secretFactory = secretFactory ?? _randomSecret {
    _markerProperty = '__usernode_${_newSecret()}';
    _capabilityKey = _newSecret();
  }

  static const privilegedMethods = <String>{
    'addHomeScreenShortcut',
    'getHomeScreenShortcuts',
    'removeHomeScreenShortcut',
    'reorderHomeScreenShortcuts',
    'openNativeScreen',
    'captureScreenshot',
    'getSettingsState',
    'manageStaking',
    'setNodeSleepEnabled',
    'setDebugMode',
    'setFacematchStrict',
    'resetZkChallenge',
    'requestPermissions',
    'openBatterySettings',
    'requestNotificationPermission',
    'requestAlarmPermissions',
    'openNotificationSettings',
    'beginSessionHandoff',
    'enterAnonymousSession',
    'completeLogin',
    'startNode',
    'stopNode',
    'getAuthStatus',
    'markPrivilegedBridgeReady',
    'logout',
    'getSocialPushState',
    'setSocialPushEnabled',
    'claimPendingSocialNotification',
    'ackPendingSocialNotification',
  };

  final Uri? _trustedOrigin;
  final bool _allowLocalDevelopment;
  final Future<Object?> Function(String script) _evaluateTopFrame;
  final String Function() _secretFactory;
  final Duration probeTimeout;

  late String _markerProperty;
  late String _capabilityKey;
  bool _disposed = false;

  bool requiresCapability(String method) => privilegedMethods.contains(method);

  /// Returns authority for the executing trusted top-frame realm. Callers must
  /// use [resolve] with the returned lease to keep token delivery realm-bound.
  Future<PrivilegedBridgeLease?> bootstrapLease() async {
    final realm = await _probeTopFrameRealm();
    return realm == null ? null : _leaseFor(realm.marker);
  }

  /// Authorizes a privileged envelope in the executing trusted top frame.
  /// The token comparison is deterministic and has no mutable current-document
  /// state, so concurrent/out-of-order probes cannot roll authority backward.
  Future<PrivilegedBridgeAuthorization?> authorize(
    Object? presentedCapability,
  ) async {
    final realm = await _probeTopFrameRealm();
    if (realm == null) return null;
    return _authorizationFor(realm, presentedCapability);
  }

  /// Resolves a page request only if the original top-frame realm still owns
  /// the exact marker. The marker check and resolver invocation are atomic
  /// within one strict JavaScript evaluation.
  Future<bool> resolve({
    required PrivilegedBridgeLease lease,
    required String id,
    required Object? value,
    required String? error,
  }) async {
    if (_disposed) return false;
    try {
      final result = await _evaluateTopFrame(
        _guardedResolveScript(lease, id, value, error),
      ).timeout(probeTimeout);
      return !_disposed && _decodeBoolean(result);
    } catch (_) {
      return false;
    }
  }

  /// Runs a native-to-page JavaScript body only in the executing trusted realm
  /// that was probed. The result reports whether that exact realm received it.
  Future<bool> runInTrustedTopFrame(String javaScriptBody) async {
    final realm = await _probeTopFrameRealm();
    if (realm == null || _disposed) return false;
    return _runInMarker(realm.marker, javaScriptBody);
  }

  /// Runs a native-to-page body only if [lease]'s exact realm is still the
  /// executing top frame. Unlike [runInTrustedTopFrame], this never admits a
  /// replacement trusted document, which is useful for readiness-bound events.
  Future<bool> runInLease(PrivilegedBridgeLease lease, String javaScriptBody) =>
      _runInMarker(lease.marker, javaScriptBody);

  Future<bool> _runInMarker(String marker, String javaScriptBody) async {
    if (_disposed) return false;
    try {
      final result = await _evaluateTopFrame(
        _guardedRunScript(marker, javaScriptBody),
      ).timeout(probeTimeout);
      return !_disposed && _decodeBoolean(result);
    } catch (_) {
      return false;
    }
  }

  /// Re-probes the current realm and requires it to match an earlier lease.
  /// Use this close to irreversible native effects to narrow the interval in
  /// which authority can move away from the originating document. WebView's
  /// generic bridge cannot make this probe atomic with an arbitrary native
  /// side effect, so the realm-bound response remains the final safety check.
  Future<bool> revalidates(PrivilegedBridgeLease lease) async {
    final realm = await _probeTopFrameRealm();
    return realm != null && realm.marker == lease.marker;
  }

  /// Detects whether [lease]'s exact trusted realm implements the explicit
  /// listener-readiness handshake.
  ///
  /// This keeps independently deployed/cached older Social shells compatible:
  /// they can be promoted on their first authorized call without treating a
  /// WebView lifecycle callback as proof. A null result means the realm moved
  /// or the evaluation was inconclusive and must never be promoted.
  Future<bool?> supportsExplicitReadiness(PrivilegedBridgeLease lease) async {
    if (_disposed) return null;
    try {
      final result = await _evaluateTopFrame(
        _guardedReadinessSupportScript(lease.marker),
      ).timeout(probeTimeout);
      if (_disposed) return null;
      return _decodeNullableBoolean(result);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    _markerProperty = '';
    _capabilityKey = '';
  }

  Future<_TopFrameRealm?> _probeTopFrameRealm() async {
    if (_disposed) return null;
    final markerCandidate = _newSecret();
    try {
      final result = await _evaluateTopFrame(
        _realmProbeScript(markerCandidate),
      ).timeout(probeTimeout);
      if (_disposed) return null;
      final realm = _decodeRealm(result);
      if (realm == null || !_allows(realm.uri)) {
        return null;
      }
      return realm;
    } catch (_) {
      return null;
    }
  }

  PrivilegedBridgeLease _leaseFor(String marker) {
    final hmac = Hmac(sha256, utf8.encode(_capabilityKey));
    final capability = base64UrlEncode(
      hmac.convert(utf8.encode('privileged:$marker')).bytes,
    ).replaceAll('=', '');
    return PrivilegedBridgeLease._(marker: marker, capability: capability);
  }

  PrivilegedBridgeAuthorization _authorizationFor(
    _TopFrameRealm realm,
    Object? presentedCapability,
  ) {
    final lease = _leaseFor(realm.marker);
    return PrivilegedBridgeAuthorization._(
      lease: lease,
      authorized: presentedCapability is String &&
          presentedCapability.isNotEmpty &&
          presentedCapability == lease.capability,
    );
  }

  String _realmProbeScript(String markerCandidate) => '''
    (function () {
      'use strict';
      const markerKey = ${jsonEncode(_markerProperty)};
      if (!Object.prototype.hasOwnProperty.call(window, markerKey)) {
        Object.defineProperty(window, markerKey, {
          value: ${jsonEncode(markerCandidate)},
          writable: false,
          configurable: false,
          enumerable: false
        });
      }
      const marker = window[markerKey];
      const href = window.location.href;
      // Keep the result scalar. WKWebView's Flutter adapter converts arrays
      // to Foundation's human-readable description, which is not JSON. A
      // length prefix keeps both fields in one atomic realm evaluation without
      // relying on the page-controlled JSON serializer.
      return marker.length + ':' + marker + href;
    })()
  ''';

  String _guardedResolveScript(
    PrivilegedBridgeLease lease,
    String id,
    Object? value,
    String? error,
  ) =>
      '''
    (function () {
      'use strict';
      const markerKey = ${jsonEncode(_markerProperty)};
      if (window[markerKey] !== ${jsonEncode(lease.marker)}) return false;
      const resolver = window.__usernodeResolve;
      if (typeof resolver !== 'function') return false;
      resolver(${jsonEncode(id)}, ${jsonEncode(value)}, ${jsonEncode(error)});
      return true;
    })()
  ''';

  String _guardedRunScript(String marker, String javaScriptBody) => '''
    (function () {
      'use strict';
      const markerKey = ${jsonEncode(_markerProperty)};
      if (window[markerKey] !== ${jsonEncode(marker)}) return false;
      $javaScriptBody
      return true;
    })()
  ''';

  String _guardedReadinessSupportScript(String marker) => '''
    (function () {
      'use strict';
      const markerKey = ${jsonEncode(_markerProperty)};
      if (window[markerKey] !== ${jsonEncode(marker)}) return null;
      return window.__usernodeExplicitReadinessClient === true;
    })()
  ''';

  static _TopFrameRealm? _decodeRealm(Object? value) {
    if (value is! String || value.isEmpty) return null;
    var encoded = value;

    // Android WebView returns a JavaScript string as a JSON string literal;
    // WKWebView returns the scalar itself. Accept those two platform shapes
    // while rejecting structured or human-readable platform descriptions.
    if (encoded.startsWith('"')) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is! String) return null;
        encoded = decoded;
      } catch (_) {
        return null;
      }
    }

    final separator = encoded.indexOf(':');
    if (separator <= 0) return null;
    final markerLengthText = encoded.substring(0, separator);
    if (!RegExp(r'^\d+$').hasMatch(markerLengthText)) return null;
    final markerLength = int.tryParse(markerLengthText);
    final markerStart = separator + 1;
    final remainingLength = encoded.length - markerStart;
    if (markerLength == null ||
        markerLength <= 0 ||
        markerLength >= remainingLength) {
      return null;
    }
    final hrefStart = markerStart + markerLength;
    final marker = encoded.substring(markerStart, hrefStart);
    final href = encoded.substring(hrefStart);
    final uri = Uri.tryParse(href);
    if (uri == null) return null;
    return _TopFrameRealm(uri, marker);
  }

  static bool _decodeBoolean(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      try {
        return jsonDecode(value) == true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static bool? _decodeNullableBoolean(Object? value) {
    if (value == null || value is bool) return value as bool?;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return decoded == null || decoded is bool ? decoded as bool? : null;
      } catch (_) {
        return null;
      }
    }
    return null;
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
        isSameWebOrigin(uri, trusted);
  }

  String _newSecret() {
    final value = _secretFactory();
    if (value.isEmpty) {
      throw StateError('Secret factory returned an empty value');
    }
    return value;
  }

  static Uri? _originOf(Uri? uri) {
    if (uri == null || uri.host.isEmpty || !_isWebUri(uri)) return null;
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
  }

  static bool _isWebUri(Uri uri) =>
      uri.host.isNotEmpty && (uri.scheme == 'https' || uri.scheme == 'http');

  static bool _isLocalDevelopmentHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '10.0.2.2';
  }

  static String _randomSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

final class _TopFrameRealm {
  const _TopFrameRealm(this.uri, this.marker);

  final Uri uri;
  final String marker;
}
