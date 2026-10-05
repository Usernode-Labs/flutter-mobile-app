// The OS notification dialog used to open on every install's first ready
// session, i.e. on the first screen, before the user had a reason to say
// yes. iOS shows that dialog once, ever, so a reflexive "Don't Allow" there
// was final. Asking is now the web's call, at a moment that explains it.
//
// main.dart cannot be loaded in a unit test (it owns the native session
// bootstrap), so these pin the source instead.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _askPattern = RegExp(r'\brequest(Notifications?)?Permissions?\(');

void main() {
  test('binding a ready session asks for nothing', () {
    final main = File('lib/main.dart').readAsStringSync();
    final start = main.indexOf('void _bindSessionFeatures(');
    final end = main.indexOf('\n  }\n', start);
    expect(start, greaterThanOrEqualTo(0));
    final bind = main.substring(start, end);

    expect(bind, contains('SocialPushService.instance.attachSession('));
    expect(bind, isNot(matches(_askPattern)));
    expect(bind, isNot(contains('Prompt')));
    expect(main, isNot(contains('startup_notification_prompt')));
  });

  test('only user-initiated paths ask for notification permission', () {
    final askers = <String>{
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            // Generated FRB bindings (CI-only) are not app code.
            !file.path.replaceAll(r'\', '/').startsWith('lib/src/rust/') &&
            _askPattern.hasMatch(file.readAsStringSync()))
          file.path.replaceAll(r'\', '/'),
    };

    expect(askers, {
      // Declarations.
      'lib/core/services/platform_alarm_service.dart',
      'lib/features/social_notifications/social_push_messaging.dart',
      // The trusted shell's `requestPermissions` and
      // `requestNotificationPermission` bridge calls.
      'lib/features/dapps/bridge/dapp_bridge_settings.dart',
      // `setSocialPushEnabled(true)`, the user's own toggle.
      'lib/features/social_notifications/social_push_service.dart',
    });

    final settings = File(
      'lib/features/dapps/bridge/dapp_bridge_settings.dart',
    ).readAsStringSync();
    for (final handler in [
      '_handleRequestPermissions(',
      '_handleRequestNotificationPermission(',
    ]) {
      final start = settings.indexOf('Future<void> $handler');
      final body = settings.substring(
        start,
        settings.indexOf('\n  }\n', start),
      );
      expect(body, contains('_requireTrustedChromeOrigin'), reason: handler);
    }

    final push = File(
      'lib/features/social_notifications/social_push_service.dart',
    ).readAsStringSync();
    final setEnabled = push.substring(
      push.indexOf('Future<void> _setEnabledNow('),
      push.indexOf('Future<void> _reconcileNow('),
    );
    expect(_askPattern.allMatches(push), hasLength(1));
    expect(setEnabled, matches(_askPattern));
  });
}
