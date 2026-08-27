import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/src/session_lifecycle/session_operation_kernel.dart';

void main() {
  test('private lifecycle kernel preserves the hard boundary', () async {
    expect(await runSessionLifecycleOrderingSelfCheck(), [
      'operation-entered',
      'child-entered',
      'effect-entered',
      'admission-closed',
      'commit',
      'publish:2',
      'publish:3',
      'retired-runner-rejected',
      'expired-effect-rejected',
      'queued-publish:4',
      'queued-runner-rejected',
    ]);
  });
}
