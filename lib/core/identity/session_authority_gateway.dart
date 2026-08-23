import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/network/request_written_http_transport.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
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
typedef SessionAuthorityAcquireHttpEffect = rust.SessionEffectPermit Function({
  required String directory,
  required String sessionId,
  required String credentialRef,
  required BigInt credentialGeneration,
  required String operationId,
  required String engineId,
});
typedef SessionAuthorityAcquireWorkflowHttpEffect
    = SessionAuthorityAcquireHttpEffect;
typedef SessionAuthorityAcquirePushEffect = rust.SessionEffectPermit Function({
  required String directory,
  required String sessionId,
  required String operationId,
  required String engineId,
});
typedef SessionAuthorityEffectPermitAction = void Function({
  required rust.SessionEffectPermit permit,
});
typedef SessionAuthorityRequestWriter = Future<http.StreamedResponse> Function(
  http.BaseRequest request, {
  required RequestWrittenCallback onRequestWritten,
});

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

typedef SessionAuthorityCredentialIssuer = AuthCredentialLease Function({
  required Identity identity,
  required String token,
});
typedef SessionAuthorityCredentialRequestSender = Future<http.StreamedResponse>
    Function({
  required AuthCredentialLease credential,
  required http.BaseRequest request,
  required String operationId,
});
typedef SessionAuthorityWorkflowCredentialRequestSender
    = Future<http.StreamedResponse> Function({
  required String appSessionId,
  required AuthCredentialLease credential,
  required http.BaseRequest request,
  required String operationId,
});
typedef SessionAuthorityPushEffectRunner = Future<T> Function<T>({
  required String sessionId,
  required String operationId,
  required Future<T> Function() effect,
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
    SessionAuthorityAcquireHttpEffect? acquireHttpEffect,
    SessionAuthorityAcquireWorkflowHttpEffect? acquireWorkflowHttpEffect,
    SessionAuthorityAcquirePushEffect? acquirePushEffect,
    SessionAuthorityEffectPermitAction? markEffectHandoff,
    SessionAuthorityEffectPermitAction? releaseEffectPermit,
    SessionAuthorityRequestWriter? requestWriter,
  })  : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
        _admissionJson = admissionJson ?? rust.sessionAuthorityAdmissionJson,
        _bootstrapJson =
            bootstrapJson ?? rust.sessionAuthorityBootstrapLoggedOut,
        _commandJson = commandJson ?? rust.sessionAuthorityCommandJson,
        _terminalReporter = terminalReporter ?? _reportTerminalToProduction,
        _acquireHttpEffect =
            acquireHttpEffect ?? rust.sessionAuthorityAcquireHttpEffect,
        _acquireWorkflowHttpEffect = acquireWorkflowHttpEffect ??
            rust.sessionAuthorityAcquireWorkflowHttpEffect,
        _acquirePushEffect =
            acquirePushEffect ?? rust.sessionAuthorityAcquirePushEffect,
        _markEffectHandoff =
            markEffectHandoff ?? rust.sessionAuthorityEffectPermitMarkHandoff,
        _releaseEffectPermit =
            releaseEffectPermit ?? rust.sessionAuthorityEffectPermitRelease,
        _requestWriter = requestWriter ?? RequestWrittenHttpTransport().send,
        _clientId = _newClientId();

  final SessionAuthoritySupportDirectory _supportDirectory;
  final SessionAuthorityAdmissionJson _admissionJson;
  final SessionAuthorityBootstrapJson _bootstrapJson;
  final SessionAuthorityCommandJson _commandJson;
  final SessionAuthorityTerminalReporter _terminalReporter;
  final SessionAuthorityAcquireHttpEffect _acquireHttpEffect;
  final SessionAuthorityAcquireWorkflowHttpEffect _acquireWorkflowHttpEffect;
  final SessionAuthorityAcquirePushEffect _acquirePushEffect;
  final SessionAuthorityEffectPermitAction _markEffectHandoff;
  final SessionAuthorityEffectPermitAction _releaseEffectPermit;
  final SessionAuthorityRequestWriter _requestWriter;
  final String _clientId;

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

  /// Runs one credential-store mutation under the exact Rust-owned Ready
  /// lease. A true result means secure storage also verified the write, which
  /// is this sink's irreversible handoff point.
  Future<bool> runCredentialStoreMutation({
    required String sessionId,
    required String credentialRef,
    required int credentialGeneration,
    required String operationId,
    required Future<bool> Function() mutation,
  }) async {
    final permit = rust.sessionAuthorityAcquireCredentialEffect(
      directory: await _resolveDirectory(),
      sessionId: sessionId,
      credentialRef: credentialRef,
      credentialGeneration: BigInt.from(credentialGeneration),
      operationId: operationId,
      engineId: _clientId,
    );
    return _runVerifiedMutation(permit, mutation);
  }

  /// Runs one resumable-workflow row mutation only while its exact app
  /// session remains Ready and has no durable revocation tombstone.
  Future<bool> runWorkflowStoreMutation({
    required String appSessionId,
    required String operationId,
    required Future<bool> Function() mutation,
  }) async {
    final permit = rust.sessionAuthorityAcquireWorkflowEffect(
      directory: await _resolveDirectory(),
      sessionId: appSessionId,
      operationId: operationId,
      engineId: _clientId,
    );
    return _runVerifiedMutation(permit, mutation);
  }

  /// Sends one exact credential request and releases its process permit at the
  /// request-written handoff, independently of response completion.
  Future<http.StreamedResponse> sendCredentialRequest({
    required AuthCredentialLease credential,
    required http.BaseRequest request,
    required String operationId,
  }) async {
    return _sendCredentialRequest(
      credential: credential,
      request: request,
      operationId: operationId,
      acquire: _acquireHttpEffect,
    );
  }

  /// Sends one durable-workflow request only when the row owner and exact
  /// credential name the same current, unrevoked Ready session.
  Future<http.StreamedResponse> sendWorkflowCredentialRequest({
    required String appSessionId,
    required AuthCredentialLease credential,
    required http.BaseRequest request,
    required String operationId,
  }) {
    final exactAppSessionId = _requiredCredentialField(
      appSessionId,
      'workflow session ID',
    );
    if (credential.sessionId != exactAppSessionId) {
      throw const StaleAuthCredentialException();
    }
    return _sendCredentialRequest(
      credential: credential,
      request: request,
      operationId: operationId,
      acquire: _acquireWorkflowHttpEffect,
    );
  }

  Future<http.StreamedResponse> _sendCredentialRequest({
    required AuthCredentialLease credential,
    required http.BaseRequest request,
    required String operationId,
    required SessionAuthorityAcquireHttpEffect acquire,
  }) async {
    final sessionId = credential.sessionId;
    final credentialRef = credential.credentialRef;
    final credentialGeneration = credential.credentialGeneration;
    if (credentialGeneration <= 0 ||
        request.headers['authorization'] != 'Bearer ${credential.token}') {
      throw const StaleAuthCredentialException();
    }

    final directory = await _resolveDirectory();
    final permit = _acquireOrThrowStale(
      () => acquire(
        directory: directory,
        sessionId: sessionId,
        credentialRef: credentialRef,
        credentialGeneration: BigInt.from(credentialGeneration),
        operationId: operationId,
        engineId: _clientId,
      ),
    );
    var released = false;
    void release() {
      if (released) return;
      released = true;
      _releaseEffectPermit(permit: permit);
    }

    try {
      return await _requestWriter(
        request,
        onRequestWritten: () {
          _markEffectHandoff(permit: permit);
          release();
        },
      );
    } finally {
      release();
    }
  }

  /// Runs one native push effect for the exact Rust-owned Ready session. The
  /// plugin Future's creation is the platform-channel submission handoff.
  Future<T> runPushEffect<T>({
    required String sessionId,
    required String operationId,
    required Future<T> Function() effect,
  }) async {
    final exactSessionId = _requiredCredentialField(sessionId, 'session ID');
    final directory = await _resolveDirectory();
    final permit = _acquireOrThrowStale(
      () => _acquirePushEffect(
        directory: directory,
        sessionId: exactSessionId,
        operationId: operationId,
        engineId: _clientId,
      ),
    );
    late Future<T> result;
    try {
      result = effect();
      _markEffectHandoff(permit: permit);
    } finally {
      _releaseEffectPermit(permit: permit);
    }
    return result;
  }

  rust.SessionEffectPermit _acquireOrThrowStale(
    rust.SessionEffectPermit Function() acquire,
  ) {
    try {
      return acquire();
    } on StaleAuthCredentialException {
      rethrow;
    } catch (_) {
      throw const StaleAuthCredentialException();
    }
  }

  Future<bool> _runVerifiedMutation(
    rust.SessionEffectPermit permit,
    Future<bool> Function() mutation,
  ) async {
    try {
      final verified = await mutation();
      if (verified) {
        _markEffectHandoff(permit: permit);
      }
      return verified;
    } finally {
      _releaseEffectPermit(permit: permit);
    }
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

String _newClientId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return 'flutter-${base64Url.encode(bytes).replaceAll('=', '')}';
}

void _reportTerminalToProduction(Map<String, Object?> details) {
  final reason = details['reason'];
  final phase = details['phase'];
  final sink = details['sink'];
  final platform = details['platform'];
  if (reason is! String ||
      phase is! String ||
      sink is! String ||
      platform is! String) {
    return;
  }
  ObservabilityReportingService.instance
      .reportSessionAuthorityTerminalEscalation(
    reason: reason,
    phase: phase,
    sink: sink,
    platform: platform,
    operationId: details['operation_id'] as String?,
    engineId: details['engine_id'] as String?,
    handedOff: details['handed_off'] as bool?,
    heldForMs: details['held_for_ms'] as int?,
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
