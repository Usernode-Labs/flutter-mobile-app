import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
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
typedef ZkPassportKeyRemover = Future<bool> Function(
  SharedPreferences preferences,
  String key,
);

bool _sameZkAccountOwner(ZkIdentityScope a, ZkIdentityScope b) =>
    a.network == b.network &&
    a.bucket == b.bucket &&
    a.participantId == b.participantId &&
    a.accountId == b.accountId &&
    a.address == b.address;

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

Future<bool> _removeKey(
  SharedPreferences preferences,
  String key, {
  ZkPassportKeyRemover? remover,
}) =>
    remover == null ? preferences.remove(key) : remover(preferences, key);

class ZkPassportRegistrationRepository {
  ZkPassportRegistrationRepository({
    ZkPassportStringWriter? stringWriter,
    ZkPassportKeyRemover? keyRemover,
  })  : _stringWriter = stringWriter,
        _keyRemover = keyRemover;

  static const _kRegisteredKeyBase = 'zkpassport:registered';
  static const _kRegistrationKeyBase = 'zkpassport:registration';
  static const _kPendingCompletionKey = 'zkpassport:pending_completion';
  static const _kRequestOutcomeKeyBase = 'zkpassport:request_outcome_v1';

  final ZkPassportStringWriter? _stringWriter;
  final ZkPassportKeyRemover? _keyRemover;

  Future<bool> isRegistered() async {
    final registration = await getActiveRegistration();
    return registration.registered;
  }

  Future<ZkPassportLocalRegistration> getActiveRegistration() async {
    final network = NetworkPrefs.currentNetwork;
    final bucket = NetworkPrefs.activeBucket;
    final accounts = await AccountsRepository.create(network: network);
    final active = await accounts.getActive();
    if (active == null ||
        NetworkPrefs.currentNetwork != network ||
        NetworkPrefs.activeBucket != bucket ||
        NetworkPrefs.bucketForAddress(active.address) != bucket) {
      return ZkPassportLocalRegistration.unregistered();
    }

    return getRegistrationForAccount(
      scope: AccountStorageScope(
        network: network,
        bucket: bucket,
        accountId: active.id,
        address: active.address,
      ),
    );
  }

