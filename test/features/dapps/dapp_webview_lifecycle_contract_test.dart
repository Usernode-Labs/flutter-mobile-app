import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resuming the app replays authoritative state into the WebView',
      () async {
    final source = await File(
      'lib/features/dapps/dapp_webview_screen.dart',
    ).readAsString();
    final lifecycleStart = source.indexOf(
      'void didChangeAppLifecycleState(AppLifecycleState state)',
    );
    final lifecycle = source.substring(
      lifecycleStart,
      source.indexOf('  /// Presents the OS file picker', lifecycleStart),
    );

    expect(source, contains('WidgetsBindingObserver,'));
    expect(source, contains('WidgetsBinding.instance.addObserver(this);'));
    expect(
      lifecycle,
      contains('state != AppLifecycleState.resumed || !mounted'),
    );
    expect(lifecycle, contains('_dispatchAuthStatusEvent();'));
    expect(lifecycle, contains('_dispatchPendingSocialPushEvents();'));
    expect(source, contains('WidgetsBinding.instance.removeObserver(this);'));
  });
}
