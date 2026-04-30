import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/services/app_reset_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/models/block_production_event.dart';
import 'package:crypto_mobile_app/features/metrics/data/slot_outcome_buffer_repository.dart';
import 'package:crypto_mobile_app/features/metrics/models/metrics_payload.dart';
import 'package:crypto_mobile_app/features/metrics/models/slot_outcome_report.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

final _log = LoggingService.instance.withTag('usernode/MetricsReporting');

/// Callback type for fetching wallet data
typedef WalletDataCallback = Future<({BigInt? balance, String? address})>
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
  http.Client? _httpClient;
  WalletDataCallback? _walletDataCallback;
  StreamSubscription<BlockProductionEvent>? _eventSubscription;
  bool _isRunning = false;
  DateTime? _lastReportTime;
  int _successCount = 0;
  int _failureCount = 0;

  static const participantWalletMismatchErrorCode =
      'participant_wallet_mismatch';

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
      onError: (error, stackTrace) {
        _log.error(
          'Error in block production event stream',
          error: error,
          stackTrace: stackTrace,
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
    if (!_isRunning || _httpClient == null) return;

    try {
      _log.debug(
        'Handling block production event: ${event.eventType}',
      );

      // Fetch wallet data if needed
      BigInt? walletBalance;
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

      // Fire and forget - send metrics without blocking
      _sendMetricsAsync(payload, eventType: event.eventType);
    } catch (e) {
      _log.debug('Error collecting event metrics: $e');
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

    if (AppConfig.viewOnly) {
      _log.warn('Metrics reporting disabled in view-only mode');
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

    // Initialize HTTP client
    _httpClient = http.Client();

    // Test connection
    final connected = await _testConnection();
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
    _httpClient?.close();
    _httpClient = null;
    _isRunning = false;
  }

  Future<void> resetForAppRestart() async {
    await stop();
    _walletDataCallback = null;
    resetStats();
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

  /// Report a custom event with optional event data
  ///
  /// Use this for one-off events that are not part of the block production flow.
  void reportEvent(String eventType, {Map<String, dynamic>? eventData}) {
    if (AppConfig.viewOnly) {
      _log.debug(
        'Skipping metrics event in view-only mode',
        context: {'event_type': eventType},
      );
      return;
    }

    if (!_isRunning || _httpClient == null) {
      _log.debug('Cannot report event: service not running');
      return;
    }

    _log.debug('Reporting custom event: $eventType');

    // Collect and send metrics with the custom event type
    MetricsCollectorService.instance
        .collectMetrics(eventType: eventType, eventData: eventData)
        .then((payload) => _sendMetricsAsync(payload, eventType: eventType))
        .catchError((e) => _log.debug('Error reporting event: $e'));
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
    if (_httpClient == null) return;

    try {
      _log.trace(
        'Collecting and reporting metrics',
      );

      // Fetch wallet data if callback is set
      BigInt? walletBalance;
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

      _log.debug(
          'Collected consensus: epoch=${payload.node.consensus?.currentEpoch}, produced=${payload.node.consensus?.currentEpochProduced}, hasContainer=${MetricsCollectorService.instance.hasContainer}, isRunning=${RustBackendService.instance.isRunning}');

      // Fire and forget - send metrics without blocking
      _sendMetricsAsync(payload);
    } catch (e) {
      _log.debug('Error collecting metrics: $e');
    }
  }

  /// Send metrics asynchronously without blocking the caller
  ///
  /// This is a fire-and-forget operation - errors are logged but not propagated.
  void _sendMetricsAsync(MetricsPayload payload, {String? eventType}) {
    if (_httpClient == null) return;

    // Use unawaited future to explicitly indicate fire-and-forget
    _sendMetrics(payload).then((success) {
      if (success) {
        _successCount++;
        _lastReportTime = DateTime.now();
        _log.trace(
          'Metrics sent',
          context: eventType != null ? {'event_type': eventType} : null,
        );
      } else {
        _failureCount++;
      }
    }).catchError((e) {
      _failureCount++;
      _log.debug('Metrics send error: $e');
    });
  }

  /// Send metrics payload to the centralized API.
  ///
  /// Piggybacks any pending [SlotOutcomeReport]s under the top-level
  /// `slot_outcomes` JSON key. On 2xx we discard the shipped ids from the
  /// buffer; on any failure (network error, non-2xx, timeout) we leave the
  /// buffer intact so the next periodic tick retries the same records.
  Future<bool> _sendMetrics(MetricsPayload payload) async {
    if (AppConfig.viewOnly || _httpClient == null) {
      return false;
    }

    try {
      final url = Uri.parse(AppConfig.metricsEndpoint);
      final jsonPayload = payload.toJson();

      // Drain pending slot outcomes (snapshot, not removed) and attach to
      // the payload so the analytics backend can join with node-side
      // lifecycle data.
      List<SlotOutcomeReport> pendingOutcomes = const [];
      try {
        pendingOutcomes = await SlotOutcomeBufferRepository.instance.drain();
      } catch (e) {
        _log.warn('Failed to drain slot-outcome buffer: $e');
      }
      if (pendingOutcomes.isNotEmpty) {
        jsonPayload['slot_outcomes'] =
            pendingOutcomes.map((r) => r.toJson()).toList();
      }

      _log.debug(
        'Sending metrics to API: ${jsonEncode(jsonPayload)}',
      );

      final response = await _httpClient!
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(jsonPayload),
      )
          .timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw Exception('Metrics request timed out');
        },
      );

      if (isParticipantWalletMismatchResponse(response)) {
        _log.error(
          'Metrics backend reported participant/wallet mismatch',
          context: {'response_body': response.body},
        );
        unawaited(
          AppResetService.instance.resetAndRestart(
            reason: participantWalletMismatchErrorCode,
            backendResponse: response.body,
          ),
        );
        return false;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _log.trace(
          'Metrics sent successfully',
          context: {
            'status_code': response.statusCode,
            if (pendingOutcomes.isNotEmpty)
              'slot_outcomes_shipped': pendingOutcomes.length,
          },
        );
        // Discard only the ids we actually sent; new outcomes that landed
        // in the buffer between drain() and now stay queued for the next
        // tick.
        if (pendingOutcomes.isNotEmpty) {
          unawaited(
            SlotOutcomeBufferRepository.instance
                .discard(pendingOutcomes.map((r) => r.id))
                .catchError(
                    (e) => _log.warn('slot-outcome discard failed: $e')),
          );
        }
        return true;
      } else {
        _log.warn(
          'Failed to send metrics',
          context: {
            'status_code': response.statusCode,
            'response_body': response.body,
          },
        );
        return false;
      }
    } catch (e) {
      _log.debug('Metrics send failed: $e');
      return false;
    }
  }

  /// Test API connection using health check endpoint
  Future<bool> _testConnection() async {
    if (_httpClient == null) return false;

    const healthEndpoint = AppConfig.metricsHealthEndpoint;
    if (healthEndpoint.isEmpty) return true;

    try {
      final url = Uri.parse(healthEndpoint);
      final response = await _httpClient!.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw Exception('Health check request timed out');
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['status'] == 'healthy') return true;
        } catch (_) {
          return true;
        }
      }
      return false;
    } catch (e) {
      _log.warn('API connection test failed: $e');
      return false;
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

String? metricsApiErrorCodeFromBody(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final code = decoded['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
  } catch (_) {
    // Ignore malformed error bodies.
  }

  return null;
}

bool isParticipantWalletMismatchResponse(http.Response response) {
  if (response.statusCode != 409) {
    return false;
  }

  return metricsApiErrorCodeFromBody(response.body) ==
      MetricsReportingService.participantWalletMismatchErrorCode;
}
