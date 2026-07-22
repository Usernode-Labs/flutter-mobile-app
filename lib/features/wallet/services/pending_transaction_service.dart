import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/features/wallet/models/pending_transaction.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

/// Service to manage locally stored pending transactions
/// Used to associate sent amounts with pending mempool transactions
class PendingTransactionService {
  static const String _keyBase = 'wallet:pending_transactions';
  static const int _maxEntries = 100; // Limit stored pending transactions
  static const Duration _defaultMaxAge = Duration(hours: 24);

  static String get _key => NetworkPrefs.prefixAccountKey(_keyBase);

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

  Future<void> _initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;

    // Clean up old entries on initialization
    await _cleanupExpiredTransactions();
  }

  /// Store a pending transaction locally
  Future<void> storePendingTransaction(PendingTransaction transaction) async {
    await _ensureInitialized();

    try {
      final existingTransactions = await _getAllTransactions();
      final newTransactions = <PendingTransaction>[
        transaction,
        ...existingTransactions
            .where((tx) => tx.storageKey != transaction.storageKey),
      ];

      // Limit the number of stored transactions
      final limitedTransactions = newTransactions.length > _maxEntries
          ? newTransactions.sublist(0, _maxEntries)
          : newTransactions;

      await _saveAllTransactions(limitedTransactions);

      _log.info(
          'Stored pending transaction: ${transaction.amount} to ${transaction.toAddress}');
    } catch (e) {
      _log.error('Failed to store pending transaction: $e');
    }
  }

  /// Get all stored pending transactions
  Future<List<PendingTransaction>> getAllPendingTransactions() async {
    await _ensureInitialized();
    return await _getAllTransactions();
  }

  /// Find pending transactions that match the given criteria
  Future<List<PendingTransaction>> findMatchingTransactions({
    required String? fromAddress,
    required String? toAddress,
    required DateTime timestamp,
    Duration timestampTolerance = const Duration(minutes: 10),
  }) async {
    await _ensureInitialized();

    final allTransactions = await _getAllTransactions();
    return allTransactions
        .where((tx) => tx.matches(
              txFromAddress: fromAddress,
              txToAddress: toAddress,
              txTimestamp: timestamp,
              timestampTolerance: timestampTolerance,
            ))
        .toList();
  }

  /// Remove a specific pending transaction
  Future<void> removePendingTransaction(PendingTransaction transaction) async {
    await _ensureInitialized();

    try {
      final allTransactions = await _getAllTransactions();
      final filteredTransactions = allTransactions
          .where((tx) => tx.storageKey != transaction.storageKey)
          .toList();

      await _saveAllTransactions(filteredTransactions);

      _log.debug('Removed pending transaction: ${transaction.storageKey}');
    } catch (e) {
      _log.error('Failed to remove pending transaction: $e');
    }
  }

  /// Remove transactions that have been confirmed or are too old
  Future<void> cleanupTransactions({
    List<String>? confirmedTransactionHashes,
    Duration maxAge = _defaultMaxAge,
  }) async {
    await _ensureInitialized();
    await _cleanupExpiredTransactions(maxAge: maxAge);
  }

  /// Get the amount for a transaction if it matches a pending transaction
  Future<double?> getAmountForTransaction({
    required String? fromAddress,
    required String? toAddress,
    required DateTime timestamp,
  }) async {
    final matches = await findMatchingTransactions(
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

  /// Internal: Get all transactions from storage
  Future<List<PendingTransaction>> _getAllTransactions() async {
    try {
      final jsonStringList = _prefs.getStringList(_key) ?? <String>[];
      return jsonStringList
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
    } catch (e) {
      _log.error('Failed to load pending transactions: $e');
      return <PendingTransaction>[];
    }
  }

  /// Internal: Save all transactions to storage
  Future<void> _saveAllTransactions(
      List<PendingTransaction> transactions) async {
    try {
      final jsonStringList =
          transactions.map((tx) => tx.toJsonString()).toList();

      await _prefs.setStringList(_key, jsonStringList);
    } catch (e) {
      _log.error('Failed to save pending transactions: $e');
    }
  }

  /// Internal: Remove expired transactions
  Future<void> _cleanupExpiredTransactions(
      {Duration maxAge = _defaultMaxAge}) async {
    try {
      final allTransactions = await _getAllTransactions();
      final validTransactions =
          allTransactions.where((tx) => !tx.isExpired(maxAge: maxAge)).toList();

      if (validTransactions.length != allTransactions.length) {
        await _saveAllTransactions(validTransactions);
        _log.info(
            'Cleaned up ${allTransactions.length - validTransactions.length} expired pending transactions');
      }
    } catch (e) {
      _log.error('Failed to cleanup expired transactions: $e');
    }
  }

  /// Clear all pending transactions (for testing/debugging)
  Future<void> clearAllPendingTransactions() async {
    await _ensureInitialized();
    await _prefs.remove(_key);
    _log.info('Cleared all pending transactions');
  }

  /// Get count of stored pending transactions
  Future<int> getPendingTransactionCount() async {
    final transactions = await getAllPendingTransactions();
    return transactions.length;
  }
}
