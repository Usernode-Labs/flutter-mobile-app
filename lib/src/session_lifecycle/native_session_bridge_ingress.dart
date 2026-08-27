final class NativeSessionException implements Exception {
  const NativeSessionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'NativeSessionException($code)';
}

/// The narrow transport surface admitted into the trusted Social WebView.
///
/// Implementations retain the process root, opaque native session client, and
/// identity publisher privately. A non-null ingress means protocol 2 has been
/// selected even when native health is recovery-required; failures reject
/// through these methods and never reopen the legacy bridge. Feature code
/// receives neither native authority nor a generic host.
abstract interface class NativeSessionBridgeIngress {
  Future<Map<String, Object?>> establishNativeSession({
    required Map<String, dynamic> payload,
    required String realmMarker,
  });

  Future<void> logoutNativeSession({required String realmMarker});
}
