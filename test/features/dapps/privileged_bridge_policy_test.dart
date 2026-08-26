import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trustedUrl = 'https://social-vibecoding.usernodelabs.org/';

  _FakeTopFrame frame({String href = trustedUrl}) => _FakeTopFrame(href);

  PrivilegedBridgePolicy policy(
    _FakeTopFrame frame, {
    bool allowLocalDevelopment = false,
    _SecretSequence? secrets,
    Duration probeTimeout = const Duration(milliseconds: 50),
  }) {
    final sequence = secrets ?? _SecretSequence();
    return PrivilegedBridgePolicy(
      trustedOrigin: Uri.parse(trustedUrl),
      allowLocalDevelopment: allowLocalDevelopment,
      evaluateTopFrame: frame.evaluate,
      secretFactory: sequence.next,
      probeTimeout: probeTimeout,
    );
  }

  test('trusted document bootstraps and authorizes its realm lease', () async {
    final topFrame = frame(href: '$trustedUrl#home');
    final subject = policy(topFrame);

    final lease = await subject.bootstrapLease();

    expect(lease, isNotNull);
    expect(lease!.capability, isNotEmpty);
    expect((await subject.authorize(lease.capability))?.authorized, isTrue);
    expect(topFrame.marker, isNotNull);
    expect(subject.requiresCapability('completeLogin'), isTrue);
    expect(subject.requiresCapability('getBridgeInfo'), isFalse);
    expect(subject.requiresCapability('submitTransaction'), isFalse);
  });

  test('the centralized privileged method set stays explicit', () {
    expect(PrivilegedBridgePolicy.privilegedMethods, {
      'addHomeScreenShortcut',
      'getHomeScreenShortcuts',
      'removeHomeScreenShortcut',
      'reorderHomeScreenShortcuts',
      'openNativeScreen',
      'captureScreenshot',
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
      'markPrivilegedBridgeReady',
      'logout',
      'getSocialPushState',
      'setSocialPushEnabled',
      'claimPendingSocialNotification',
      'ackPendingSocialNotification',
    });
  });

  test('missing, empty, and guessed capabilities are denied in their realm',
      () async {
    final topFrame = frame();
    final subject = policy(topFrame);

    expect((await subject.authorize(null))?.authorized, isFalse);
    expect((await subject.authorize(''))?.authorized, isFalse);

    expect(
      (await subject.authorize('child-frame-guess'))?.authorized,
      isFalse,
    );
    expect(topFrame.evaluationCount, 3);
  });

  test('same-realm path, query, and fragment changes preserve capability',
      () async {
    final topFrame = frame(href: '$trustedUrl#home');
    final subject = policy(topFrame);
    final first = await subject.bootstrapLease();

    for (final nextLocation in <String>[
      '$trustedUrl#settings',
      '${trustedUrl}settings',
      '${trustedUrl}settings?tab=notifications#ios',
      trustedUrl,
    ]) {
      topFrame.href = nextLocation;
      final next = await subject.bootstrapLease();
      expect(
        next?.capability,
        first?.capability,
        reason: '$nextLocation is the same JavaScript realm',
      );
      expect(
        (await subject.authorize(first?.capability))?.authorized,
        isTrue,
      );
    }
  });

  test('document replacement rotates token without lifecycle callbacks',
      () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    final first = await subject.bootstrapLease();

    topFrame.replaceDocument(href: '${trustedUrl}settings');

    expect((await subject.authorize(first?.capability))?.authorized, isFalse);
    final second = await subject.bootstrapLease();
    expect(second?.capability, isNot(first?.capability));
    expect((await subject.authorize(second?.capability))?.authorized, isTrue);
  });

  test('BFCache restoration revives only the original realm token', () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    final first = await subject.bootstrapLease();
    final firstMarker = topFrame.marker;

    topFrame.replaceDocument(href: '${trustedUrl}settings');
    final second = await subject.bootstrapLease();
    expect(second?.capability, isNot(first?.capability));

    topFrame.restoreDocument(href: '$trustedUrl#home', marker: firstMarker);
    expect((await subject.authorize(second?.capability))?.authorized, isFalse);
    final restored = await subject.bootstrapLease();
    expect(restored?.capability, first?.capability);
    expect((await subject.authorize(first?.capability))?.authorized, isTrue);
  });

  test('untrusted document cannot bootstrap or use a cached capability',
      () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    final trusted = await subject.bootstrapLease();

    topFrame.replaceDocument(href: 'https://untrusted.example/app');

    expect(await subject.bootstrapLease(), isNull);
    expect(await subject.authorize(trusted?.capability), isNull);
  });

  test('bootstrap response is dropped after a document replacement', () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    final lease = await subject.bootstrapLease();

    topFrame.replaceDocument(href: 'https://untrusted.example/app');

    expect(
      await subject.resolve(
        lease: lease!,
        id: 'bootstrap-request',
        value: lease.capability,
        error: null,
      ),
      isFalse,
    );
    expect(topFrame.resolutions, isEmpty);
  });

  test('privileged response is delivered only to its authorizing realm',
      () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    final bootstrap = await subject.bootstrapLease();
    final authorization = await subject.authorize(bootstrap?.capability);
    final lease = authorization?.lease;

    expect(
      await subject.resolve(
        lease: lease!,
        id: 'settings-request',
        value: const {'notifications': true},
        error: null,
      ),
      isTrue,
    );
    expect(topFrame.resolutions, ['settings-request']);

    topFrame.replaceDocument(href: '${trustedUrl}other');
    expect(
      await subject.resolve(
        lease: lease,
        id: 'late-settings-request',
        value: const {'notifications': true},
        error: null,
      ),
      isFalse,
    );
    expect(topFrame.resolutions, ['settings-request']);
  });

  test('native events dispatch and acknowledge only the probed realm',
      () async {
    final topFrame = frame();
    final subject = policy(topFrame);

    expect(
      await subject.runInTrustedTopFrame('window.dispatchEvent(event);'),
      isTrue,
    );
    expect(topFrame.guardedRuns, 1);

    topFrame.replaceBeforeNextGuard =
        'https://social-vibecoding.usernodelabs.org/replacement';
    expect(
      await subject.runInTrustedTopFrame('window.dispatchEvent(event);'),
      isFalse,
    );
    expect(topFrame.guardedRuns, 1);
  });

  test('effect-time revalidation requires the same realm marker', () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    final lease = await subject.bootstrapLease();

    expect(await subject.revalidates(lease!), isTrue);

    topFrame.replaceDocument(href: '${trustedUrl}replacement');
    expect(await subject.revalidates(lease), isFalse);
  });

  test('readiness support is checked only in the exact leased realm', () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    final lease = await subject.bootstrapLease();

    topFrame.supportsExplicitReadiness = true;
    expect(await subject.supportsExplicitReadiness(lease!), isTrue);
    topFrame.supportsExplicitReadiness = false;
    expect(await subject.supportsExplicitReadiness(lease), isFalse);

    topFrame.replaceDocument(href: '${trustedUrl}replacement');
    expect(await subject.supportsExplicitReadiness(lease), isNull);
  });

  test('out-of-order concurrent probes derive one realm token', () async {
    final topFrame = frame();
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    topFrame.probeGates.addAll([firstGate, secondGate]);
    final subject = policy(topFrame);

    final first = subject.bootstrapLease();
    final second = subject.bootstrapLease();
    secondGate.complete();
    final secondLease = await second;
    firstGate.complete();
    final firstLease = await first;

    expect(firstLease?.capability, secondLease?.capability);
  });

  test('overlapping request contexts retain their own realm leases', () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    final firstLease = await subject.bootstrapLease();
    topFrame.replaceDocument(href: '${trustedUrl}settings');
    final secondLease = await subject.bootstrapLease();
    final releaseFirst = Completer<void>();
    final releaseSecond = Completer<void>();

    final first = PrivilegedBridgeRequestContext.run(
      lease: firstLease,
      body: () async {
        expect(
          PrivilegedBridgeRequestContext.currentLease?.capability,
          firstLease?.capability,
        );
        await releaseFirst.future;
        return PrivilegedBridgeRequestContext.currentLease?.capability;
      },
    );
    final second = PrivilegedBridgeRequestContext.run(
      lease: secondLease,
      body: () async {
        expect(
          PrivilegedBridgeRequestContext.currentLease?.capability,
          secondLease?.capability,
        );
        await releaseSecond.future;
        return PrivilegedBridgeRequestContext.currentLease?.capability;
      },
    );

    releaseSecond.complete();
    expect(await second, secondLease?.capability);
    releaseFirst.complete();
    expect(await first, firstLease?.capability);
  });

  test('an unprivileged request shadows a parent privileged context', () async {
    final subject = policy(frame());
    final lease = await subject.bootstrapLease();

    await PrivilegedBridgeRequestContext.run(
      lease: lease,
      body: () async {
        expect(PrivilegedBridgeRequestContext.currentLease, same(lease));
        await PrivilegedBridgeRequestContext.run(
          lease: null,
          body: () async {
            expect(PrivilegedBridgeRequestContext.currentLease, isNull);
          },
        );
        expect(PrivilegedBridgeRequestContext.currentLease, same(lease));
      },
    );
  });

  test('uses a scalar realm result on WKWebView and Android WebView', () async {
    final iosFrame = frame();
    final androidFrame = frame()..androidResultEncoding = true;

    expect(await policy(iosFrame).bootstrapLease(), isNotNull);
    expect(await policy(androidFrame).bootstrapLease(), isNotNull);
    expect(iosFrame.lastProbeScript, isNot(contains('return [')));
    expect(
      iosFrame.lastProbeScript,
      contains("return marker.length + ':' + marker + href"),
    );
  });

  test('page-controlled JSON serializer is never used by the probe', () async {
    final topFrame = frame()..rejectJsonStringify = true;
    final subject = policy(topFrame);

    expect(await subject.bootstrapLease(), isNotNull);
    expect(topFrame.lastProbeScript, isNot(contains('JSON.stringify')));
  });

  test('production requires the exact configured HTTPS origin', () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    expect(await subject.bootstrapLease(), isNotNull);

    for (final denied in <String>[
      'http://social-vibecoding.usernodelabs.org/',
      'https://sub.social-vibecoding.usernodelabs.org/',
      'https://social-vibecoding.usernodelabs.org:444/',
      'https://social-vibecoding.usernodelabs.org@evil.example/',
      'about:blank',
      'data:text/html,hello',
      'blob:https://social-vibecoding.usernodelabs.org/id',
    ]) {
      topFrame.replaceDocument(href: denied);
      expect(
        await subject.bootstrapLease(),
        isNull,
        reason: '$denied is outside the configured origin',
      );
    }
  });

  test('loopback is trusted only when local development is enabled', () async {
    final releaseFrame = frame(href: 'http://127.0.0.1:3000/');
    final debugFrame = frame(href: 'http://127.0.0.1:3000/');

    expect(await policy(releaseFrame).bootstrapLease(), isNull);
    final debugPolicy = policy(debugFrame, allowLocalDevelopment: true);
    expect(await debugPolicy.bootstrapLease(), isNotNull);

    for (final loopback in <String>[
      'http://localhost:3000/',
      'http://10.0.2.2:3000/',
      'http://[::1]:3000/',
    ]) {
      debugFrame.replaceDocument(href: loopback);
      expect(await debugPolicy.bootstrapLease(), isNotNull);
    }
  });

  test('malformed and failed probe results deny access', () async {
    for (final result in <Object?>[
      null,
      true,
      1,
      '',
      'not json',
      '{}',
      '(\n    "$trustedUrl",\n    "marker"\n)',
      '0:$trustedUrl',
      '6:short',
      '999:marker$trustedUrl',
      jsonEncode('broken envelope'),
      <Object?>[],
      <Object?>[trustedUrl],
      <Object?>[trustedUrl, ''],
      <Object?>[true, 'marker'],
      <Object?>[trustedUrl, 'marker', true],
    ]) {
      final topFrame = frame()..forcedResult = result;
      expect(
        await policy(topFrame).bootstrapLease(),
        isNull,
        reason: '$result must fail closed',
      );
    }

    final failedFrame = frame()..failure = StateError('page replaced');
    expect(await policy(failedFrame).bootstrapLease(), isNull);
  });

  test('a timed-out probe fails closed without poisoning its realm', () async {
    final topFrame = frame()..neverComplete = true;
    final subject = policy(topFrame);

    expect(await subject.bootstrapLease(), isNull);

    topFrame.neverComplete = false;
    expect(await subject.bootstrapLease(), isNotNull);
  });

  test('dispose invalidates completed and in-flight probes', () async {
    final topFrame = frame();
    final subject = policy(topFrame);
    final lease = await subject.bootstrapLease();
    final gate = Completer<void>();
    topFrame.probeGates.add(gate);
    final inFlight = subject.authorize(lease?.capability);

    subject.dispose();
    gate.complete();

    expect(await inFlight, isNull);
    final readsAfterDispose = topFrame.evaluationCount;
    expect(await subject.bootstrapLease(), isNull);
    expect(await subject.authorize(lease?.capability), isNull);
    expect(topFrame.evaluationCount, readsAfterDispose);
  });

  test('separate WebViews use different tokens', () async {
    final secrets = _SecretSequence();
    final first = policy(frame(), secrets: secrets);
    final second = policy(frame(), secrets: secrets);

    final firstLease = await first.bootstrapLease();
    final secondLease = await second.bootstrapLease();

    expect(firstLease?.capability, isNot(secondLease?.capability));
    expect(
      (await first.authorize(secondLease?.capability))?.authorized,
      isFalse,
    );
    expect(
      (await second.authorize(firstLease?.capability))?.authorized,
      isFalse,
    );
  });
}

