import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/features/metrics/domain/services/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _log = LoggingService.instance.withTag(LogTag.metrics);

/// Provider that manages the lifecycle of metrics reporting
/// Starts metrics service at initialization if enabled in environment
final metricsLifecycleProvider = Provider<void>((ref) {
  // Start metrics service on initialization if enabled
  if (AppConfig.metricsEnabled && AppConfig.metricsEndpoint.isNotEmpty) {
    _log.debug(
      'Metrics enabled in environment - starting service',
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

    _log.debug(
      'Connected metrics reporting to block production events',
    );
  } else {
    _log.debug(
      'Metrics disabled or not configured',
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
///
/// Balance is the raw BigInt value (smallest unit) from summing all UTXO amounts.
Future<({BigInt? balance, String? address})> _fetchWalletData() async {
  try {
    // Get active account
    final accountsRepo = await AccountsRepository.create();
    final activeAccount = await accountsRepo.getActive();

    if (activeAccount == null || activeAccount.address.isEmpty) {
      return (balance: null, address: null);
    }

    // Only fetch UTXOs if address is in UTXO format (starts with 'ut')
    if (!activeAccount.address.startsWith('ut')) {
      _log.debug(
        'Account address not in UTXO format, skipping balance calculation',
        context: {'address': activeAccount.address},
      );
      return (balance: null, address: activeAccount.address);
    }

    // Fetch UTXOs for the active account from blockchain
    _log.debug(
      'Fetching UTXOs for metrics',
      context: {'address': activeAccount.address},
    );
    final owner = frb_types.publicKeyHashFromString(s: activeAccount.address);
    final utxosResp = await RustBackendService.instance.listUtxosByOwner(
      owner: owner,
    );
    final utxos = utxosResp?.items ?? [];

    // Calculate total balance by summing all UTXO amounts
    BigInt totalBalance = BigInt.zero;
    for (final ownedUtxo in utxos) {
      try {
        // Serialize UTXO to JSON to access its fields
        final jsonStr = frb_types.utxoToJson(utxo: ownedUtxo.utxo);
        final utxoData = json.decode(jsonStr) as Map<String, dynamic>;

        // Extract assets and sum their balances
        final assetsJson = utxoData['assets'] as List<dynamic>? ?? [];
        for (final assetJson in assetsJson) {
          final balance = assetJson['balance'] as int;
          totalBalance += BigInt.from(balance);
        }
      } catch (e) {
        // Skip this UTXO if parsing fails, but log for debugging
        _log.debug(
          'Failed to parse UTXO for balance calculation',
          context: {'error': e.toString()},
        );
      }
    }

    _log.debug(
      'Calculated wallet balance from UTXOs',
      context: {
        'utxo_count': utxos.length,
        'raw_balance': totalBalance.toString(),
      },
    );

    return (
      balance: totalBalance,
      address: activeAccount.address,
    );
  } catch (e) {
    // Log error but don't fail metrics collection
    _log.warn(
      'Failed to fetch wallet data for metrics',
      context: {'error': e.toString()},
    );
    return (balance: null, address: null);
  }
}
