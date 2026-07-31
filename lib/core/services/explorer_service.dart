import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('ExplorerService');

/// Data source for wallet data
enum DataSource {
  explorerPrimary,
  explorerSecondary,
  cached,
  local,
}

typedef _ExplorerCircuitKey = ({
  String endpoint,
  String network,
  String bucket,
  String accountId,
  String address,
  String chainId,
});

/// Explorer API service with multi-tier fallback strategy
class ExplorerService {
  ExplorerService({http.Client? httpClient})
      : _client = httpClient ?? createAppHttpClient();

  /// The client is owned by this service and closed by [dispose].
  final http.Client _client;

  // Circuit breaker state tracking
  final Map<_ExplorerCircuitKey, DateTime> _lastFailureTime = {};
  final Map<_ExplorerCircuitKey, int> _failureCount = {};
  static const int _circuitBreakerThreshold = 3;
  static const Duration _circuitBreakerCooldown = Duration(minutes: 5);

  /// Resolves the chain provenance for stable wallet data. A live node
  /// observation replaces the remembered value; while offline, the last
  /// observed chain lets the account read only its own chain-scoped cache.
  Future<String?> resolveChainId({
    required AccountStorageScope scope,
    String? observedChainId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final observed = observedChainId?.trim();
      if (observed != null && observed.isNotEmpty) {
        await prefs.setString(_lastChainIdKey(scope), observed);
        return observed;
      }
      final remembered = prefs.getString(_lastChainIdKey(scope))?.trim();
      return remembered == null || remembered.isEmpty ? null : remembered;
    } catch (e) {
      _log.warn('Failed to resolve explorer chain provenance: $e');
      return null;
    }
  }

  /// Get account balance from explorer APIs with fallback
  /// Returns null if all APIs fail - caller should use cached data or UTXO fallback
  Future<ExplorerBalanceResponse?> getAccountBalance({
    required AccountStorageScope scope,
    required String chainId,
  }) async {
    final capturedChainId = _requireChainId(chainId);
    _log.debug(
      'Fetching balance for account: ${scope.address} '
      'on chain: $capturedChainId',
    );

    // Try primary explorer
    final primaryResponse = await _tryGetBalance(
      AppConfig.primaryExplorerUrl,
      scope,
      capturedChainId,
      DataSource.explorerPrimary,
    );
    if (primaryResponse != null) return primaryResponse;

    // Try secondary explorer
    final secondaryResponse = await _tryGetBalance(
      AppConfig.secondaryExplorerUrl,
      scope,
      capturedChainId,
      DataSource.explorerSecondary,
    );
    if (secondaryResponse != null) return secondaryResponse;

    _log.warn('All explorer APIs failed for balance request');
    return null;
  }

  /// Get account transactions from explorer APIs with fallback
  /// Returns null if all APIs fail - caller should use cached data or UTXO fallback
  Future<ExplorerTransactionsResponse?> getAccountTransactions({
    required AccountStorageScope scope,
    required String chainId,
  }) async {
    final capturedChainId = _requireChainId(chainId);
    _log.debug(
      'Fetching transactions for account: ${scope.address} '
      'on chain: $capturedChainId',
    );

    // Try primary explorer
    final primaryResponse = await _tryGetTransactions(
      AppConfig.primaryExplorerUrl,
      scope,
      capturedChainId,
      DataSource.explorerPrimary,
    );
    if (primaryResponse != null) return primaryResponse;

    // Try secondary explorer
    final secondaryResponse = await _tryGetTransactions(
      AppConfig.secondaryExplorerUrl,
      scope,
      capturedChainId,
      DataSource.explorerSecondary,
    );
    if (secondaryResponse != null) return secondaryResponse;

    _log.warn('All explorer APIs failed for transactions request');
    return null;
  }

