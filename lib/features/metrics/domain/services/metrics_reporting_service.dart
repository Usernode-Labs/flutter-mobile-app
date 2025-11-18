import 'dart:async';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/features/metrics/data/repositories/metrics_repository.dart';
import 'package:crypto_mobile_app/features/metrics/domain/services/metrics_collector_service.dart';

/// Callback type for fetching wallet data
typedef WalletDataCallback = Future<({double? balance, String? address})>
    Function();

/// Service responsible for periodically collecting and reporting metrics
class MetricsReportingService {
  MetricsReportingService._();
  static final MetricsReportingService instance = MetricsReportingService._();

  Timer? _reportingTimer;
  MetricsRepository? _repository;
  WalletDataCallback? _walletDataCallback;
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

  /// Start metrics reporting using configuration from environment variables
  Future<void> start() async {
    if (_isRunning) {
      LoggingService.instance.warn(
        'Metrics reporting already running',
        tag: LogTag.metrics,
      );
      return;
    }

    // Check if metrics are enabled in environment
    if (!AppConfig.metricsEnabled) {
      LoggingService.instance.info(
        'Metrics reporting is disabled in environment',
        tag: LogTag.metrics,
      );
      return;
    }

    if (AppConfig.metricsEndpoint.isEmpty) {
      LoggingService.instance.warn(
        'Cannot start metrics reporting: API endpoint not configured',
        tag: LogTag.metrics,
      );
      return;
    }

    // Clamp interval to valid range
    final intervalSeconds = AppConfig.metricsInterval.clamp(1, 3600);
    final intervalDuration = Duration(seconds: intervalSeconds);

    LoggingService.instance.info(
      'Starting metrics reporting',
      tag: LogTag.metrics,
      context: {
        'endpoint': AppConfig.metricsEndpoint,
        'interval_seconds': intervalSeconds,
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
      LoggingService.instance.warn(
        'Failed to connect to metrics API',
        tag: LogTag.metrics,
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

    LoggingService.instance.info(
      'Stopping metrics reporting',
      tag: LogTag.metrics,
      context: {
        'success_count': _successCount,
        'failure_count': _failureCount,
      },
    );

    _reportingTimer?.cancel();
    _reportingTimer = null;
    _repository?.dispose();
    _repository = null;
    _isRunning = false;
  }

  /// Manually trigger a metrics report (outside of periodic schedule)
  Future<void> reportNow() async {
    if (!_isRunning) {
      LoggingService.instance.warn(
        'Cannot report metrics: service not running',
        tag: LogTag.metrics,
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

    LoggingService.instance.debug(
      'Periodic metrics reporting started',
      tag: LogTag.metrics,
      context: {'interval': interval.toString()},
    );
  }

  /// Collect and report metrics
  Future<void> _reportMetrics() async {
    if (_repository == null) return;

    try {
      LoggingService.instance.trace(
        'Collecting and reporting metrics',
        tag: LogTag.metrics,
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
          LoggingService.instance.warn(
            'Error fetching wallet data: $e',
            tag: LogTag.metrics,
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
        LoggingService.instance.trace(
          'Metrics reported successfully',
          tag: LogTag.metrics,
          context: {
            'peer_id': payload.node.identity.peerId,
            'node_state': payload.node.status.nodeState,
          },
        );
      } else {
        _failureCount++;
        LoggingService.instance.debug(
          'Failed to report metrics',
          tag: LogTag.metrics,
        );
      }
    } catch (e, stackTrace) {
      _failureCount++;
      LoggingService.instance.error(
        'Error reporting metrics',
        tag: LogTag.metrics,
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
