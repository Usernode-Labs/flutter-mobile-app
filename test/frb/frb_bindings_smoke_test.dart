// FRB bindings smoke tests
//
// Goal: verify that the generated flutter_rust_bridge bindings load and a few
// simple calls work. These tests are intended to run during the usernode
// backend build to catch binding breaks early. If the dynamic library is not
// present, these tests will no-op to avoid flakiness in normal Flutter runs.

@Tags(['frb', 'smoke'])

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart';
import 'package:crypto_mobile_app/src/rust/third_party/usernode_p2p/identity.dart';
import 'package:crypto_mobile_app/src/rust/third_party/usernode_core/build.dart';

void main() {
  group('FRB compile contract (no-load)', () {
    test('buildEnv has expected signature', () {
      // Ensure the buildEnv symbol still returns BuildEnv and takes no args.
      BuildEnv Function() f = buildEnv;
      expect(f, isNotNull);
    });

    test('PeerId constructor shape compiles', () {
      // Do not call methods that would touch the bridge (e.g., toString).
      // Just ensure constructor & field types still match.
      void accept(PeerId Function({required U64Array4 field0}) ctor) {}
      accept(({required U64Array4 field0}) => PeerId(field0: field0));
    });
  });
}
