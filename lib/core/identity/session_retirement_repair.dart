import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/src/rust/node/mobile.dart';

typedef RetireRuntimeAuthority = Future<void> Function({
  required String directory,
  required int expectedSequence,
  required String sessionId,
  required String successorLoggedOutSessionId,
  required String? successorNetwork,
  required String transitionId,
});

/// The exact retirement could not finish, but replaying it is safe.
///
/// The durable journal keeps the reserved successor. Callers remain on their
/// in-process recovery surface and invoke the same transition again.
class SessionRetirementRetryableException implements Exception {
  const SessionRetirementRetryableException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SessionRetirementRetryableException($message)';
}

/// Executes the one global retirement transition selected by the journal.
///
/// Rust owns the `Ready -> Retiring` CAS and exact runtime shutdown under its
/// process-global supervisor. Flutter owns only the detached WebView realm and
/// the final `Retiring -> LoggedOut` acknowledgement. Replaying this method
/// uses the same immutable owner tuple; it never invents phases or attempts.
class RetirementRepairScope {
  RetirementRepairScope({
    required SessionAuthorityGateway authority,
    required Future<bool> Function() clearWebSessionData,
    RetireRuntimeAuthority? retireRuntimeAuthority,
  })  : _authority = authority,
        _clearWebSessionData = clearWebSessionData,
        _retireRuntimeAuthority =
            retireRuntimeAuthority ?? _defaultRetireRuntimeAuthority;

  final SessionAuthorityGateway _authority;
  final Future<bool> Function() _clearWebSessionData;
  final RetireRuntimeAuthority _retireRuntimeAuthority;

  static Future<void> _defaultRetireRuntimeAuthority({
    required String directory,
    required int expectedSequence,
    required String sessionId,
    required String successorLoggedOutSessionId,
    required String? successorNetwork,
    required String transitionId,
  }) async {
    await MobileNode.retireSessionIfAuthoritative(
      authority: RetiringSessionEnvelope(
        authorityDirectory: directory,
        expectedSequence: BigInt.from(expectedSequence),
        sessionId: sessionId,
        successorLoggedOutSessionId: successorLoggedOutSessionId,
        successorNetwork: successorNetwork,
        transitionId: transitionId,
        operationId: 'retire-session:$transitionId',
        engineId: 'flutter-ui',
      ),
    );
  }

  Future<Map<String, dynamic>> repair(
    Map<String, dynamic> initialResponse, {
    String? successorLoggedOutSessionId,
    String? successorNetwork,
    String? transitionId,
  }) async {
    final initial = _record(initialResponse);
    final initialState = _map(initial['state'], 'record.state');
    final initialKind = initialState['kind'];
    if (initialKind == 'logged_out') return initialResponse;

    final retirement = switch (initialKind) {
      'ready' => _RetirementOwner(
          expectedSequence: _sequence(initial),
          sessionId: _string(initialState['session_id'], 'ready.session_id'),
          successorLoggedOutSessionId: _string(
            successorLoggedOutSessionId,
            'successor_logged_out_session_id',
          ),
          successorNetwork: successorNetwork,
          transitionId: _string(transitionId, 'transition_id'),
        ),
      'retiring' => _RetirementOwner.fromState(
          expectedSequence: _sequence(initial),
          state: initialState,
        ),
      _ => throw StateError(
          'Session authority cannot retire from $initialKind',
        ),
    };

    try {
      await _retireRuntimeAuthority(
        directory: _authority.directory,
        expectedSequence: retirement.expectedSequence,
        sessionId: retirement.sessionId,
        successorLoggedOutSessionId: retirement.successorLoggedOutSessionId,
        successorNetwork: retirement.successorNetwork,
        transitionId: retirement.transitionId,
      );
    } catch (error) {
      throw SessionRetirementRetryableException(
        'global runtime retirement was not confirmed',
        error,
      );
    }

    late final Map<String, dynamic> retiringReply;
    try {
      retiringReply = await _authority.command({'command': 'read_record'});
    } catch (error) {
      throw SessionRetirementRetryableException(
        'retiring authority could not be read',
        error,
      );
    }
    final retiringRecord = _record(retiringReply);
    final retiringState = _map(retiringRecord['state'], 'record.state');
    if (retiringState['kind'] == 'logged_out') {
      _verifyLoggedOut(retiringRecord, retiringState, retirement);
      return retiringReply;
    }
    retirement.verifyRetiring(retiringState);

    try {
      if (!await _clearWebSessionData()) {
        throw const SessionRetirementRetryableException(
          'WebView realm cleanup was not confirmed',
        );
      }
    } on SessionRetirementRetryableException {
      rethrow;
    } catch (error) {
      throw SessionRetirementRetryableException(
        'WebView realm cleanup failed',
        error,
      );
    }

    late final Map<String, dynamic> completed;
    try {
      completed = await _authority.command({
        'command': 'complete_retirement',
        'expected': _map(retiringReply['revision'], 'revision'),
        'session_id': retirement.sessionId,
        'transition_id': retirement.transitionId,
      });
    } catch (error) {
      throw SessionRetirementRetryableException(
        'logged-out successor was not committed',
        error,
      );
    }
    final completedRecord = _record(completed);
    _verifyLoggedOut(
      completedRecord,
      _map(completedRecord['state'], 'record.state'),
      retirement,
    );
    return completed;
  }
}

class _RetirementOwner {
  const _RetirementOwner({
    required this.expectedSequence,
    required this.sessionId,
    required this.successorLoggedOutSessionId,
    required this.successorNetwork,
    required this.transitionId,
  });

  factory _RetirementOwner.fromState({
    required int expectedSequence,
    required Map<String, dynamic> state,
  }) =>
      _RetirementOwner(
        expectedSequence: expectedSequence,
        sessionId: _string(state['session_id'], 'retiring.session_id'),
        successorLoggedOutSessionId: _string(
          state['successor_logged_out_session_id'],
          'retiring.successor_logged_out_session_id',
        ),
        successorNetwork: state['successor_network'] as String?,
        transitionId: _string(state['transition_id'], 'retiring.transition_id'),
      );

  final int expectedSequence;
  final String sessionId;
  final String successorLoggedOutSessionId;
  final String? successorNetwork;
  final String transitionId;

  void verifyRetiring(Map<String, dynamic> state) {
    if (state['kind'] != 'retiring' ||
        state['session_id'] != sessionId ||
        state['successor_logged_out_session_id'] !=
            successorLoggedOutSessionId ||
        state['successor_network'] != successorNetwork ||
        state['transition_id'] != transitionId) {
      throw StateError('Session authority returned a different retirement');
    }
  }
}

void _verifyLoggedOut(
  Map<String, dynamic> record,
  Map<String, dynamic> state,
  _RetirementOwner retirement,
) {
  if (state['kind'] != 'logged_out' ||
      state['mode'] != 'signed_out' ||
      state['session_id'] != retirement.successorLoggedOutSessionId) {
    throw StateError('Session authority returned a different successor');
  }
  final expectedNetwork = retirement.successorNetwork;
  if (expectedNetwork != null && record['network'] != expectedNetwork) {
    throw StateError('Session authority returned a different network');
  }
}

Map<String, dynamic> _record(Map<String, dynamic> response) =>
    _map(response['record'], 'record');

int _sequence(Map<String, dynamic> record) {
  final sequence = record['sequence'];
  if (sequence is! int || sequence < 0) {
    throw StateError('Session authority record.sequence is invalid');
  }
  return sequence;
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
