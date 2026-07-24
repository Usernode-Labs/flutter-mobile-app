import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/utils/utils.dart';

void main() {
  group('Utils.timestampToUTC unit auto-detection', () {
    const expected = '2024-01-01T00:00:00.000Z';
    test('seconds (<13 digits)', () {
      expect(Utils.timestampToUTC(BigInt.from(1704067200)), expected);
    });
    test('milliseconds (13-15 digits)', () {
      expect(Utils.timestampToUTC(BigInt.from(1704067200000)), expected);
    });
    test('microseconds (16-18 digits)', () {
      expect(Utils.timestampToUTC(BigInt.from(1704067200000000)), expected);
    });
    test('nanoseconds (19+ digits)', () {
      expect(
          Utils.timestampToUTC(BigInt.parse('1704067200000000000')), expected);
    });
  });

  group('Utils.timestampToTimeAgo', () {
    BigInt msAgo(Duration d) => BigInt.from(
        DateTime.now().toUtc().subtract(d).millisecondsSinceEpoch);

    test('buckets from just-now up to years', () {
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(seconds: 10))),
          'just now');
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(seconds: 90))),
          'a minute ago');
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(minutes: 10))),
          '10 minutes ago');
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(minutes: 90))),
          'an hour ago');
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(hours: 5))),
          '5 hours ago');
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(hours: 25))),
          'yesterday');
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(days: 3))),
          '3 days ago');
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(days: 14))),
          '2 weeks ago');
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(days: 60))),
          '2 months ago');
      expect(Utils.timestampToTimeAgo(msAgo(const Duration(days: 730))),
          '2 years ago');
    });
  });

  group('Utils.shortenID', () {
    test('shortens long ids with an ellipsis', () {
      expect(Utils.shortenID('0123456789abcdef0123456789abcdef',
          head: 8, tail: 8), '01234567…89abcdef');
    });
    test('returns short strings unchanged', () {
      expect(Utils.shortenID('short', head: 8, tail: 8), 'short');
    });
  });

  group('Utils.formatBigInt', () {
    test('groups thousands', () {
      expect(Utils.formatBigInt(BigInt.from(1234567)), '1,234,567');
      expect(Utils.formatBigInt(BigInt.zero), '0');
    });
  });
}