final class _SecretSequence {
  int _next = 0;

  String next() => 'secret-${++_next}';
}

final class _FakeTopFrame {
  _FakeTopFrame(this.href);

  String href;
  String? marker;
  bool androidResultEncoding = false;
  bool neverComplete = false;
  bool rejectJsonStringify = false;
  bool supportsExplicitReadiness = true;
  String? replaceBeforeNextGuard;
  Object? forcedResult = _unset;
  Object? failure;
  int evaluationCount = 0;
  int guardedRuns = 0;
  String? lastProbeScript;
  final List<String> resolutions = <String>[];
  final List<Completer<void>> probeGates = <Completer<void>>[];

  Future<Object?> evaluate(String script) async {
    evaluationCount++;
    if (failure case final error?) throw error;
    if (!identical(forcedResult, _unset)) return forcedResult;

    if (script.contains('Object.defineProperty(window, markerKey')) {
      lastProbeScript = script;
      if (rejectJsonStringify && script.contains('JSON.stringify')) {
        throw StateError('page replaced JSON.stringify');
      }
      marker ??= _extractDefinedValue(script);
      final result = currentProbeResult(script);
      final gate = probeGates.isEmpty ? null : probeGates.removeAt(0);
      if (neverComplete) return Completer<Object?>().future;
      if (gate != null) await gate.future;
      return result;
    }

    if (script.contains('__usernodeExplicitReadinessClient')) {
      final expectedMarker = _extractExpectedMarker(script);
      if (marker != expectedMarker) return null;
      return androidResultEncoding
          ? jsonEncode(supportsExplicitReadiness)
          : supportsExplicitReadiness;
    }

    final expectedMarker = _extractExpectedMarker(script);
    final replacement = replaceBeforeNextGuard;
    if (replacement != null) {
      replaceBeforeNextGuard = null;
      replaceDocument(href: replacement);
    }
    final delivered = marker == expectedMarker;
    if (delivered && script.contains('const resolver =')) {
      resolutions.add(_extractResolverId(script));
    } else if (delivered) {
      guardedRuns++;
    }
    return androidResultEncoding ? jsonEncode(delivered) : delivered;
  }