  /// Try to get balance from a specific explorer endpoint
  Future<ExplorerBalanceResponse?> _tryGetBalance(
    String baseUrl,
    AccountStorageScope scope,
    String chainId,
    DataSource source,
  ) async {
    final circuitKey = _circuitKey(baseUrl, scope, chainId);
    if (_isCircuitBreakerOpen(circuitKey)) {
      _log.debug('Circuit breaker is open for $baseUrl, skipping');
      return null;
    }

    try {
      final encodedChainId = Uri.encodeComponent(chainId);
      final encodedAddress = Uri.encodeComponent(scope.address);
      final url =
          '$baseUrl/$encodedChainId/blocks/best_tip/$encodedAddress/balance';
      _log.debug('Requesting balance from: $url');

      final response =
          await _client.get(Uri.parse(url)).timeout(AppConfig.explorerTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final balanceResponse = ExplorerBalanceResponse.fromJson(data, source);

        // Check if we got meaningful data (non-zero balance or valid response structure)
        if (balanceResponse.balance > 0 || _isValidBalanceResponse(data)) {
          _recordSuccess(circuitKey);
          _log.debug(
              'Successfully fetched balance from $source: ${balanceResponse.balance}');

          // Cache the successful response
          await _cacheBalanceResponse(scope, chainId, balanceResponse);

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
        _recordFailure(circuitKey);
        return null;
      }
    } catch (e) {
      _log.warn('Failed to fetch balance from $baseUrl: $e');
      _recordFailure(circuitKey);
      return null;
    }
  }

  /// Try to get transactions from a specific explorer endpoint
  Future<ExplorerTransactionsResponse?> _tryGetTransactions(
    String baseUrl,
    AccountStorageScope scope,
    String chainId,
    DataSource source,
  ) async {
    final circuitKey = _circuitKey(baseUrl, scope, chainId);
    if (_isCircuitBreakerOpen(circuitKey)) {
      _log.debug('Circuit breaker is open for $baseUrl, skipping');
      return null;
    }

    try {
      final encodedChainId = Uri.encodeComponent(chainId);
      final encodedAddress = Uri.encodeComponent(scope.address);
      final url =
          '$baseUrl/$encodedChainId/accounts/$encodedAddress/txs?limit=25';
      _log.debug('Requesting transactions from: $url');

      final response =
          await _client.get(Uri.parse(url)).timeout(AppConfig.explorerTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final txResponse = ExplorerTransactionsResponse.fromJson(data, source);

        // Check if we got meaningful data (has transactions or valid response structure)
        if (txResponse.transactions.isNotEmpty ||
            _isValidTransactionsResponse(data)) {
          _recordSuccess(circuitKey);
          _log.debug(
              'Successfully fetched ${txResponse.transactions.length} transactions from $source');

          // Cache the successful response
          await _cacheTransactionsResponse(scope, chainId, txResponse);

          return txResponse;
        } else {
          _log.debug('Explorer returned empty transaction data from $source');
          // Don't record this as a failure, but also don't cache empty data
          return null;
        }
      } else {
        _log.warn(
            'Explorer API returned ${response.statusCode}: ${response.body}');
        _recordFailure(circuitKey);
        return null;
      }
    } catch (e) {
      _log.warn('Failed to fetch transactions from $baseUrl: $e');
      _recordFailure(circuitKey);
      return null;
    }
  }

  /// Cache balance response for offline use
  Future<void> _cacheBalanceResponse(
    AccountStorageScope scope,
    String chainId,
    ExplorerBalanceResponse response,
  ) =>
      _cacheResponse(
        scope: scope,
        chainId: chainId,
        kind: 'balance',
        response: response.toJson(),
      );

  /// Cache transactions response for offline use
  Future<void> _cacheTransactionsResponse(
    AccountStorageScope scope,
    String chainId,
    ExplorerTransactionsResponse response,
  ) =>
      _cacheResponse(
        scope: scope,
        chainId: chainId,
        kind: 'transactions',
        response: response.toJson(),
      );

  Future<void> _cacheResponse({
    required AccountStorageScope scope,
    required String chainId,
    required String kind,
    required Map<String, dynamic> response,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _discardLegacyEntry(prefs, scope, kind);
      final cacheData = {
        'response': response,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(
        _cacheKey(scope, chainId, kind),
        json.encode(cacheData),
      );
      _log.debug('Cached $kind response for ${scope.address}');
    } catch (e) {
      _log.warn('Failed to cache $kind response: $e');
    }
  }

  /// Get cached balance if available and not expired
  Future<ExplorerBalanceResponse?> getCachedBalance({
    required AccountStorageScope scope,
    required String chainId,
  }) =>
      _readCachedResponse(
        scope: scope,
        chainId: _requireChainId(chainId),
        kind: 'balance',
        decode: (response) =>
            ExplorerBalanceResponse.fromJson(response, DataSource.cached),
      );

  /// Get cached transactions if available and not expired
  Future<ExplorerTransactionsResponse?> getCachedTransactions({
    required AccountStorageScope scope,
    required String chainId,
  }) =>
      _readCachedResponse(
        scope: scope,
        chainId: _requireChainId(chainId),
        kind: 'transactions',
        decode: (response) =>
            ExplorerTransactionsResponse.fromJson(response, DataSource.cached),
      );

  Future<T?> _readCachedResponse<T>({
    required AccountStorageScope scope,
    required String chainId,
    required String kind,
    required T Function(Map<String, dynamic>) decode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _discardLegacyEntry(prefs, scope, kind);
      final cacheKey = _cacheKey(scope, chainId, kind);
      final cachedData = prefs.getString(cacheKey);
      if (cachedData == null) return null;

      try {
        final decoded = json.decode(cachedData);
        if (decoded is! Map) {
          throw const FormatException('Cache root is not an object');
        }
        final cache = Map<String, dynamic>.from(decoded);
        final cachedAtMillis = cache['cached_at'];
        final response = cache['response'];
        if (cachedAtMillis is! int || response is! Map) {
          throw const FormatException('Cache entry has an invalid shape');
        }

        final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMillis);
        if (DateTime.now().difference(cachedAt) > AppConfig.explorerCacheTtl) {
          await prefs.remove(cacheKey);
          _log.debug('Cached $kind for ${scope.address} has expired');
          return null;
        }

        final result = decode(Map<String, dynamic>.from(response));
        _log.debug('Retrieved cached $kind for ${scope.address}');
        return result;
      } catch (e) {
        await prefs.remove(cacheKey);
        rethrow;
      }
    } catch (e) {
      _log.warn('Failed to retrieve cached $kind: $e');
      return null;
    }
  }

  String _cacheKey(
    AccountStorageScope scope,
    String chainId,
    String kind,
  ) {
    final encodedChainId = Uri.encodeComponent(chainId);
    final encodedAccountId = Uri.encodeComponent(scope.accountId);
    final encodedAddress = Uri.encodeComponent(scope.address);
    return scope.preferenceKey(
      'explorer:v2:chain:$encodedChainId:account:$encodedAccountId:'
      'address:$encodedAddress:$kind',
    );
  }

  String _lastChainIdKey(AccountStorageScope scope) {
    final encodedAccountId = Uri.encodeComponent(scope.accountId);
    final encodedAddress = Uri.encodeComponent(scope.address);
    return scope.preferenceKey(
      'explorer:v2:account:$encodedAccountId:address:$encodedAddress:'
      'last_chain_id',
    );
  }

  Future<void> _discardLegacyEntry(
    SharedPreferences prefs,
    AccountStorageScope scope,
    String kind,
  ) async {
    // The legacy key has no network, account ID, or chain provenance. It
    // cannot be assigned safely to this scope, so discard it instead.
    await prefs.remove('explorer_${kind}_${scope.address}');
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

  String _requireChainId(String chainId) {
    final capturedChainId = chainId.trim();
    if (capturedChainId.isEmpty) {
      throw ArgumentError.value(chainId, 'chainId', 'Must not be empty');
    }
    return capturedChainId;
  }

  _ExplorerCircuitKey _circuitKey(
    String endpoint,
    AccountStorageScope scope,
    String chainId,
  ) =>
      (
        endpoint: endpoint,
        network: scope.network,
        bucket: scope.bucket,
        accountId: scope.accountId,
        address: scope.address,
        chainId: chainId,
      );

  /// Circuit breaker logic
  bool _isCircuitBreakerOpen(_ExplorerCircuitKey key) {
    final failureCount = _failureCount[key] ?? 0;
    final lastFailure = _lastFailureTime[key];

    if (failureCount < _circuitBreakerThreshold) return false;

    if (lastFailure == null) return false;

    // Check if cooldown period has passed
    if (DateTime.now().difference(lastFailure) > _circuitBreakerCooldown) {
      _log.debug(
          'Circuit breaker cooldown passed for ${key.endpoint}, resetting');
      _failureCount[key] = 0;
      _lastFailureTime.remove(key);
      return false;
    }

    return true;
  }

  void _recordSuccess(_ExplorerCircuitKey key) {
    _failureCount[key] = 0;
    _lastFailureTime.remove(key);
  }

  void _recordFailure(_ExplorerCircuitKey key) {
    _failureCount[key] = (_failureCount[key] ?? 0) + 1;
    _lastFailureTime[key] = DateTime.now();

    final failureCount = _failureCount[key]!;
    if (failureCount >= _circuitBreakerThreshold) {
      _log.warn(
          'Circuit breaker opened for ${key.endpoint} after $failureCount failures');
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
    // Mirror the live API shape (`items`) so a cached blob round-trips back
    // through [fromJson]. Writing a different key here silently yields an
    // empty list on read, wiping cached Recent Activity.
    return {
      'items': transactions.map((tx) => tx.toJson()).toList(),
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
    // Use the same field names [fromJson] reads from the live API so a cached
    // entry deserializes back into an identical ExplorerTransaction. (`amount`
    // round-trips as a number; `token_symbol` is not in the API and is
    // re-defaulted to TKN on read, so it is intentionally not persisted.)
    return {
      'tx_id': id,
      'tx_type': txType,
      'direction': direction,
      'amount': amount,
      'timestamp_ms': timestamp.millisecondsSinceEpoch,
      'status': status,
      'source': fromAddress,
      'destination': toAddress,
      'block_height': blockHeight,
      'block_hash': blockHash,
    };
  }
}
