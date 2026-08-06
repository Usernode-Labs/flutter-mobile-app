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
      'setNodeSleepEnabled',
      'setDebugMode',
      'setFacematchStrict',
      'resetZkChallenge',
      'requestPermissions',
      'openBatterySettings',
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

    subject.beginMainFrameNavigation();
    expect(subject.authorizes(first), isFalse);
    expect(subject.bootstrapCapability(), isNull);

    subject.activateMainFrame(Uri.parse('${trustedUrl}next'));
    final second = subject.bootstrapCapability();
    expect(second, 'capability-2');
    expect(subject.authorizes(first), isFalse);
    expect(subject.authorizes(second), isTrue);
  });

  test('leaving the trusted origin revokes privileged access', () {
    final subject = policy();
    subject.activateMainFrame(Uri.parse(trustedUrl));
    final capability = subject.bootstrapCapability();

    subject.observeMainFrameUrl(Uri.parse('https://untrusted.example/app'));

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
