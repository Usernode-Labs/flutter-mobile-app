import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' as rust;

typedef SessionAuthoritySupportDirectory = Future<Directory> Function();
typedef SessionAuthorityAdmissionJson = String Function({
  required String directory,
});
typedef SessionAuthorityBootstrapJson = String Function({
  required String directory,
  required String network,
  required String sessionId,
});
typedef SessionAuthorityCommandJson = Future<String> Function({
  required String directory,
  required String request,
});
typedef SessionAuthorityTerminalReporter = void Function(
  Map<String, Object?> details,
);

/// The exact credential attached to one authenticated request.
///
/// Only [SessionAuthorityGateway.captureCredential] can construct this value;
/// downstream callers may retain it but cannot manufacture a partial lease.
@immutable
class AuthCredentialLease {
  const AuthCredentialLease._({
    required this.epoch,
    required this.token,
    required this.sessionId,
    required this.credentialRef,
    required this.credentialGeneration,
  });

  final int epoch;
  final String token;
  final String sessionId;
  final String credentialRef;
  final int credentialGeneration;

  bool matchesIdentity(Identity identity) =>
      epoch == identity.epoch &&
      // Null authority fields exist only in the isolated compatibility
      // controller path. Production identities compare the complete tuple.
      (identity.sessionId == null || sessionId == identity.sessionId) &&
      (identity.credentialRef == null ||
          credentialRef == identity.credentialRef) &&
      (identity.credentialGeneration == null ||
          credentialGeneration == identity.credentialGeneration);

  @override
  String toString() => 'AuthCredentialLease(epoch: $epoch, '
      'sessionId: $sessionId, generation: $credentialGeneration, '
      'token: <redacted>)';
}

/// Exact Ready owner for one account-scoped effect.
///
/// Construction is private so retaining an account ID or address cannot be
/// upgraded into authority by downstream code.
@immutable
class AccountCapability {
  const AccountCapability._({
    required this.sessionId,
    required this.userNamespace,
    required this.network,
    required this.accountId,
    required this.address,
    required this.bucket,
    required this.secretKeyRef,
  });

  final String sessionId;
  final String userNamespace;
  final String network;
  final String accountId;
  final String address;
  final String bucket;
  final String secretKeyRef;
}

/// Exact activation owner for the one-time account reconciliation effect.
@immutable
class AccountReconciliationLease {
  const AccountReconciliationLease._({
    required this.sessionId,
    required this.credentialRef,
    required this.credentialGeneration,
    required this.userNamespace,
    required this.network,
    required this.address,
  });

  final String sessionId;
  final String credentialRef;
  final int credentialGeneration;
  final String userNamespace;
  final String network;
  final String address;
}

/// Exact app-session and top-frame realm attached to one WebView callback.
@immutable
class WebViewRealmLease {
  const WebViewRealmLease._({
    required this.sessionId,
    required this.realmId,
  });

  final String sessionId;
  final String realmId;
}

typedef SessionAuthorityCredentialIssuer = AuthCredentialLease Function({
  required Identity identity,
  required String token,
});

/// Thin transport to the single Rust session-authority actor.
///
/// This class owns no lifecycle state or recovery policy. It resolves the one
/// installation directory, transports JSON commands, and rejects malformed
/// transport responses before callers act on them.
class SessionAuthorityGateway {
  SessionAuthorityGateway({
    SessionAuthoritySupportDirectory? supportDirectory,
    SessionAuthorityAdmissionJson? admissionJson,
    SessionAuthorityBootstrapJson? bootstrapJson,
    SessionAuthorityCommandJson? commandJson,
    SessionAuthorityTerminalReporter? terminalReporter,
  })  : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
        _admissionJson = admissionJson ?? rust.sessionAuthorityAdmissionJson,
        _bootstrapJson =
            bootstrapJson ?? rust.sessionAuthorityBootstrapLoggedOut,
        _commandJson = commandJson ?? rust.sessionAuthorityCommandJson,
        _terminalReporter = terminalReporter ?? _reportTerminalToProduction;

  final SessionAuthoritySupportDirectory _supportDirectory;
  final SessionAuthorityAdmissionJson _admissionJson;
  final SessionAuthorityBootstrapJson _bootstrapJson;
  final SessionAuthorityCommandJson _commandJson;
  final SessionAuthorityTerminalReporter _terminalReporter;

  String? _directory;

  String get directory =>
      _directory ??
      (throw StateError('Session authority directory is not initialized'));

  /// Captures one immutable, complete credential tuple before async work.
  static AuthCredentialLease captureCredential({
    required Identity identity,
    required String token,
  }) {
    if (!identity.isAuthenticated) {
      throw const StaleAuthCredentialException();
    }
    final sessionId =
        _requiredCredentialField(identity.sessionId, 'session ID');
    final credentialRef =
        _requiredCredentialField(identity.credentialRef, 'reference');
    final credentialGeneration = identity.credentialGeneration;
    if (credentialGeneration == null || credentialGeneration <= 0) {
      throw const StaleAuthCredentialException();
    }
    final exactToken = _requiredCredentialField(token, 'bearer');
    return AuthCredentialLease._(
      epoch: identity.epoch,
      token: exactToken,
      sessionId: sessionId,
      credentialRef: credentialRef,
      credentialGeneration: credentialGeneration,
    );
  }

