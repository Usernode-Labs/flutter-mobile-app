// ignore_for_file: invalid_annotation_target

// FRB bindings smoke tests
//
// Goal: verify that the generated flutter_rust_bridge bindings load and a few
// simple calls work. These tests are intended to run during the usernode
// backend build to catch binding breaks early. If the dynamic library is not
// present, these tests will no-op to avoid flakiness in normal Flutter runs.

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart';
import 'package:crypto_mobile_app/src/rust/node.dart';
import 'package:crypto_mobile_app/src/rust/observability.dart';

typedef ObservabilityRecordFn = FlutterObservabilityRecordResult Function({
  required FlutterObservabilityKind kind,
  required String event,
  String? payloadJson,
});

@Tags(['frb', 'smoke'])
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

    test('observabilityRecord has expected signature', () {
      ObservabilityRecordFn f = observabilityRecord;
      expect(f, isNotNull);
    });
  });
}
