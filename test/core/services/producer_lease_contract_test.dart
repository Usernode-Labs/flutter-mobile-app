import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Effect-point fencing for producer work that a SURVIVING process can leave
/// in flight across an identity boundary.
///
/// Rotating the native incarnation only rejects newly delivered events; Dart
/// work that already passed admission keeps running. These paths are singletons
/// gated on `Platform.isAndroid`, so the contract is asserted at the source
/// rather than driven — the behaviour it encodes is exercised through
/// `NodeLifecycleCoordinator` and `BlockProductionAlarmAuditService`.
void main() {
  late String controller;

  setUpAll(() async {
    controller = await File(
      'lib/core/services/android_foreground_task_controller.dart',
    ).readAsString();
  });

  test('the monitoring lease is reversible and separate from terminal reset',
      () {
    expect(controller, contains('int _monitoringGeneration = 0;'));
    expect(controller, contains('void retireMonitoringSession()'));
    // The one-way terminal flag cannot serve a boundary the process survives,
    // so the lease check covers both.
    expect(
      controller,
      contains('bool _superseded(int generation) =>\n'
          '      _terminalResetRequested || generation != _monitoringGeneration;'),
    );
  });

  test('every monitoring effect re-checks the lease it started under', () {
    final start = controller.substring(
      controller.indexOf('Future<bool> startMonitoring({'),
      controller.indexOf('/// Stops the Android production support.'),
    );
    expect(start, contains('final generation = _monitoringGeneration;'));
    // The wakelock, the foreground service, the watchdog re-arm and the poll
    // timer are each an effect that must not land after the boundary.
    expect('_superseded(generation)'.allMatches(start).length, greaterThan(4));

    final poll = controller.substring(
      controller.indexOf('Future<void> _pollVrf(int generation) async {'),
      controller.indexOf('Future<bool> _shouldHoldForOtherProducerBlock('),
    );
    // A poll schedules alarms after several unbounded node round-trips.
    expect('_superseded(generation)'.allMatches(poll).length, greaterThan(3));
  });

  test('the teardown retires leases first and then drains', () {
    final stop = controller.substring(
      controller.indexOf('Future<void> stopMonitoring({'),
      controller.indexOf('Future<void> _drainActivePoll()'),
    );
    // Retire BEFORE the drain: a poll released mid-drain must find its lease
    // already invalid rather than re-arming what the teardown just cancelled.
    expect(
      stop.indexOf('retireMonitoringSession();'),
      lessThan(stop.indexOf('await _drainActivePoll();')),
    );
    expect(controller, contains('await poll.timeout(const Duration('));
  });
}
