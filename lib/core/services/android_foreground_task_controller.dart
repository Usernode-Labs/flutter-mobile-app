import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:crypto_mobile_app/core/models/vrf_status.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';

final _log = LoggingService.instance.withTag('usernode/AndroidForegroundTask');

class AndroidForegroundTaskController {
  AndroidForegroundTaskController._();

  static final AndroidForegroundTaskController instance =
      AndroidForegroundTaskController._();

  static const Duration _pollInterval = Duration(seconds: 30);
  static const Duration _alarmLead = Duration(minutes: 1);

  Timer? _pollTimer;
  bool _initialized = false;
  bool _wakelockHeld = false;
  AccountPublicKey? _cachedOurPubKey;
  ({int height, DateTime since})? _awaitingOtherProducerState;

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    // Request notification permission on Android 13+ so the foreground
    // notification is visible. In headless mode (no Activity), we can only
    // check the status, not request it.
    try {
      final notificationStatus = await Permission.notification.request();
      _log.info('Notification permission status: $notificationStatus');
    } on PlatformException catch (e) {
      // In headless mode, PermissionHandler cannot detect an Activity.
      // Just check the status instead of requesting.
      if (e.code == 'PermissionHandler.PermissionManager' &&
          e.message?.contains('Unable to detect current Android Activity') ==
              true) {
        _log.debug(
            'Running in headless mode, checking notification permission status instead of requesting');
        try {
          final status = await Permission.notification.status;
          _log.info('Notification permission status (headless): $status');
        } catch (statusError) {
          _log.warn(
              'Could not check notification permission status: $statusError');
        }
      } else {
        // Re-throw if it's a different error
        rethrow;
      }
    } catch (e) {
      _log.warn('Error handling notification permission: $e');
    }

