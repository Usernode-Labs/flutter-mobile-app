import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isTerminalZkCompletionRejection', () {
    LeaderboardApiException ex(int code) =>
        LeaderboardApiException(code, 'error $code');

    test('terminal 4xx responses are rejections', () {
      expect(isTerminalZkCompletionRejection(ex(400)), isTrue);
      expect(isTerminalZkCompletionRejection(ex(401)), isTrue);
      expect(isTerminalZkCompletionRejection(ex(404)), isTrue);
      // Duplicate nullifier / session already used.
      expect(isTerminalZkCompletionRejection(ex(409)), isTrue);
      // Closed or superseded challenge.
      expect(isTerminalZkCompletionRejection(ex(422)), isTrue);
    });

    test('retryable statuses are not terminal', () {
      expect(isTerminalZkCompletionRejection(ex(408)), isFalse);
      expect(isTerminalZkCompletionRejection(ex(429)), isFalse);
      expect(isTerminalZkCompletionRejection(ex(500)), isFalse);
      expect(isTerminalZkCompletionRejection(ex(502)), isFalse);
      expect(isTerminalZkCompletionRejection(ex(503)), isFalse);
    });

    test('transport errors and null are not terminal', () {
      expect(isTerminalZkCompletionRejection(null), isFalse);
      expect(isTerminalZkCompletionRejection(StateError('boom')), isFalse);
      expect(isTerminalZkCompletionRejection(Exception('socket')), isFalse);
    });
  });
}
