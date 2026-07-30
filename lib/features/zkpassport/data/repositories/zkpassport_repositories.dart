import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ZkPassportRegistrationRepository {
  static const _kRegisteredKeyBase = 'zkpassport:registered';
  static const _kRegistrationKeyBase = 'zkpassport:registration';
  static const _kPendingCompletionKey = 'zkpassport:pending_completion';

  Future<bool> isRegistered() async {
    final registration = await getActiveRegistration();
    return registration.registered;
  }

  Future<ZkPassportLocalRegistration> getActiveRegistration() async {
    final accounts = await AccountsRepository.create();
    final active = await accounts.getActive();
    if (active == null) {
      return ZkPassportLocalRegistration.unregistered();
    }

    return _loadRegistrationForAccount(active.id);
  }

  Future<void> storeActiveRegistration({
    required bool registered,
    required String? nullifierHex,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
  }) async {
    final accounts = await AccountsRepository.create();
    final active = await accounts.getActive();
    if (active == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _registrationKeyForAccount(active.id);
    final payload = ZkPassportLocalRegistration(
      registered: registered,
      nullifierHex: nullifierHex,
      registeredAtMs: registered ? DateTime.now().millisecondsSinceEpoch : null,
      facematchVerified: facematchVerified,
      verifyOuterMs: verifyOuterMs,
      wrapOuterMs: wrapOuterMs,
      verifyWrappedMs: verifyWrappedMs,
    );
    await prefs.setString(key, jsonEncode(payload.toJson()));
  }

  /// Stores a pending backend completion (the identity-keyed outbox row) for
  /// retry on the next settled-identity opportunity (cold start, sign-in,
  /// reconcile completion). See [getPendingCompletion] for [bucket] semantics.
  Future<void> storePendingCompletion({
    required int participantId,
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
    String? bucket,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _pendingCompletionKey(bucket);
    await prefs.setString(
        key,
        jsonEncode({
          'participant_id': participantId,
          'challenge_id': challengeId,
          'wallet_address': walletAddress,
          'session_id': sessionId,
          'nullifier_hex': nullifierHex,
        }));
  }

  /// Returns a pending completion if one exists, or null.
  ///
  /// [bucket] pins the read to an explicit storage bucket. Retry flows
  /// capture the active bucket once at the start and pass it to every
  /// subsequent read/clear, so a mid-flight bucket switch (account
  /// reconcile) can't make the clear target a different identity's record.
  Future<Map<String, dynamic>?> getPendingCompletion({String? bucket}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _pendingCompletionKey(bucket);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Corrupt data — clear it.
      await prefs.remove(key);
    }
    return null;
  }

  /// Clears a stored pending completion after successful retry.
  /// See [getPendingCompletion] for [bucket] semantics.
  Future<void> clearPendingCompletion({String? bucket}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCompletionKey(bucket));
  }

  String _pendingCompletionKey(String? bucket) => bucket == null
      ? NetworkPrefs.prefixAccountKey(_kPendingCompletionKey)
      : NetworkPrefs.prefixAccountKeyFor(_kPendingCompletionKey, bucket);

  Future<void> clearActiveRegistration() async {
    final accounts = await AccountsRepository.create();
    final active = await accounts.getActive();
    if (active == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_registrationKeyForAccount(active.id));
  }

  String _registrationKeyForAccount(String accountId) {
    return NetworkPrefs.prefixAccountKey('$_kRegistrationKeyBase:$accountId');
  }

  Future<ZkPassportLocalRegistration> _loadRegistrationForAccount(
    String accountId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _registrationKeyForAccount(accountId);
    final raw = prefs.getString(key);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        final parsed = ZkPassportLocalRegistration.fromJson(decoded);
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // Fall through to migration/unregistered.
      }
    }

    // Migration: older versions stored a single boolean for the whole network.
    final legacyKey = NetworkPrefs.prefixAccountKey(_kRegisteredKeyBase);
    final legacyRegistered = prefs.getBool(legacyKey) ?? false;
    if (!legacyRegistered) {
      return ZkPassportLocalRegistration.unregistered();
    }

    final migrated = ZkPassportLocalRegistration(
      registered: true,
      nullifierHex: null,
      registeredAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(key, jsonEncode(migrated.toJson()));
    return migrated;
  }
}

class ZkPassportSettingsRepository {
  static const _kSettingsKeyBase = 'zkpassport:settings_v1';

  Future<ZkPassportSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = NetworkPrefs.prefixAccountKey(_kSettingsKeyBase);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return ZkPassportSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      return ZkPassportSettings.fromJson(decoded) ??
          ZkPassportSettings.defaults;
    } catch (_) {
      await prefs.remove(key);
      return ZkPassportSettings.defaults;
    }
  }

  Future<void> save(ZkPassportSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final key = NetworkPrefs.prefixAccountKey(_kSettingsKeyBase);
    await prefs.setString(key, jsonEncode(settings.toJson()));
  }

  Future<void> setFacematchStrict(bool value) async {
    final current = await load();
    await save(current.copyWith(facematchStrict: value));
  }
}

class ZkPassportRuntimeSessionRepository {
  static const _kRuntimeSessionKeyBase = 'zkpassport:runtime_session_v1';

  Future<ZkPassportRuntimeSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = NetworkPrefs.prefixAccountKey(_kRuntimeSessionKeyBase);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(key);
        return null;
      }
      final session = ZkPassportRuntimeSession.fromJson(decoded);
      if (session == null) {
        await prefs.remove(key);
        return null;
      }
      return session;
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> save(ZkPassportRuntimeSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final key = NetworkPrefs.prefixAccountKey(_kRuntimeSessionKeyBase);
    await prefs.setString(key, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final key = NetworkPrefs.prefixAccountKey(_kRuntimeSessionKeyBase);
    await prefs.remove(key);
  }
}

