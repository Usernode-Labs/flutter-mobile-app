import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations_en.dart';
import 'package:crypto_mobile_app/features/zk_identity/zk_identity_status_mapper.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('formatDurationMs', () {
    test('sub-second is milliseconds', () {
      expect(formatDurationMs(0), '0 ms');
      expect(formatDurationMs(253), '253 ms');
      expect(formatDurationMs(999), '999 ms');
    });
    test('>= 1000 is seconds with 1 decimal', () {
      expect(formatDurationMs(1000), '1.0 sec');
      expect(formatDurationMs(1600), '1.6 sec');
    });
  });

  group('buildZkIdentityStatusData', () {
    test('base registration yields the 3 always-present steps', () {
      final data = buildZkIdentityStatusData(
        const ZkPassportLocalRegistration(
            registered: true, nullifierHex: null, registeredAtMs: null),
        l10n,
      );
      // uniqueness, face-match, privacy
      expect(data.steps, hasLength(3));
    });

    test('adds date, proof-id, and timing rows when present', () {
      final data = buildZkIdentityStatusData(
        const ZkPassportLocalRegistration(
          registered: true,
          nullifierHex: '0123456789abcdef',
          registeredAtMs: 1700000000000,
          facematchVerified: true,
          verifyOuterMs: 120,
          wrapOuterMs: 2000,
          verifyWrappedMs: 50,
        ),
        l10n,
      );
      // 3 base + date + proofId + 3 timings = 8
      expect(data.steps, hasLength(8));
      // truncated nullifier: first 8 + ... + last 4
      final proofStep =
          data.steps.firstWhere((s) => s.value == '01234567...cdef');
      expect(proofStep.monospace, isTrue);
    });

    test('short nullifier (<12 chars) is not shown as a proof-id row', () {
      final data = buildZkIdentityStatusData(
        const ZkPassportLocalRegistration(
            registered: true, nullifierHex: 'abc', registeredAtMs: null),
        l10n,
      );
      expect(data.steps, hasLength(3));
    });
  });
}