  /// Issues a complete account capability only from a settled Ready identity.
  AccountCapability captureAccountCapability({
    required Identity identity,
    required String userNamespace,
    required String network,
  }) {
    if (identity.phase != IdentityPhase.ready) {
      throw const StaleAuthCredentialException();
    }
    final sessionId =
        _requiredCredentialField(identity.sessionId, 'session ID');
    final namespace = _requiredCredentialField(userNamespace, 'user namespace');
    final exactNetwork = _requiredCredentialField(network, 'network');
    final accountId =
        _requiredCredentialField(identity.accountId, 'account ID');
    final address = _requiredCredentialField(identity.address, 'address');
    return AccountCapability._(
      sessionId: sessionId,
      userNamespace: namespace,
      network: exactNetwork,
      accountId: accountId,
      address: address,
      bucket: NetworkPrefs.bucketForAddress(address),
      secretKeyRef: '$exactNetwork:account:$accountId:secretKey',
    );
  }

  /// Issues the activation-only owner used while the backend-provisioned
  /// address is reconciled with retained local account data.
  AccountReconciliationLease captureAccountReconciliationLease({
    required Identity identity,
    required String userNamespace,
    required String network,
    required String address,
  }) {
    if (identity.phase != IdentityPhase.reconciling) {
      throw const StaleAuthCredentialException();
    }
    final sessionId =
        _requiredCredentialField(identity.sessionId, 'session ID');
    final credentialRef = _requiredCredentialField(
        identity.credentialRef, 'credential reference');
    final credentialGeneration = identity.credentialGeneration;
    if (credentialGeneration == null || credentialGeneration <= 0) {
      throw const StaleAuthCredentialException();
    }
    return AccountReconciliationLease._(
      sessionId: sessionId,
      credentialRef: credentialRef,
      credentialGeneration: credentialGeneration,
      userNamespace: _requiredCredentialField(
        userNamespace,
        'user namespace',
      ),
      network: _requiredCredentialField(network, 'network'),
      address: _requiredCredentialField(address, 'address'),
    );
  }

  /// Captures the exact session/realm pair at bridge admission.
  WebViewRealmLease captureWebViewRealmLease({
    required Identity identity,
    required String realmId,
  }) {
    if (identity.phase == IdentityPhase.unknown) {
      throw const StaleAuthCredentialException();
    }
    return WebViewRealmLease._(
      sessionId: _requiredCredentialField(identity.sessionId, 'session ID'),
      realmId: _requiredCredentialField(realmId, 'WebView realm ID'),
    );
  }

  Future<Map<String, dynamic>> admission() async {
    final directory = await _resolveDirectory();
    return _decodeObject(_admissionJson(directory: directory));
  }

  Future<Map<String, dynamic>> bootstrapLoggedOut({
    required String network,
    required String sessionId,
  }) async {
    final directory = await _resolveDirectory();
    return _decodeObject(
      _bootstrapJson(
        directory: directory,
        network: network,
        sessionId: sessionId,
      ),
    );
  }

  Future<Map<String, dynamic>> command(Map<String, dynamic> request) async {
    final directory = await _resolveDirectory();
    final response = _decodeObject(
      await _commandJson(
        directory: directory,
        request: jsonEncode(request),
      ),
    );
    _reportTerminal(response);
    if (response['status'] == 'rejected') {
      throw SessionAuthorityRejected(
        reason: response['reason'] is String
            ? response['reason'] as String
            : 'session-authority command was rejected',
        record: _optionalObject(response['record']),
      );
    }
    if (response['status'] != 'ok') {
      throw const SessionAuthorityProtocolException(
        'session-authority response has an unknown status',
      );
    }
    return response;
  }

  void _reportTerminal(Map<String, dynamic> response) {
    final telemetry = response['telemetry'];
    if (telemetry is! Map) return;
    try {
      _terminalReporter(Map<String, Object?>.from(telemetry));
    } catch (_) {
      // Telemetry must never change authority protocol handling.
    }
  }

  Future<String> _resolveDirectory() async {
    final existing = _directory;
    if (existing != null) return existing;
    final support = await _supportDirectory();
    final resolved = '${support.path}/session-authority';
    _directory = resolved;
    return resolved;
  }
}

String _requiredCredentialField(String? value, String field) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    throw const StaleAuthCredentialException();
  }
  return normalized;
}

void _reportTerminalToProduction(Map<String, Object?> details) {
  final reason = details['reason'];
  final phase = details['phase'];
  final platform = details['platform'];
  if (reason is! String || phase is! String || platform is! String) {
    return;
  }
  ObservabilityReportingService.instance
      .reportSessionAuthorityTerminalEscalation(
    reason: reason,
    phase: phase,
    platform: platform,
  );
}

class SessionAuthorityRejected implements Exception {
  const SessionAuthorityRejected({required this.reason, this.record});

  final String reason;
  final Map<String, dynamic>? record;

  @override
  String toString() => 'SessionAuthorityRejected($reason)';
}

class SessionAuthorityProtocolException implements Exception {
  const SessionAuthorityProtocolException(this.message);

  final String message;

  @override
  String toString() => 'SessionAuthorityProtocolException($message)';
}

Map<String, dynamic> _decodeObject(String encoded) {
  try {
    return _requiredObject(jsonDecode(encoded), 'response');
  } on SessionAuthorityProtocolException {
    rethrow;
  } catch (error) {
    throw SessionAuthorityProtocolException(
      'session-authority response is not valid JSON: $error',
    );
  }
}

Map<String, dynamic> _requiredObject(Object? value, String field) {
  if (value is! Map) {
    throw SessionAuthorityProtocolException(
      'session-authority $field is not an object',
    );
  }
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    throw SessionAuthorityProtocolException(
      'session-authority $field has non-string keys',
    );
  }
}

Map<String, dynamic>? _optionalObject(Object? value) =>
    value == null ? null : _requiredObject(value, 'record');
