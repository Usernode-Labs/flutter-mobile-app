import 'dart:async';
import 'package:logger/logger.dart';
import '../../features/node/data/repositories/rust_backend_service.dart';
import '../config/blockchain_timing.dart';
import '../data/slot_production_repository.dart';
import 'epoch_slot_scheduler_service.dart';

/// Service responsible for monitoring slot production status in real-time
///
/// This service polls the Rust backend during active slot monitoring windows
/// to track state transitions and detect successful or failed block production.
class SlotMonitorService {
  static final SlotMonitorService instance = SlotMonitorService._();
  SlotMonitorService._();

  final Logger _logger = Logger();
  bool _initialized = false;
  bool _isMonitoring = false;
  Timer? _monitoringTimer;

  // Stream controller for real-time monitoring updates
  final StreamController<SlotMonitoringEvent> _eventController =
      StreamController<SlotMonitoringEvent>.broadcast();

  // Currently monitored slot
  ScheduledSlot? _currentSlot;

  // Monitoring state tracking
  String? _lastNodeState;
  int? _lastBestTipSlot;
  DateTime? _monitoringStartTime;
  int _pollAttemptCount = 0;

  /// Stream of monitoring events for UI updates
  Stream<SlotMonitoringEvent> get monitoringEvents => _eventController.stream;

