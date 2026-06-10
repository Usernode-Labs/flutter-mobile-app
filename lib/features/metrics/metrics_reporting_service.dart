import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/services/app_reset_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/models/block_production_event.dart';
import 'package:crypto_mobile_app/features/metrics/data/slot_outcome_buffer_repository.dart';
import 'package:crypto_mobile_app/features/metrics/models/metrics_payload.dart';
import 'package:crypto_mobile_app/features/metrics/models/slot_outcome_report.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/metrics/services/slot_outcome_drain_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

final _log = LoggingService.instance.withTag('usernode/MetricsReporting');

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
  StreamSubscription<BlockProductionEvent>? _eventSubscription;
  bool _isRunning = false;
  DateTime? _lastReportTime;
  int _successCount = 0;
  int _failureCount = 0;

  /// Debounced out-of-band ship-now machinery. Decoupled from
  /// [_reportingTimer]: callers ([SlotOutcomeRecorder] mostly) request
  /// a ship right after appending an outcome to the buffer; the actual
  /// HTTP POST is delayed [_outcomeShipDebounceDuration] so a burst of
  /// appends (multi-slot reorg, drain catch-up, …) collapses into one
  /// POST. [_outcomeShipInFlight] coalesces concurrent ships — a second
  /// caller while a ship is mid-POST awaits the same Future and then
  /// gets a fresh snapshot of the buffer on return.
  Timer? _outcomeShipDebounce;
  Future<void>? _outcomeShipInFlight;
  static const Duration _outcomeShipDebounceDuration =
      Duration(milliseconds: 250);

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

      // Collect targeted metrics for this event
      final payload =
          await MetricsCollectorService.instance.collectMetricsForEvent(event);

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
    _httpClient = createAppHttpClient();

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

  /// Request a debounced, out-of-band ship of any currently-buffered slot
  /// outcomes.
  ///
  /// **Why this exists**: the periodic heartbeat ([_reportingTimer]) is
  /// the normal path for shipping buffered outcomes, but it's gated by
  /// `_isRunning` — which [AppSleepService] flips off whenever the app
  /// enters sleep state (idle timeout, lifecycle non-resumed, wakelock
  /// release). When [SlotOutcomeRecorder] appends an outcome during an
  /// alarm-wake window (the common "phone in pocket, scheduled won-slot
  /// fires" case), the heartbeat isn't running, so the outcome would
  /// otherwise sit in the buffer until the user opens the app. This
  /// hook ships it within ~250ms instead, independent of heartbeat
  /// lifecycle.
  ///
  /// **Cadence**: debounced by [_outcomeShipDebounceDuration]; concurrent
  /// requests during the debounce window collapse to one POST.
  /// In-flight ships are coalesced via [_outcomeShipInFlight] so a
  /// second caller during a POST awaits the same Future. Server-side
  /// `persistSlotOutcomes` is UPSERT-idempotent on
  /// (`chain_id`, `wallet_address`, `report_uid`), so even if a redundant
  /// POST happens to slip through (e.g. heartbeat fires while a request
  /// is mid-flight), the duplicate is a no-op on the database side.
  ///
  /// **Payload**: outcome-only — just `slot_outcomes`. Per-outcome
  /// `chain_id` and `wallet_address` are already on each report (see
  /// [SlotOutcomeRecorder]); no envelope-level identity is sent. The
  /// server's `persistSlotOutcomes` uses per-outcome fields directly.
  ///
  /// Fire-and-forget — callers don't await this. Failures are logged
  /// and the buffer is left intact for the next heartbeat or request.
  void requestSlotOutcomeShip() {
    if (AppConfig.viewOnly ||
        !AppConfig.metricsEnabled ||
        AppConfig.metricsEndpoint.isEmpty) {
      return;
    }
    _outcomeShipDebounce?.cancel();
    _outcomeShipDebounce = Timer(_outcomeShipDebounceDuration, () {
      _outcomeShipDebounce = null;
      unawaited(_shipSlotOutcomesNow());
    });
  }

  /// Coalesce concurrent ships into one.
  Future<void> _shipSlotOutcomesNow() {
    if (_outcomeShipInFlight != null) {
      return _outcomeShipInFlight!;
    }
    final future = _shipSlotOutcomesNowImpl();
    _outcomeShipInFlight = future;
    return future.whenComplete(() {
      _outcomeShipInFlight = null;
    });
  }

  Future<void> _shipSlotOutcomesNowImpl() async {
    List<SlotOutcomeReport> pending;
    try {
      pending = await SlotOutcomeBufferRepository.instance.drain();
    } catch (e) {
      _log.warn('Outcome-only drain failed: $e');
      return;
    }
    if (pending.isEmpty) return;

    final body = jsonEncode({
      'slot_outcomes': pending.map((r) => r.toJson()).toList(),
    });

    // Reuse the heartbeat's HTTP client when alive, otherwise spin up a
    // one-shot client so this works during sleep state (the heartbeat
    // closes [_httpClient] in [stop]).
    var client = _httpClient;
    final ownedClient = client == null;
    client ??= createAppHttpClient();

    try {
      final response = await client
          .post(
        Uri.parse(AppConfig.metricsEndpoint),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      )
          .timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Slot outcome ship timed out');
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          await SlotOutcomeBufferRepository.instance
              .discard(pending.map((r) => r.id));
        } catch (e) {
          _log.warn('Slot outcome discard after ship failed: $e');
        }
        _log.info(
          'Shipped slot outcomes out-of-band',
          context: {
            'count': pending.length,
            'status': response.statusCode,
          },
        );
      } else {
        _log.warn(
          'Slot outcome out-of-band ship returned non-2xx',
          context: {
            'status': response.statusCode,
            'count': pending.length,
          },
        );
        // Leave buffer intact; the next heartbeat or request retries.
      }
    } catch (e) {
      _log.warn('Slot outcome out-of-band ship error: $e');
      // Buffer is intact (drain is non-destructive); next retry handles it.
    } finally {
      if (ownedClient) {
        client.close();
      }
    }
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

      // Collect all metrics
      final payload = await MetricsCollectorService.instance.collectMetrics();

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

      // First, ask the drain service to pull any newly-terminal slot
      // outcomes from the embedded node into the buffer. This is the
      // primary path that populates `slot_outcome_reports` — the recorder
      // path (SlotMonitorService) only fires when the app is foregrounded
      // for a slot in real time, which is the rare case. Errors are
      // swallowed inside drain(); a 0 return just means "nothing new".
      try {
        await SlotOutcomeDrainService.instance.drain();
      } catch (e) {
        _log.warn('Slot-outcome drain failed: $e');
      }

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
