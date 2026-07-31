import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/features/wallet/models/pending_transaction.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

/// Service to manage locally stored pending transactions
/// Used to associate sent amounts with pending mempool transactions
class PendingTransactionService {
  static const String _keyBase = 'wallet:pending_transactions';
  static const int _maxEntries = 100; // Limit stored pending transactions
  static const Duration _defaultMaxAge = Duration(hours: 24);

  static String _key(AccountStorageScope scope) =>
      scope.preferenceKey(_keyBase);

  static final _log =
      LoggingService.instance.withTag('usernode/PendingTransactionService');

  static PendingTransactionService? _instance;

  static Future<PendingTransactionService> getInstance() async {
    _instance ??= PendingTransactionService._();
    await _instance!._initialize();
    return _instance!;
  }

  PendingTransactionService._();

  late SharedPreferences _prefs;
  bool _initialized = false;
  final Map<AccountStorageScope, Future<void>> _scopeTails = {};

  Future<void> _initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Store a pending transaction locally
  Future<void> storePendingTransaction(
    AccountStorageScope scope,
    PendingTransaction transaction,
  ) async {
    await _ensureInitialized();
    await _withScopeLock(scope, () async {
      try {
        final existingTransactions = await _getAllTransactions(scope);
        final newTransactions = <PendingTransaction>[
          transaction,
          ...existingTransactions
              .where((tx) => tx.storageKey != transaction.storageKey),
        ];

        // Limit the number of stored transactions
        final limitedTransactions = newTransactions.length > _maxEntries
            ? newTransactions.sublist(0, _maxEntries)
            : newTransactions;

        await _saveAllTransactions(scope, limitedTransactions);

        _log.info(
            'Stored pending transaction: ${transaction.amount} to ${transaction.toAddress}');
      } catch (e) {
        _log.error('Failed to store pending transaction: $e');
      }
    });
  }

  /// Get all stored pending transactions
  Future<List<PendingTransaction>> getAllPendingTransactions(
    AccountStorageScope scope,
  ) async {
    await _ensureInitialized();
    return _withScopeLock(scope, () => _getAllTransactions(scope));
  }

  /// Find pending transactions that match the given criteria
  Future<List<PendingTransaction>> findMatchingTransactions({
    required AccountStorageScope scope,
    required String? fromAddress,
    required String? toAddress,
    required DateTime timestamp,
    Duration timestampTolerance = const Duration(minutes: 10),
  }) async {
    await _ensureInitialized();

    return _withScopeLock(scope, () async {
      final allTransactions = await _getAllTransactions(scope);
      return allTransactions
          .where((tx) => tx.matches(
                txFromAddress: fromAddress,
                txToAddress: toAddress,
                txTimestamp: timestamp,
                timestampTolerance: timestampTolerance,
              ))
          .toList();
    });
  }

  /// Remove a specific pending transaction
  Future<void> removePendingTransaction(
    AccountStorageScope scope,
    PendingTransaction transaction,
  ) async {
    await _ensureInitialized();

    await _withScopeLock(scope, () async {
      try {
        final allTransactions = await _getAllTransactions(scope);
        final filteredTransactions = allTransactions
            .where((tx) => tx.storageKey != transaction.storageKey)
            .toList();

        await _saveAllTransactions(scope, filteredTransactions);

        _log.debug('Removed pending transaction: ${transaction.storageKey}');
      } catch (e) {
        _log.error('Failed to remove pending transaction: $e');
      }
    });
  }

  /// Remove transactions that have been confirmed or are too old
  Future<void> cleanupTransactions({
    required AccountStorageScope scope,
    List<String>? confirmedTransactionHashes,
    Duration maxAge = _defaultMaxAge,
  }) async {
    await _ensureInitialized();
    await _withScopeLock(
      scope,
      () => _cleanupExpiredTransactions(scope, maxAge: maxAge),
    );
  }

  /// Get the amount for a transaction if it matches a pending transaction
  Future<double?> getAmountForTransaction({
    required AccountStorageScope scope,
    required String? fromAddress,
    required String? toAddress,
    required DateTime timestamp,
  }) async {
    final matches = await findMatchingTransactions(
      scope: scope,
      fromAddress: fromAddress,
      toAddress: toAddress,
      timestamp: timestamp,
    );

    if (matches.isNotEmpty) {
      final match = matches.first;
      _log.debug(
          'Found amount match: ${match.amount} for transaction at $timestamp');
      return match.amount;
    }

    return null;
  }

  /// Internal: Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _initialize();
    }
  }

  /// Serializes read-modify-write operations per stable account scope while
  /// allowing unrelated accounts to proceed independently.
  Future<T> _withScopeLock<T>(
    AccountStorageScope scope,
    Future<T> Function() operation,
  ) async {
    final previous = _scopeTails[scope];
    final release = Completer<void>();
    _scopeTails[scope] = release.future;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // A failed predecessor must not poison this scope's queue.
      }
    }
    try {
      return await operation();
    } finally {
      release.complete();
      if (identical(_scopeTails[scope], release.future)) {
        _scopeTails.remove(scope);
      }
    }
  }

  /// Internal: Get all transactions from storage
  Future<List<PendingTransaction>> _getAllTransactions(
    AccountStorageScope scope, {
    Duration maxAge = _defaultMaxAge,
  }) async {
    try {
      final jsonStringList = _prefs.getStringList(_key(scope)) ?? <String>[];
      final parsed = jsonStringList
          .map((jsonString) {
            try {
              return PendingTransaction.fromJsonString(jsonString);
            } catch (e) {
              _log.warn('Failed to parse pending transaction: $e');
              return null;
            }
          })
          .where((tx) => tx != null)
          .cast<PendingTransaction>()
          .toList();
      final valid = parsed
          .where((transaction) => !transaction.isExpired(maxAge: maxAge))
          .toList(growable: false);
      if (valid.length != parsed.length) {
        await _saveAllTransactions(scope, valid);
        _log.info(
          'Cleaned up ${parsed.length - valid.length} expired pending '
          'transactions',
        );
      }
      return valid;
    } catch (e) {
      _log.error('Failed to load pending transactions: $e');
      return <PendingTransaction>[];
    }
  }

  /// Internal: Save all transactions to storage
  Future<void> _saveAllTransactions(
    AccountStorageScope scope,
    List<PendingTransaction> transactions,
  ) async {
    try {
      final jsonStringList =
          transactions.map((tx) => tx.toJsonString()).toList();

      await _prefs.setStringList(_key(scope), jsonStringList);
    } catch (e) {
      _log.error('Failed to save pending transactions: $e');
    }
  }

  /// Internal: Remove expired transactions
  Future<void> _cleanupExpiredTransactions(
    AccountStorageScope scope, {
    Duration maxAge = _defaultMaxAge,
  }) async {
    await _getAllTransactions(scope, maxAge: maxAge);
  }

  /// Clear pending transactions for every account scope (app reset/debugging).
  Future<void> clearAllPendingTransactions() async {
    await _ensureInitialized();
    final keys = _prefs
        .getKeys()
        .where((key) => key.endsWith(':$_keyBase'))
        .toList(growable: false);
    for (final key in keys) {
      await _prefs.remove(key);
    }
    _log.info('Cleared all pending transactions');
  }

  /// Get count of stored pending transactions
  Future<int> getPendingTransactionCount(AccountStorageScope scope) async {
    final transactions = await getAllPendingTransactions(scope);
    return transactions.length;
  }
}
