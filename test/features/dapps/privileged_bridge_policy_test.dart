import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trustedUrl = 'https://social-vibecoding.usernodelabs.org/';

  PrivilegedBridgePolicy policy({
    bool allowLocalDevelopment = false,
  }) {
    var next = 0;
    return PrivilegedBridgePolicy(
      trustedOrigin: Uri.parse(trustedUrl),
      allowLocalDevelopment: allowLocalDevelopment,
      capabilityFactory: () => 'capability-${++next}',
    );
  }

  test('trusted top-level navigation bootstraps a privileged capability', () {
    final subject = policy();
    subject.activateMainFrame(Uri.parse('$trustedUrl#home'));

    final capability = subject.bootstrapCapability();
    expect(capability, 'capability-1');
    expect(subject.authorizes(capability), isTrue);
    expect(subject.requiresCapability('completeLogin'), isTrue);
    expect(subject.requiresCapability('getBridgeInfo'), isFalse);
    expect(subject.requiresCapability('sendTransaction'), isFalse);
  });

  test('the centralized privileged method set stays explicit', () {
    expect(PrivilegedBridgePolicy.privilegedMethods, {
      'addHomeScreenShortcut',
      'getHomeScreenShortcuts',
      'removeHomeScreenShortcut',
      'reorderHomeScreenShortcuts',
      'openNativeScreen',
      'getProfileInfo',
      'getSettingsState',
      'manageStaking',
      'setNodeSleepEnabled',
      'setDebugMode',
      'setFacematchStrict',
      'resetZkChallenge',
      'requestPermissions',
      'openBatterySettings',
      'requestNotificationPermission',
      'requestAlarmPermissions',
      'openNotificationSettings',
      'beginSessionHandoff',
      'enterAnonymousSession',
      'completeLogin',
      'startNode',
      'stopNode',
      'getAuthStatus',
      'logout',
      'getSocialPushState',
      'setSocialPushEnabled',
      'claimPendingSocialNotification',
      'ackPendingSocialNotification',
    });
  });

  test('child-frame envelopes without the top-frame secret are rejected', () {
    final subject = policy();
    subject.activateMainFrame(Uri.parse(trustedUrl));

    expect(subject.authorizes(null), isFalse);
    expect(subject.authorizes('child-frame-guess'), isFalse);
  });

  test('loopback is rejected unless local development is explicitly enabled',
      () {
    final releasePolicy = policy();
    releasePolicy.activateMainFrame(Uri.parse('http://127.0.0.1:3000/'));
    expect(releasePolicy.bootstrapCapability(), isNull);

    final debugPolicy = policy(allowLocalDevelopment: true);
    debugPolicy.activateMainFrame(Uri.parse('http://127.0.0.1:3000/'));
    expect(debugPolicy.bootstrapCapability(), isNotNull);
  });

  test('main-frame navigation revokes and rotates the capability', () {
    final subject = policy();
    subject.activateMainFrame(Uri.parse(trustedUrl));
    final first = subject.bootstrapCapability();

    subject.beginMainFrameNavigation(Uri.parse('${trustedUrl}next'));
    expect(subject.authorizes(first), isFalse);
    expect(subject.bootstrapCapability(), isNull);

    subject.activateMainFrame(Uri.parse('${trustedUrl}next'));
    final second = subject.bootstrapCapability();
    expect(second, 'capability-2');
    expect(subject.authorizes(first), isFalse);
    expect(subject.authorizes(second), isTrue);
  });

  test('fragment-only navigation preserves the active document capability', () {
    final subject = policy();
    subject.activateMainFrame(Uri.parse('$trustedUrl#home'));
    final capability = subject.bootstrapCapability();

    subject.beginMainFrameNavigation(Uri.parse('$trustedUrl#settings'));
    subject.observeMainFrameUrl(Uri.parse('$trustedUrl#settings'));

    expect(subject.bootstrapCapability(), capability);
    expect(subject.authorizes(capability), isTrue);
  });

  test('a document load after a fragment-shaped request rotates capability',
      () {
    final subject = policy();
    subject.activateMainFrame(Uri.parse('$trustedUrl#home'));
    final previous = subject.bootstrapCapability();

    // The request alone is indistinguishable from a same-document hash change,
    // so it tentatively preserves the current JavaScript realm.
    subject.beginMainFrameNavigation(Uri.parse('$trustedUrl#settings'));
    expect(subject.authorizes(previous), isTrue);

    // A page-start callback proves this is a real document load. Native fences
    // the provisional interval, then trusts the replacement only on finish.
    subject.revoke();
    expect(subject.authorizes(previous), isFalse);
    expect(subject.bootstrapCapability(), isNull);

    subject.activateMainFrame(Uri.parse('$trustedUrl#settings'));
    final replacement = subject.bootstrapCapability();
    expect(replacement, 'capability-2');
    expect(subject.authorizes(previous), isFalse);
    expect(subject.authorizes(replacement), isTrue);
  });

  test('same-origin path, query, and reload requests still revoke immediately',
      () {
    final destinations = [
      Uri.parse('${trustedUrl}settings'),
      Uri.parse('$trustedUrl?screen=settings'),
      Uri.parse('$trustedUrl#home'),
    ];

    for (final destination in destinations) {
      final subject = policy();
      subject.activateMainFrame(Uri.parse('$trustedUrl#home'));
      final capability = subject.bootstrapCapability();

      subject.beginMainFrameNavigation(destination);

      expect(subject.bootstrapCapability(), isNull,
          reason: '$destination must start a new capability lifecycle');
      expect(subject.authorizes(capability), isFalse);
    }
  });

  test('leaving the trusted origin revokes privileged access', () {
    final subject = policy();
    subject.activateMainFrame(Uri.parse(trustedUrl));
    final capability = subject.bootstrapCapability();

    subject.observeMainFrameUrl(Uri.parse('https://untrusted.example/app'));

    expect(subject.authorizes(capability), isFalse);
    expect(subject.bootstrapCapability(), isNull);
  });

  test('a requested cross-origin navigation revokes before the page changes',
      () {
    final subject = policy();
    subject.activateMainFrame(Uri.parse('$trustedUrl#settings'));
    final capability = subject.bootstrapCapability();

    subject.beginMainFrameNavigation(
      Uri.parse('https://untrusted.example/#settings'),
    );

    expect(subject.authorizes(capability), isFalse);
    expect(subject.bootstrapCapability(), isNull);
  });

  test('same-origin SPA navigation preserves the current capability', () {
    final subject = policy();
    subject.activateMainFrame(Uri.parse(trustedUrl));
    final capability = subject.bootstrapCapability();

    subject.observeMainFrameUrl(Uri.parse('$trustedUrl#settings'));

    expect(subject.authorizes(capability), isTrue);
  });
}