    _initialized = true;
    _log.info('AndroidForegroundTask initialized');
  }

  Future<void> onNodeStarted() async {
    if (!Platform.isAndroid) return;
    if (AppSleepStateStore.isSleeping) {
      _log.info('Skipping Android monitoring start while app sleep is active');
      return;
    }
    await startMonitoring(reason: 'node_started');
  }

  Future<void> startMonitoring({String reason = 'manual'}) async {
    if (!Platform.isAndroid) return;
    if (AppSleepStateStore.isSleeping) {
      _log.info(
        'Skipping Android monitoring start while app sleep is active',
        context: {'reason': reason},
      );
      return;
    }
    await initialize();

    // Ensure the Rust node is running before polling VRF or scheduling alarms.
    final nodeOk = await _ensureNodeRunning();
    if (!nodeOk) {
      _log.error('Cannot start monitoring: node failed to start');
      return;
    }

    await _acquireWakelock();

    final running =
        await PlatformAlarmService.instance.isForegroundServiceRunning();
    if (!running) {
      final result = await PlatformAlarmService.instance.startForegroundService(
        title: 'Usernode',
        message: 'Evaluating VRF slots',
        slotNumber: 0,
      );
      _log.info('Foreground service start result: $result');
    }

    _startPollTimer();
  }

  Future<void> stopMonitoring({String reason = 'stopped'}) async {
    if (!Platform.isAndroid) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isAppMinimized = lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached;
    if (isAppMinimized) {
      await RustBackendService.instance.pauseNode();
    } else {
      _log.info(
          'Activity is resumed; skipping node pause on stopMonitoring ($reason)');
    }
    await _releaseWakelock();
    await PlatformAlarmService.instance.stopForegroundService();
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollVrf());
    });
    unawaited(_pollVrf());
  }

  Future<void> handleAlarmFire({String reason = 'alarm'}) async {
    if (AppSleepStateStore.isSleeping) {
      _log.info(
        'Ignoring alarm-fired monitoring start while app sleep is active',
        context: {'reason': reason},
      );
      return;
    }
    _log.info('Alarm fired, restarting foreground task ($reason)');
    await startMonitoring(reason: reason);
  }

  Future<void> resetForAppRestart() async {
    if (!Platform.isAndroid) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    _initialized = false;
    _wakelockHeld = false;
    _cachedOurPubKey = null;
    _awaitingOtherProducerState = null;
  }

  Future<bool> _ensureNodeRunning() async {
    try {
      final started = await RustBackendService.instance.startNode();
      await RustBackendService.instance.resumeNode();
      _log.info('Node start result: $started');
      return started;
    } catch (e, st) {
      _log.error('Error ensuring node running', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> _pollVrf() async {
    try {
      final info = await RustBackendService.instance.getEpochInfo();
      if (info == null) {
        _log.warn('VRF poll: epoch info unavailable');
        return;
      }

      final clockDriftMs =
          await RustBackendService.instance.resolveNodeClockDriftMs();
      if (clockDriftMs == null) {
        _log.warn('VRF poll: node clock drift unavailable');
        return;
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final rustNowMs = RustBackendService.instance.rustTimeMsFromLocalTimeMs(
        nowMs,
        clockDriftMs: clockDriftMs,
      );
      final nextWon = _nextWonSlot(info.wonSlots, rustNowMs);

      if (nextWon != null) {
        final rustSlotTimeMs = nextWon.expectedTimeMs.toInt();
        final localSlotTimeMs =
            RustBackendService.instance.localTimeMsFromRustTimeMs(
          rustSlotTimeMs,
          clockDriftMs: clockDriftMs,
        );
        final diffMs = localSlotTimeMs - nowMs;

        if (diffMs > _alarmLead.inMilliseconds) {
          await _scheduleResume(
            rustSlotTimeMs - _alarmLead.inMilliseconds,
            'next_won_slot:${nextWon.globalSlot}',
          );
        } else {
          _log.info(
            'Next won slot ${nextWon.globalSlot} in <1m, keeping foreground running',
          );
        }
        return;
      }

      if (info.vrfStatus != VRFStatus.complete) {
        _log.debug(
            'VRF poll: status=${info.vrfStatus.displayName}, continuing');
        return;
      }

      final epochEndRustTimeMs = await _getEpochEndTimeMs(info.currentEpoch);
      if (epochEndRustTimeMs == null) {
        _log.warn('VRF poll: could not compute epoch end');
        return;
      }

      final localEpochEndTimeMs =
          RustBackendService.instance.localTimeMsFromRustTimeMs(
        epochEndRustTimeMs,
        clockDriftMs: clockDriftMs,
      );
      final untilEndMs = localEpochEndTimeMs - nowMs;
      if (untilEndMs > _alarmLead.inMilliseconds) {
        await _scheduleResume(
          epochEndRustTimeMs - _alarmLead.inMilliseconds,
          'epoch_end_${info.currentEpoch}',
        );
      } else {
        _log.info('Epoch end <1m, keeping foreground until end');
      }
    } catch (e, st) {
      _log.error('VRF poll failed', error: e, stackTrace: st);
    }
  }

  Future<bool> _shouldHoldForOtherProducerBlock(
      {bool doubleCheck = true}) async {
    try {
      if (_cachedOurPubKey == null) {
        final bpStatus =
            await RustBackendService.instance.getBlockProducerStatus();
        _cachedOurPubKey = bpStatus?.blockProducer?.pubKey;
      }
      if (_cachedOurPubKey == null) {
        _awaitingOtherProducerState = null;
        return false;
      }

      if (_awaitingOtherProducerState == null) {
        final ownBlocks = await RustBackendService.instance.listBlockchain(
          limit: 1,
          fromTip: true,
          blockProducer: _cachedOurPubKey,
        );
        final ownBlock = (ownBlocks?.items.isNotEmpty ?? false)
            ? ownBlocks!.items.first
            : null;
        if (ownBlock == null) {
          _awaitingOtherProducerState = null;
          return false;
        }
        _awaitingOtherProducerState =
            (height: ownBlock.height, since: DateTime.now());
      }

      if (_awaitingOtherProducerState == null) {
        return false;
      }

      final waitingSince = _awaitingOtherProducerState!.since;
      if (DateTime.now().difference(waitingSince) >
          const Duration(seconds: 30)) {
        _log.info(
          'Waited 30 seconds for another producer block after height ${_awaitingOtherProducerState!.height}; releasing',
        );
        _awaitingOtherProducerState = null;
        return false;
      }

      final recentBlocks = await RustBackendService.instance.listBlockchain(
        limit: 1,
        fromTip: true,
      );
      final items = recentBlocks?.items ?? const [];
      final ourPubKeyStr = _cachedOurPubKey.toString();
      final hasOtherAfter = items.any((block) =>
          block.height > _awaitingOtherProducerState!.height &&
          block.producerPubkey.toString() != ourPubKeyStr);

      if (hasOtherAfter) {
        if (doubleCheck) {
          return await _shouldHoldForOtherProducerBlock(doubleCheck: false);
        }
        _awaitingOtherProducerState = null;
        return false;
      }

      return true;
    } catch (e, st) {
      _log.warn(
        'Failed to check post-production block status: $e',
      );
      _log.debug('$st');
      return _awaitingOtherProducerState != null;
    }
  }

  Future<void> _scheduleResume(int rustWakeTimeMs, String reason) async {
    if (await _shouldHoldForOtherProducerBlock()) {
      final height = _awaitingOtherProducerState?.height;
      _log.info(
        'Keeping wakelock: waiting for another producer block after height ${height ?? 'unknown'}',
      );
      return;
    }

    final clockDriftMs =
        await RustBackendService.instance.resolveNodeClockDriftMs();
    if (clockDriftMs == null) {
      _log.warn('Skipping resume alarm: node clock drift unavailable');
      return;
    }
    final localWakeTimeMs =
        RustBackendService.instance.localTimeMsFromRustTimeMs(
      rustWakeTimeMs,
      clockDriftMs: clockDriftMs,
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final delayMs = localWakeTimeMs - nowMs;
    final success = await PlatformAlarmService.instance.scheduleAlarm(
      alarmId: 'fg_resume',
      delayMs: delayMs,
      slotNumber: 0,
      data: {
        'reason': reason,
        'nodeRunning': RustBackendService.instance.isRunning,
      },
    );

    final localWakeTime = DateTime.fromMillisecondsSinceEpoch(localWakeTimeMs);
    _log.info(
      'Scheduled resume alarm at $localWakeTime for $reason '
      '(success=$success, rustWakeTimeMs=$rustWakeTimeMs, '
      'clockDriftMs=$clockDriftMs)',
    );
    await stopMonitoring(reason: reason);
  }

  RpcEpochWonSlot? _nextWonSlot(List<RpcEpochWonSlot> slots, int rustNowMs) {
    final futureSlots = slots
        .where((s) => s.expectedTimeMs.toInt() + 5000 > rustNowMs)
        .toList()
      ..sort((a, b) => a.expectedTimeMs.compareTo(b.expectedTimeMs));
    if (futureSlots.isEmpty) return null;
    return futureSlots.first;
  }

  Future<int?> _getEpochEndTimeMs(int epoch) async {
    try {
      final status = await RustBackendService.instance.getStatus(
        includeVrfDetails: false,
      );
      final slotsInEpoch = status?.node.slotsInEpoch;
      if (slotsInEpoch == null || slotsInEpoch <= 0) return null;

      final slotResp = await RustBackendService.instance.getSlotTime(
        epoch: epoch,
        slot: slotsInEpoch - 1,
      );
      final timestampMs = slotResp?.timestampMs?.toInt();
      if (timestampMs == null) return null;
      return timestampMs;
    } catch (_) {
      return null;
    }
  }

  Future<void> _acquireWakelock() async {
    try {
      // Use a native PARTIAL_WAKE_LOCK so it works without a foreground Activity.
      final ok = await PlatformAlarmService.instance.acquireWakelock();
      _wakelockHeld = ok;
      if (ok) _log.info('Native wakelock acquired');
    } catch (e) {
      _log.warn('Failed to acquire wakelock: $e');
    }
  }

  Future<void> _releaseWakelock() async {
    try {
      final ok = await PlatformAlarmService.instance.releaseWakelock();
      _wakelockHeld = false;
      if (ok) _log.info('Native wakelock released');
    } catch (e) {
      _log.warn('Failed to release wakelock: $e');
    }
  }

  Future<bool> isForegroundServiceRunning() async {
    if (!Platform.isAndroid) return false;
    return await PlatformAlarmService.instance.isForegroundServiceRunning();
  }

  /// Handle native alarm events (from AlarmReceiver via PlatformAlarmService)
  void handleNativeEvent(String eventType, Map<String, dynamic> data) {
    if (!Platform.isAndroid) return;
    if (eventType != 'android_alarm_fired') return;
    if (AppSleepStateStore.isSleeping) {
      _log.info('Ignoring native alarm event while app sleep is active');
      return;
    }

    final alarmId = data['alarmId'] as String? ?? '';
    if (alarmId == 'fg_resume') {
      unawaited(handleAlarmFire(reason: 'alarm_resume'));
    }
  }

  Future<bool> isWakelockHeld() async {
    if (!Platform.isAndroid) return false;
    if (_wakelockHeld) return true;
    try {
      return await PlatformAlarmService.instance.isWakelockHeld();
    } catch (_) {
      return false;
    }
  }

  bool isWakelockHeldSync() {
    if (!Platform.isAndroid) return false;
    return _wakelockHeld;
  }
}

// Foreground service lifecycle is handled natively via PlatformAlarmService.
