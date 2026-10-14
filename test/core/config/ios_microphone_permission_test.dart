import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS web microphone capture has a nonempty permission explanation', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final purpose = RegExp(
      r'<key>NSMicrophoneUsageDescription</key>\s*<string>([^<]*)</string>',
    ).firstMatch(plist);

    expect(
      purpose,
      isNotNull,
      reason: 'iOS terminates the app when web microphone capture requests '
          'access without NSMicrophoneUsageDescription.',
    );
    expect(purpose!.group(1)!.trim(), isNotEmpty);
  });
}
