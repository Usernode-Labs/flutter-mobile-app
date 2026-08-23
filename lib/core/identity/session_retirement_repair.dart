import 'dart:async';

import 'package:crypto_mobile_app/core/identity/session_authority_cleanup.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/src/rust/node/mobile.dart';

final _log = LoggingService.instance.withTag('usernode/RetirementRepairScope');

typedef RetireRuntimeAuthority = Future<bool> Function({
  required String directory,
  required String sessionId,
  required String transitionId,
});

/// Capable UI executor for the phase currently named by the Rust journal.
///
/// Rust owns transition state, durable attempts, bounds and every phase
/// decision. This scope keeps only a request-local acknowledgement cursor and
/// invokes the one idempotent platform effect Rust instructs it to perform.
class RetirementRepairScope {
  RetirementRepairScope({
    required SessionAuthorityGateway authority,
    required AuthTokenStore tokenStore,
    required AuthGuestFlag guestFlag,
    required Future<bool> Function() revokeNativeAdmission,
    required Future<bool> Function() clearWebSessionData,
    RetireRuntimeAuthority? retireRuntimeAuthority,
  })  : _authority = authority,
        _tokenStore = tokenStore,
        _guestFlag = guestFlag,
        _revokeNativeAdmission = revokeNativeAdmission,
        _clearWebSessionData = clearWebSessionData,
        _retireRuntimeAuthority =
            retireRuntimeAuthority ?? _defaultRetireRuntimeAuthority;

  final SessionAuthorityGateway _authority;
  final AuthTokenStore _tokenStore;
  final AuthGuestFlag _guestFlag;
  final Future<bool> Function() _revokeNativeAdmission;
  final Future<bool> Function() _clearWebSessionData;
  final RetireRuntimeAuthority _retireRuntimeAuthority;

  static Future<bool> _defaultRetireRuntimeAuthority({
    required String directory,
    required String sessionId,
    required String transitionId,
  }) async {
    await MobileNode.retireSessionIfAuthoritative(
      authority: RetiringSessionEnvelope(
        authorityDirectory: directory,
        sessionId: sessionId,
        transitionId: transitionId,
        operationId: 'retire-runtime:$transitionId',
        engineId: 'retirement-repair',
      ),
    );
    return true;
  }

  /// Returns the committed `LoggedOut` acknowledgement, or null after Rust
  /// records a terminal outcome. [initialResponse] is the acknowledged
  /// read/entry that selected this exact repair transition.
  Future<Map<String, dynamic>?> repair(
    Map<String, dynamic> initialResponse,
  ) async {
    final cursor = _RetirementCursor(_authority, initialResponse);
    final invocation = Stopwatch()..start();
    while (true) {
      final authorityState = cursor.state;
      final kind = authorityState['kind'];
      if (kind == 'logged_out') return cursor.response;
      if (kind == 'terminal_reset_required') return null;
      if (kind != 'retiring') {
        throw StateError('Retirement repair found authority state $kind');
      }

      final phase = _string(authorityState['phase'], 'retirement.phase');
      final sessionId =
          _string(authorityState['session_id'], 'retirement.session_id');
      final transitionId = _string(
        authorityState['transition_id'],
        'retirement.transition_id',
      );
      if (phase == 'commit_logged_out') {
        await cursor.evidence(
          const {'kind': 'verified'},
          remainingBudgetMs: _remainingBudget(invocation),
        );
        continue;
      }
      if (phase == 'tombstone_work') {
        await _repairTombstone(cursor, invocation);
        continue;
      }

      final instruction = await cursor.evidence(
        const {'kind': 'needs_invocation'},
        remainingBudgetMs: _remainingBudget(invocation),
      );
      final outcome = _map(instruction['outcome'], 'outcome');
      if (outcome['kind'] != 'retirement_invoke') continue;
      if (outcome['phase'] != phase) {
        throw StateError('Retirement instruction changed phase unexpectedly');
      }
      final timeoutMs = _integer(outcome['timeout_ms'], 'outcome.timeout_ms');
      final completed = await _invokeEffect(
        phase: phase,
        sessionId: sessionId,
        transitionId: transitionId,
        timeout: Duration(milliseconds: timeoutMs),
      );
      if (!completed) continue;
      await cursor.evidence(
        const {'kind': 'verified'},
        remainingBudgetMs: _remainingBudget(invocation),
      );
    }
  }

