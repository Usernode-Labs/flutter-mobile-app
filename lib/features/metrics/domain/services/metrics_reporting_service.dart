import 'dart:async';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/core/models/block_production_event.dart';
import 'package:crypto_mobile_app/features/metrics/data/repositories/metrics_repository.dart';
import 'package:crypto_mobile_app/features/metrics/domain/services/metrics_collector_service.dart';

final _log = LoggingService.instance.withTag(LogTag.metrics);

/// Callback type for fetching wallet data
typedef WalletDataCallback = Future<({double? balance, String? address})>
    Function();

/// Service responsible for collecting and reporting metrics
///
/// Supports both:
/// - Periodic health checks (timer-based, independent)
/// - Event-driven metric collection (triggered by block production events)
class MetricsReportingService {
  MetricsReportingService._();
  static final MetricsReportingService instance = MetricsReportingService._();

  Timer? _reportingTimer;
  MetricsRepository? _repository;
  WalletDataCallback? _walletDataCallback;
  StreamSubscription<BlockProductionEvent>? _eventSubscription;
  bool _isRunning = false;
  DateTime? _lastReportTime;
  int _successCount = 0;
  int _failureCount = 0;

  /// Whether the service is currently running
  bool get isRunning => _isRunning;

  /// Last time metrics were successfully reported
  DateTime? get lastReportTime => _lastReportTime;

  /// Number of successful metric reports
  int get successCount => _successCount;

  /// Number of failed metric reports
  int get failureCount => _failureCount;

  /// Set the callback for fetching wallet data
  void setWalletDataCallback(WalletDataCallback callback) {
    _walletDataCallback = callback;
  }

  /// Start listening to block production events
  ///
  /// When events are emitted, targeted metrics are collected and reported immediately.
  void startListeningToEvents(Stream<BlockProductionEvent> eventStream) {
    _eventSubscription?.cancel();

    _eventSubscription = eventStream.listen(
      (event) => _handleBlockProductionEvent(event),
      onError: (error) {
        _log.error(
          'Error in block production event stream',
          error: error,
        );
      },
    );

    _log.trace(
      'Started listening to block production events for metrics',
    );
  }

  /// Stop listening to block production events
  void stopListeningToEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  /// Handle a block production event by collecting and reporting targeted metrics
  Future<void> _handleBlockProductionEvent(BlockProductionEvent event) async {
    if (!_isRunning || _repository == null) return;

    try {
      _log.debug(
        'Handling block production event: ${event.eventType}',
      );

      // Fetch wallet data if needed
      double? walletBalance;
      String? walletAddress;

      if (_walletDataCallback != null) {
        try {
          final walletData = await _walletDataCallback!();
          walletBalance = walletData.balance;
          walletAddress = walletData.address;
        } catch (e) {
          // Continue without wallet data
        }
      }

      // Collect targeted metrics for this event
      final payload =
          await MetricsCollectorService.instance.collectMetricsForEvent(
        event,
        walletBalance: walletBalance,
        walletAddress: walletAddress,
      );

      // Send metrics to API
      final success = await _repository!.sendMetrics(payload);

      if (success) {
        _successCount++;
        _lastReportTime = DateTime.now();
        _log.trace(
          'Event metrics reported successfully',
          context: {
            'event_type': event.eventType,
          },
        );
      } else {
        _failureCount++;
      }
    } catch (e, stackTrace) {
      _failureCount++;
      _log.error(
        'Error reporting event metrics',
        error: e,
        stackTrace: stackTrace,
        context: {'event_type': event.eventType},
      );
    }
  }