  /// Initialize the slot monitor service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      _logger.i('SlotMonitorService initializing...');
      _initialized = true;
      _logger.i('SlotMonitorService initialized');
      return true;
    } catch (e) {
      _logger.e('Error initializing SlotMonitorService: $e');
      return false;
    }
  }

  /// Start monitoring a specific slot
  ///
  /// This begins polling the Rust backend status every 10 seconds
  /// to track block production state transitions.
  Future<void> startMonitoringSlot(ScheduledSlot slot) async {
    if (!_initialized) {
      _logger.w('Cannot start monitoring: service not initialized');
      return;
    }

    if (_isMonitoring && _currentSlot?.slotNumber == slot.slotNumber) {
      _logger.d('Already monitoring slot ${slot.slotNumber}');
      return;
    }

    // Stop any existing monitoring
    await stopMonitoring();

    _logger.i('Starting monitoring for slot ${slot.slotNumber}');
    _currentSlot = slot;
    _isMonitoring = true;
    _monitoringStartTime = DateTime.now();
    _lastNodeState = null;
    _lastBestTipSlot = null;
    _pollAttemptCount = 0;

    // Emit monitoring started event
    _eventController.add(SlotMonitoringEvent(
      type: MonitoringEventType.started,
      slotNumber: slot.slotNumber,
      timestamp: DateTime.now(),
    ));

    // Start polling timer (poll interval based on slot duration)
    _monitoringTimer = Timer.periodic(
      BlockchainTiming.pollInterval,
      (_) => _pollNodeStatus(),
    );

    // Do initial poll immediately
    await _pollNodeStatus();
  }

  /// Stop monitoring current slot
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _logger.i('Stopping slot monitoring');
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;

    if (_currentSlot != null) {
      _eventController.add(SlotMonitoringEvent(
        type: MonitoringEventType.stopped,
        slotNumber: _currentSlot!.slotNumber,
        timestamp: DateTime.now(),
      ));
    }

    _currentSlot = null;
    _lastNodeState = null;
    _lastBestTipSlot = null;
    _monitoringStartTime = null;
  }

  /// Check if currently monitoring a slot
  bool get isMonitoring => _isMonitoring;

  /// Get currently monitored slot
  ScheduledSlot? get currentSlot => _currentSlot;

  /// Poll Rust backend for node status
  Future<void> _pollNodeStatus() async {
    if (!_isMonitoring || _currentSlot == null) return;

    _pollAttemptCount++;
    _logger.d(
        'Poll attempt #$_pollAttemptCount for slot ${_currentSlot!.slotNumber}');

    try {
      final status = await RustBackendService.instance.getStatus();
      if (status == null) {
        _logger.w('No status available from Rust backend');

        // Emit monitoring poll event (failed)
        _eventController.add(SlotMonitoringEvent(
          type: MonitoringEventType.poll,
          slotNumber: _currentSlot!.slotNumber,
          timestamp: DateTime.now(),
          pollAttempt: _pollAttemptCount,
          nodeState: 'unknown',
          success: false,
        ));
        return;
      }

      // Get node state from block producer status
      final nodeState = status.blockProducer?.status.toString() ?? 'idle';

      // Use backend-provided current global slot
      final bestTipSlot = status.node.curGlobalSlot;
      if (bestTipSlot == null) {
        // TODO: Decide fallback strategy when curGlobalSlot is unavailable
        _logger.w('curGlobalSlot unavailable from backend, skipping poll');

        // Emit monitoring poll event (failed)
        _eventController.add(SlotMonitoringEvent(
          type: MonitoringEventType.poll,
          slotNumber: _currentSlot!.slotNumber,
          timestamp: DateTime.now(),
          pollAttempt: _pollAttemptCount,
          nodeState: nodeState,
          success: false,
        ));
        return;
      }

      final currentSlotNumber = _currentSlot!.slotNumber;

      _logger.d(
          'Poll #$_pollAttemptCount - Node: $nodeState, BestTip: $bestTipSlot, Target: $currentSlotNumber');

      // Emit monitoring poll event (successful)
      _eventController.add(SlotMonitoringEvent(
        type: MonitoringEventType.poll,
        slotNumber: currentSlotNumber,
        timestamp: DateTime.now(),
        pollAttempt: _pollAttemptCount,
        nodeState: nodeState,
        bestTipSlot: bestTipSlot,
        success: true,
      ));

      // Track state transitions
      if (_lastNodeState != nodeState) {
        _logger.d(
          'Node state transition: ${_lastNodeState ?? "unknown"} → $nodeState',
        );

        _eventController.add(SlotMonitoringEvent(
          type: MonitoringEventType.stateChanged,
          slotNumber: currentSlotNumber,
          timestamp: DateTime.now(),
          nodeState: nodeState,
        ));

        _lastNodeState = nodeState;
      }

      // Check if best tip advanced
      if (_lastBestTipSlot != null && bestTipSlot > _lastBestTipSlot!) {
        _logger.d('Best tip advanced: $_lastBestTipSlot → $bestTipSlot');

        _eventController.add(SlotMonitoringEvent(
          type: MonitoringEventType.tipAdvanced,
          slotNumber: currentSlotNumber,
          timestamp: DateTime.now(),
          bestTipSlot: bestTipSlot,
        ));
      }
      _lastBestTipSlot = bestTipSlot;

      // Check if our slot was produced
      if (bestTipSlot >= currentSlotNumber) {
        await _checkSlotProduction(currentSlotNumber);
      }

      // Check for timeout (based on slot duration)
      final now = DateTime.now();
      final timeoutTime =
          _currentSlot!.slotTime.add(BlockchainTiming.monitoringTimeout);

      if (now.isAfter(timeoutTime)) {
        _logger.w('Monitoring timeout for slot $currentSlotNumber');

        _eventController.add(SlotMonitoringEvent(
          type: MonitoringEventType.timeout,
          slotNumber: currentSlotNumber,
          timestamp: now,
        ));

        // Record production failure to statistics repository
        try {
          await SlotProductionRepository.instance.recordProductionFailure(
            slotNumber: currentSlotNumber,
            failedTime: now,
            reason: 'Monitoring timeout',
          );
          _logger.d('Recorded production failure for slot $currentSlotNumber');
        } catch (e) {
          _logger.w(
              'Failed to record production failure for slot $currentSlotNumber: $e');
        }

        await stopMonitoring();
      }
    } catch (e) {
      _logger.e('Error polling node status: $e');

      _eventController.add(SlotMonitoringEvent(
        type: MonitoringEventType.error,
        slotNumber: _currentSlot!.slotNumber,
        timestamp: DateTime.now(),
        error: e.toString(),
      ));
    }
  }

  /// Check if a specific slot was produced by querying blockchain
  Future<void> _checkSlotProduction(int slotNumber) async {
    try {
      // Query recent blockchain to see if our slot is there
      final blockchain = await RustBackendService.instance.listBlockchain(
        limit: 50,
        fromTip: true,
      );

      if (blockchain?.items == null) return;

      // Look for our slot in the blockchain
      final ourBlock = blockchain!.items.firstWhere(
        (block) => block.globalSlot == slotNumber,
        orElse: () => throw StateError('Slot not found'),
      );

      // Found it! Slot was successfully produced
      _logger.i('SUCCESS: Slot $slotNumber was produced!');

      _eventController.add(SlotMonitoringEvent(
        type: MonitoringEventType.slotProduced,
        slotNumber: slotNumber,
        timestamp: DateTime.now(),
        blockHeight: ourBlock.height,
      ));

      // Record production success to statistics repository
      try {
        await SlotProductionRepository.instance.recordProductionSuccess(
          slotNumber: slotNumber,
          blockHeight: ourBlock.height,
          producedTime: DateTime.now(),
        );
        _logger.d('Recorded production success for slot $slotNumber');
      } catch (e) {
        _logger
            .w('Failed to record production success for slot $slotNumber: $e');
      }

      // Stop monitoring this slot
      await stopMonitoring();
    } on StateError {
      // Slot not found in blockchain - still waiting or failed
      _logger.d('Slot $slotNumber not yet in blockchain');
    } catch (e) {
      _logger.e('Error checking slot production: $e');
    }
  }

  /// Automatically start monitoring when slot time approaches
  ///
  /// This should be called when an alarm fires or when entering
  /// a slot monitoring window (2 minutes before slot time).
  Future<void> autoStartMonitoring() async {
    if (!_initialized) {
      _logger.w('Cannot auto-start monitoring: service not initialized');
      return;
    }

    // Check if we should be monitoring any slots right now
    final nextSlot = EpochSlotSchedulerService.instance.getNextSlot();
    if (nextSlot == null) {
      _logger.d('No upcoming slots to monitor');
      return;
    }

    final now = DateTime.now();
    final monitoringStartTime = nextSlot.slotTime.subtract(
      BlockchainTiming.alarmAdvanceTime,
    );
    final monitoringEndTime = nextSlot.slotTime.add(
      BlockchainTiming.monitoringTimeout,
    );

    // Check if we're in the monitoring window
    if (now.isAfter(monitoringStartTime) && now.isBefore(monitoringEndTime)) {
      _logger.i('Auto-starting monitoring for slot ${nextSlot.slotNumber}');
      await startMonitoringSlot(nextSlot);
    }
  }

  /// Get monitoring duration for current slot
  Duration? get monitoringDuration {
    if (_monitoringStartTime == null) return null;
    return DateTime.now().difference(_monitoringStartTime!);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopMonitoring();
    await _eventController.close();
    _initialized = false;
  }
}

