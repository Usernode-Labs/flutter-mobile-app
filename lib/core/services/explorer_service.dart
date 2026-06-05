import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';

final _log = LoggingService.instance.withTag('ExplorerService');

/// Data source for wallet data
enum DataSource {
  explorerPrimary,
  explorerSecondary,
  cached,
  local,
}

/// Explorer API service with multi-tier fallback strategy
class ExplorerService {
  final Ref _ref;
  final _client = createAppHttpClient();

  ExplorerService(this._ref);

  // Circuit breaker state tracking
  final Map<String, DateTime> _lastFailureTime = {};
  final Map<String, int> _failureCount = {};
  static const int _circuitBreakerThreshold = 3;
  static const Duration _circuitBreakerCooldown = Duration(minutes: 5);

  /// Get account balance from explorer APIs with fallback
  /// Returns null if all APIs fail - caller should use cached data or UTXO fallback
  Future<ExplorerBalanceResponse?> getAccountBalance(String account) async {
    // Get chain ID from node status
    final chainId = _ref.read(nodeStatusProvider).value?.chainId;
    if (chainId == null) {
      _log.debug(
          'Chain ID not available from node status, skipping explorer API');
      return null;
    }

    _log.debug('Fetching balance for account: $account on chain: $chainId');

    // Try primary explorer
    final primaryResponse = await _tryGetBalance(AppConfig.primaryExplorerUrl,
        account, chainId, DataSource.explorerPrimary);
    if (primaryResponse != null) return primaryResponse;

    // Try secondary explorer
    final secondaryResponse = await _tryGetBalance(
        AppConfig.secondaryExplorerUrl,
        account,
        chainId,
        DataSource.explorerSecondary);
    if (secondaryResponse != null) return secondaryResponse;

    _log.warn('All explorer APIs failed for balance request');
    return null;
  }

  /// Get account transactions from explorer APIs with fallback
  /// Returns null if all APIs fail - caller should use cached data or UTXO fallback
  Future<ExplorerTransactionsResponse?> getAccountTransactions(
      String account) async {
    // Get chain ID from node status
    final chainId = _ref.read(nodeStatusProvider).value?.chainId;
    if (chainId == null) {
      _log.debug(
          'Chain ID not available from node status, skipping explorer API');
      return null;
    }

    _log.debug(
        'Fetching transactions for account: $account on chain: $chainId');

    // Try primary explorer
    final primaryResponse = await _tryGetTransactions(
        AppConfig.primaryExplorerUrl,
        account,
        chainId,
        DataSource.explorerPrimary);
    if (primaryResponse != null) return primaryResponse;

    // Try secondary explorer
    final secondaryResponse = await _tryGetTransactions(
        AppConfig.secondaryExplorerUrl,
        account,
        chainId,
        DataSource.explorerSecondary);
    if (secondaryResponse != null) return secondaryResponse;

    _log.warn('All explorer APIs failed for transactions request');
    return null;
  }

  /// Try to get balance from a specific explorer endpoint
  Future<ExplorerBalanceResponse?> _tryGetBalance(
      String baseUrl, String account, String chainId, DataSource source) async {
    if (_isCircuitBreakerOpen(baseUrl)) {
      _log.debug('Circuit breaker is open for $baseUrl, skipping');
      return null;
    }

    try {
      final url = '$baseUrl/$chainId/blocks/best_tip/$account/balance';
      _log.debug('Requesting balance from: $url');

      final response =
          await _client.get(Uri.parse(url)).timeout(AppConfig.explorerTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final balanceResponse = ExplorerBalanceResponse.fromJson(data, source);

        // Check if we got meaningful data (non-zero balance or valid response structure)
        if (balanceResponse.balance > 0 || _isValidBalanceResponse(data)) {
          _recordSuccess(baseUrl);
          _log.debug(
              'Successfully fetched balance from $source: ${balanceResponse.balance}');

          // Cache the successful response
          await _cacheBalanceResponse(account, balanceResponse);

          return balanceResponse;
        } else {
          _log.debug(
              'Explorer returned empty/invalid balance data from $source');
          // Don't record this as a failure, but also don't cache empty data
          return null;
        }
      } else {
        _log.warn(
            'Explorer API returned ${response.statusCode}: ${response.body}');
        _recordFailure(baseUrl);
        return null;
      }
    } catch (e) {
      _log.warn('Failed to fetch balance from $baseUrl: $e');
      _recordFailure(baseUrl);
      return null;
    }
  }

