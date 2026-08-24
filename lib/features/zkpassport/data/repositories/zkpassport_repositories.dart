import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
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

String _encodeOwnerPart(String value) =>
    base64Url.encode(utf8.encode(value.trim())).replaceAll('=', '');

bool _isNewerOperation(
  ZkPassportRequestVersion candidate,
  ZkPassportRequestVersion? current,
) {
  if (current == null || candidate.createdAtMs != current.createdAtMs) {
    return current == null || candidate.createdAtMs > current.createdAtMs;
  }
  return candidate.operationId.compareTo(current.operationId) > 0;
}

class ZkPassportRegistrationRepository {
  ZkPassportRegistrationRepository({
    ZkPassportStringWriter? stringWriter,
  }) : _stringWriter = stringWriter;

  static const _kRegistrationKeyBase = 'zkpassport:registration_v2';
  static const _kPendingCompletionKeyBase = 'zkpassport:pending_completion_v2';
  static const _kRequestOutcomeKeyBase = 'zkpassport:request_outcome_v2';

  final ZkPassportStringWriter? _stringWriter;

  Future<bool> isRegistered(AccountCapability capability) async {
    final registration = await getActiveRegistration(capability);
    return registration.registered;
  }

  Future<ZkPassportLocalRegistration> getActiveRegistration(
    AccountCapability capability,
  ) {
    return getRegistrationForAccount(capability);
  }

  Future<void> storeActiveRegistration({
    required AccountCapability capability,
    required bool registered,
    required String? nullifierHex,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    required ZkPassportRequestVersion requestVersion,
  }) {
    return storeRegistrationForAccount(
      capability: capability,
      registered: registered,
      nullifierHex: nullifierHex,
      facematchVerified: facematchVerified,
      verifyOuterMs: verifyOuterMs,
      wrapOuterMs: wrapOuterMs,
      verifyWrappedMs: verifyWrappedMs,
      requestVersion: requestVersion,
    );
  }

