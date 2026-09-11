import 'package:crypto_mobile_app/features/dapps/node_requirement_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses acquire and explicit release requests', () {
    final acquire = NodeRequirementRequest.fromBridgeArgs({
      'required': true,
      'scope': 'wallet',
    });
    final release = NodeRequirementRequest.fromBridgeArgs({
      'required': false,
      'scope': 'wallet',
      'guardId': 'opaque-guard-id',
    });

    expect(acquire, isA<NodeRequirementAcquire>());
    expect(acquire.scope, 'wallet');
    expect(release, isA<NodeRequirementRelease>());
    expect(release.scope, 'wallet');
    expect((release as NodeRequirementRelease).guardId, 'opaque-guard-id');
  });

  test('rejects ambiguous or noncanonical requests', () {
    for (final args in <Object?>[
      null,
      <String, Object?>{'required': 'true', 'scope': 'wallet'},
      <String, Object?>{'required': true, 'scope': ''},
      <String, Object?>{'required': true, 'scope': '/wallet'},
      <String, Object?>{
        'required': true,
        'scope': 'wallet',
        'guardId': 'not-allowed-on-acquire',
      },
      <String, Object?>{'required': false, 'scope': 'wallet'},
      <String, Object?>{
        'required': false,
        'scope': 'wallet',
        'guardId': ' opaque ',
      },
    ]) {
      expect(
        () => NodeRequirementRequest.fromBridgeArgs(args),
        throwsFormatException,
        reason: '$args',
      );
    }
  });
}
