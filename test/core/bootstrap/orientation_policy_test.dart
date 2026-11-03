import 'package:crypto_mobile_app/core/bootstrap/orientation_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // iPhone Duo (iOS 27.1 simulator): the cover is 466x678pt, the inner
  // display 669x951pt. Held sideways, the inner display kept the app portrait.
  group('orientationsFor', () {
    test('a phone stays portrait', () {
      expect(orientationsFor(const Size(393, 852), TargetPlatform.iOS),
          portraitOnly);
    });

    test('the Duo folded is a phone', () {
      expect(orientationsFor(const Size(466, 678), TargetPlatform.iOS),
          portraitOnly);
    });

    test('the Duo unfolded turns, either way round', () {
      expect(orientationsFor(const Size(669, 951), TargetPlatform.iOS),
          anyOrientation);
      expect(orientationsFor(const Size(951, 669), TargetPlatform.iOS),
          anyOrientation);
    });

    test('an iPad turns, as its Info.plist list already says', () {
      expect(orientationsFor(const Size(820, 1180), TargetPlatform.iOS),
          anyOrientation);
    });

    test('no size yet reads as a phone', () {
      expect(orientationsFor(Size.zero, TargetPlatform.iOS), portraitOnly);
    });

    test('Android keeps its manifest portrait lock', () {
      expect(orientationsFor(const Size(900, 1200), TargetPlatform.android),
          portraitOnly);
    });

    test('anyOrientation is all four', () {
      expect(anyOrientation.toSet(), DeviceOrientation.values.toSet());
    });
  });

  // Flutter hands a new list to UIKit once. Unfolding, that can land while the
  // scene is still moving to the inner display, and the app stayed portrait
  // until a trip home (#635), so iOS is asked to read the list again once the
  // screen has settled.
  group('OrientationPolicy', () {
    late List<Object?> preferred;
    late List<String> rereads;
    late OrientationPolicy policy;

    Future<void> showScreen(WidgetTester tester, Size points) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = points * 3;
      await tester.pump();
    }

    setUp(() {
      preferred = [];
      rereads = [];
      policy = OrientationPolicy.forTesting();
    });

    Future<void> startOn(WidgetTester tester, Size points) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          preferred.add(call.arguments);
        }
        return null;
      });
      messenger.setMockMethodCallHandler(orientationChannel, (call) async {
        rereads.add(call.method);
        return null;
      });
      addTearDown(() {
        policy.stop();
        tester.view.reset();
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(orientationChannel, null);
      });
      await showScreen(tester, points);
      await policy.start();
    }

    testWidgets('asks iOS to read the list again once the unfold settles',
        (tester) async {
      await startOn(tester, const Size(466, 678));
      await tester.pump(orientationSettleDelay);
      expect(preferred, hasLength(1));
      expect(rereads, ['refresh']);

      await showScreen(tester, const Size(669, 951));
      expect(preferred, hasLength(2));
      expect(rereads, ['refresh'], reason: 'the screen has not settled yet');

      // Still changing (the strip's insets arriving): the wait starts again.
      await tester.pump(const Duration(milliseconds: 300));
      tester.view.padding = const FakeViewPadding(right: 84 * 3);
      await tester.pump(const Duration(milliseconds: 300));
      expect(rereads, ['refresh']);

      await tester.pump(orientationSettleDelay);
      expect(rereads, ['refresh', 'refresh']);
      expect(preferred, hasLength(2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('does not ask again while the list stays the same',
        (tester) async {
      await startOn(tester, const Size(669, 951));
      await tester.pump(orientationSettleDelay);
      expect(rereads, ['refresh']);

      // Turned sideways: still a large screen, so nothing new to read.
      await showScreen(tester, const Size(951, 669));
      await tester.pump(orientationSettleDelay * 2);
      expect(preferred, hasLength(1));
      expect(rereads, ['refresh']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('leaves Android alone', (tester) async {
      await startOn(tester, const Size(900, 1200));
      await tester.pump(orientationSettleDelay * 2);
      expect(preferred, hasLength(1));
      expect(rereads, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