  Object currentProbeResult(String script) {
    final currentMarker = marker;
    if (currentMarker == null) throw StateError('missing realm marker');
    if (script.contains('return [window.location.href, window[markerKey]]')) {
      if (androidResultEncoding) {
        return jsonEncode(<Object?>[href, currentMarker]);
      }
      // webview_flutter_wkwebview returns Foundation's description for an
      // NSArray because its native adapter directly supports only scalar
      // strings and numbers. This deliberately is not JSON.
      return '(\n    "$href",\n    "$currentMarker"\n)';
    }
    if (!script.contains("return marker.length + ':' + marker + href")) {
      throw StateError('unknown realm probe result shape');
    }
    final value = '${currentMarker.length}:$currentMarker$href';
    return androidResultEncoding ? jsonEncode(value) : value;
  }

  void replaceDocument({required String href}) {
    this.href = href;
    marker = null;
  }

  void restoreDocument({required String href, required String? marker}) {
    this.href = href;
    this.marker = marker;
  }

  static String _extractDefinedValue(String script) {
    final match = RegExp(r'value:\s*"([^"]+)"').firstMatch(script);
    if (match == null) throw StateError('missing marker candidate');
    return match.group(1)!;
  }

  static String _extractExpectedMarker(String script) {
    final match =
        RegExp(r'window\[markerKey\] !== ("[^"]+")').firstMatch(script);
    if (match == null) throw StateError('missing marker guard');
    return jsonDecode(match.group(1)!) as String;
  }

  static String _extractResolverId(String script) {
    final match = RegExp(r'resolver\(("[^"]+")').firstMatch(script);
    if (match == null) throw StateError('missing resolver id');
    return jsonDecode(match.group(1)!) as String;
  }
}

const _unset = Object();
