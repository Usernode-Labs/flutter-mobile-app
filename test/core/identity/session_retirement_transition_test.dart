import 'package:crypto_mobile_app/core/identity/session_retirement_repair.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/session_authority_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one exact retirement reaches its reserved logged-out successor',
      () async {
    final authority = ScriptedSessionAuthority([
      sessionAuthorityResponse(
        sequence: 6,
        state: _retiring(),
        outcome: 'record_read',
      ),
      sessionAuthorityResponse(
        sequence: 7,
        state: loggedOutAuthorityState(sessionId: 'logged-out-b'),
        outcome: 'retirement_logged_out',
      ),
    ]);
    final runtimeRequests = <Map<String, Object?>>[];
    var webRealmClears = 0;
    final transition = RetirementRepairScope(
      authority: authority,
      clearWebSessionData: () async {
        webRealmClears += 1;
        return true;
      },
      retireRuntimeAuthority: ({
        required directory,
        required expectedSequence,
        required sessionId,
        required successorLoggedOutSessionId,
        required successorNetwork,
        required transitionId,
      }) async {
        runtimeRequests.add({
          'directory': directory,
          'expected_sequence': expectedSequence,
          'session_id': sessionId,
          'successor_logged_out_session_id': successorLoggedOutSessionId,
          'successor_network': successorNetwork,
          'transition_id': transitionId,
        });
      },
    );

    final completed = await transition.repair(
      sessionAuthorityResponse(
        sequence: 5,
        state: readyAuthorityState(),
        outcome: 'record_read',
      ),
      successorLoggedOutSessionId: 'logged-out-b',
      transitionId: 'retire-a',
    );

    expect(runtimeRequests, [
      {
        'directory': '/application-support/session-authority',
        'expected_sequence': 5,
        'session_id': 'session-a',
        'successor_logged_out_session_id': 'logged-out-b',
        'successor_network': null,
        'transition_id': 'retire-a',
      },
    ]);
    expect(webRealmClears, 1);
    expect(
      authority.commands.map((command) => command['command']),
      ['read_record', 'complete_retirement'],
    );
    expect(authority.commands.last, {
      'command': 'complete_retirement',
      'expected': {
        'sequence': 6,
        'session_id': 'session-a',
        'state': 'retiring',
        'transition_id': 'retire-a',
      },
      'session_id': 'session-a',
      'transition_id': 'retire-a',
    });
    expect(
      (completed['record'] as Map)['state'],
      loggedOutAuthorityState(sessionId: 'logged-out-b'),
    );
  });

  test('realm cleanup failure is retryable with the same exact transition',
      () async {
    final authority = ScriptedSessionAuthority([
      sessionAuthorityResponse(
        sequence: 6,
        state: _retiring(),
        outcome: 'record_read',
      ),
      sessionAuthorityResponse(
        sequence: 6,
        state: _retiring(),
        outcome: 'record_read',
      ),
      sessionAuthorityResponse(
        sequence: 7,
        state: loggedOutAuthorityState(sessionId: 'logged-out-b'),
        outcome: 'retirement_logged_out',
      ),
    ]);
    var realmIsClear = false;
    final runtimeRequests = <Map<String, Object?>>[];
    final transition = RetirementRepairScope(
      authority: authority,
      clearWebSessionData: () async => realmIsClear,
      retireRuntimeAuthority: ({
        required directory,
        required expectedSequence,
        required sessionId,
        required successorLoggedOutSessionId,
        required successorNetwork,
        required transitionId,
      }) async {
        runtimeRequests.add({
          'expected_sequence': expectedSequence,
          'session_id': sessionId,
          'successor': successorLoggedOutSessionId,
          'network': successorNetwork,
          'transition': transitionId,
        });
      },
    );
    final initial = sessionAuthorityResponse(
      sequence: 5,
      state: readyAuthorityState(),
      outcome: 'record_read',
    );

    await expectLater(
      transition.repair(
        initial,
        successorLoggedOutSessionId: 'logged-out-b',
        transitionId: 'retire-a',
      ),
      throwsA(isA<SessionRetirementRetryableException>()),
    );
    expect(
      authority.commands.map((command) => command['command']),
      ['read_record'],
      reason: 'LoggedOut must not commit over an uncleared shared realm',
    );

    realmIsClear = true;
    final completed = await transition.repair(
      initial,
      successorLoggedOutSessionId: 'logged-out-b',
      transitionId: 'retire-a',
    );

    expect(runtimeRequests, hasLength(2));
    expect(runtimeRequests[1], runtimeRequests[0]);
    expect(
      authority.commands.map((command) => command['command']),
      ['read_record', 'read_record', 'complete_retirement'],
    );
    expect(
      ((completed['record'] as Map)['state'] as Map)['session_id'],
      'logged-out-b',
    );
  });

  test('cold Retiring replay derives and preserves the reserved successor',
      () async {
    final authority = ScriptedSessionAuthority([
      sessionAuthorityResponse(
        sequence: 6,
        state: _retiring(successorNetwork: 'internal'),
        outcome: 'record_read',
        network: 'testnet',
      ),
      sessionAuthorityResponse(
        sequence: 7,
        state: loggedOutAuthorityState(sessionId: 'logged-out-b'),
        outcome: 'retirement_logged_out',
        network: 'internal',
      ),
    ]);
    Map<String, Object?>? runtimeRequest;
    final transition = RetirementRepairScope(
      authority: authority,
      clearWebSessionData: () async => true,
      retireRuntimeAuthority: ({
        required directory,
        required expectedSequence,
        required sessionId,
        required successorLoggedOutSessionId,
        required successorNetwork,
        required transitionId,
      }) async {
        runtimeRequest = {
          'expected_sequence': expectedSequence,
          'session_id': sessionId,
          'successor': successorLoggedOutSessionId,
          'network': successorNetwork,
          'transition': transitionId,
        };
      },
    );

    final completed = await transition.repair(
      sessionAuthorityResponse(
        sequence: 6,
        state: _retiring(successorNetwork: 'internal'),
        outcome: 'record_read',
      ),
    );

    expect(runtimeRequest, {
      'expected_sequence': 6,
      'session_id': 'session-a',
      'successor': 'logged-out-b',
      'network': 'internal',
      'transition': 'retire-a',
    });
    expect((completed['record'] as Map)['network'], 'internal');
  });
}

Map<String, dynamic> _retiring({String? successorNetwork}) => {
      'kind': 'retiring',
      'session_id': 'session-a',
      'successor_logged_out_session_id': 'logged-out-b',
      'successor_network': successorNetwork,
      'transition_id': 'retire-a',
    };
