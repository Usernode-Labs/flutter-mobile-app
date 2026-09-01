import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/main.dart';

void main() {
  test('private lifecycle kernel preserves the hard boundary', () async {
    expect(await runSessionLifecycleOrderingSelfCheck(), [
      'operation-entered',
      'child-entered',
      'effect-entered',
      'admission-closed',
      'closing-child-entered',
      'commit',
      'publish:2',
      'publish:3',
      'retired-runner-rejected',
      'expired-effect-rejected',
      'uncertain-establish-failed-closed',
      'committed-ready-single-state',
      'wake-failure-preserved-ready',
      'precommit-terminal-retained',
      'terminal-effect-closed-admission',
      'background-gate-closed',
      'resume-gate-held',
      'resume-gate-retired-runner-rejected',
    ]);
  });
}