  Future<void> _repairTombstone(
    _RetirementCursor cursor,
    Stopwatch invocation,
  ) async {
    final status = await cursor.command(
      const {'command': 'retirement_tombstone', 'invoke': false},
    );
    if (_map(status['outcome'], 'outcome')['verified'] == true) {
      await cursor.evidence(
        const {'kind': 'verified'},
        remainingBudgetMs: _remainingBudget(invocation),
      );
      return;
    }
    final instruction = await cursor.evidence(
      const {'kind': 'needs_invocation'},
      remainingBudgetMs: _remainingBudget(invocation),
    );
    final outcome = _map(instruction['outcome'], 'outcome');
    if (outcome['kind'] != 'retirement_invoke') return;
    if (outcome['phase'] != 'tombstone_work') {
      throw StateError('Tombstone instruction changed phase unexpectedly');
    }
    final invoked = await cursor.command(
      const {'command': 'retirement_tombstone', 'invoke': true},
    );
    if (_map(invoked['outcome'], 'outcome')['verified'] == true) {
      await cursor.evidence(
        const {'kind': 'verified'},
        remainingBudgetMs: _remainingBudget(invocation),
      );
    }
  }

  Future<bool> _invokeEffect({
    required String phase,
    required String sessionId,
    required String transitionId,
    required Duration timeout,
  }) async {
    Future<bool> invoke() => switch (phase) {
          'revoke_native_admission' => _revokeNativeAdmission(),
          'revoke_runtime' => _retireRuntimeAuthority(
              directory: _authority.directory,
              sessionId: sessionId,
              transitionId: transitionId,
            ),
          'clear_credential' => _clearCredential(sessionId),
          'clear_webview' => _clearWebSessionData(),
          _ => throw StateError('Unsupported retirement phase $phase'),
        };
    try {
      return await invoke().timeout(timeout);
    } catch (error, stackTrace) {
      _log.error(
        'Retirement effect could not be confirmed',
        error: error,
        stackTrace: stackTrace,
        context: {'phase': phase},
      );
      return false;
    }
  }

  Future<bool> _clearCredential(String sessionId) async {
    if (!await _tokenStore.clearSessionCredentials(sessionId)) return false;
    return clearCompatibilitySessionAuthority(_guestFlag);
  }

  static int _remainingBudget(Stopwatch invocation) {
    const budgetMs = 30000;
    final remaining = budgetMs - invocation.elapsedMilliseconds;
    return remaining > 0 ? remaining : 0;
  }
}

class _RetirementCursor {
  _RetirementCursor(this._authority, Map<String, dynamic> initialResponse) {
    _adopt(initialResponse);
  }

  final SessionAuthorityGateway _authority;
  late Map<String, dynamic> _revision;
  late Map<String, dynamic> _record;
  late Map<String, dynamic> _response;

  Map<String, dynamic> get state => _map(_record['state'], 'record.state');
  Map<String, dynamic> get response => _response;

  Future<Map<String, dynamic>> command(Map<String, dynamic> command) async {
    final response =
        await _authority.command({...command, 'expected': _revision});
    _adopt(response);
    return response;
  }

  Future<Map<String, dynamic>> evidence(
    Map<String, dynamic> evidence, {
    required int remainingBudgetMs,
  }) =>
      command({
        'command': 'recover_retirement',
        'evidence': evidence,
        'remaining_budget_ms': remainingBudgetMs,
      });

  void _adopt(Map<String, dynamic> response) {
    _response = response;
    _revision = _map(response['revision'], 'revision');
    _record = _map(response['record'], 'record');
  }
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is! Map) throw StateError('Session authority $field is not a map');
  return Map<String, dynamic>.from(value);
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw StateError('Session authority $field is missing');
  }
  return value;
}

int _integer(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw StateError('Session authority $field is invalid');
  }
  return value;
}
