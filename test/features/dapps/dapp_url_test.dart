import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/dapps/dapp_url.dart';

void main() {
  group('isSameWebOrigin', () {
    test('matches normalized default ports and ignores document pieces', () {
      expect(
        isSameWebOrigin(
          Uri.parse('https://example.org/path?a=1#old'),
          Uri.parse('https://example.org:443/other?b=2#new'),
        ),
        isTrue,
      );
    });

    test('rejects scheme, host, and port differences', () {
      final base = Uri.parse('https://example.org');
      expect(isSameWebOrigin(base, Uri.parse('http://example.org')), isFalse);
      expect(isSameWebOrigin(base, Uri.parse('https://other.org')), isFalse);
      expect(
        isSameWebOrigin(base, Uri.parse('https://example.org:8443')),
        isFalse,
      );
    });
  });

  group('isSameWebDocument', () {
    test('allows only fragment changes within the current document', () {
      expect(
        isSameWebDocument(
          Uri.parse('https://example.org/app?a=1#old'),
          Uri.parse('https://example.org/app?a=1#new'),
        ),
        isTrue,
      );
      expect(
        isSameWebDocument(
          Uri.parse('https://example.org/#old'),
          Uri.parse('https://example.org#new'),
        ),
        isTrue,
      );
      expect(
        isSameWebDocument(
          Uri.parse('https://foreign.example/app?a=1#old'),
          Uri.parse('https://example.org/app?a=1#new'),
        ),
        isFalse,
      );
      expect(
        isSameWebDocument(
          Uri.parse('https://example.org/other?a=1#old'),
          Uri.parse('https://example.org/app?a=1#new'),
        ),
        isFalse,
      );
      expect(
        isSameWebDocument(
          Uri.parse('https://example.org/app?a=2#old'),
          Uri.parse('https://example.org/app?a=1#new'),
        ),
        isFalse,
      );
    });
  });
}
