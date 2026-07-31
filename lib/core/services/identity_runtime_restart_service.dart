import 'dart:async';

import 'package:crypto_mobile_app/core/utils/logger.dart';

typedef IdentityRuntimeRestartHandler = Future<void> Function(String reason);

/// Bridges a durable identity transition to the interactive runtime host.
///
/// `SessionController` closes the identity gate and persists the replacement
/// before requesting a restart. The handler is scheduled on the next event
/// turn so the controller's serialized transition can return before its
/// provider container is disposed.
class IdentityRuntimeRestartService {
  IdentityRuntimeRestartService._();

  static final instance = IdentityRuntimeRestartService._();

  final _log =
      LoggingService.instance.withTag('usernode/IdentityRuntimeRestart');

  IdentityRuntimeRestartHandler? _handler;
  final List<String> _pendingReasons = [];
  bool _drainScheduled = false;
  bool _draining = false;

  void registerHandler(IdentityRuntimeRestartHandler handler) {
    _handler = handler;
  }

  void unregisterHandler() {
    _handler = null;
  }

  /// Returns whether an interactive host accepted the request.
  ///
  /// Headless and unit-test containers have no host. Their session controller
  /// uses its in-container fallback publication instead.
  bool request({required String reason}) {
    if (_handler == null) {
      _log.debug(
        'No interactive runtime host; keeping the transition in-container',
        context: {'reason': reason},
      );
      return false;
    }

    _pendingReasons.add(reason);
    _scheduleDrain();
    return true;
  }

  void _scheduleDrain() {
    if (_drainScheduled || _draining) return;
    _drainScheduled = true;
    Timer.run(() {
      _drainScheduled = false;
      unawaited(_drain());
    });
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_pendingReasons.isNotEmpty) {
        final reasons = List<String>.of(_pendingReasons);
        _pendingReasons.clear();
        final handler = _handler;
        if (handler == null) {
          _log.warn(
            'Runtime host disappeared before identity cutover',
            context: {'reasons': reasons},
          );
          return;
        }
        try {
          await handler(reasons.join(', '));
        } catch (error, stackTrace) {
          _log.error(
            'Identity runtime restart failed',
            error: error,
            stackTrace: stackTrace,
            context: {'reasons': reasons},
          );
          return;
        }
      }
    } finally {
      _draining = false;
      if (_pendingReasons.isNotEmpty) _scheduleDrain();
    }
  }

  void resetForTesting() {
    _handler = null;
    _pendingReasons.clear();
    _drainScheduled = false;
    _draining = false;
  }
}
