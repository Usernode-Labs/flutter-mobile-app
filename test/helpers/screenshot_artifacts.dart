import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const String challengeUiProofDirectory = '/tmp/codex-challenge-ui-proof';

Future<void> setScreenshotSurfaceSize(
  WidgetTester tester,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<File> writeWidgetScreenshotArtifact(
  WidgetTester tester,
  GlobalKey repaintBoundaryKey,
  String fileName, {
  double pixelRatio = 1,
}) async {
  final file = await tester.runAsync(() async {
    final context = repaintBoundaryKey.currentContext;
    if (context == null) {
      throw StateError('Screenshot boundary is not mounted.');
    }

    final boundary = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('Screenshot key must be attached to RepaintBoundary.');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (bytes == null) {
      throw StateError('Could not encode screenshot artifact.');
    }

    final file = File('$challengeUiProofDirectory/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  });

  if (file == null) {
    throw StateError('Could not write screenshot artifact.');
  }
  return file;
}
