import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/dapps/home_shortcuts_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.usernode.app/home_shortcuts');
  final calls = <MethodCall>[];
  Object? nextResult;

  setUp(() {
    calls.clear();
    nextResult = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return nextResult;
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('shortcutDarkIconUpdateFor', () {
    test('omission and null keep an existing dark icon', () {
      expect(
        shortcutDarkIconUpdateFor(fieldPresent: false, value: null),
        ShortcutDarkIconUpdate.keep,
      );
      expect(
        shortcutDarkIconUpdateFor(fieldPresent: true, value: null),
        ShortcutDarkIconUpdate.keep,
      );
    });

    test('empty string clears and non-empty string replaces', () {
      expect(
        shortcutDarkIconUpdateFor(fieldPresent: true, value: '  '),
        ShortcutDarkIconUpdate.clear,
      );
      expect(
        shortcutDarkIconUpdateFor(
          fieldPresent: true,
          value: 'https://example.org/dark.png',
        ),
        ShortcutDarkIconUpdate.replace,
      );
    });

    test('invalid non-string input keeps the stored slot', () {
      expect(
        shortcutDarkIconUpdateFor(fieldPresent: true, value: 42),
        ShortcutDarkIconUpdate.keep,
      );
    });
  });

  group('saveWidgetIcon', () {
    test('defaults to the light slot (dark: false)', () async {
      nextResult = true;
      final ok = await HomeShortcutsChannel.saveWidgetIcon(
        'abc123',
        Uint8List.fromList([1, 2, 3]),
      );
      expect(ok, isTrue);
      expect(calls.single.method, 'saveWidgetIcon');
      final args = calls.single.arguments as Map;
      expect(args['id'], 'abc123');
      expect(args['dark'], isFalse);
    });

    test('dark: true targets the dark slot', () async {
      nextResult = true;
      await HomeShortcutsChannel.saveWidgetIcon(
        'abc123',
        Uint8List.fromList([1, 2, 3]),
        dark: true,
      );
      expect((calls.single.arguments as Map)['dark'], isTrue);
    });
  });

  group('deleteWidgetIcon', () {
    test('defaults to clearing both slots (unpin path)', () async {
      nextResult = true;
      await HomeShortcutsChannel.deleteWidgetIcon('abc123');
      final args = calls.single.arguments as Map;
      expect(args['id'], 'abc123');
      expect(args['dark'], isFalse);
    });

    test('darkOnly clears just the dark slot (single-asset revert)', () async {
      nextResult = true;
      await HomeShortcutsChannel.deleteWidgetIcon('abc123', darkOnly: true);
      expect((calls.single.arguments as Map)['dark'], isTrue);
    });
  });

  group('listWidgetIconIds', () {
    test('splits native filename stems into light and dark id sets', () async {
      // The native side returns raw stems: bare ids for light assets,
      // `<id>.dark` for dark ones.
      nextResult = <Object?>['abc123', 'abc123.dark', 'def456'];
      final ids = await HomeShortcutsChannel.listWidgetIconIds();
      expect(ids.light, {'abc123', 'def456'});
      expect(ids.dark, {'abc123'});
    });

    test('returns empty sets on platform errors', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });
      final ids = await HomeShortcutsChannel.listWidgetIconIds();
      expect(ids.light, isEmpty);
      expect(ids.dark, isEmpty);
    });

    test('returns empty sets off iOS without touching the channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final ids = await HomeShortcutsChannel.listWidgetIconIds();
      expect(ids.light, isEmpty);
      expect(ids.dark, isEmpty);
      expect(calls, isEmpty);
    });
  });
}
