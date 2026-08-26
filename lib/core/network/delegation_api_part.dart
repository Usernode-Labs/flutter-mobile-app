part of 'legacy_session_capabilities.dart';

const _delegationWritesDisabledMessage =
    'Backend write requests are disabled in view-only mode.';

class DelegationApiException implements Exception {
  DelegationApiException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final Object? body;

  @override
  String toString() => 'DelegationApiException($statusCode, $message)';
}

class DelegationStatus {
  const DelegationStatus({required this.delegated, this.delegatedSince});

  final bool delegated;
  final String? delegatedSince;

  factory DelegationStatus.fromJson(Map<String, Object?> json) {
    final rawSince = json['delegated_since'];
    final delegatedSince =
        rawSince is String && rawSince.isNotEmpty && rawSince == rawSince.trim()
            ? rawSince
            : null;
    return DelegationStatus(
      delegated: json['delegated'] == true,
      delegatedSince: delegatedSince,
    );
  }
}

/// Typed delegation capability used by the native staking control only.
abstract interface class DelegationApi {
  Future<DelegationStatus?> get({required String walletAddress});

  Future<DelegationStatus> set({
    required String walletAddress,
    required bool delegated,
  });
}

class _HttpDelegationApi implements DelegationApi {
  _HttpDelegationApi({
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
  Future<DelegationStatus?> get({required String walletAddress}) async {
    _validateWalletAddress(walletAddress);
    try {
      final data = await _transport.getData(
        '/delegation',
        queryParameters: {'wallet_address': walletAddress},
        expectedStatuses: const {404},
      );
      if (data is! Map<String, dynamic>) {
        throw DelegationApiException(502, 'Invalid delegation response.');
      }
      return DelegationStatus.fromJson(data);
    } on _SessionApiException catch (error) {
      if (error.statusCode == 404) return null;
      throw DelegationApiException(
        error.statusCode,
        error.message,
        body: error.body,
      );
    }
  }

  @override
  Future<DelegationStatus> set({
    required String walletAddress,
    required bool delegated,
  }) async {
    _validateWalletAddress(walletAddress);
    if (!_writesEnabled) {
      throw DelegationApiException(503, _delegationWritesDisabledMessage);
    }
    try {
      final data = await _transport.postData(
        '/delegation',
        body: {
          'wallet_address': walletAddress,
          'delegated': delegated,
        },
      );
      if (data is! Map<String, dynamic>) {
        throw DelegationApiException(502, 'Invalid delegation response.');
      }
      return DelegationStatus.fromJson(data);
    } on _SessionApiException catch (error) {
      throw DelegationApiException(
        error.statusCode,
        error.message,
        body: error.body,
      );
    }
  }

  void _validateWalletAddress(String walletAddress) {
    if (walletAddress.isEmpty || walletAddress != walletAddress.trim()) {
      throw DelegationApiException(400, 'Invalid wallet address.');
    }
  }

  void dispose() => _transport.dispose();
}

final delegationApiProvider = Provider<DelegationApi>((ref) {
  final api = _HttpDelegationApi(
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