  /// Try to get transactions from a specific explorer endpoint
  Future<ExplorerTransactionsResponse?> _tryGetTransactions(
      String baseUrl, String account, String chainId, DataSource source) async {
    if (_isCircuitBreakerOpen(baseUrl)) {
      _log.debug('Circuit breaker is open for $baseUrl, skipping');
      return null;
    }

    try {
      final url = '$baseUrl/$chainId/accounts/$account/txs?limit=25';
      _log.debug('Requesting transactions from: $url');

      final response =
          await _client.get(Uri.parse(url)).timeout(AppConfig.explorerTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final txResponse = ExplorerTransactionsResponse.fromJson(data, source);

        // Check if we got meaningful data (has transactions or valid response structure)
        if (txResponse.transactions.isNotEmpty ||
            _isValidTransactionsResponse(data)) {
          _recordSuccess(baseUrl);
          _log.debug(
              'Successfully fetched ${txResponse.transactions.length} transactions from $source');

          // Cache the successful response
          await _cacheTransactionsResponse(account, txResponse);

          return txResponse;
        } else {
          _log.debug('Explorer returned empty transaction data from $source');
          // Don't record this as a failure, but also don't cache empty data
          return null;
        }
      } else {
        _log.warn(
            'Explorer API returned ${response.statusCode}: ${response.body}');
        _recordFailure(baseUrl);
        return null;
      }
    } catch (e) {
      _log.warn('Failed to fetch transactions from $baseUrl: $e');
      _recordFailure(baseUrl);
      return null;
    }
  }

  /// Cache balance response for offline use
  Future<void> _cacheBalanceResponse(
      String account, ExplorerBalanceResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'explorer_balance_$account';
      final cacheData = {
        'response': response.toJson(),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(cacheKey, json.encode(cacheData));
      _log.debug('Cached balance response for $account');
    } catch (e) {
      _log.warn('Failed to cache balance response: $e');
    }
  }

  /// Cache transactions response for offline use
  Future<void> _cacheTransactionsResponse(
      String account, ExplorerTransactionsResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'explorer_transactions_$account';
      final cacheData = {
        'response': response.toJson(),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(cacheKey, json.encode(cacheData));
      _log.debug('Cached transactions response for $account');
    } catch (e) {
      _log.warn('Failed to cache transactions response: $e');
    }
  }

  /// Get cached balance if available and not expired
  Future<ExplorerBalanceResponse?> getCachedBalance(String account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'explorer_balance_$account';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData == null) return null;

