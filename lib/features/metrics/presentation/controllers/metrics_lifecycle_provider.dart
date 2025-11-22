import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/metrics/domain/services/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/wallet_service.dart';
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

    // Set wallet data callback for metrics collection
    MetricsReportingService.instance.setWalletDataCallback(_fetchWalletData);

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

/// Fetches current wallet data for metrics reporting
///
/// Returns a record with balance and address from the active account.
/// Returns null values if data is unavailable (no active account, errors, etc.)
Future<({double? balance, String? address})> _fetchWalletData() async {
  try {
    // Get active account
    final accountsRepo = await AccountsRepository.create();
    final activeAccount = await accountsRepo.getActive();

    // Get wallet balance
    final walletService = WalletService.instance;
    final balance = walletService.getBalance();

    return (
      balance: balance.tokenAmount,
      address: activeAccount?.address,
    );
  } catch (e) {
    // Log error but don't fail metrics collection
    LoggingService.instance.warn(
      'Failed to fetch wallet data for metrics',
      tag: LogTag.metrics,
      context: {'error': e.toString()},
    );
    return (balance: null, address: null);
  }
}
