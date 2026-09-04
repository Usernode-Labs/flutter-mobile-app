import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native channel secrets become mutable Dart-owned bytes', () async {
    final channelBytes = Uint8List.fromList(
      List<int>.filled(32, 7),
    ).asUnmodifiableView();

    expect(
      () => channelBytes.fillRange(0, channelBytes.length, 0),
      throwsUnsupportedError,
    );

    final ownedBytes = Uint8List.fromList(channelBytes);
    ownedBytes.fillRange(0, ownedBytes.length, 0);

    expect(ownedBytes, everyElement(0));
    expect(channelBytes, everyElement(7));

    final source = await File(
      'lib/src/session_lifecycle/native_session_transport.dart',
    ).readAsString();
    expect(source, contains('return Uint8List.fromList(raw);'));
    expect(
      RegExp(r'_ownedNativeSecret\(').allMatches(source),
      hasLength(6), // Five channel values plus the private boundary helper.
    );
  });
}
