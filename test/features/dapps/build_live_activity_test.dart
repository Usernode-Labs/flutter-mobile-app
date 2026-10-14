import 'dart:io';

import 'package:crypto_mobile_app/features/dapps/build_live_activity.dart';
import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2026-10-14 12:00 and 12:25 UTC.
  const startedAt = 1791979200000;
  const etaAt = 1791980700000;

  Map<String, Object?> validArgs([Map<String, Object?> overrides = const {}]) =>
      {
        'activityId': 'first-version:club-votes-b7cc89',
        'state': 'active',
        'title': 'Club Votes',
        'stage': 'Building it',
        'detail': 'Screens drawn',
        'startedAt': startedAt,
        'etaAt': etaAt,
        'deepLink': 'https://app.onhomeroom.com/#app/club-votes-b7cc89',
        ...overrides,
      };

  Matcher refusedWith(String code) => throwsA(
        isA<BuildActivityException>().having((e) => e.code, 'code', code),
      );

  group('BuildActivityRequest.parse', () {
    test('reads a full active request', () {
      final request = BuildActivityRequest.parse(validArgs());

      expect(request.activityId, 'first-version:club-votes-b7cc89');
      expect(request.state, BuildActivityState.active);
      expect(request.title, 'Club Votes');
      expect(request.stage, 'Building it');
      expect(request.detail, 'Screens drawn');
      expect(request.startedAtMs, startedAt);
      expect(request.etaAtMs, etaAt);
      expect(
        request.deepLink,
        'https://app.onhomeroom.com/#app/club-votes-b7cc89',
      );
      expect(request.endedTitle, isNull);
    });

    test('optional fields may be absent or null', () {
      final request = BuildActivityRequest.parse(const {
        'activityId': 'b1',
        'state': 'active',
        'title': 'Club Votes',
        'stage': 'Building it',
        'detail': null,
        'etaAt': null,
      });

      expect(request.detail, isNull);
      expect(request.startedAtMs, isNull);
      expect(request.etaAtMs, isNull);
      expect(request.deepLink, isNull);
    });

    test('ended needs no stage and carries the web headline', () {
      final request = BuildActivityRequest.parse(const {
        'activityId': 'b1',
        'state': 'ended',
        'title': 'Club Votes',
        'endedTitle': 'Club Votes is live',
      });

      expect(request.state, BuildActivityState.ended);
      expect(request.stage, isNull);
      expect(request.endedTitle, 'Club Votes is live');
    });

    test('text is one line: whitespace runs collapse, blanks are absent', () {
      final request = BuildActivityRequest.parse(validArgs({
        'title': '  Club\n Votes ',
        'stage': 'Building\t\tit',
        'detail': '   ',
      }));

      expect(request.title, 'Club Votes');
      expect(request.stage, 'Building it');
      expect(request.detail, isNull);
    });

    test('a fractional epoch rounds to whole milliseconds', () {
      final request = BuildActivityRequest.parse(
        validArgs({'startedAt': startedAt + 0.6}),
      );
      expect(request.startedAtMs, startedAt + 1);
    });

    test('refuses anything outside the contract', () {
      final bad = <String, Object?>{
        'args not an object': null,
        'activityId missing': validArgs({'activityId': null}),
        'activityId empty': validArgs({'activityId': ''}),
        'activityId too long': validArgs({'activityId': 'a' * 129}),
        'activityId with a space': validArgs({'activityId': 'club votes'}),
        'activityId with a slash': validArgs({'activityId': 'a/../b'}),
        'activityId not a string': validArgs({'activityId': 7}),
        'unknown state': validArgs({'state': 'paused'}),
        'state missing': validArgs({'state': null}),
        'title missing': validArgs({'title': null}),
        'title blank': validArgs({'title': ' \n '}),
        'title too long': validArgs({'title': 'x' * 81}),
        'title not a string': validArgs({'title': 42}),
        'stage missing while active': validArgs({'stage': null}),
        'stage too long': validArgs({'stage': 'x' * 81}),
        'detail too long': validArgs({'detail': 'x' * 121}),
        'endedTitle too long': validArgs({'endedTitle': 'x' * 121}),
        'startedAt in seconds': validArgs({'startedAt': 1791979200}),
        'startedAt a string': validArgs({'startedAt': '$startedAt'}),
        'etaAt not finite': validArgs({'etaAt': double.infinity}),
        'etaAt NaN': validArgs({'etaAt': double.nan}),
        'etaAt before startedAt': validArgs({'etaAt': startedAt - 1}),
        'etaAt equal to startedAt': validArgs({'etaAt': startedAt}),
        'deepLink http': validArgs({'deepLink': 'http://app.onhomeroom.com/'}),
        'deepLink custom scheme': validArgs({'deepLink': 'homeroom://app'}),
        'deepLink javascript': validArgs({'deepLink': 'javascript:alert(1)'}),
        'deepLink without host': validArgs({'deepLink': 'https:///path'}),
        'deepLink with credentials':
            validArgs({'deepLink': 'https://a:b@app.onhomeroom.com/'}),
        'deepLink too long': validArgs(
          {'deepLink': 'https://app.onhomeroom.com/${'x' * 1024}'},
        ),
        'deepLink not a string': validArgs({'deepLink': true}),
      };
      for (final entry in bad.entries) {
        expect(
          () => BuildActivityRequest.parse(entry.value),
          refusedWith('invalid_args'),
          reason: entry.key,
        );
      }
    });

    test('the channel arguments use the wire names', () {
      final args = BuildActivityRequest.parse(validArgs({
        'endedTitle': 'Club Votes is live',
      })).toChannelArguments();

      expect(args, {
        'activityId': 'first-version:club-votes-b7cc89',
        'state': 'active',
        'title': 'Club Votes',
        'stage': 'Building it',
        'detail': 'Screens drawn',
        'startedAt': startedAt,
        'etaAt': etaAt,
        'deepLink': 'https://app.onhomeroom.com/#app/club-votes-b7cc89',
        'endedTitle': 'Club Votes is live',
      });
    });
  });

  group('BuildLiveActivity', () {
    const channel = MethodChannel(BuildLiveActivity.channelName);
    final calls = <MethodCall>[];

    void answer(Object? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return handler(call);
      });
    }

    /// Native on iOS 16.1+: available, and `setBuildActivity` answers [reply].
    void answerAvailable(Object? Function(MethodCall call) reply) {
      answer((call) => call.method == 'isAvailable' ? true : reply(call));
    }

    tearDown(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('advertised only where ActivityKit exists, asked once', () async {
      answer((_) => true);
      final iosNew = BuildLiveActivity(isSupportedPlatform: true);
      expect(await iosNew.capabilities(), ['setBuildActivity']);
      expect(await iosNew.capabilities(), ['setBuildActivity']);
      expect(calls.map((c) => c.method), ['isAvailable']);

      answer((_) => false);
      final iosOld = BuildLiveActivity(isSupportedPlatform: true);
      expect(await iosOld.capabilities(), isEmpty);
    });

    test('a missing native handler advertises nothing', () async {
      final subject = BuildLiveActivity(isSupportedPlatform: true);
      expect(await subject.capabilities(), isEmpty);
      expect(await subject.apply(validArgs()), {'supported': false});
    });

    test('off iOS: never advertised, and a call resolves unsupported',
        () async {
      answer((_) => true);
      final android = BuildLiveActivity(isSupportedPlatform: false);

      expect(await android.capabilities(), isEmpty);
      expect(await android.apply(validArgs()), {'supported': false});
      // Whatever the page sent: nothing can show here, so nothing is wrong.
      expect(await android.apply(null), {'supported': false});
      expect(calls, isEmpty);
    });

    test('forwards the validated request and passes on the reply', () async {
      answerAvailable(
        (_) => {'supported': true, 'started': true, 'pushToken': 'ab12'},
      );
      final subject = BuildLiveActivity(isSupportedPlatform: true);

      final reply = await subject.apply(validArgs({'title': ' Club Votes '}));

      expect(reply, {'supported': true, 'started': true, 'pushToken': 'ab12'});
      final call = calls.singleWhere((c) => c.method == 'setBuildActivity');
      expect(
        call.arguments,
        BuildActivityRequest.parse(validArgs()).toChannelArguments(),
      );
    });

    test('the reply keeps only the contract keys, with their types', () async {
      answerAvailable(
        (_) => {
          'supported': true,
          'started': 'yes',
          'pushToken': '',
          'activity': 'internal',
        },
      );
      final subject = BuildLiveActivity(isSupportedPlatform: true);

      expect(
        await subject.apply(validArgs()),
        {'supported': true, 'started': false},
      );
    });

    test('Live Activities switched off resolve unsupported', () async {
      answerAvailable((_) => {'supported': false});
      final subject = BuildLiveActivity(isSupportedPlatform: true);

      expect(await subject.apply(validArgs()), {'supported': false});
    });

    test('bad args are refused before native is asked', () async {
      answerAvailable((_) => {'supported': true, 'started': true});
      final subject = BuildLiveActivity(isSupportedPlatform: true);

      await expectLater(
        subject.apply(validArgs({'deepLink': 'http://example.com'})),
        refusedWith('invalid_args'),
      );
      expect(calls.where((c) => c.method == 'setBuildActivity'), isEmpty);
    });

    test('a native error rejects as failed', () async {
      answerAvailable((_) => throw PlatformException(code: 'invalid_args'));
      final subject = BuildLiveActivity(isSupportedPlatform: true);

      await expectLater(subject.apply(validArgs()), refusedWith('failed'));
    });
  });

  group('bridge wiring', () {
    final dispatch = File(
      'lib/features/dapps/bridge/dapp_bridge_dispatch.dart',
    ).readAsStringSync();
    final handler = File(
      'lib/features/dapps/bridge/dapp_bridge_build_activity.dart',
    ).readAsStringSync();

    test('routed to its handler and advertised from native availability', () {
      expect(
        dispatch,
        contains(
          "if (method == 'setBuildActivity') {\n"
          '      await _handleSetBuildActivity(id, payload);',
        ),
      );
      expect(
        dispatch,
        contains('...await BuildLiveActivity.instance.capabilities(),'),
      );
      // Never unconditionally: the static list is advertised everywhere.
      expect(dispatch, isNot(contains("    'setBuildActivity',\n")));
    });

    test('privileged: trusted top frame only, revalidated before acting', () {
      expect(
        PrivilegedBridgePolicy.privilegedMethods,
        contains(BuildLiveActivity.capability),
      );
      final trusted =
          handler.indexOf('_requireTrustedChromeOrigin(id, method)');
      final revalidated =
          handler.indexOf('_revalidatePrivilegedBridgeLease(id, method)');
      final applied = handler.indexOf('BuildLiveActivity.instance.apply(');
      expect(trusted, greaterThanOrEqualTo(0));
      expect(revalidated, greaterThan(trusted));
      expect(applied, greaterThan(revalidated));
      expect(handler, contains("const method = 'setBuildActivity';"));
    });
  });

  group('iOS native contract', () {
    late String channelSwift;
    late String attributesSwift;
    late String widgetSwift;
    late String bundleSwift;
    late String appDelegate;
    late String project;
    late String infoPlist;

    setUpAll(() async {
      channelSwift =
          await File('ios/Runner/BuildActivityChannel.swift').readAsString();
      attributesSwift =
          await File('ios/Runner/BuildActivityAttributes.swift').readAsString();
      widgetSwift = await File('ios/HomeroomWidgets/BuildLiveActivity.swift')
          .readAsString();
      bundleSwift =
          await File('ios/HomeroomWidgets/HomeroomWidgetsBundle.swift')
              .readAsString();
      appDelegate = await File('ios/Runner/AppDelegate.swift').readAsString();
      project =
          await File('ios/Runner.xcodeproj/project.pbxproj').readAsString();
      infoPlist = await File('ios/Runner/Info.plist').readAsString();
    });

    test('Swift answers the channel, methods and argument names Dart sends',
        () {
      expect(
        channelSwift,
        contains('static let channelName = "${BuildLiveActivity.channelName}"'),
      );
      expect(channelSwift, contains('case "isAvailable":'));
      expect(channelSwift, contains('case "setBuildActivity":'));
      final wireKeys =
          BuildActivityRequest.parse(validArgs()).toChannelArguments().keys;
      for (final key in wireKeys) {
        expect(channelSwift, contains('args["$key"]'), reason: key);
      }
    });

    test('Swift re-checks the same limits Dart enforces', () {
      for (final (name, value) in [
        ('maxActivityIdLength', BuildActivityRequest.maxActivityIdLength),
        ('maxTitleLength', BuildActivityRequest.maxTitleLength),
        ('maxStageLength', BuildActivityRequest.maxStageLength),
        ('maxDetailLength', BuildActivityRequest.maxDetailLength),
        ('maxDeepLinkLength', BuildActivityRequest.maxDeepLinkLength),
      ]) {
        expect(channelSwift, contains('static let $name = $value'),
            reason: name);
      }
      expect(channelSwift, contains('url.scheme == "https"'));
      expect(attributesSwift, contains('url.scheme == "https"'));
    });

    test('the app registers the channel and ends the activity at sign-out', () {
      expect(appDelegate, contains('name: BuildActivityChannel.channelName'));
      expect(appDelegate, contains('buildActivityChannel.handle(call'));
      final clear = appDelegate.substring(
        appDelegate.indexOf('private func clearSessionNotifications('),
      );
      expect(
        clear.substring(0, clear.indexOf('\n  }\n')),
        contains('BuildActivityChannel.endAll()'),
      );
    });

    test('the attributes compile into both the app and the extension', () {
      int sources(String file) =>
          RegExp('/\\* ${RegExp.escape(file)} in Sources \\*/ = ')
              .allMatches(project)
              .length;
      expect(sources('BuildActivityAttributes.swift'), 2);
      expect(sources('BuildActivityChannel.swift'), 1);
      expect(sources('BuildLiveActivity.swift'), 1);
      expect(attributesSwift, contains('struct BuildActivityAttributes'));
      expect(attributesSwift, contains('@available(iOS 16.1, *)'));
    });

    test('the extension draws it and the app declares Live Activities', () {
      expect(bundleSwift, contains('BuildLiveActivityWidget()'));
      expect(bundleSwift, contains('if #available(iOS 16.1, *)'));
      expect(
        widgetSwift,
        contains('ActivityConfiguration(for: BuildActivityAttributes.self)'),
      );
      expect(
        infoPlist,
        contains('<key>NSSupportsLiveActivities</key>\n\t<true/>'),
      );
    });

    test('the countdown and progress run on their own while asleep', () {
      expect(widgetSwift, contains('Text(timerInterval: interval'));
      expect(widgetSwift, contains('ProgressView(timerInterval: interval'));
      expect(widgetSwift, contains('return isStale'));
    });
  });
}
