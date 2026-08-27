import 'dart:async';

import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';

final class NativeSessionException implements Exception {
  const NativeSessionException(
    this.code,
    this.message, {
    this.statusCode,
    this.latestMutationRevision,
  });

  final String code;
  final String message;
  final int? statusCode;
  final int? latestMutationRevision;

  @override
  String toString() => 'NativeSessionException($code)';
}

/// The narrow transport surface admitted into the trusted Social WebView.
///
/// Implementations retain the process root, opaque native session client, and
/// identity publisher privately. Failures remain fail-closed through these
/// exact methods. Feature code receives neither native authority nor a generic
/// lifecycle host.
abstract interface class NativeSessionBridgeIngress {
  /// Read-only terminal latch used by the WebView boundary to avoid loading an
  /// authenticated document after a retirement event that preceded mounting.
  bool get terminallyRetired;

  /// Emits once when the current process must stop rendering an authenticated
  /// document until relaunch.
  Stream<void> get terminalRetirements;

  Future<Map<String, Object?>> establishNativeSession({
    required Map<String, dynamic> payload,
    required String realmMarker,
  });

  Future<void> logoutNativeSession({required String realmMarker});

  /// Admits one feature operation for the exact Social document/session pair.
  ///
  /// The opaque realm claim is compared inside the private composition root.
  /// Callers receive only the immutable identity and an operation-scoped
  /// facade; native clients and publication authority never cross this seam.
  Future<T> runSessionOperation<T>({
    required String realmMarker,
    required String realmSessionClaim,
    required FutureOr<T> Function(
      SessionIdentityProjection identity,
      SessionOperation operation,
    ) body,
  });
}