  /// Start metrics reporting using configuration from environment variables
  ///
  /// This starts the periodic health check timer. To enable event-driven metrics,
  /// also call startListeningToEvents() with the orchestrator's event stream.
  Future<void> start() async {
    if (_isRunning) {
      _log.warn(
        'Metrics reporting already running',
      );
      return;
    }

    // Check if metrics are enabled in environment
    if (!AppConfig.metricsEnabled) {
      _log.warn(
        'Metrics reporting is disabled in environment',
      );
      return;
    }

    if (AppConfig.metricsEndpoint.isEmpty) {
      _log.warn(
        'Cannot start metrics reporting: API endpoint not configured',
      );
      return;
    }

    // Use the new configuration for metrics collection interval
    final intervalDuration = AppConfig.metricsCollectionInterval;

    _log.trace(
      'Starting metrics reporting',
      context: {
        'endpoint': AppConfig.metricsEndpoint,
        'interval_seconds': AppConfig.metricsCollectionIntervalSeconds,
      },
    );

    // Initialize repository
    _repository = MetricsRepository(
      apiMetricsEndpoint: AppConfig.metricsEndpoint,
      apiHealthEndpoint: AppConfig.metricsHealthEndpoint.isNotEmpty
          ? AppConfig.metricsHealthEndpoint
          : null,
    );

    // Test connection
    final connected = await _repository!.testConnection();
    if (!connected) {
      _log.warn(
        'Failed to connect to metrics API',
        context: {'endpoint': AppConfig.metricsEndpoint},
      );
      // Continue anyway - connection might be restored later
    }

    // Start periodic reporting
    _isRunning = true;
    _startPeriodicReporting(intervalDuration);

    // Report immediately on start
    _reportMetrics();
  }

  /// Stop metrics reporting
  Future<void> stop() async {
    if (!_isRunning) return;

    _log.debug(
      'Stopping metrics reporting',
      context: {
        'success_count': _successCount,
        'failure_count': _failureCount,
      },
    );

    _reportingTimer?.cancel();
    _reportingTimer = null;
    stopListeningToEvents();
    _repository?.dispose();
    _repository = null;
    _isRunning = false;
  }

  /// Manually trigger a metrics report (outside of periodic schedule)
  Future<void> reportNow() async {
    if (!_isRunning) {
      _log.warn(
        'Cannot report metrics: service not running',
      );
      return;
    }

    await _reportMetrics();
  }

  /// Start the periodic reporting timer
  void _startPeriodicReporting(Duration interval) {
    _reportingTimer?.cancel();

    _reportingTimer = Timer.periodic(interval, (_) {
      _reportMetrics();
    });

    _log.trace(
      'Periodic metrics reporting started',
      context: {'interval': interval.toString()},
    );
  }

  /// Collect and report metrics
  Future<void> _reportMetrics() async {
    if (_repository == null) return;

    try {
      _log.trace(
        'Collecting and reporting metrics',
      );

      // Fetch wallet data if callback is set
      double? walletBalance;
      String? walletAddress;

      if (_walletDataCallback != null) {
        try {
          final walletData = await _walletDataCallback!();
          walletBalance = walletData.balance;
          walletAddress = walletData.address;
        } catch (e) {
          _log.warn(
            'Error fetching wallet data: $e',
          );
          // Continue without wallet data
        }
      }

      // Collect all metrics
      final payload = await MetricsCollectorService.instance.collectMetrics(
        walletBalance: walletBalance,
        walletAddress: walletAddress,
      );

      // Send metrics to API
      final success = await _repository!.sendMetrics(payload);

      if (success) {
        _successCount++;
        _lastReportTime = DateTime.now();
        _log.trace(
          'Metrics reported successfully',
          context: {
            'peer_id': payload.node.identity.peerId,
            'node_state': payload.node.status?.nodeState ?? 'unknown',
          },
        );
      } else {
        _failureCount++;
        _log.debug(
          'Failed to report metrics',
        );
      }
    } catch (e, stackTrace) {
      _failureCount++;
      _log.error(
        'Error reporting metrics',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get current metrics stats
  Map<String, dynamic> getStats() {
    return {
      'is_running': _isRunning,
      'last_report_time': _lastReportTime?.toIso8601String(),
      'success_count': _successCount,
      'failure_count': _failureCount,
      'success_rate': _successCount + _failureCount > 0
          ? (_successCount / (_successCount + _failureCount) * 100)
              .toStringAsFixed(1)
          : 'N/A',
    };
  }

  /// Reset stats
  void resetStats() {
    _successCount = 0;
    _failureCount = 0;
    _lastReportTime = null;
  }
}
