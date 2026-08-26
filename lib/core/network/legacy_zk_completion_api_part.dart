part of 'legacy_session_capabilities.dart';

const _zkIdentityKind = 'ZK_IDENTITY_VERIFICATION';
const _zkWritesDisabledMessage =
    'Backend write requests are disabled in view-only mode.';

enum LegacyZkCompletionFailure {
  api,
  activeChallengeUnavailable,
  ambiguousActiveChallenge,
  invalidResponse,
  writesDisabled,
}

class LegacyZkCompletionException implements Exception {
  LegacyZkCompletionException(
    this.statusCode,
    this.message, {
    required this.failure,
    this.body,
  });

  final int statusCode;
  final String message;
  final LegacyZkCompletionFailure failure;
  final Object? body;

  @override
  String toString() =>
      'LegacyZkCompletionException($statusCode, ${failure.name}, $message)';
}

/// Temporary adapter for the old server-owned ZK completion protocol.
///
/// It intentionally exposes no challenge list, season model, reward state, or
/// cache. New attempts resolve exactly one active ZK row just in time; durable
/// retries submit the exact challenge id already stored in their outbox row.
///
/// TODO(proof-only-cut): Delete this adapter when Social owns challenge
/// selection/completion and invokes the typed native proof-only operation.
abstract interface class LegacyZkCompletionApi {
  Future<int> resolveActiveChallengeId();

  Future<void> complete({
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  });
}

class _HttpLegacyZkCompletionApi implements LegacyZkCompletionApi {
  _HttpLegacyZkCompletionApi({
    String? baseUrl,
    http.Client? httpClient,
    bool? writesEnabled,
    int maxGetRetries = 2,
    Duration retryBaseDelay = const Duration(milliseconds: 300),
    Future<String?> Function()? tokenProvider,
    Future<void> Function(AuthCredentialLease credential)? onUnauthorized,
    Future<void> Function(int epoch)? onCredentialMissing,
  })  : _transport = _SessionApiTransport(
          baseUrl: baseUrl,
          httpClient: httpClient,
          maxGetRetries: maxGetRetries,
          retryBaseDelay: retryBaseDelay,
          tokenProvider: tokenProvider,
          onUnauthorized: onUnauthorized,
          onCredentialMissing: onCredentialMissing,
        ),
        _writesEnabled = writesEnabled ?? !AppConfig.viewOnly;

  final _SessionApiTransport _transport;
  final bool _writesEnabled;

  @override
  Future<int> resolveActiveChallengeId() async {
    final identity = IdentitySnapshots.current;
    try {
      final seasons = await _transport.getData(
        '/seasons',
        queryParameters: const {'include_challenges': '0'},
      );
      _requireCurrent(identity);
      final seasonId = _resolveActiveSeasonId(seasons);
      final challenges = await _transport.getData(
        '/challenges',
        queryParameters: {
          'season_id': seasonId.toString(),
          'active_only': '1',
        },
      );
      _requireCurrent(identity);
      return _resolveZkChallengeId(challenges);
    } on _SessionApiException catch (error) {
      throw LegacyZkCompletionException(
        error.statusCode,
        error.message,
        failure: LegacyZkCompletionFailure.api,
        body: error.body,
      );
    }
  }

  @override
  Future<void> complete({
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) async {
    if (!_writesEnabled) {
      throw LegacyZkCompletionException(
        503,
        _zkWritesDisabledMessage,
        failure: LegacyZkCompletionFailure.writesDisabled,
      );
    }
    if (challengeId <= 0 ||
        !_isCanonical(walletAddress) ||
        !_isCanonical(sessionId) ||
        !_isCanonical(nullifierHex)) {
      throw LegacyZkCompletionException(
        400,
        'Invalid ZK completion request.',
        failure: LegacyZkCompletionFailure.invalidResponse,
      );
    }
    try {
      await _transport.postData(
        '/zkpassport/complete',
        body: {
          'challenge_id': challengeId,
          'wallet_address': walletAddress,
          'session_id': sessionId,
          'nullifier_hex': nullifierHex,
          if (completedAt != null) 'completed_at': completedAt,
        },
      );
    } on _SessionApiException catch (error) {
      throw LegacyZkCompletionException(
        error.statusCode,
        error.message,
        failure: LegacyZkCompletionFailure.api,
        body: error.body,
      );
    }
  }

  void _requireCurrent(Identity expected) {
    if (!expected.sameScopeAs(IdentitySnapshots.current)) {
      throw const StaleAuthCredentialException();
    }
  }

  int _resolveActiveSeasonId(Object? data) {
    if (data is! List) {
      throw _invalidResponse('Invalid active-season response.');
    }
    final ids = <int>[];
    for (final item in data) {
      if (item is! Map<String, dynamic> || item['is_active'] != true) continue;
      final id = _positiveInt(item['season_id'] ?? item['id']);
      if (id == null) {
        throw _invalidResponse('Invalid active-season identifier.');
      }
      ids.add(id);
    }
    if (ids.length != 1) {
      throw LegacyZkCompletionException(
        409,
        'Expected exactly one active ZK season.',
        failure: ids.isEmpty
            ? LegacyZkCompletionFailure.activeChallengeUnavailable
            : LegacyZkCompletionFailure.ambiguousActiveChallenge,
      );
    }
    return ids.single;
  }

  int _resolveZkChallengeId(Object? data) {
    if (data is! List) {
      throw _invalidResponse('Invalid active-challenge response.');
    }
    final ids = <int>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final kind = item['kind'] ?? item['sub_category'];
      if (kind != _zkIdentityKind || item['enabled'] == false) continue;
      final id = _positiveInt(item['id'] ?? item['challenge_id']);
      if (id == null) {
        throw _invalidResponse('Invalid ZK challenge identifier.');
      }
      ids.add(id);
    }
    if (ids.length != 1) {
      throw LegacyZkCompletionException(
        409,
        'Expected exactly one active ZK challenge.',
        failure: ids.isEmpty
            ? LegacyZkCompletionFailure.activeChallengeUnavailable
            : LegacyZkCompletionFailure.ambiguousActiveChallenge,
      );
    }
    return ids.single;
  }

  LegacyZkCompletionException _invalidResponse(String message) {
    return LegacyZkCompletionException(
      502,
      message,
      failure: LegacyZkCompletionFailure.invalidResponse,
    );
  }

  static int? _positiveInt(Object? value) {
    final parsed = switch (value) {
      int number => number,
      String text when text.isNotEmpty && text == text.trim() =>
        int.tryParse(text),
      _ => null,
    };
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static bool _isCanonical(String value) =>
      value.isNotEmpty && value == value.trim();

  void dispose() => _transport.dispose();
}

final legacyZkCompletionApiProvider = Provider<LegacyZkCompletionApi>((ref) {
  final api = _HttpLegacyZkCompletionApi(
    tokenProvider: () => ref.read(authTokenStoreProvider).read(),
    onUnauthorized: (credential) => ref
        .read(identityProvider.notifier)
        .onUnauthorized(credential: credential),
    onCredentialMissing: (epoch) =>
        ref.read(identityProvider.notifier).onCredentialMissing(epoch: epoch),
  );
  ref.onDispose(api.dispose);
  return api;
});
