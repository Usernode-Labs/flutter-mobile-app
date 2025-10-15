// FRB bindings smoke tests
//
// Goal: verify that the generated flutter_rust_bridge bindings load and a few
// simple calls work. These tests are intended to run during the usernode
// backend build to catch binding breaks early. If the dynamic library is not
// present, these tests will no-op to avoid flakiness in normal Flutter runs.

@Tags(['frb', 'smoke'])

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart';

void main() {
  group('FRB compile contract (no-load)', () {
    test('buildInfo has expected signature', () {
      // Ensure the buildInfo symbol still returns BuildInfo and takes no args.
      BuildInfo Function() f = buildInfo;
      expect(f, isNotNull);
    });

    test('PeerId method shape compiles', () {
      // Ensure we can refer to PeerId in signatures and call toString on it
      void accept(String Function(PeerId) f) {}
      accept((p) => p.toString());
    });
  });
}
