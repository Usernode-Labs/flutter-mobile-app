import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/services/startup_notification_prompt.dart';

void main() {
  late int requests;
  late int changes;

  StartupNotificationPrompt prompt({
    bool initialized = true,
    bool granted = false,
    bool isMobile = true,
  }) =>
      StartupNotificationPrompt(
        initialize: () async => initialized,
        hasPermission: () async => granted,
        requestPermission: () async {
          requests++;
          return true;
        },
        onPermissionsChanged: () => changes++,
        isMobile: isMobile,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = 0;
    changes = 0;
  });

  test('asks on the first ready session and tells SV', () async {
    await prompt().maybePrompt();

    expect(requests, 1);
    expect(changes, 1);
  });

  test('never asks twice on the same install', () async {
    await prompt().maybePrompt();
    await prompt().maybePrompt();

    expect(requests, 1);
  });

  test('skips the dialog when already granted', () async {
    await prompt(granted: true).maybePrompt();
    await prompt().maybePrompt();

    expect(requests, 0);
    expect(changes, 0);
  });

  test('retries later when the platform service is not ready', () async {
    await prompt(initialized: false).maybePrompt();
    expect(requests, 0);

    await prompt().maybePrompt();
    expect(requests, 1);
  });

  test('ignores concurrent calls', () async {
    final p = prompt();
    await Future.wait([p.maybePrompt(), p.maybePrompt()]);

    expect(requests, 1);
  });

  test('does nothing off mobile', () async {
    await prompt(isMobile: false).maybePrompt();

    expect(requests, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(StartupNotificationPrompt.askedKey), isNull);
  });

  test('pending waits for the user to answer the dialog', () async {
    final answer = Completer<bool>();
    final p = StartupNotificationPrompt(
      initialize: () async => true,
      hasPermission: () async => false,
      requestPermission: () => answer.future,
      onPermissionsChanged: () => changes++,
      isMobile: true,
    );

    unawaited(p.maybePrompt());
    var settled = false;
    unawaited(p.pending.then((_) => settled = true));
    await pumpEventQueue();
    expect(settled, isFalse);

    answer.complete(true);
    await pumpEventQueue();
    expect(settled, isTrue);
    expect(changes, 1);
  });

  test('pending is already complete when nothing is running', () async {
    await prompt().pending;
    expect(requests, 0);
  });
}