  Future<void> storeActiveRegistration({
    required bool registered,
    required String? nullifierHex,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    ZkPassportRequestVersion? requestVersion,
  }) async {
    final network = NetworkPrefs.currentNetwork;
    final bucket = NetworkPrefs.activeBucket;
    final accounts = await AccountsRepository.create(network: network);
    final active = await accounts.getActive();
    if (active == null ||
        NetworkPrefs.bucketForAddress(active.address) != bucket) {
      return;
    }

    await storeRegistrationForAccount(
      scope: AccountStorageScope(
        network: network,
        bucket: bucket,
        accountId: active.id,
        address: active.address,
      ),
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
  /// Identity-sensitive flows use this instead of resolving the ambient
  /// active account after an `await`.
  Future<void> storeRegistrationForAccount({
    required AccountStorageScope scope,
    required bool registered,
    required String? nullifierHex,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    ZkPassportRequestVersion? requestVersion,
  }) async {
    if (scope.accountId.isEmpty ||
        scope.bucket.isEmpty ||
        scope.network.isEmpty ||
        scope.address.isEmpty) {
      throw ArgumentError('account storage scope must be complete');
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _registrationKeyForAccount(scope);
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
  /// reconcile completion). See [getPendingCompletion] for [scope] semantics.
  Future<void> storePendingCompletion({
    required ZkIdentityScope scope,
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
    await prefs.reload();
    final key = _pendingCompletionKey(scope);
    final existingRaw = prefs.getString(key);
    if (existingRaw != null && existingRaw.trim().isNotEmpty) {
      try {
        final existing = jsonDecode(existingRaw);
        if (existing is Map<String, dynamic>) {
          final existingSessionId = existing['session_id'];
          if (existingSessionId is! String ||
              existingSessionId.trim().isEmpty) {
            await prefs.remove(key);
          } else {
            final existingVersion = ZkPassportRequestVersion.fromJson(existing);
            final sameRequest = existingVersion == requestVersion &&
                existingSessionId == sessionId;
            final retired = existingVersion != null &&
                _requestOutcome(
                      prefs,
                      existingVersion,
                      scope: _accountScope(scope),
                    ) !=
                    null;
            if (!sameRequest && !retired) {
              throw StateError(
                'A different zkPassport completion is still pending for this '
                'account',
              );
            }
          }
        }
      } on StateError {
        rethrow;
      } catch (_) {
        // A corrupt row has no recoverable request identity. Replace it with
        // the validated exact-version payload below.
      }
    }
    // FIXME(zk-storage): the guarded source row remains one mutable slot per
    // account. Request-keyed native rows are still required for transactional
    // writes across Flutter engines, but a second local flow can no longer
    // silently overwrite an unresolved claim.
    await _checkedSetString(
      prefs,
      key,
      jsonEncode({
        'scope': scope.toJson(),
        'session_id': sessionId,
        'nullifier_hex': nullifierHex,
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
  /// [scope] pins the read to an explicit network and storage owner. Retry
  /// flows pass the same value to every read/outcome/clear, so an identity or
  /// network switch cannot redirect a later operation.
  Future<Map<String, dynamic>?> getPendingCompletion({
    required ZkIdentityScope scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = _pendingCompletionKey(scope);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final sessionId = decoded['session_id'];
        if (sessionId is! String || sessionId.trim().isEmpty) {
          await prefs.remove(key);
          return null;
        }
        final storedScope = ZkIdentityScope.fromJson(decoded['scope']);
        // The physical outbox slot is account-owned. Return a row from an
        // older challenge to that same owner so the controller can retire it
        // explicitly instead of making it permanently invisible.
        if (storedScope != null &&
            _accountScope(storedScope) != _accountScope(scope)) {
          return null;
        }
        final version = ZkPassportRequestVersion.fromJson(decoded);
        if (version != null &&
            _requestOutcome(prefs, version, scope: _accountScope(scope)) !=
                null) {
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

  /// Best-effort compare-and-clear for a legacy, unversioned outbox row.
  ///
  /// Versioned rows are retired with append-only request outcomes. This
  /// method exists only for rows that predate [ZkPassportRequestVersion].
  Future<bool> clearPendingCompletionIfCurrent({
    required ZkIdentityScope scope,
    required String sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = _pendingCompletionKey(scope);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return true;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['session_id'] != sessionId) {
        return false;
      }
      final storedScope = ZkIdentityScope.fromJson(decoded['scope']);
      if (storedScope != null) {
        if (storedScope != scope) return false;
      } else if ((decoded['network'] is String &&
              decoded['network'] != scope.network) ||
          (decoded['bucket'] is String && decoded['bucket'] != scope.bucket) ||
          (decoded['participant_id'] is int &&
              decoded['participant_id'] != scope.participantId) ||
          (decoded['account_id'] is String &&
              decoded['account_id'] != scope.accountId) ||
          (decoded['wallet_address'] is String &&
              decoded['wallet_address'] != scope.address) ||
          (decoded['challenge_id'] is int &&
              decoded['challenge_id'] != scope.challengeId)) {
        return false;
      }

      // FIXME(zk-storage): SharedPreferences cannot make this comparison and
      // removal transactional across Flutter engines. Move the outbox to the
      // native transactional store when multiple simultaneous engines are a
      // supported execution mode.
      return _removeKey(prefs, key, remover: _keyRemover);
    } catch (_) {
      return false;
    }
  }

  String _pendingCompletionKey(ZkIdentityScope scope) =>
      _accountScope(scope).preferenceKey(_kPendingCompletionKey);

  /// Records a durable event consumed by both the outbox and optimistic
  /// registration views. The outcome name is part of the key, so concurrent
  /// writers never overwrite each other. If conflicting markers exist,
  /// [_requestOutcome] resolves them deterministically with `delivered`
  /// taking precedence over rejection/discard.
  Future<void> recordRequestOutcome({
    required ZkPassportRequestVersion version,
    required ZkPassportRequestOutcome outcome,
    required ZkIdentityScope scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final accountScope = _accountScope(scope);
    final existing = _requestOutcome(prefs, version, scope: accountScope);
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
      _requestOutcomeKey(version, outcome, scope: accountScope),
      jsonEncode({...version.toJson(), 'outcome': outcome.name}),
      operation: 'record zkPassport request outcome',
      writer: _stringWriter,
    );
  }

  ZkPassportRequestOutcome? _requestOutcome(
    SharedPreferences prefs,
    ZkPassportRequestVersion version, {
    required AccountStorageScope scope,
  }) {
    // Enum order is the conflict precedence: a confirmed delivery must not be
    // rolled back by a duplicate request's late rejection.
    for (final outcome in ZkPassportRequestOutcome.values) {
      final raw = prefs.getString(
        _requestOutcomeKey(version, outcome, scope: scope),
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
    required AccountStorageScope scope,
  }) {
    final encodedRequestId =
        base64Url.encode(utf8.encode(version.requestId)).replaceAll('=', '');
    final key = '$_kRequestOutcomeKeyBase:$encodedRequestId:'
        '${version.createdAtMs}:${version.nonce}:${outcome.name}';
    return scope.preferenceKey(key);
  }

  Future<void> clearActiveRegistration() async {
    final network = NetworkPrefs.currentNetwork;
    final bucket = NetworkPrefs.activeBucket;
    final accounts = await AccountsRepository.create(network: network);
    final active = await accounts.getActive();
    if (active == null ||
        NetworkPrefs.bucketForAddress(active.address) != bucket) {
      return;
    }

    final scope = AccountStorageScope(
      network: network,
      bucket: bucket,
      accountId: active.id,
      address: active.address,
    );
    await clearRegistrationForAccount(scope: scope);
  }

  Future<void> clearRegistrationForAccount({
    required AccountStorageScope scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final removed = await _removeKey(
      prefs,
      _registrationKeyForAccount(scope),
      remover: _keyRemover,
    );
    if (!removed) {
      throw StateError('Failed to clear zkPassport registration');
    }
  }

  String _registrationKeyForAccount(AccountStorageScope scope) =>
      scope.preferenceKey('$_kRegistrationKeyBase:${scope.accountId}');

  Future<ZkPassportLocalRegistration> getRegistrationForAccount({
    required AccountStorageScope scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = _registrationKeyForAccount(scope);
    final raw = prefs.getString(key);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        final parsed = ZkPassportLocalRegistration.fromJson(decoded);
        if (parsed != null) {
          final version = parsed.requestVersion;
          final outcome = version == null
              ? null
              : _requestOutcome(prefs, version, scope: scope);
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
    final legacyKey = scope.preferenceKey(_kRegisteredKeyBase);
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

  AccountStorageScope _accountScope(ZkIdentityScope scope) =>
      AccountStorageScope(
        network: scope.network,
        bucket: scope.bucket,
        accountId: scope.accountId,
        address: scope.address,
      );
}

class ZkPassportSettingsRepository {
  static const _kSettingsKeyBase = 'zkpassport:settings_v1';

  Future<ZkPassportSettings> load({
    required AccountStorageScope scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = scope.preferenceKey(_kSettingsKeyBase);
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

  Future<void> save({
    required AccountStorageScope scope,
    required ZkPassportSettings settings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final persisted = await prefs.setString(
        scope.preferenceKey(_kSettingsKeyBase), jsonEncode(settings.toJson()));
    if (!persisted) {
      throw StateError('Failed to persist zkPassport settings');
    }
  }

  Future<void> setFacematchStrict({
    required AccountStorageScope scope,
    required bool value,
  }) async {
    final current = await load(scope: scope);
    await save(
      scope: scope,
      settings: current.copyWith(facematchStrict: value),
    );
  }
}

class ZkPassportRuntimeSessionRepository {
  ZkPassportRuntimeSessionRepository({
    ZkPassportKeyRemover? keyRemover,
  }) : _keyRemover = keyRemover;

  static const _kRuntimeSessionKeyBase = 'zkpassport:runtime_session_v1';

  final ZkPassportKeyRemover? _keyRemover;

  Future<ZkPassportRuntimeSession?> load({
    required ZkIdentityScope scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(scope);
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
      final launchScope = session.launchScope;
      if (launchScope == null || !_sameZkAccountOwner(launchScope, scope)) {
        return null;
      }
      return session;
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> save(ZkPassportRuntimeSession session) async {
    final scope = session.launchScope;
    if (scope == null) {
      throw ArgumentError('runtime session must have a launch scope');
    }
    final prefs = await SharedPreferences.getInstance();
    final key = _key(scope);
    // FIXME(zk-storage): the runtime slot is still one row per account. The
    // request key in the payload prevents stale local clears, but a native
    // request-keyed store is required for transactional cross-engine writes.
    await _checkedSetString(
      prefs,
      key,
      jsonEncode(session.toJson()),
      operation: 'store zkPassport runtime session',
    );
  }

  /// Updates a runtime row only while it still names the same request.
  Future<bool> saveIfCurrent(ZkPassportRuntimeSession session) async {
    final scope = session.launchScope;
    final requestKey = session.requestVersion?.key;
    if (scope == null || requestKey == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = _key(scope);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      final current = ZkPassportRuntimeSession.fromJson(decoded);
      if (current?.launchScope != scope ||
          current?.requestVersion?.key != requestKey) {
        return false;
      }
    } catch (_) {
      return false;
    }

    // FIXME(zk-storage): this is isolate-safe but not a transactional CAS
    // across Flutter engines. A native multi-row store should own the runtime
    // and completion state before concurrent engines are supported.
    await _checkedSetString(
      prefs,
      key,
      jsonEncode(session.toJson()),
      operation: 'update zkPassport runtime session',
    );
    return true;
  }

  Future<void> clear({required ZkIdentityScope scope}) async {
    final prefs = await SharedPreferences.getInstance();
    final removed = await _removeKey(
      prefs,
      _key(scope),
      remover: _keyRemover,
    );
    if (!removed) {
      throw StateError('Failed to clear zkPassport runtime session');
    }
  }

  Future<bool> clearIfCurrent({
    required ZkIdentityScope scope,
    required ZkRequestKey requestKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = _key(scope);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return true;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      final current = ZkPassportRuntimeSession.fromJson(decoded);
      if (current?.launchScope != scope ||
          current?.requestVersion?.key != requestKey) {
        return false;
      }

      // See the cross-engine CAS FIXME in [saveIfCurrent].
      return _removeKey(prefs, key, remover: _keyRemover);
    } catch (_) {
      return false;
    }
  }

  String _key(ZkIdentityScope scope) => NetworkPrefs.prefixKeyWith(
        'acct:${scope.bucket}:$_kRuntimeSessionKeyBase',
        scope.network,
      );
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
