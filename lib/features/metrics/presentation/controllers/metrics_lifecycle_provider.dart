import 'dart:convert';
import 'dart:math';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/metrics/domain/services/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
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
///
/// Balance is calculated by summing all UTXO amounts from the blockchain.
Future<({double? balance, String? address})> _fetchWalletData() async {
  try {
    // Get active account
    final accountsRepo = await AccountsRepository.create();
    final activeAccount = await accountsRepo.getActive();

    if (activeAccount == null || activeAccount.address.isEmpty) {
      return (balance: null, address: null);
    }

    // Only fetch UTXOs if address is in UTXO format (starts with 'ut')
    if (!activeAccount.address.startsWith('ut')) {
      LoggingService.instance.debug(
        'Account address not in UTXO format, skipping balance calculation',
        tag: LogTag.metrics,
        context: {'address': activeAccount.address},
      );
      return (balance: null, address: activeAccount.address);
    }

    // Fetch UTXOs for the active account from blockchain
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
        LoggingService.instance.debug(
          'Failed to parse UTXO for balance calculation',
          tag: LogTag.metrics,
          context: {'error': e.toString()},
        );
      }
    }

    // Convert from smallest unit to token amount (8 decimals, like BTC/crypto standard)
    const decimals = 8;
    final balanceDouble = totalBalance.toDouble() / pow(10, decimals);

    LoggingService.instance.debug(
      'Calculated wallet balance from UTXOs',
      tag: LogTag.metrics,
      context: {
        'utxo_count': utxos.length,
        'raw_balance': totalBalance.toString(),
        'balance': balanceDouble,
      },
    );

    return (
      balance: balanceDouble,
      address: activeAccount.address,
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
