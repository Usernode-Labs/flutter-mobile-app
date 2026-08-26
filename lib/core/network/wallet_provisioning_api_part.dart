part of 'legacy_session_capabilities.dart';

const _walletWritesDisabledMessage =
    'Backend write requests are disabled in view-only mode.';

class WalletProvisioningException implements Exception {
  WalletProvisioningException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final Object? body;

  @override
  String toString() => 'WalletProvisioningException($statusCode, $message)';
}

/// Exact account material returned by the temporary v4 provisioning seam.
///
/// Protocol 2 replaces the raw [secretKey] with a platform-vault reference.
class WalletProvisioningResult {
  const WalletProvisioningResult({
    required this.address,
    required this.publicKey,
    required this.secretKey,
    required this.newlyAllocated,
    required this.bpReleased,
  });

  final String address;
  final String publicKey;
  final String secretKey;
  final bool newlyAllocated;
  final bool bpReleased;

  factory WalletProvisioningResult.fromJson(Map<String, Object?> json) {
    return WalletProvisioningResult(
      address: _requiredCanonicalString(json, 'address'),
      publicKey: _requiredCanonicalString(json, 'public_key'),
      secretKey: _requiredCanonicalString(json, 'secret_key'),
      newlyAllocated: json['newly_allocated'] == true,
      bpReleased: json['bp_released'] == true,
    );
  }
}

String _requiredCanonicalString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty || value != value.trim()) {
    throw WalletProvisioningException(
      502,
      'Invalid wallet provisioning response: $field.',
    );
  }
  return value;
}

/// The only Flutter capability that may provision a platform wallet.
abstract interface class WalletProvisioningApi {
  Future<WalletProvisioningResult> provision();
}

class _HttpWalletProvisioningApi implements WalletProvisioningApi {
  _HttpWalletProvisioningApi({
    String? baseUrl,
    http.Client? httpClient,
    bool? writesEnabled,
    Future<String?> Function()? tokenProvider,
    Future<void> Function(AuthCredentialLease credential)? onUnauthorized,
    Future<void> Function(int epoch)? onCredentialMissing,
  })  : _transport = _SessionApiTransport(
          baseUrl: baseUrl,
          httpClient: httpClient,
          tokenProvider: tokenProvider,
          onUnauthorized: onUnauthorized,
          onCredentialMissing: onCredentialMissing,
        ),
        _writesEnabled = writesEnabled ?? !AppConfig.viewOnly;

  final _SessionApiTransport _transport;
  final bool _writesEnabled;

  @override
  Future<WalletProvisioningResult> provision() async {
    if (!_writesEnabled) {
      throw WalletProvisioningException(503, _walletWritesDisabledMessage);
    }
    try {
      final data = await _transport.postData(
        '/wallet/provision',
        body: const {},
      );
      if (data is! Map<String, dynamic>) {
        throw WalletProvisioningException(
          502,
          'Invalid wallet provisioning response.',
        );
      }
      return WalletProvisioningResult.fromJson(data);
    } on _SessionApiException catch (error) {
      throw WalletProvisioningException(
        error.statusCode,
        error.message,
        body: error.body,
      );
    }
  }

  void dispose() => _transport.dispose();
}

final walletProvisioningApiProvider = Provider<WalletProvisioningApi>((ref) {
  final api = _HttpWalletProvisioningApi(
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
