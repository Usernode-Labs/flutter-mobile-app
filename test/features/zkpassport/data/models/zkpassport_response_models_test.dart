import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';

void main() {
  group('ZkPassportSessionStartResponse.fromJson', () {
    test('reads and trims fields', () {
      final r = ZkPassportSessionStartResponse.fromJson({
        'session_id': '  sid  ',
        'status': ' started ',
        'launch_url': ' https://x ',
      });
      expect(r.sessionId, 'sid');
      expect(r.status, 'started');
      expect(r.launchUrl, 'https://x');
    });

    test('defaults missing fields to empty', () {
      final r = ZkPassportSessionStartResponse.fromJson({});
      expect(r.sessionId, '');
      expect(r.status, '');
      expect(r.launchUrl, '');
    });
  });

  group('ZkPassportSessionStatusResponse', () {
    test('fromJson parses fields', () {
      final r = ZkPassportSessionStatusResponse.fromJson({
        'session_id': 'sid',
        'status': 'pending',
        'final_available': true,
        'updated_at_ms': 1700,
      });
      expect(r.sessionId, 'sid');
      expect(r.status, 'pending');
      expect(r.finalAvailable, isTrue);
      expect(r.updatedAtMs, 1700);
    });

    test('final_available only true for boolean true; ms defaults to 0', () {
      final r = ZkPassportSessionStatusResponse.fromJson({
        'status': 'pending',
        'final_available': 'true', // not a bool
      });
      expect(r.finalAvailable, isFalse);
      expect(r.updatedAtMs, 0);
    });

    final dispositionCases = <({
      String status,
      bool finalAvailable,
      ZkPassportSessionDisposition expected,
    })>[
      (
        status: 'pending',
        finalAvailable: false,
        expected: ZkPassportSessionDisposition.pending,
      ),
      (
        status: 'pending',
        finalAvailable: true,
        expected: ZkPassportSessionDisposition.proofReady,
      ),
      (
        status: 'result_ok',
        finalAvailable: false,
        expected: ZkPassportSessionDisposition.proofReady,
      ),
      (
        status: ' RESULT_OK ',
        finalAvailable: false,
        expected: ZkPassportSessionDisposition.proofReady,
      ),
      (
        status: 'result_error',
        finalAvailable: false,
        expected: ZkPassportSessionDisposition.failed,
      ),
      (
        status: 'result_error',
        finalAvailable: true,
        expected: ZkPassportSessionDisposition.failed,
      ),
      (
        status: 'expired',
        finalAvailable: false,
        expected: ZkPassportSessionDisposition.expired,
      ),
      (
        status: 'expired',
        finalAvailable: true,
        expected: ZkPassportSessionDisposition.expired,
      ),
      (
        status: 'unknown',
        finalAvailable: true,
        expected: ZkPassportSessionDisposition.proofReady,
      ),
    ];

    for (final testCase in dispositionCases) {
      test(
        '${testCase.status}/${testCase.finalAvailable} maps to '
        '${testCase.expected.name}',
        () {
          final response = ZkPassportSessionStatusResponse.fromJson({
            'status': testCase.status,
            'final_available': testCase.finalAvailable,
          });

          expect(response.disposition, testCase.expected);
        },
      );
    }
  });

  group('ZkPassportSessionResultResponse.fromJson', () {
    test('success requires result_ok status AND a proof', () {
      final ok = ZkPassportSessionResultResponse.fromJson({
        'session_id': 'sid',
        'status': 'result_ok',
        'proof': 'PROOF',
      });
      expect(ok.success, isTrue);
      expect(ok.outerProofB64Url, 'PROOF');

      final noProof = ZkPassportSessionResultResponse.fromJson({
        'status': 'result_ok',
      });
      expect(noProof.success, isFalse);

      final err = ZkPassportSessionResultResponse.fromJson({
        'status': 'result_error',
        'proof': 'PROOF',
      });
      expect(err.success, isFalse);
    });

    test('sessionId accepts camelCase or snake_case', () {
      expect(
        ZkPassportSessionResultResponse.fromJson({'sessionId': 'camel'})
            .sessionId,
        'camel',
      );
      expect(
        ZkPassportSessionResultResponse.fromJson({'session_id': 'snake'})
            .sessionId,
        'snake',
      );
    });

    test('finalizedAtMs accepts camelCase or snake_case, else 0', () {
      expect(
        ZkPassportSessionResultResponse.fromJson({'finalizedAtMs': 5})
            .finalizedAtMs,
        5,
      );
      expect(
        ZkPassportSessionResultResponse.fromJson({'finalized_at_ms': 6})
            .finalizedAtMs,
        6,
      );
      expect(ZkPassportSessionResultResponse.fromJson({}).finalizedAtMs, 0);
    });

    group('outer proof extraction', () {
      String? proofOf(Map<String, dynamic> json) =>
          ZkPassportSessionResultResponse.fromJson(json).outerProofB64Url;

      test('direct string on proof', () {
        expect(proofOf({'proof': '  P  '}), 'P');
      });
      test('nested map keys are tried in order', () {
        expect(
            proofOf({
              'proof': {'outer_proof': 'A'}
            }),
            'A');
        expect(
            proofOf({
              'proof': {'outerProof': 'B'}
            }),
            'B');
        expect(
            proofOf({
              'proof': {'proof_payload': 'C'}
            }),
            'C');
      });
      test('proofs list yields first encoded entry', () {
        expect(
          proofOf({
            'proof': {
              'proofs': [
                {'x': 1},
                {'proof': 'L'}
              ]
            }
          }),
          'L',
        );
      });
      test('falls back to the result payload', () {
        expect(
            proofOf({
              'result': {'outer_proof': 'R'}
            }),
            'R');
      });
      test('null when nothing matches', () {
        expect(proofOf({'status': 'result_ok'}), isNull);
      });
    });

    group('error extraction', () {
      String? errOf(Map<String, dynamic> json) =>
          ZkPassportSessionResultResponse.fromJson(json).error;

      test('prefers error, then message, then result.error', () {
        expect(errOf({'error': ' boom '}), 'boom');
        expect(errOf({'message': 'msg'}), 'msg');
        expect(
            errOf({
              'result': {'error': 'nested'}
            }),
            'nested');
      });
      test('null when absent', () {
        expect(errOf({'status': 'x'}), isNull);
      });
    });

    group('string/int field extraction (top-level and via result map)', () {
      test('nullifierHex from either casing', () {
        expect(
          ZkPassportSessionResultResponse.fromJson({'nullifier_hex': 'h1'})
              .nullifierHex,
          'h1',
        );
        expect(
          ZkPassportSessionResultResponse.fromJson({
            'result': {'nullifierHex': 'h2'},
          }).nullifierHex,
          'h2',
        );
      });

      test('oprfPkHash extraction', () {
        expect(
          ZkPassportSessionResultResponse.fromJson({'oprf_pk_hash': 'o'})
              .oprfPkHash,
          'o',
        );
      });

      test('int fields accept int, num and numeric string', () {
        expect(
          ZkPassportSessionResultResponse.fromJson({'nullifier_type': 3})
              .nullifierType,
          3,
        );
        expect(
          ZkPassportSessionResultResponse.fromJson({'nullifier_type': 4.9})
              .nullifierType,
          4,
        );
        expect(
          ZkPassportSessionResultResponse.fromJson({
            'unique_identifier_type': '7',
          }).uniqueIdentifierType,
          7,
        );
        expect(
          ZkPassportSessionResultResponse.fromJson({
            'nullifier_type': 'not-a-number',
          }).nullifierType,
          isNull,
        );
      });
    });
  });
}
