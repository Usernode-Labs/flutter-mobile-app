import 'dart:convert';

import 'package:crypto_mobile_app/features/dapps/native_screen_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(NativeScreenCapture.channelName);
  const subject = NativeScreenCapture();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns a JPEG bridge payload from native bytes', () async {
    final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'capture');
      return bytes;
    });

    final result = await subject.capture();

    expect(result['contentType'], 'image/jpeg');
    expect(base64Decode(result['base64']!), bytes);
  });

  test('rejects an empty native capture', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => Uint8List(0));

    await expectLater(subject.capture(), throwsStateError);
  });

  test('rejects a native capture above the feedback upload limit', () async {
    final oversized = Uint8List(NativeScreenCapture.maxUploadBytes + 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => oversized);

    await expectLater(subject.capture(), throwsStateError);
  });
}
