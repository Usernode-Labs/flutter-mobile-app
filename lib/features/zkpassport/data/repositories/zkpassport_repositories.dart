import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef ZkPassportStringWriter = Future<bool> Function(
  SharedPreferences preferences,
  String key,
  String value,
);

Future<void> _checkedSetString(
  SharedPreferences preferences,
  String key,
  String value, {
  required String operation,
  ZkPassportStringWriter? writer,
}) async {
  final wrote = await (writer == null
      ? preferences.setString(key, value)
      : writer(preferences, key, value));
  if (!wrote) {
    throw StateError('Failed to $operation');
  }
}

class ZkPassportRegistrationRepository {
  ZkPassportRegistrationRepository({
    ZkPassportStringWriter? stringWriter,
  }) : _stringWriter = stringWriter;

  static const _kRegisteredKeyBase = 'zkpassport:registered';
  static const _kRegistrationKeyBase = 'zkpassport:registration';
  static const _kPendingCompletionKey = 'zkpassport:pending_completion';
  static const _kRequestOutcomeKeyBase = 'zkpassport:request_outcome_v1';

  final ZkPassportStringWriter? _stringWriter;

  /// Stores registration state under an explicitly captured account scope.
  /// Identity-sensitive flows use this instead of resolving the ambient
  /// active account after an `await`.
  Future<void> storeRegistrationForAccount({
    required String accountId,
    required String bucket,
    required bool registered,
    required String? nullifierHex,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    ZkPassportRequestVersion? requestVersion,
  }) async {
    if (accountId.isEmpty || bucket.isEmpty) {
      throw ArgumentError('accountId and bucket must not be empty');
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _registrationKeyForAccount(accountId, bucket: bucket);
    final payload = ZkPassportLocalRegistration(
      registered: registered,
      nullifierHex: nullifierHex,
      registeredAtMs: registered ? DateTime.now().millisecondsSinceEpoch : null,
      facematchVerified: facematchVerified,
      verifyOuterMs: verifyOuterMs,
      wrapOuterMs: wrapOuterMs,
      verifyWrappedMs: verifyWrappedMs,
      requestVersion: requestVersion,
    );
    await _checkedSetString(
      prefs,
      key,
      jsonEncode(payload.toJson()),
      operation: 'store zkPassport registration',
      writer: _stringWriter,
    );
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
    required ZkPassportRequestVersion requestVersion,
    required String accountId,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    String? bucket,
  }) async {
    if (sessionId != requestVersion.requestId) {
      throw ArgumentError.value(
        sessionId,
        'sessionId',
        'must match the request version',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final key = _pendingCompletionKey(bucket);
    await _checkedSetString(
      prefs,
      key,
      jsonEncode({
        'participant_id': participantId,
        'challenge_id': challengeId,
        'wallet_address': walletAddress,
        'session_id': sessionId,
        'nullifier_hex': nullifierHex,
        'account_id': accountId,
        'facematch_verified': facematchVerified,
        'verify_outer_ms': verifyOuterMs,
        'wrap_outer_ms': wrapOuterMs,
        'verify_wrapped_ms': verifyWrappedMs,
        ...requestVersion.toJson(),
      }),
      operation: 'store zkPassport pending completion',
      writer: _stringWriter,
    );
  }

  /// Returns a pending completion if one exists, or null.
  ///
  /// [bucket] pins the read to an explicit storage bucket. Retry flows
  /// capture the active bucket once at the start and pass it to every
  /// subsequent read/clear, so a mid-flight bucket switch (account
  /// reconcile) can't make the clear target a different identity's record.
  Future<Map<String, dynamic>?> getPendingCompletion({String? bucket}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = _pendingCompletionKey(bucket);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final version = ZkPassportRequestVersion.fromJson(decoded);
        if (version != null &&
            _requestOutcome(prefs, version, bucket: bucket) != null) {
          return null;
        }
        return decoded;
      }
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

  /// Records a durable event consumed by both the outbox and optimistic
  /// registration views. The outcome name is part of the key, so concurrent
  /// writers never overwrite each other. If conflicting markers exist,
  /// [_requestOutcome] resolves them deterministically with `delivered`
  /// taking precedence over rejection/discard.
  Future<void> recordRequestOutcome({
    required ZkPassportRequestVersion version,
    required ZkPassportRequestOutcome outcome,
    String? bucket,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final existing = _requestOutcome(prefs, version, bucket: bucket);
    if (existing != null) {
      if (existing == outcome ||
          existing == ZkPassportRequestOutcome.delivered) {
        return;
      }
      if (outcome != ZkPassportRequestOutcome.delivered) {
        throw StateError(
          'zkPassport request ${version.requestId} already has terminal '
          'outcome ${existing.name}',
        );
      }
    }
    await _checkedSetString(
      prefs,
      _requestOutcomeKey(version, outcome, bucket: bucket),
      jsonEncode({...version.toJson(), 'outcome': outcome.name}),
      operation: 'record zkPassport request outcome',
      writer: _stringWriter,
    );
  }

  ZkPassportRequestOutcome? _requestOutcome(
    SharedPreferences prefs,
    ZkPassportRequestVersion version, {
    String? bucket,
  }) {
    // Enum order is the conflict precedence: a confirmed delivery must not be
    // rolled back by a duplicate request's late rejection.
    for (final outcome in ZkPassportRequestOutcome.values) {
      final raw = prefs.getString(
        _requestOutcomeKey(version, outcome, bucket: bucket),
      );
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            ZkPassportRequestVersion.fromJson(decoded) == version &&
            decoded['outcome'] == outcome.name) {
          return outcome;
        }
      } catch (_) {
        // Ignore a corrupt marker; another append-only marker may be valid.
      }
    }
    return null;
  }

  String _requestOutcomeKey(
    ZkPassportRequestVersion version,
    ZkPassportRequestOutcome outcome, {
    String? bucket,
  }) {
    final encodedRequestId =
        base64Url.encode(utf8.encode(version.requestId)).replaceAll('=', '');
    final key = '$_kRequestOutcomeKeyBase:$encodedRequestId:'
        '${version.createdAtMs}:${version.nonce}:${outcome.name}';
    return bucket == null
        ? NetworkPrefs.prefixAccountKey(key)
        : NetworkPrefs.prefixAccountKeyFor(key, bucket);
  }

  Future<void> clearRegistrationForAccount({
    required String accountId,
    required String bucket,
  }) async {
    if (accountId.isEmpty || bucket.isEmpty) {
      throw ArgumentError('accountId and bucket must not be empty');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_registrationKeyForAccount(accountId, bucket: bucket));
  }

  String _registrationKeyForAccount(String accountId, {String? bucket}) {
    final key = '$_kRegistrationKeyBase:$accountId';
    return bucket == null
        ? NetworkPrefs.prefixAccountKey(key)
        : NetworkPrefs.prefixAccountKeyFor(key, bucket);
  }

  Future<ZkPassportLocalRegistration> getRegistrationForAccount({
    required String accountId,
    required String bucket,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = _registrationKeyForAccount(accountId, bucket: bucket);
    final raw = prefs.getString(key);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        final parsed = ZkPassportLocalRegistration.fromJson(decoded);
        if (parsed != null) {
          final version = parsed.requestVersion;
          final outcome = version == null
              ? null
              : _requestOutcome(prefs, version, bucket: bucket);
          if (outcome == ZkPassportRequestOutcome.rejected ||
              outcome == ZkPassportRequestOutcome.discarded) {
            return ZkPassportLocalRegistration.unregistered();
          }
          return parsed;
        }
      } catch (_) {
        // Fall through to migration/unregistered.
      }
    }

    // Migration: older versions stored a single boolean for the whole network.
    final legacyKey =
        NetworkPrefs.prefixAccountKeyFor(_kRegisteredKeyBase, bucket);
    final legacyRegistered = prefs.getBool(legacyKey) ?? false;
    if (!legacyRegistered) {
      return ZkPassportLocalRegistration.unregistered();
    }

    final migrated = ZkPassportLocalRegistration(
      registered: true,
      nullifierHex: null,
      registeredAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _checkedSetString(
      prefs,
      key,
      jsonEncode(migrated.toJson()),
      operation: 'migrate zkPassport registration',
      writer: _stringWriter,
    );
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

  /// Resolves the row's key.
  ///
  /// [bucket] is the session's captured LAUNCH bucket. Every runtime write
  /// happens after a long Rust/RPC await, by which time the ambient bucket
  /// may already belong to a guest or to the next signed-in user — recomputing
  /// it per call is how a proof launched by A ends up written into B's bucket,
  /// or how finalization clears the wrong row. Only [load], which is looking
  /// for whatever row belongs to the CURRENT identity, may resolve it
  /// ambiently.
  String _key(String? bucket) => bucket == null
      ? NetworkPrefs.prefixAccountKey(_kRuntimeSessionKeyBase)
      : NetworkPrefs.prefixAccountKeyFor(_kRuntimeSessionKeyBase, bucket);

  Future<ZkPassportRuntimeSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(null);
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

  /// Writes the row into the session's launch bucket (see [_key]). Sessions
  /// persisted by older app versions carry no launch bucket and fall back to
  /// the ambient one.
  Future<void> save(ZkPassportRuntimeSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkedSetString(
      prefs,
      _key(session.launchBucket),
      jsonEncode(session.toJson()),
      operation: 'store zkPassport runtime session',
    );
  }

  Future<void> clear({String? bucket}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(bucket));
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
