import 'package:crypto_mobile_app/features/metrics/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/features/metrics/models/metrics_payload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('metricsApiErrorCodeFromBody', () {
    test('returns code from JSON error body', () {
      expect(
        metricsApiErrorCodeFromBody(
          '{"error":"Participant wallet mismatch","code":"participant_wallet_mismatch"}',
        ),
        MetricsReportingService.participantWalletMismatchErrorCode,
      );
    });

    test('returns null for malformed bodies', () {
      expect(metricsApiErrorCodeFromBody('not-json'), isNull);
    });
  });

  group('isParticipantWalletMismatchResponse', () {
    test('returns true for dedicated mismatch response', () {
      final response = http.Response(
        '{"code":"participant_wallet_mismatch"}',
        409,
      );

      expect(isParticipantWalletMismatchResponse(response), isTrue);
    });

    test('returns false for unrelated responses', () {
      final response = http.Response('{"code":"other"}', 409);

      expect(isParticipantWalletMismatchResponse(response), isFalse);
    });
  });

  test('identity metrics serialize participant_id', () {
    const identity = IdentityMetrics(
      peerId: 'peer-1',
      chainId: 'chain-1',
      participantId: 42,
    );

    expect(identity.toJson(), {
      'peer_id': 'peer-1',
      'chain_id': 'chain-1',
      'participant_id': 42,
    });
  });
}
