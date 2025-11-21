import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/metrics/domain/services/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that manages the lifecycle of metrics reporting
/// Starts metrics service at initialization if enabled in environment
final metricsLifecycleProvider = Provider<void>((ref) {
  // Start metrics service on initialization if enabled
  if (AppConfig.metricsEnabled && AppConfig.metricsEndpoint.isNotEmpty) {
    LoggingService.instance.debug(
      'Metrics enabled in environment - starting service',
      tag: LogTag.metrics,
      context: {
        'endpoint': AppConfig.metricsEndpoint,
        'interval_seconds': AppConfig.metricsInterval,
      },
    );

    // Start the metrics reporting service
    MetricsReportingService.instance.start();

    // Connect to orchestrator event stream for event-driven metrics
    MetricsReportingService.instance.startListeningToEvents(
      BackgroundBlockProductionOrchestrator.instance.events,
    );

    LoggingService.instance.debug(
      'Connected metrics reporting to block production events',
      tag: LogTag.metrics,
    );
  } else {
    LoggingService.instance.debug(
      'Metrics disabled or not configured',
      tag: LogTag.metrics,
      context: {
        'enabled': AppConfig.metricsEnabled,
        'endpoint_configured': AppConfig.metricsEndpoint.isNotEmpty,
      },
    );
  }

  // Clean up when provider is disposed
  ref.onDispose(() async {
    final service = MetricsReportingService.instance;
    if (service.isRunning) {
      await service.stop();
    }
  });
});
