import 'package:flutter/widgets.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

class AppLifecycleLogger with WidgetsBindingObserver {
  static AppLifecycleLogger? _instance;

  static void register() {
    _instance ??= AppLifecycleLogger();
    WidgetsBinding.instance.addObserver(_instance!);
    SentryUtil.addBreadcrumb(category: 'lifecycle', message: 'observer registered');
  }

  static void unregister() {
    if (_instance != null) {
      WidgetsBinding.instance.removeObserver(_instance!);
      SentryUtil.addBreadcrumb(category: 'lifecycle', message: 'observer removed');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SentryUtil.addBreadcrumb(
      category: 'lifecycle',
      message: 'state: ${state.name}',
    );
  }
}

