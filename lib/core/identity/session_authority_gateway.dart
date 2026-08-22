import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

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
        _terminalReporter = terminalReporter ?? _reportTerminalToProduction,
        _clientId = _newClientId();

  final SessionAuthoritySupportDirectory _supportDirectory;
  final SessionAuthorityAdmissionJson _admissionJson;
  final SessionAuthorityBootstrapJson _bootstrapJson;
  final SessionAuthorityCommandJson _commandJson;
  final SessionAuthorityTerminalReporter _terminalReporter;
  final String _clientId;

  String? _directory;

  String get directory =>
      _directory ??
      (throw StateError('Session authority directory is not initialized'));

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

  Future<bool> _runVerifiedMutation(
    rust.SessionEffectPermit permit,
    Future<bool> Function() mutation,
  ) async {
    try {
      final verified = await mutation();
      if (verified) {
        rust.sessionAuthorityEffectPermitMarkHandoff(permit: permit);
      }
      return verified;
    } finally {
      rust.sessionAuthorityEffectPermitRelease(permit: permit);
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
