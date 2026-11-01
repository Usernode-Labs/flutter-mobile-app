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
}
