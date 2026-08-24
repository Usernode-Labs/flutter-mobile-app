import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';

typedef NetworkChangeRestartHandler = void Function();

/// Ends the current UI process after a journal-committed network change.
///
/// Session safety is already established by the journal, disposable host and
/// runtime supervisor before this boundary runs. Android restarts the process;
/// iOS stays on the inert relaunch surface because self-termination is not a
/// supported platform operation.
class NetworkChangeRestartService {
  NetworkChangeRestartService._();

  static final NetworkChangeRestartService instance =
      NetworkChangeRestartService._();

  NetworkChangeRestartHandler? _handler;

  void registerRestartHandler(NetworkChangeRestartHandler handler) {
    _handler = handler;
  }

  void unregisterRestartHandler() {
    _handler = null;
  }

  @visibleForTesting
  void enterRestartSurfaceForTesting() => _handler?.call();

  Future<void> restart() async {
    final handler = _handler;
    if (handler == null) {
      throw StateError('No network-change restart surface is registered');
    }
    handler();
    await PlatformAlarmService.instance.restartAfterNetworkChange();
  }
}
