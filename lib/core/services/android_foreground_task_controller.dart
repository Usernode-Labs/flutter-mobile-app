import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:crypto_mobile_app/core/models/vrf_status.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';

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

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    // Request notification permission on Android 13+ so the foreground
    // notification is visible.
    final notificationStatus = await Permission.notification.request();
    _log.info('Notification permission status: $notificationStatus');

    _initialized = true;
    _log.info('AndroidForegroundTask initialized');
  }

  Future<void> onNodeStarted() async {
    if (!Platform.isAndroid) return;
    await startMonitoring(reason: 'node_started');
  }

  Future<void> startMonitoring({String reason = 'manual'}) async {
    if (!Platform.isAndroid) return;
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
    _log.info('Alarm fired, restarting foreground task ($reason)');
    await startMonitoring(reason: reason);
  }

  Future<bool> _ensureNodeRunning() async {
    try {
      if (RustBackendService.instance.isRunning) {
        _log.debug('Node already running; skip start');
        return true;
      }
      _log.info('Node not running; starting node before monitoring');
      final started = await RustBackendService.instance.startNode();
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

      final now = DateTime.now();
      final nextWon = _nextWonSlot(info.wonSlots, now);

      if (nextWon != null) {
        final slotTime =
            DateTime.fromMillisecondsSinceEpoch(nextWon.expectedTimeMs.toInt());
        final diff = slotTime.difference(now);

        if (diff > _alarmLead) {
          await _scheduleResume(
            slotTime.subtract(_alarmLead),
            'next_won_slot:${nextWon.globalSlot}',
          );
          await stopMonitoring(reason: 'next_won_slot_scheduled');
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

      final epochEnd = await _getEpochEndTime(info.currentEpoch);
      if (epochEnd == null) {
        _log.warn('VRF poll: could not compute epoch end');
        return;
      }

      final untilEnd = epochEnd.difference(now);
      if (untilEnd > _alarmLead) {
        await _scheduleResume(
          epochEnd.subtract(_alarmLead),
          'epoch_end_${info.currentEpoch}',
        );
        await stopMonitoring(reason: 'epoch_fully_evaluated');
      } else {
        _log.info('Epoch end <1m, keeping foreground until end');
      }
    } catch (e, st) {
      _log.error('VRF poll failed', error: e, stackTrace: st);
    }
  }

  Future<void> _scheduleResume(DateTime time, String reason) async {
    final success = await PlatformAlarmService.instance.scheduleAlarm(
      alarmId: 'fg_resume',
      alarmTime: time,
      slotNumber: 0,
      data: {
        'reason': reason,
        'nodeRunning': RustBackendService.instance.isRunning,
      },
    );

    _log.info(
        'Scheduled resume alarm at $time for $reason (success=$success)');
    await _releaseWakelock();
    await PlatformAlarmService.instance.stopForegroundService();
  }

  RpcEpochWonSlot? _nextWonSlot(List<RpcEpochWonSlot> slots, DateTime now) {
    final futureSlots = slots
        .where((s) => s.expectedTimeMs.toInt() > now.millisecondsSinceEpoch)
        .toList()
      ..sort((a, b) => a.expectedTimeMs.compareTo(b.expectedTimeMs));
    if (futureSlots.isEmpty) return null;
    return futureSlots.first;
  }

  Future<DateTime?> _getEpochEndTime(int epoch) async {
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
      return DateTime.fromMillisecondsSinceEpoch(timestampMs);
    } catch (_) {
      return null;
    }
  }

  Future<void> _acquireWakelock() async {
    try {
      final enabled = await WakelockPlus.enabled;
      if (!enabled) {
        await WakelockPlus.enable();
        _log.info('Wakelock acquired');
      }
      _wakelockHeld = true;
    } catch (e, st) {
      _log.warn('Failed to acquire wakelock: $e');
    }
  }

  Future<void> _releaseWakelock() async {
    try {
      final enabled = await WakelockPlus.enabled;
      if (enabled) {
        await WakelockPlus.disable();
        _log.info('Wakelock released');
      }
      _wakelockHeld = false;
    } catch (e, st) {
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

    final alarmId = data['alarmId'] as String? ?? '';
    if (alarmId == 'fg_resume') {
      unawaited(handleAlarmFire(reason: 'alarm_resume'));
    }
  }

  Future<bool> isWakelockHeld() async {
    if (!Platform.isAndroid) return false;
    if (_wakelockHeld) return true;
    try {
      return await WakelockPlus.enabled;
    } catch (_) {
      return false;
    }
  }
}

// Foreground service lifecycle is handled natively via PlatformAlarmService.