  /// Stores registration state under an explicitly captured account scope.
  Future<void> storeRegistrationForAccount({
    required AccountCapability capability,
    required bool registered,
    required String? nullifierHex,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    required ZkPassportRequestVersion requestVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _registrationKey(capability, requestVersion);
    final payload = ZkPassportLocalRegistration(
      registered: registered,
      nullifierHex: nullifierHex,
      registeredAtMs: registered ? DateTime.now().millisecondsSinceEpoch : null,
      appSessionId: capability.sessionId,
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

  /// Stores one outbox row under the captured session and operation owner.
  Future<void> storePendingCompletion({
    required AccountCapability capability,
    required int participantId,
    required int challengeId,
    required String sessionId,
    required String nullifierHex,
    required ZkPassportRequestVersion requestVersion,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
  }) async {
    if (sessionId != requestVersion.requestId) {
      throw ArgumentError.value(
        sessionId,
        'sessionId',
        'must match the request version',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final key = _pendingCompletionKey(capability, requestVersion);
    await _checkedSetString(
      prefs,
      key,
      jsonEncode({
        'app_session_id': capability.sessionId,
        'participant_id': participantId,
        'challenge_id': challengeId,
        'wallet_address': capability.address,
        'session_id': sessionId,
        'nullifier_hex': nullifierHex,
        'account_id': capability.accountId,
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
  /// Only rows owned by [capability]'s exact application session are visible.
  Future<Map<String, dynamic>?> getPendingCompletion(
    AccountCapability capability,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    Map<String, dynamic>? selected;
    ZkPassportRequestVersion? selectedVersion;
    final prefix = _pendingCompletionPrefix(capability);
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> ||
            decoded['app_session_id'] != capability.sessionId) {
          continue;
        }
        final version = ZkPassportRequestVersion.fromJson(decoded);
        if (version == null ||
            key != _pendingCompletionKey(capability, version) ||
            _requestOutcome(prefs, capability, version) != null) {
          continue;
        }
        if (_isNewerOperation(version, selectedVersion)) {
          selected = decoded;
          selectedVersion = version;
        }
      } catch (_) {
        await prefs.remove(key);
      }
    }
    return selected;
  }

  /// Reclaims only the row owned by this exact session/operation pair.
  Future<void> clearPendingCompletion({
    required AccountCapability capability,
    required ZkPassportRequestVersion requestVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCompletionKey(capability, requestVersion));
  }

  String _pendingCompletionPrefix(AccountCapability capability) =>
      NetworkPrefs.prefixAccountKeyForIn(
        '$_kPendingCompletionKeyBase:'
        '${_encodeOwnerPart(capability.sessionId)}:',
        capability.bucket,
        capability.network,
      );

  String _pendingCompletionKey(
    AccountCapability capability,
    ZkPassportRequestVersion version,
  ) =>
      '${_pendingCompletionPrefix(capability)}'
      '${_encodeOwnerPart(version.operationId)}';

  /// Records a durable event consumed by both the outbox and optimistic
  /// registration views. The outcome name is part of the key, so concurrent
  /// writers never overwrite each other. If conflicting markers exist,
  /// [_requestOutcome] resolves them deterministically with `delivered`
  /// taking precedence over rejection/discard.
  Future<void> recordRequestOutcome({
    required AccountCapability capability,
    required ZkPassportRequestVersion version,
    required ZkPassportRequestOutcome outcome,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final existing = _requestOutcome(prefs, capability, version);
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
      _requestOutcomeKey(capability, version, outcome),
      jsonEncode({
        'app_session_id': capability.sessionId,
        ...version.toJson(),
        'outcome': outcome.name,
      }),
      operation: 'record zkPassport request outcome',
      writer: _stringWriter,
    );
  }

  ZkPassportRequestOutcome? _requestOutcome(
    SharedPreferences prefs,
    AccountCapability capability,
    ZkPassportRequestVersion version,
  ) {
    // Enum order is the conflict precedence: a confirmed delivery must not be
    // rolled back by a duplicate request's late rejection.
    for (final outcome in ZkPassportRequestOutcome.values) {
      final raw = prefs.getString(
        _requestOutcomeKey(capability, version, outcome),
      );
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            decoded['app_session_id'] == capability.sessionId &&
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
    AccountCapability capability,
    ZkPassportRequestVersion version,
    ZkPassportRequestOutcome outcome,
  ) {
    final key = '$_kRequestOutcomeKeyBase:'
        '${_encodeOwnerPart(capability.sessionId)}:'
        '${_encodeOwnerPart(version.operationId)}:${outcome.name}';
    return NetworkPrefs.prefixAccountKeyForIn(
      key,
      capability.bucket,
      capability.network,
    );
  }

  Future<void> clearActiveRegistration(AccountCapability capability) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _registrationPrefix(capability);
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
  }

  String _registrationPrefix(AccountCapability capability) =>
      NetworkPrefs.prefixAccountKeyForIn(
        '$_kRegistrationKeyBase:${_encodeOwnerPart(capability.accountId)}:'
        '${_encodeOwnerPart(capability.sessionId)}:',
        capability.bucket,
        capability.network,
      );

  String _registrationKey(
    AccountCapability capability,
    ZkPassportRequestVersion version,
  ) =>
      '${_registrationPrefix(capability)}'
      '${_encodeOwnerPart(version.operationId)}';

  Future<ZkPassportLocalRegistration> getRegistrationForAccount(
    AccountCapability capability,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    ZkPassportLocalRegistration? selected;
    ZkPassportRequestVersion? selectedVersion;
    final prefix = _registrationPrefix(capability);
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        final parsed = ZkPassportLocalRegistration.fromJson(decoded);
        final version = parsed?.requestVersion;
        if (parsed == null ||
            parsed.appSessionId != capability.sessionId ||
            version == null ||
            key != _registrationKey(capability, version) ||
            !_isNewerOperation(version, selectedVersion)) {
          continue;
        }
        selected = parsed;
        selectedVersion = version;
      } catch (_) {
        await prefs.remove(key);
      }
    }
    if (selected == null || selectedVersion == null) {
      return ZkPassportLocalRegistration.unregistered();
    }
    final outcome = _requestOutcome(prefs, capability, selectedVersion);
    if (outcome == ZkPassportRequestOutcome.rejected ||
        outcome == ZkPassportRequestOutcome.discarded) {
      return ZkPassportLocalRegistration.unregistered();
    }
    return selected;
  }
}

class ZkPassportSettingsRepository {
  static const _kSettingsKeyBase = 'zkpassport:settings_v1';

  String _key(AccountCapability capability) =>
      NetworkPrefs.prefixAccountKeyForIn(
        _kSettingsKeyBase,
        capability.bucket,
        capability.network,
      );

  Future<ZkPassportSettings> load(AccountCapability capability) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(capability);
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

  Future<void> save(
    AccountCapability capability,
    ZkPassportSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(capability), jsonEncode(settings.toJson()));
  }

  Future<void> setFacematchStrict(
    AccountCapability capability,
    bool value,
  ) async {
    final current = await load(capability);
    await save(capability, current.copyWith(facematchStrict: value));
  }
}

class ZkPassportRuntimeSessionRepository {
  ZkPassportRuntimeSessionRepository();

  static const _kRuntimeSessionKeyBase = 'zkpassport:runtime_session_v2';

  String _sessionPrefix({
    required String appSessionId,
    required String network,
    required String bucket,
  }) =>
      NetworkPrefs.prefixAccountKeyForIn(
        '$_kRuntimeSessionKeyBase:${_encodeOwnerPart(appSessionId)}:',
        bucket,
        network,
      );

  String _key(ZkPassportRuntimeSession session) {
    final network = session.launchNetwork?.trim();
    final bucket = session.launchBucket?.trim();
    final version = session.requestVersion;
    if (network == null ||
        network.isEmpty ||
        bucket == null ||
        bucket.isEmpty ||
        version == null) {
      throw ArgumentError('runtime session has no complete durable owner');
    }
    return '${_sessionPrefix(
      appSessionId: session.appSessionId,
      network: network,
      bucket: bucket,
    )}${_encodeOwnerPart(version.operationId)}';
  }

  Future<ZkPassportRuntimeSession?> loadForSession({
    required String appSessionId,
    required String network,
    required String bucket,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    ZkPassportRuntimeSession? selected;
    final prefix = _sessionPrefix(
      appSessionId: appSessionId,
      network: network,
      bucket: bucket,
    );
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        final session = decoded is Map<String, dynamic>
            ? ZkPassportRuntimeSession.fromJson(decoded)
            : null;
        if (session == null ||
            session.appSessionId != appSessionId ||
            session.launchNetwork != network ||
            session.launchBucket != bucket ||
            key != _key(session)) {
          continue;
        }
        final selectedVersion = selected?.requestVersion;
        final version = session.requestVersion!;
        if (_isNewerOperation(version, selectedVersion)) {
          selected = session;
        }
      } catch (_) {
        await prefs.remove(key);
      }
    }
    return selected;
  }

  Future<void> save(ZkPassportRuntimeSession session) async {
    if (session.appSessionId.trim().isEmpty) {
      throw ArgumentError.value(
        session.appSessionId,
        'session.appSessionId',
        'must not be empty',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await _checkedSetString(
      prefs,
      _key(session),
      jsonEncode(session.toJson()),
      operation: 'store zkPassport runtime session',
    );
  }

  Future<void> clear(ZkPassportRuntimeSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(session));
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
