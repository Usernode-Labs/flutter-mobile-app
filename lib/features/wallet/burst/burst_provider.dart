import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/wallet/burst/genesis_address_service.dart';

import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

final _log = LoggingService.instance.withTag('usernode/BurstProvider');

const kBurstCount = 50;

// --- State ---

sealed class BurstState {
  const BurstState();
}

class BurstIdle extends BurstState {
  const BurstIdle();
}

class BurstRunning extends BurstState {
  final int total;
  final int completed;
  final int succeeded;
  final int failed;
  final Stopwatch stopwatch;

  const BurstRunning({
    required this.total,
    required this.completed,
    required this.succeeded,
    required this.failed,
    required this.stopwatch,
  });
}

class BurstComplete extends BurstState {
  final int total;
  final int succeeded;
  final int failed;
  final Duration elapsed;
  final List<String> errors;

  const BurstComplete({
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.elapsed,
    required this.errors,
  });
}

// --- Notifier ---

class BurstTransactionNotifier extends Notifier<BurstState> {
  bool _cancelled = false;

  @override
  BurstState build() => const BurstIdle();

  void cancel() {
    _cancelled = true;
  }

  Future<void> start() async {
    _cancelled = false;

    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    var succeeded = 0;
    var failed = 0;

    try {
      // 1. Get active account
      final accountsRepo = await AccountsRepository.create();
      final userAccount = await accountsRepo.getActive();
      if (userAccount == null) {
        state = BurstComplete(
          total: 0,
          succeeded: 0,
          failed: 1,
          elapsed: stopwatch.elapsed,
          errors: ['No active account found'],
        );
        return;
      }

      // 2. Get genesis addresses
      final genesisService = GenesisAddressService.instance;
      final allAddresses = await genesisService.getAddresses();
      final recipients = genesisService.pickRandom(
        allAddresses,
        kBurstCount,
        exclude: userAccount.address,
      );

      final total = recipients.length;

      state = BurstRunning(
        total: total,
        completed: 0,
        succeeded: 0,
        failed: 0,
        stopwatch: stopwatch,
      );

      // 4. Sequential loop with retry on "already pending"
      final fromAddress = userAccount.address;
      const maxRetries = 3;
      const retryDelay = Duration(milliseconds: 250);

      for (var i = 0; i < total; i++) {
        if (_cancelled) {
          _log.info('Burst cancelled at $i/$total');
          break;
        }

        for (var attempt = 0; attempt <= maxRetries; attempt++) {
          if (_cancelled) break;

          try {
            final freshFromPkHash =
                frb_types.publicKeyHashFromString(s: fromAddress);
            final toPkHash =
                frb_types.publicKeyHashFromString(s: recipients[i]);
            final response = await RustBackendService.instance.transferFunds(
              fromPkHash: freshFromPkHash,
              amount: BigInt.one,
              toPkHash: toPkHash,
            );

            if (response != null && response.queued) {
              succeeded++;

              break;
            }

            final msg = response?.error ?? 'Unknown error';
            if (msg.contains('already pending') && attempt < maxRetries) {
              await Future<void>.delayed(retryDelay);
              continue;
            }

            // Non-retryable error or out of retries
            failed++;
            errors.add('tx ${i + 1}: $msg');
            _log.warn('Burst tx ${i + 1} failed: $msg');
            break;
          } catch (e) {
            if (attempt < maxRetries) {
              await Future<void>.delayed(retryDelay);
              continue;
            }
            failed++;
            errors.add('tx ${i + 1}: $e');
            _log.warn('Burst tx ${i + 1} exception: $e');
            break;
          }
        }

        state = BurstRunning(
          total: total,
          completed: i + 1,
          succeeded: succeeded,
          failed: failed,
          stopwatch: stopwatch,
        );
      }

      stopwatch.stop();
      _log.info(
          'Burst complete: $succeeded/$total succeeded in ${stopwatch.elapsed}');

      state = BurstComplete(
        total: total,
        succeeded: succeeded,
        failed: failed,
        elapsed: stopwatch.elapsed,
        errors: errors,
      );
    } catch (e, st) {
      _log.error('Burst failed', error: e, stackTrace: st);
      stopwatch.stop();
      state = BurstComplete(
        total: kBurstCount,
        succeeded: succeeded,
        failed: failed + 1,
        elapsed: stopwatch.elapsed,
        errors: [...errors, e.toString()],
      );
    }
  }
}

final burstProvider = NotifierProvider<BurstTransactionNotifier, BurstState>(
  BurstTransactionNotifier.new,
);
