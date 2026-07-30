import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:flutter_test/flutter_test.dart';

HttpLogEntry _entry({
  String method = 'GET',
  String url = 'https://example.com/api',
  int? statusCode = 200,
  Map<String, String> requestHeaders = const {},
  String? responseBody,
}) {
  return HttpLogEntry(
    timestamp: DateTime(2026, 1, 1),
    method: method,
    url: url,
    statusCode: statusCode,
    requestHeaders: requestHeaders,
    responseBody: responseBody,
  );
}

void main() {
  group('redactHeaders', () {
    test('masks sensitive headers case-insensitively, keeps the rest', () {
      final redacted = redactHeaders({
        'Authorization': 'Bearer secret-token',
        'COOKIE': 'session=abc',
        'X-Api-Key': 'key123',
        'Content-Type': 'application/json',
      });

      expect(redacted['Authorization'], '***');
      expect(redacted['COOKIE'], '***');
      expect(redacted['X-Api-Key'], '***');
      // Non-sensitive headers pass through untouched.
      expect(redacted['Content-Type'], 'application/json');
    });

    test('entry construction redacts request and response headers', () {
      final entry = HttpLogEntry(
        timestamp: DateTime(2026, 1, 1),
        method: 'POST',
        url: 'https://example.com',
        requestHeaders: const {'authorization': 'Bearer x'},
        responseHeaders: const {'set-cookie': 'a=b'},
      );

      expect(entry.requestHeaders['authorization'], '***');
      expect(entry.responseHeaders['set-cookie'], '***');
      expect(entry.toLogText(), isNot(contains('Bearer x')));
      expect(entry.toLogText(), isNot(contains('a=b')));
    });
  });

  group('redactSensitiveBodyFields', () {
    test('masks secret_key in a wallet-provision-style response', () {
      const body = '{"address":"ut1abc","public_key":"utpk1xyz",'
          '"secret_key":"utsk1verysecret","newly_allocated":true}';
      final redacted = redactSensitiveBodyFields(body)!;

      expect(redacted, isNot(contains('utsk1verysecret')));
      expect(redacted, contains('"secret_key":"***"'));
      // Non-sensitive fields pass through untouched.
      expect(redacted, contains('"address":"ut1abc"'));
      expect(redacted, contains('"public_key":"utpk1xyz"'));
    });

    test('masks credentials in auth request/response bodies', () {
      const login = '{"email":"a@b.c","password":"hunter2"}';
      const otp = '{"email":"a@b.c","code":"123456"}';
      const session = '{"token":"sess-token-1","user":{"id":7}}';

      expect(redactSensitiveBodyFields(login), isNot(contains('hunter2')));
      expect(redactSensitiveBodyFields(otp), isNot(contains('123456')));
      final redactedSession = redactSensitiveBodyFields(session)!;
      expect(redactedSession, isNot(contains('sess-token-1')));
      expect(redactedSession, contains('"user":{"id":7}'));
    });

    test('does not mask keys that merely contain a sensitive key name', () {
      const body = '{"token_type":"bearer","passcode_hint":"none"}';
      expect(redactSensitiveBodyFields(body), body);
    });

    test('masks values with escaped quotes and truncated strings', () {
      const escaped = r'{"secret_key":"with\"escaped\"quotes"}';
      expect(redactSensitiveBodyFields(escaped), isNot(contains('escaped')));

      // A body cut off mid-secret (e.g. by truncation) still gets masked.
      const cutOff = '{"secret_key":"utsk1verysec';
      expect(
        redactSensitiveBodyFields(cutOff),
        isNot(contains('utsk1verysec')),
      );
    });

    test('is idempotent and passes non-JSON bodies through', () {
      const body = '{"secret_key":"s3cret"}';
      final once = redactSensitiveBodyFields(body);
      expect(redactSensitiveBodyFields(once), once);

      expect(redactSensitiveBodyFields('plain text body'), 'plain text body');
      expect(redactSensitiveBodyFields(null), isNull);
      expect(redactSensitiveBodyFields(''), '');
    });

    test('entry construction redacts request and response bodies', () {
      final entry = HttpLogEntry(
        timestamp: DateTime(2026, 1, 1),
        method: 'POST',
        url: 'https://example.com/wallet/provision',
        requestBody: '{"password":"hunter2"}',
        responseBody: '{"secret_key":"utsk1verysecret"}',
      );

      expect(entry.requestBody, isNot(contains('hunter2')));
      expect(entry.responseBody, isNot(contains('utsk1verysecret')));
      expect(entry.toLogText(), isNot(contains('utsk1verysecret')));
      final json = entry.toJsonEvent();
      expect(json['request_body'], isNot(contains('hunter2')));
      expect(json['response_body'], isNot(contains('utsk1verysecret')));
    });
  });

  group('truncateBody', () {
    test('passes through null and short bodies', () {
      expect(truncateBody(null), isNull);
      expect(truncateBody('short'), 'short');
    });

    test('truncates bodies over the cap and marks them', () {
      final long = 'x' * (9 * 1024);
      final result = truncateBody(long)!;

      expect(result.length, lessThan(long.length));
      expect(result, endsWith('…[truncated]'));
    });
  });

  group('HttpDebugLogStore', () {
    final store = HttpDebugLogStore.instance;

    setUp(store.clear);
    tearDown(store.clear);

    test('returns entries newest-first', () {
      store
        ..add(_entry(url: 'https://example.com/first'))
        ..add(_entry(url: 'https://example.com/second'));

      final entries = store.entries;
      expect(entries.first.url, 'https://example.com/second');
      expect(entries.last.url, 'https://example.com/first');
    });

    test('clear empties the buffer and resets the byte total', () {
      store.add(_entry(responseBody: 'some body'));
      expect(store.entries, isNotEmpty);
      expect(store.totalBytes, greaterThan(0));

      store.clear();
      expect(store.entries, isEmpty);
      expect(store.totalBytes, 0);
    });

    test('evicts oldest entries to stay within the byte cap', () {
      // Each entry carries a ~200KB body, so ~6 exceed the 1MB cap.
      final bigBody = 'y' * (200 * 1024);
      for (var i = 0; i < 12; i++) {
        store.add(_entry(url: 'https://example.com/$i', responseBody: bigBody));
      }

      expect(store.totalBytes, lessThanOrEqualTo(HttpDebugLogStore.maxBytes));
      // The oldest entry must have been evicted; the newest must survive.
      final urls = store.entries.map((e) => e.url).toList();
      expect(urls, contains('https://example.com/11'));
      expect(urls, isNot(contains('https://example.com/0')));
    });

    test('keeps a single entry even if it alone exceeds the cap', () {
      final huge = HttpLogEntry(
        timestamp: DateTime(2026, 1, 1),
        method: 'GET',
        url: 'https://example.com/huge',
        statusCode: 200,
        // approxBytes counts UTF-16 (2 bytes/char), so this clears 1MB alone.
        responseBody: 'z' * (HttpDebugLogStore.maxBytes),
      );
      store.add(huge);

      expect(store.entries.length, 1);
      expect(store.entries.first.url, 'https://example.com/huge');
    });
  });

  group('HttpLogEntry.isError', () {
    test('is true for >=400 status and for thrown errors', () {
      expect(_entry(statusCode: 500).isError, isTrue);
      expect(_entry(statusCode: 404).isError, isTrue);
      expect(_entry(statusCode: 200).isError, isFalse);

      final errored = HttpLogEntry(
        timestamp: DateTime(2026, 1, 1),
        method: 'GET',
        url: 'https://example.com',
        statusCode: null,
        error: 'TimeoutException',
      );
      expect(errored.isError, isTrue);
    });
  });
}
