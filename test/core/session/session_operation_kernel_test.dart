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
      'held-wake-terminal-suppressed',
      'uncertain-establish-failed-closed',
      'committed-ready-retained-private',
      'precommit-terminal-retained',
      'background-gate-closed',
      'resume-gate-held',
      'resume-gate-retired-runner-rejected',
    ]);
  });
}
