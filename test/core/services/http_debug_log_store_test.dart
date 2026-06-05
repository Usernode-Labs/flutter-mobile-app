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