      final cache = json.decode(cachedData);
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cache['cached_at']);

      // Check if cache is still valid
      if (DateTime.now().difference(cachedAt) > AppConfig.explorerCacheTtl) {
        _log.debug('Cached balance for $account has expired');
        return null;
      }

      final response = ExplorerBalanceResponse.fromJson(
          cache['response'], DataSource.cached);
      _log.debug('Retrieved cached balance for $account');
      return response;
    } catch (e) {
      _log.warn('Failed to retrieve cached balance: $e');
      return null;
    }
  }

  /// Get cached transactions if available and not expired
  Future<ExplorerTransactionsResponse?> getCachedTransactions(
      String account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'explorer_transactions_$account';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData == null) return null;

      final cache = json.decode(cachedData);
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cache['cached_at']);

      // Check if cache is still valid
      if (DateTime.now().difference(cachedAt) > AppConfig.explorerCacheTtl) {
        _log.debug('Cached transactions for $account have expired');
        return null;
      }

      final response = ExplorerTransactionsResponse.fromJson(
          cache['response'], DataSource.cached);
      _log.debug('Retrieved cached transactions for $account');
      return response;
    } catch (e) {
      _log.warn('Failed to retrieve cached transactions: $e');
      return null;
    }
  }

  /// Check if balance response contains valid data structure
  bool _isValidBalanceResponse(Map<String, dynamic> data) {
    // Consider response valid if it has proper structure even with 0 balance
    // This handles new accounts that legitimately have 0 balance
    return data.containsKey('balance') ||
        data.containsKey('token_symbol') ||
        data.containsKey('amount');
  }

  /// Check if transactions response contains valid data structure
  bool _isValidTransactionsResponse(Map<String, dynamic> data) {
    // Consider response valid if it has proper structure even with empty transactions
    // This handles accounts that legitimately have no transactions yet
    return data.containsKey('items') ||
        data.containsKey('transactions') ||
        data.containsKey('txs') ||
        data.containsKey('data');
  }

  /// Circuit breaker logic
  bool _isCircuitBreakerOpen(String endpoint) {
    final failureCount = _failureCount[endpoint] ?? 0;
    final lastFailure = _lastFailureTime[endpoint];

    if (failureCount < _circuitBreakerThreshold) return false;

    if (lastFailure == null) return false;

    // Check if cooldown period has passed
    if (DateTime.now().difference(lastFailure) > _circuitBreakerCooldown) {
      _log.debug('Circuit breaker cooldown passed for $endpoint, resetting');
      _failureCount[endpoint] = 0;
      _lastFailureTime.remove(endpoint);
      return false;
    }

    return true;
  }

  void _recordSuccess(String endpoint) {
    _failureCount[endpoint] = 0;
    _lastFailureTime.remove(endpoint);
  }

  void _recordFailure(String endpoint) {
    _failureCount[endpoint] = (_failureCount[endpoint] ?? 0) + 1;
    _lastFailureTime[endpoint] = DateTime.now();

    if (_failureCount[endpoint]! >= _circuitBreakerThreshold) {
      _log.warn(
          'Circuit breaker opened for $endpoint after ${_failureCount[endpoint]} failures');
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Response model for explorer balance API
class ExplorerBalanceResponse {
  final double balance;
  final String tokenSymbol;
  final DataSource dataSource;
  final DateTime fetchedAt;

  ExplorerBalanceResponse({
    required this.balance,
    required this.tokenSymbol,
    required this.dataSource,
    required this.fetchedAt,
  });

  factory ExplorerBalanceResponse.fromJson(
      Map<String, dynamic> json, DataSource source) {
    return ExplorerBalanceResponse(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      tokenSymbol: json['token_symbol'] as String? ?? 'TKN',
      dataSource: source,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balance': balance,
      'token_symbol': tokenSymbol,
      'data_source': dataSource.toString(),
      'fetched_at': fetchedAt.millisecondsSinceEpoch,
    };
  }
}

/// Response model for explorer transactions API
class ExplorerTransactionsResponse {
  final List<ExplorerTransaction> transactions;
  final DataSource dataSource;
  final DateTime fetchedAt;

  ExplorerTransactionsResponse({
    required this.transactions,
    required this.dataSource,
    required this.fetchedAt,
  });

  factory ExplorerTransactionsResponse.fromJson(
      Map<String, dynamic> json, DataSource source) {
    final txList = json['items'] as List<dynamic>? ?? [];
    final transactions = txList
        .map((tx) => ExplorerTransaction.fromJson(tx as Map<String, dynamic>))
        .toList();

    return ExplorerTransactionsResponse(
      transactions: transactions,
      dataSource: source,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactions': transactions.map((tx) => tx.toJson()).toList(),
      'data_source': dataSource.toString(),
      'fetched_at': fetchedAt.millisecondsSinceEpoch,
    };
  }
}

/// Individual transaction from explorer API
class ExplorerTransaction {
  final String id;
  final String txType; // "transfer", "reward", "genesis"
  final String direction; // "in", "out"
  final double amount;
  final String tokenSymbol;
  final DateTime timestamp;
  final String status;
  final String? fromAddress;
  final String? toAddress;
  final int? blockHeight;
  final String? blockHash;

  ExplorerTransaction({
    required this.id,
    required this.txType,
    required this.direction,
    required this.amount,
    required this.tokenSymbol,
    required this.timestamp,
    required this.status,
    this.fromAddress,
    this.toAddress,
    this.blockHeight,
    this.blockHash,
  });

  /// Legacy getter for backward compatibility
  String get type => direction;

  factory ExplorerTransaction.fromJson(Map<String, dynamic> json) {
    return ExplorerTransaction(
      id: json['tx_id'] as String? ?? '',
      txType: json['tx_type'] as String? ?? 'transfer',
      direction: json['direction'] as String? ?? 'unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      tokenSymbol: 'TKN', // API doesn't provide token_symbol, default to TKN
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp_ms'] as int? ??
              DateTime.now().millisecondsSinceEpoch),
      status: json['status'] as String? ?? 'confirmed',
      fromAddress: json['source'] as String?,
      toAddress: json['destination'] as String?,
      blockHeight: json['block_height'] as int?,
      blockHash: json['block_hash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tx_type': txType,
      'direction': direction,
      'amount': amount,
      'token_symbol': tokenSymbol,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status,
      'from_address': fromAddress,
      'to_address': toAddress,
      'block_height': blockHeight,
      'block_hash': blockHash,
    };
  }
}
