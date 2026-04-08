/// Debug entrypoint for Marionette MCP runtime interaction.
///
/// Run with: `flutter run -t lib/main_debug.dart`
/// Then connect via: `claude mcp add --transport stdio marionette -- marionette_mcp`
///
/// MarionetteBinding replaces the standard WidgetsFlutterBinding,
/// enabling AI agents to interact with the running app via MCP tools
/// (tap, scroll, type, screenshot, etc.).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'package:crypto_mobile_app/core/bootstrap/app_bootstrap.dart';
import 'package:crypto_mobile_app/main.dart' show AppRuntimeRoot;

import 'core/debug/marionette_config.dart';

Future<void> main() async {
  // Initialize MarionetteBinding instead of the standard binding.
  // This must be called before any other Flutter initialization.
  MarionetteBinding.ensureInitialized(marionetteConfiguration);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final boot = await AppBootstrap.initNonUi(logTag: 'usernode/Debug');
  boot.log.info('Debug app started (Marionette MCP enabled)');

  runApp(AppRuntimeRoot(initialContainer: boot.container));
}