final _sessionServerLog =
    LoggingService.instance.withTag('usernode/ZkPassportSessionServer');

const _userPublicKeyHeader = 'X-Usernode-Public-Key';

class ZkPassportSessionServerException implements Exception {
  ZkPassportSessionServerException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final Object? body;

  @override
  String toString() =>
      'ZkPassportSessionServerException($statusCode, $message)';
}

class ZkPassportSessionServerRepository {
  ZkPassportSessionServerRepository({
    required String baseUrl,
    http.Client? httpClient,
    bool? writesEnabled,
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _http = httpClient ?? createAppHttpClient(),
        _writesEnabled = writesEnabled ?? !AppConfig.viewOnly;

  final String _baseUrl;
  final http.Client _http;
  final bool _writesEnabled;

  Future<ZkPassportSessionStartResponse> startSession({
    required String walletAddress,
    required String chainId,
    required int nonce,
    required bool facematchStrict,
    String? userPublicKey,
  }) async {
    if (!_writesEnabled) {
      throw ZkPassportSessionServerException(
        503,
        'Backend write requests are disabled in view-only mode.',
      );
    }

    final json = await _postJson(
      '/v1/zkp/sessions/start',
      body: {
        'wallet_address': walletAddress,
        'chain_id': chainId,
        'nonce': nonce,
        'facematch_strict': facematchStrict,
      },
      userPublicKey: userPublicKey,
      timeout: const Duration(seconds: 10),
    );
    return ZkPassportSessionStartResponse.fromJson(json);
  }

  Future<ZkPassportSessionStatusResponse> getSessionStatus({
    required String sessionId,
    String? userPublicKey,
  }) async {
    final json = await _getJson(
      '/v1/zkp/sessions/${sessionId.trim()}',
      userPublicKey: userPublicKey,
      timeout: const Duration(seconds: 5),
    );
    return ZkPassportSessionStatusResponse.fromJson(json);
  }

  Future<ZkPassportSessionResultResponse?> tryGetSessionResult({
    required String sessionId,
    int waitMs = 0,
    String? userPublicKey,
  }) async {
    final normalizedWaitMs = waitMs > 0 ? waitMs : 0;
    final url =
        Uri.parse('$_baseUrl/v1/zkp/sessions/${sessionId.trim()}/result')
            .replace(
      queryParameters: normalizedWaitMs > 0
          ? <String, String>{'wait_ms': normalizedWaitMs.toString()}
          : null,
    );
    _sessionServerLog.trace('GET $url');

    late final http.Response response;
    try {
      final timeout = normalizedWaitMs > 0
          ? Duration(milliseconds: normalizedWaitMs + 2000)
          : const Duration(seconds: 5);
      response = await _http
          .get(
            url,
            headers: _headers(
              acceptJson: true,
              userPublicKey: userPublicKey,
            ),
          )
          .timeout(timeout);
    } catch (e) {
      _sessionServerLog.warn('Session server request failed for $url: $e');
      rethrow;
    }

    // result_not_ready
    if (response.statusCode == 409) {
      return null;
    }

    final json = _decodeResponseJson(response);
    return ZkPassportSessionResultResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    String? userPublicKey,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    _sessionServerLog.trace('GET $url');

    late final http.Response response;
    try {
      response = await _http
          .get(
            url,
            headers: _headers(
              acceptJson: true,
              userPublicKey: userPublicKey,
            ),
          )
          .timeout(timeout);
    } catch (e) {
      _sessionServerLog.warn('Session server request failed for $url: $e');
      rethrow;
    }
    return _decodeResponseJson(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    Map<String, dynamic>? body,
    String? userPublicKey,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    _sessionServerLog.trace('POST $url');

    late final http.Response response;
    try {
      response = await _http
          .post(
            url,
            headers: _headers(
              acceptJson: true,
              contentJson: true,
              userPublicKey: userPublicKey,
            ),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout);
    } catch (e) {
      _sessionServerLog.warn('Session server request failed for $url: $e');
      rethrow;
    }
    return _decodeResponseJson(response);
  }

  Map<String, dynamic> _decodeResponseJson(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['error'] as String? ??
              decoded['message'] as String? ??
              'Request failed')
          : 'Request failed';
      throw ZkPassportSessionServerException(
        response.statusCode,
        message,
        body: decoded ?? response.body,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ZkPassportSessionServerException(
        response.statusCode,
        'Unexpected response shape',
        body: response.body,
      );
    }
    return decoded;
  }

  void dispose() {
    _http.close();
  }
}

Map<String, String> _headers({
  bool acceptJson = false,
  bool contentJson = false,
  String? userPublicKey,
}) {
  final headers = <String, String>{};
  if (contentJson) {
    headers['Content-Type'] = 'application/json';
  }
  if (acceptJson) {
    headers['Accept'] = 'application/json';
  }
  final normalizedUserPublicKey = _normalizeHeaderValue(userPublicKey);
  if (normalizedUserPublicKey != null) {
    headers[_userPublicKeyHeader] = normalizedUserPublicKey;
  }
  return headers;
}

String? _normalizeHeaderValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final sanitized = trimmed
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (sanitized.isEmpty) {
    return null;
  }
  return sanitized.length > 256 ? sanitized.substring(0, 256) : sanitized;
}

String _normalizeBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw StateError('Session server base URL must not be empty.');
  }
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || parsed.scheme.isEmpty || parsed.host.isEmpty) {
    throw StateError('Invalid session server base URL: "$raw".');
  }
  final normalized = parsed.toString();
  if (normalized.endsWith('/')) {
    return normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}