/// Types of monitoring events
enum MonitoringEventType {
  started,
  stopped,
  poll, // New: Emitted on each status poll attempt
  stateChanged,
  tipAdvanced,
  slotProduced,
  timeout,
  error,
}

/// Event emitted during slot monitoring
class SlotMonitoringEvent {
  final MonitoringEventType type;
  final int slotNumber;
  final DateTime timestamp;
  final String? nodeState;
  final int? bestTipSlot;
  final int? blockHeight;
  final String? error;
  final int? pollAttempt; // New: Poll attempt number
  final bool? success; // New: Whether the poll was successful

  SlotMonitoringEvent({
    required this.type,
    required this.slotNumber,
    required this.timestamp,
    this.nodeState,
    this.bestTipSlot,
    this.blockHeight,
    this.error,
    this.pollAttempt,
    this.success,
  });

  @override
  String toString() {
    return 'SlotMonitoringEvent('
        'type: $type, '
        'slot: $slotNumber, '
        'time: $timestamp'
        '${nodeState != null ? ", state: $nodeState" : ""}'
        '${bestTipSlot != null ? ", tip: $bestTipSlot" : ""}'
        '${blockHeight != null ? ", height: $blockHeight" : ""}'
        '${error != null ? ", error: $error" : ""}'
        '${pollAttempt != null ? ", poll: #$pollAttempt" : ""}'
        '${success != null ? ", success: $success" : ""}'
        ')';
  }
}
