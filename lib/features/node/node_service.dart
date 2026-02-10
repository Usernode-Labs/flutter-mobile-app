import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/block_producer_status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/transfer_funds.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' show enableLogging;
import 'package:crypto_mobile_app/src/rust/tracing.dart' show TracingLevel;
import 'package:crypto_mobile_app/src/rust/node.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/models/backend_rpc_response.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

final _log = LoggingService.instance.withTag('usernode/NodeService');

/// Parse log level string to TracingLevel enum
TracingLevel _parseTracingLevel(String level) {
  switch (level.toLowerCase()) {
    case 'trace':
      return TracingLevel.trace;
    case 'debug':
      return TracingLevel.debug;
    case 'info':
      return TracingLevel.info;
    case 'warn':
    case 'warning':
      return TracingLevel.warn;
    case 'error':
      return TracingLevel.error;
    default:
      return TracingLevel.error;
  }
}

/// Network type for chain selection
enum NetworkType { testnet, internal, custom }

/// Storage key for selected network
const _kNetworkTypeKey = 'network:type';

/// A small façade around flutter_rust_bridge generated APIs.
/// Centralizes initialization and access to the Rust node / RPC.
class RustBackendService {
  RustBackendService._() {
    _log.info('Service created');
  }
  static RustBackendService? _instance;
  static RustBackendService get instance =>
      _instance ??= RustBackendService._();

  bool _initialized = false;
  Completer<void>?
      _initCompleter; // Prevents race condition on concurrent init() calls
  Completer<bool>? _startNodeCompleter;
  bool _nodeRunning = false;
  String? _instanceId;
  String? _cachedPeerId;
  int? _cachedGenesisTimestamp;

  NodeControl? _control;
  NodeRpcClient? _rpc;
  bool get isRunning => _nodeRunning;
  String? get instanceId => _instanceId;
  void setInstanceId(String id) {
    _instanceId = id;
  }

  Future<void> _cachePeerIdFromRpc(NodeRpcClient rpc) async {
    try {
      final status = await rpc.status(includeVrfDetails: false);
      _cachedPeerId = status?.node.peerId.toString();
    } catch (e, st) {
      _log.error(
          '_cachePeerIdFromRpc: Failed to cache peer ID from RPC status()',
          error: e,
          stackTrace: st);
      _cachedPeerId = null;
    }
  }

  /// Initialize flutter_rust_bridge and load the dynamic library.
  /// Call once at app startup (before runApp).
  /// Thread-safe: concurrent calls will await the same initialization.
  Future<void> init() async {
    // Fast path: already initialized (check both our flag and FRB's internal state)
    if (_initialized || RustLib.instance.initialized) {
      _initialized = true; // Sync our flag with FRB state (handles hot restart)
      return;
    }

    _log.warn('FRB Init');

    // If initialization is in progress, await it
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    // Start initialization - create completer before any async work
    _initCompleter = Completer<void>();

    try {
      await RustLib.init(
        externalLibrary: Platform.isIOS || Platform.isMacOS
            ? ExternalLibrary.process(iKnowHowToUseIt: true)
            : null,
      );

      // Enable Rust-side logging if RUST_LOG_LEVEL is explicitly set (also in release).
      if (AppConfig.rustLogLevel.isNotEmpty) {
        final rustLogLevel = _parseTracingLevel(AppConfig.rustLogLevel);
        final appSupportDir = await getApplicationSupportDirectory();
        final logDir = '${appSupportDir.path}/logs';
        enableLogging(logLevel: rustLogLevel, outputDir: logDir);
        _log.info(
            'Rust logging enabled: level=${AppConfig.rustLogLevel}, dir=$logDir');
      }

      _initialized = true;
      _initCompleter!.complete();
    } on PanicException catch (e, st) {
      final msg = e.toString();
      // Handle duplicate tracing subscriber setup from Rust side gracefully
      if (msg.contains('SetGlobalDefaultError') ||
          msg.contains(
              'global default trace dispatcher has already been set')) {
        _log.warn(
          'Tracing subscriber already set in Rust; continuing initialization',
        );
        _initialized = true; // library loaded; only tracing init failed
        _initCompleter!.complete();
      } else {
        LoggingService.instance
            .error('FRB init failed', error: e, stackTrace: st);
        _initCompleter!.completeError(e, st);
        _initCompleter = null; // Allow retry on next call
        rethrow;
      }
    } catch (e, st) {
      // Handle any other unexpected errors
      LoggingService.instance
          .error('FRB init failed unexpectedly', error: e, stackTrace: st);
      _initCompleter!.completeError(e, st);
      _initCompleter = null; // Allow retry on next call
      rethrow;
    }
  }

  /// Start the node using the active account's secret key.
  /// Returns true if started successfully, false if no account or error.
  /// Safe to call multiple times; subsequent calls return true if already running.
  Future<bool> startNode({int? httpPort}) async {
    if (_startNodeCompleter != null) {
      _log.debug('startNode already in progress; waiting for existing start');
      return _startNodeCompleter!.future;
    }

    final completer = Completer<bool>();
    _startNodeCompleter = completer;
    try {
      final started = await _startNodeInternal(httpPort: httpPort);
      completer.complete(started);
      return started;
    } catch (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
      rethrow;
    } finally {
      if (identical(_startNodeCompleter, completer)) {
        _startNodeCompleter = null;
      }
    }
  }

  Future<bool> _startNodeInternal({int? httpPort}) async {
    if (!_initialized) {
      await init();
    }
    if (_nodeRunning) {
      _log.trace('Node already running');
      return true;
    }

    // Get active account
    final repo = await AccountsRepository.create();
    _log.trace('Checking if any accounts exist...');
    final hasAny = await repo.hasAny();
    _log.trace('Account check result: hasAny = $hasAny');
    if (!hasAny) {
      _log.trace('No accounts found - skipping node start');
      return false;
    }

    // Retrieve active account
    _log.debug('Retrieving active account...');
    final account = await repo.getActive();

    if (account == null) {
      _log.error('Failed to retrieve active account');
      return false;
    }

    _log.debug('Active account: ${account.id} (${account.name})');

    // Get secret key for active account
    _log.trace('Retrieving secret key for account ${account.id}...');
    final secretKey = await repo.getSecretKey(account.id);

    if (secretKey == null || secretKey.isEmpty) {
      _log.error(
        'Cannot start node: secret key unavailable for account ${account.id}',
      );
      return false;
    }

    // SECURITY: Only log key length, not value
    _log.trace('Secret key retrieved (length: ${secretKey.length})');

    // First try to reuse an already-running *global* node (shared across Dart
    // isolates / FlutterEngines in the same process) by grabbing its RPC client.
    // This avoids spinning up a second node when another engine already started it.
    final existing = Node.getGlobal();
    if (existing case (final rpc, final control)) {
      _rpc = rpc;
      _control = control;
      _nodeRunning = true;
      control.resume();
      await _cachePeerIdFromRpc(rpc);
      _log.info('Reused previously started node');
      return true;
    }

    // Start node
    try {
      _log.trace('Starting node${httpPort != null ? ' on $httpPort' : ''}');

      // No global node exists yet, so build/configure a new one.
      final builder = NodeBuilder();
      if (httpPort != null) {
        builder.httpServer(port: httpPort);
      }

      // Load network configuration from URLs (with retry)
      await _configureNetworkFromUrls(builder);

      _log.trace(
        'Configuring block producer with user secret key (length: ${secretKey.length})',
      );
      builder.blockProducerSecretKey(secretKey: secretKey);
      _log.info('Forcing real prover mode');
      builder.enableRealProver();
      builder.mempoolAutoinsertInterval(secs: BigInt.from(1));

      // Configure persistent VRF storage path so VRF evaluation progress survives restarts.
      // Use network-specific path to avoid conflicts when switching networks.
      final appSupportDir = await getApplicationSupportDirectory();
      final networkType = await _getSelectedNetwork();
      // TODO this should include the hash of the genesis block
      final vrfPath =
          '${appSupportDir.path}/${networkType.name}_usernode_vrf_storage.sqlite';
      _log.trace('Using VRF storage path: $vrfPath');
      builder.vrfStoragePath(path: vrfPath);

      final node = builder.build();
      _rpc = node.rpc();

      // Run the node in a background thread.
      _control = node.runForeverInNewThread();
      _nodeRunning = true;

      // Cache peer ID once on startup.
      // Prefer RPC status so callers don't depend on holding a Node handle.
      // Wait a bit for the node to be ready before trying to cache peer ID
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await _cachePeerIdFromRpc(_rpc!);
      } catch (e) {
        _log.warn('Failed to cache peer ID (node may still be starting): $e');
      }

      // Set the signer in the usernode for transaction signing
      try {
        _log.debug('Configuring wallet signer for account ${account.id}...');
        final signerResponse = await _rpc!.walletSetSignerFromSecret(
          secretKey: secretKey,
        );

        if (signerResponse != null && signerResponse.ok) {
          _log.info(
              'Wallet signer configured successfully for account ${account.id}');
        } else {
          final error = signerResponse?.error ?? 'Unknown error';
          _log.warn('Failed to configure wallet signer: $error');
        }
      } catch (e, st) {
        _log.warn('Exception while configuring wallet signer: $e $st');
        // Don't fail node startup if signer configuration fails
      }

      _log.info('Node started with user account block producer');
      return true;
    } catch (e, st) {
      _log.error('Failed to start node with account ${account.id}',
          error: e, stackTrace: st);
      await SentryUtil.captureError(e, st, tag: 'startNode');
      return false;
    }
  }

  Future<void> resumeNode() async {
    _log.info('Resuming node');
    _control?.resume();
  }

  Future<void> pauseNode() async {
    _log.info('Pausing node');
    _control?.pause();
  }

  Future<void> stopNode() async {
    if (!_initialized && !_nodeRunning) return;
    // Currently frb-generated API does not expose a graceful shutdown; dispose bridge.
    _log.warn(
      'Stopping node (dropping references; FRB stays initialized)',
    );
    _control?.shutdown();
    _nodeRunning = false;
    _rpc = null;
    _control = null;
    _cachedPeerId = null;
  }

  /// Get the currently selected network type from storage.
  ///
  /// This is exposed via the public [getSelectedNetwork] wrapper so that other
  /// parts of the app (e.g. providers) can read the current network without
  /// duplicating storage keys or logic.
  Future<NetworkType> _getSelectedNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kNetworkTypeKey);
    if (value == 'internal') {
      return NetworkType.internal;
    }
    if (value == 'custom') {
      return NetworkType.custom;
    }
    return NetworkType.testnet; // default
  }

  /// Public wrapper around [_getSelectedNetwork] so callers outside this file
  /// can determine which network (testnet / internal / custom) is currently selected.
  Future<NetworkType> getSelectedNetwork() => _getSelectedNetwork();

  /// Configure network settings from URLs (seedlist, genesis).
  Future<void> _configureNetworkFromUrls(NodeBuilder builder) async {
    final retries = BigInt.from(AppConfig.loadGenesisNbRetries);
    final networkType = await _getSelectedNetwork();

    // Get URLs based on selected network
    final String seedlistUrl;
    final String genesisUrl;
    switch (networkType) {
      case NetworkType.testnet:
        seedlistUrl = AppConfig.testnetSeedlistUrl;
        genesisUrl = AppConfig.testnetGenesisUrl;
      case NetworkType.internal:
        seedlistUrl = AppConfig.internalSeedlistUrl;
        genesisUrl = AppConfig.internalGenesisUrl;
      case NetworkType.custom:
        seedlistUrl = AppConfig.customSeedlistUrl;
        genesisUrl = AppConfig.customGenesisUrl;
    }

    _log.info('Selected network: ${networkType.name}');
    _log.info('Loading seedlist from URL: $seedlistUrl');
    await builder.initialPeersFromUrlWithRetries(
      url: seedlistUrl,
      retries: retries,
    );
    _log.info('Seedlist loaded successfully');

    _log.info('Loading genesis from URL: $genesisUrl');
    await builder.genesisJsonFromUrlWithRetries(
      url: genesisUrl,
      retries: retries,
    );
    _log.info('Genesis configured successfully');
  }

  /// Restart node using current active account context.
  Future<void> restartNode() async {
    _log.info('Restarting node');
    await stopNode();
    await startNode();
  }

  /// Obtain the RPC client for ad-hoc calls.
  NodeRpcClient? get rpc => _rpc;

  /// Get the node's P2P peer ID.
  /// Returns the cached peer ID that was retrieved on node startup.
  /// Returns null if the node is not running or peer ID was not cached.
  String? getPeerId() {
    return _cachedPeerId;
  }

  Future<RpcStatusNode?> getStatusNode() async {
    _log.trace('getStatusNode called');
    final r = _rpc;
    if (r == null) return null;
    try {
      final status = await r.status(includeVrfDetails: false);
      return status?.node;
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getStatusNode', error: e, stackTrace: st);
      return null;
    } catch (e, st) {
      _log.warn('RPC getStatusNode failed: $e $st');
      return null;
    }
  }

  /// Convenience helper to fetch node status via RPC.
  Future<RpcStatusResp?> getStatus({
    bool includeVrfDetails = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    _log.debug(
        'getStatus RPC call started (includeVrfDetails: $includeVrfDetails)');
    final r = _rpc;
    if (r == null) {
      stopwatch.stop();
      _log.debug(
          'getStatus failed: RPC client is null (${stopwatch.elapsedMilliseconds}ms)');
      return null;
    }

    // Call into FRB with defensive handling for panics / transport errors.
    RpcStatusResp? status;
    try {
      status = await r.status(
        includeVrfDetails: includeVrfDetails,
      );
      stopwatch.stop();
      _log.debug(
          'getStatus RPC completed successfully in ${stopwatch.elapsedMilliseconds}ms');
    } on PanicException catch (e, st) {
      stopwatch.stop();
      // FRB surfaced a Rust-side panic (e.g., stdout transport failure in process mode).
      _log.error(
          'FRB panic during getStatus after ${stopwatch.elapsedMilliseconds}ms',
          error: e,
          stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_getStatus');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      stopwatch.stop();
      // Any other error from the bridge/RPC call.
      _log.warn(
          'RPC getStatus failed after ${stopwatch.elapsedMilliseconds}ms: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_getStatus');
      return null;
    }
    // Log the response for debugging purposes as JSON.
    try {
      final peersList = status?.peers ?? const <RpcPeerInfo>[];
      final peers = peersList
          .map((p) => {
                'address': p.address,
                'connectingDetails': p.connectingDetails,
                'connectionStatus': (() {
                  try {
                    final dynamic cs = p.connectionStatus;
                    return (cs as dynamic).name ??
                        cs.toString().split('.').last;
                  } catch (_) {
                    return p.connectionStatus.toString();
                  }
                })(),
                'incoming': p.incoming,
                'peerId': p.peerId.toString(),
                'time': p.time.toString(),
                'bestTip': p.bestTip?.toString(),
                'bestTipHeight': p.bestTipHeight,
                'bestTipGlobalSlot': p.bestTipGlobalSlot,
                'bestTipTimestamp': p.bestTipTimestamp?.toString(),
              })
          .toList();

      // Build blockchain data for logging
      Map<String, dynamic>? blockchainData;
      final blockchain = status?.blockchain;
      if (blockchain != null) {
        try {
          final bestTip = blockchain.bestTip;
          final syncBlocks = blockchain.sync.blocks;

          blockchainData = {
            'best_tip': {
              'hash': bestTip.hash.toString(),
              'height': bestTip.height,
              'global_slot': bestTip.globalSlot,
              'epoch': bestTip.epoch,
              'producer_pubkey': bestTip.producerPubkey.toString(),
              'transactions': bestTip.transactions.toString(),
              'batches': bestTip.batches
                  .map((b) => {
                        'transactions': b.transactions.toString(),
                      })
                  .toList(),
            },
            'sync': {
              'blocks': syncBlocks != null
                  ? {
                      'best_tip': {
                        'hash': syncBlocks.bestTip.hash.toString(),
                        'height': syncBlocks.bestTip.height,
                        'global_slot': syncBlocks.bestTip.globalSlot,
                        'epoch': syncBlocks.bestTip.epoch,
                        'producer_pubkey':
                            syncBlocks.bestTip.producerPubkey.toString(),
                        'transactions':
                            syncBlocks.bestTip.transactions.toString(),
                        'batches': syncBlocks.bestTip.batches
                            .map((b) => {
                                  'transactions': b.transactions.toString(),
                                })
                            .toList(),
                      },
                      'fetch_progress': {
                        'idle': syncBlocks.fetchProgress.idle.toString(),
                        'pending': syncBlocks.fetchProgress.pending.toString(),
                        'done': syncBlocks.fetchProgress.done.toString(),
                      },
                      'apply_progress': {
                        'idle': syncBlocks.applyProgress.idle.toString(),
                        'pending': syncBlocks.applyProgress.pending.toString(),
                        'done': syncBlocks.applyProgress.done.toString(),
                      },
                    }
                  : null,
            },
          };
        } catch (e) {
          blockchainData = {'error': 'Failed to parse blockchain data: $e'};
        }
      }

      final fullResponse = {
        'peers': peers,
        if (blockchainData != null) 'blockchain': blockchainData,
      };
      final json = jsonEncode(fullResponse);
      _log.trace('getStatus response: $json');

      // Build summarized fields
      int connected = 0, connecting = 0, disconnected = 0, disconnecting = 0;
      int incoming = 0;
      for (final p in peersList) {
        String name;
        try {
          final dynamic cs = p.connectionStatus;
          name = (cs as dynamic).name ?? cs.toString().split('.').last;
        } catch (_) {
          name = p.connectionStatus.toString().split('.').last;
        }
        switch (name) {
          case 'connected':
            connected++;
            break;
          case 'connecting':
            connecting++;
            break;
          case 'disconnected':
            disconnected++;
            break;
          case 'disconnecting':
            disconnecting++;
            break;
        }
        if (p.incoming == true) incoming++;
      }
      final peerCount = peersList.length;
      final outgoing = peerCount - incoming;

      // Log successful RPC operation
      _log.debug('getStatus ok', context: {
        'peerCount': peerCount,
        'connected': connected,
        'connecting': connecting,
        'disconnected': disconnected,
        'disconnecting': disconnecting,
        'incoming': incoming,
        'outgoing': outgoing,
      });
    } catch (e, st) {
      LoggingService.instance
          .warn('Failed to encode getStatus to JSON: $e\$st');
      // Report handled error to Sentry with context
      await SentryUtil.captureError(e, st, tag: 'getStatus');
    }
    return status;
  }

  /// Fetch block producer and VRF evaluator status via RPC.
  Future<RpcBlockProducerStatusResp?> getBlockProducerStatus({
    bool includeVrfDetails = true,
  }) async {
    _log.trace('getBlockProducerStatus called');
    final r = _rpc;
    if (r == null) return null;

    RpcBlockProducerStatusResp? status;
    try {
      status = await r.blockProducerStatus(
        includeVrfDetails: includeVrfDetails,
      );
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getBlockProducerStatus',
          error: e, stackTrace: st);
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st,
          tag: 'frb_panic_getBlockProducerStatus');
      return null;
    } catch (e, st) {
      _log.warn('RPC getBlockProducerStatus failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_getBlockProducerStatus');
      return null;
    }
    return status;
  }

  /// Convenience helper to fetch blockchain blocks via RPC.
  Future<RpcListBlockchainResp?> listBlockchain({
    int? limit,
    bool? fromTip,
    int? epoch,
    AccountPublicKey? blockProducer,
  }) async {
    final stopwatch = Stopwatch()..start();
    _log.debug(
        'listBlockchain RPC call started (limit: $limit, fromTip: $fromTip, epoch: $epoch)');
    final r = _rpc;
    if (r == null) {
      stopwatch.stop();
      _log.debug(
          'listBlockchain failed: RPC client is null (${stopwatch.elapsedMilliseconds}ms)');
      return null;
    }

    // Call into FRB with defensive handling for panics / transport errors.
    RpcListBlockchainResp? blockchain;
    try {
      blockchain = await r.listBlockchain(
        limit: limit,
        fromTip: fromTip,
        epoch: epoch,
        blockProducer: blockProducer,
      );
      stopwatch.stop();
      _log.debug(
          'listBlockchain RPC completed successfully in ${stopwatch.elapsedMilliseconds}ms');
    } on PanicException catch (e, st) {
      stopwatch.stop();
      // FRB surfaced a Rust-side panic.
      _log.error(
          'FRB panic during listBlockchain after ${stopwatch.elapsedMilliseconds}ms',
          error: e,
          stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_listBlockchain');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      stopwatch.stop();
      // Any other error from the bridge/RPC call.
      _log.warn(
          'RPC listBlockchain failed after ${stopwatch.elapsedMilliseconds}ms: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_listBlockchain');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final totalBlocks = blockchain?.totalBlocks ?? BigInt.zero;
      final itemsCount = blockchain?.items.length ?? 0;

      // Build detailed block list
      final blocks = blockchain?.items.map((block) {
            try {
              return {
                'height': block.height,
                'epoch': block.epoch,
                'globalSlot': block.globalSlot,
                'hash': block.hash.toString(),
                'producerPubkey': block.producerPubkey.toString(),
                'batches': block.batches.length,
                'batchTransactions': block.batches
                    .map((b) => b.transactions.toString())
                    .toList(),
              };
            } catch (e) {
              return {'error': 'Failed to parse block: $e'};
            }
          }).toList() ??
          [];

      final fullResponse = {
        'totalBlocks': totalBlocks.toString(),
        'itemsCount': itemsCount,
        'blocks': blocks,
        if (blockchain?.rootHash != null)
          'rootHash': blockchain!.rootHash.toString(),
        if (blockchain?.tipHash != null)
          'tipHash': blockchain!.tipHash.toString(),
        if (blockchain == null) 'nullBlockchain': true,
      };

      final json = jsonEncode(fullResponse);
      _log.debug('listBlockchain response: $json');

      // Log successful RPC operation
      _log.debug(
        'listBlockchain ok',
        context: {
          'totalBlocks': totalBlocks.toString(),
          'itemsCount': itemsCount,
        },
      );
    } catch (e, st) {
      LoggingService.instance
          .warn('Failed to log listBlockchain response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'listBlockchain_logging');
    }
    return blockchain;
  }

  /// Convenience helper to fetch mempool transactions via RPC.
  Future<RpcListMempoolResp?> listMempool({
    PublicKeyHash? owner,
    int? limit,
    bool? idsOnly,
    TransactionHash? cursorAfter,
  }) async {
    final stopwatch = Stopwatch()..start();
    _log.debug(
        'listMempool RPC call started (limit: $limit, idsOnly: $idsOnly)');
    final r = _rpc;
    if (r == null) {
      stopwatch.stop();
      _log.debug(
          'listMempool failed: RPC client is null (${stopwatch.elapsedMilliseconds}ms)');
      return null;
    }

    // Call into FRB with defensive handling for panics / transport errors.
    RpcListMempoolResp? mempool;
    try {
      mempool = await r.listMempool(
        owner: owner,
        limit: limit,
        idsOnly: idsOnly,
        cursorAfter: cursorAfter,
      );
      stopwatch.stop();
      _log.debug(
          'listMempool RPC completed successfully in ${stopwatch.elapsedMilliseconds}ms');
    } on PanicException catch (e, st) {
      stopwatch.stop();
      // FRB surfaced a Rust-side panic.
      _log.error(
          'FRB panic during listMempool after ${stopwatch.elapsedMilliseconds}ms',
          error: e,
          stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      stopwatch.stop();
      // Any other error from the bridge/RPC call.
      _log.warn(
          'RPC listMempool failed after ${stopwatch.elapsedMilliseconds}ms: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_listMempool');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final count = mempool?.count ?? BigInt.zero;
      final orphans = mempool?.orphans ?? BigInt.zero;
      final totalSize = mempool?.totalSize ?? BigInt.zero;
      final entriesCount = mempool?.entries.length ?? 0;

      // Build detailed transaction list
      final transactions = mempool?.entries
              .map((tx) => {
                    'id': tx.id.toString(),
                    'fee': tx.fee.toString(),
                    'inputs': tx.inputs.length,
                    'outputs': tx.outputs.length,
                    'sizeBytes': tx.sizeBytes,
                  })
              .toList() ??
          [];

      final fullResponse = {
        'count': count.toString(),
        'orphans': orphans.toString(),
        'totalSize': totalSize.toString(),
        'entriesCount': entriesCount,
        'transactions': transactions,
        if (mempool == null) 'nullMempool': true,
      };

      final json = jsonEncode(fullResponse);
      _log.trace('listMempool response: $json');

      // Log successful RPC operation
      _log.debug(
        'listMempool ok',
        context: {
          'count': count.toString(),
          'orphans': orphans.toString(),
          'totalSize': totalSize.toString(),
          'entriesCount': entriesCount,
        },
      );
    } catch (e, st) {
      _log.warn('Failed to log listMempool response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'listMempool_logging');
    }
    return mempool;
  }

  /// Convenience helper to fetch epoch rewards via RPC.
  Future<RpcEpochRewardsResp?> epochRewards({
    int? epoch,
  }) async {
    _log.trace('epochRewards called with params: epoch=$epoch');
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcEpochRewardsResp? rewards;
    try {
      rewards = await r.epochRewards(
        epoch: epoch,
        includeWonSlots: true,
      );
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic.
      _log.error('FRB panic during epochRewards', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_epochRewards');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      _log.warn('RPC epochRewards failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_epochRewards');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final epochNum = rewards?.epoch;
      final rewardPerBlock = rewards?.rewardPerBlock ?? BigInt.zero;
      final producedInEpoch = rewards?.producedInEpoch ?? 0;
      final winsInEpoch = rewards?.winsInEpoch ?? 0;
      final earnedSoFar = rewards?.earnedSoFar ?? BigInt.zero;
      final expectedTotal = rewards?.expectedTotal ?? BigInt.zero;
      final producerPubkey = rewards?.producerPubkey?.toString();
      final wonSlots = rewards?.wonSlots;

      // Build detailed won slots list
      final wonSlotsList = wonSlots?.map((slot) {
        try {
          return {
            'globalSlot': slot.globalSlot,
            'expectedTimeMs': slot.expectedTimeMs.toString(),
          };
        } catch (e) {
          return {'error': 'Failed to parse slot: $e'};
        }
      }).toList();

      final fullResponse = {
        'epoch': epochNum,
        'rewardPerBlock': rewardPerBlock.toString(),
        'producedInEpoch': producedInEpoch,
        'winsInEpoch': winsInEpoch,
        'earnedSoFar': earnedSoFar.toString(),
        'expectedTotal': expectedTotal.toString(),
        if (producerPubkey != null) 'producerPubkey': producerPubkey,
        if (wonSlots != null) 'wonSlots': wonSlotsList,
        'wonSlotsCount': wonSlots?.length ?? 0,
        'wonSlotsIsNull': wonSlots == null,
        if (rewards == null) 'nullRewards': true,
      };

      final json = jsonEncode(fullResponse);
      _log.debug('epochRewards response: $json');

      // Log successful RPC operation
      _log.debug(
        'epochRewards ok',
        context: {
          'epoch': epochNum,
          'producedInEpoch': producedInEpoch,
          'winsInEpoch': winsInEpoch,
        },
      );
    } catch (e, st) {
      _log.warn('Failed to log epochRewards response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'epochRewards_logging');
    }
    return rewards;
  }

  /// Convenience helper to fetch UTXOs by owner via RPC.
  Future<RpcListUtxosByOwnerResp?> listUtxosByOwner({
    required PublicKeyHash owner,
    int? limit,
  }) async {
    _log.trace(
      'listUtxosByOwner called with params: owner=[PublicKeyHash], limit=$limit',
    );
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcListUtxosByOwnerResp? utxos;
    try {
      utxos = await r.listUtxosByOwner(
        owner: owner,
        limit: limit,
      );
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic.
      _log.error('FRB panic during listUtxosByOwner', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_listUtxosByOwner');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      _log.warn('RPC listUtxosByOwner failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_listUtxosByOwner');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final itemsCount = utxos?.items.length ?? 0;

      _log.trace(
        'listUtxosByOwner response: itemsCount=$itemsCount',
      );

      // Log successful RPC operation
      _log.debug(
        'listUtxosByOwner ok',
        context: {
          'itemsCount': itemsCount,
        },
      );
    } catch (e, st) {
      _log.warn('Failed to log listUtxosByOwner response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'listUtxosByOwner_logging');
    }
    return utxos;
  }

  /// Convenience helper to transfer funds via RPC.
  Future<RpcTransferFundsResp?> transferFunds({
    required PublicKeyHash fromPkHash,
    required BigInt amount,
    required PublicKeyHash toPkHash,
  }) async {
    _log.trace(
      'transferFunds called with params: fromPkHash=[PublicKeyHash], amount=$amount, toPkHash=[PublicKeyHash]',
    );
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcTransferFundsResp? response;
    try {
      response = await r.transferFunds(
        fromPkHash: fromPkHash,
        amount: amount,
        toPkHash: toPkHash,
      );
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic.
      _log.error('FRB panic during transferFunds', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_transferFunds');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      _log.warn('RPC transferFunds failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_transferFunds');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final queued = response?.queued ?? false;
      final error = response?.error;

      _log.trace(
        'transferFunds response: queued=$queued, error=$error',
      );

      // Log successful RPC operation
      _log.debug(
        'transferFunds ${queued ? 'queued' : 'failed'}',
        context: {
          'queued': queued,
          if (error != null) 'error': error,
        },
      );
    } catch (e, st) {
      _log.warn('Failed to log transferFunds response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'transferFunds_logging');
    }

    return response;
  }

  /// Query backend for epoch information with VRF status awareness
  ///
  /// This method combines status and epochRewards calls to provide comprehensive
  /// epoch information including VRF calculation status (inferred from response).
  ///
  /// Returns null if backend is unavailable or calls fail.
  Future<BackendRPCResponse?> getEpochInfo({int? epoch}) async {
    try {
      // First, get current blockchain status to determine current slot
      final status = await getStatus();
      if (status?.blockchain == null) {
        _log.warn('Cannot get epoch info: blockchain status unavailable');
        return null;
      }

      // Use backend-provided current global slot
      final currentSlot = status!.node.curGlobalSlot;
      if (currentSlot == null) {
        _log.warn('Cannot get epoch info: curGlobalSlot unavailable');
        return null;
      }

      // Query epoch rewards with won slots
      final epochRewardsResp = await epochRewards(epoch: epoch);
      if (epochRewardsResp == null) {
        _log.warn('Cannot get epoch info: epoch rewards unavailable');
        return null;
      }

      // Get block producer status for VRF info
      final bpStatus = await getBlockProducerStatus();

      // Create enhanced response with actual VRF status from backend
      final response = BackendRPCResponse.fromEpochRewards(
        epochRewardsResp,
        currentSlot: currentSlot,
        blockProducerStatus: bpStatus,
      );

      _log.trace(
        'getEpochInfo: ${response.toString()}',
      );

      return response;
    } catch (e, st) {
      _log.error(
        'Error getting epoch info: $e',
        error: e,
        stackTrace: st,
      );
      await SentryUtil.captureError(e, st, tag: 'getEpochInfo');
      return null;
    }
  }

  /// Convenience helper to fetch epochs with slot data via RPC.
  Future<RpcEpochsWithDataResp?> getEpochsWithData() async {
    _log.trace('getEpochsWithData called');
    final r = _rpc;
    if (r == null) return null;

    RpcEpochsWithDataResp? response;
    try {
      response = await r.epochsWithData();
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getEpochsWithData',
          error: e, stackTrace: st);
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_getEpochsWithData');
      return null;
    } catch (e, st) {
      _log.warn('RPC getEpochsWithData failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_getEpochsWithData');
      return null;
    }

    try {
      final epochsCount = response?.epochs.length ?? 0;
      _log.trace('getEpochsWithData response: epochsCount=$epochsCount');

      _log.debug(
        'getEpochsWithData ok',
        context: {'epochsCount': epochsCount},
      );
    } catch (e, st) {
      _log.warn('Failed to log getEpochsWithData response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'getEpochsWithData_logging');
    }
    return response;
  }

  /// Convenience helper to fetch epoch slot results via RPC.
  Future<RpcEpochSlotResultsResp?> getEpochSlotResults({
    required int epoch,
  }) async {
    _log.trace('getEpochSlotResults called with params: epoch=$epoch');
    final r = _rpc;
    if (r == null) return null;

    RpcEpochSlotResultsResp? response;
    try {
      response = await r.epochSlotResults(epoch: epoch);
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getEpochSlotResults',
          error: e, stackTrace: st);
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st,
          tag: 'frb_panic_getEpochSlotResults');
      return null;
    } catch (e, st) {
      _log.warn('RPC getEpochSlotResults failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_getEpochSlotResults');
      return null;
    }

    try {
      final resultsCount = response?.results.length ?? 0;
      _log.trace(
        'getEpochSlotResults response: epoch=${response?.epoch}, resultsCount=$resultsCount',
      );

      _log.debug(
        'getEpochSlotResults ok',
        context: {'epoch': response?.epoch, 'resultsCount': resultsCount},
      );
    } catch (e, st) {
      _log.warn('Failed to log getEpochSlotResults response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'getEpochSlotResults_logging');
    }
    return response;
  }

  /// Convenience helper to fetch slot time via RPC.
  Future<RpcSlotTimeResp?> getSlotTime({
    required int epoch,
    required int slot,
  }) async {
    _log.trace('getSlotTime called with params: epoch=$epoch, slot=$slot');
    final r = _rpc;
    if (r == null) return null;

    RpcSlotTimeResp? response;
    try {
      response = await r.slotTime(epoch: epoch, slot: slot);
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getSlotTime', error: e, stackTrace: st);
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_getSlotTime');
      return null;
    } catch (e, st) {
      _log.warn('RPC getSlotTime failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_getSlotTime');
      return null;
    }

    try {
      _log.trace(
        'getSlotTime response: epoch=${response?.epoch}, slot=${response?.slot}, timestampMs=${response?.timestampMs}',
      );

      // _log.debug(
      //   'getSlotTime ok',
      //   context: {
      //     'epoch': response?.epoch,
      //     'slot': response?.slot,
      //     'hasTimestamp': response?.timestampMs != null,
      //   },
      // );
    } catch (e, st) {
      _log.warn('Failed to log getSlotTime response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'getSlotTime_logging');
    }
    return response;
  }

  /// Convenience helper to fetch produced block metadata via RPC.
  Future<RpcProducedBlockMetadataResp?> getProducedBlockMetadata({
    required int epoch,
    required int slot,
  }) async {
    _log.trace(
        'getProducedBlockMetadata called with params: epoch=$epoch, slot=$slot');
    final r = _rpc;
    if (r == null) return null;

    RpcProducedBlockMetadataResp? response;
    try {
      response = await r.producedBlockMetadata(epoch: epoch, slot: slot);
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getProducedBlockMetadata',
          error: e, stackTrace: st);
      _nodeRunning = false;
      _rpc = null;
      _control = null;
      await SentryUtil.captureError(e, st,
          tag: 'frb_panic_getProducedBlockMetadata');
      return null;
    } catch (e, st) {
      _log.warn('RPC getProducedBlockMetadata failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_getProducedBlockMetadata');
      return null;
    }

    try {
      final metadata = response?.metadata;
      _log.trace(
        'getProducedBlockMetadata response: epoch=${response?.epoch}, slot=${response?.slot}, hasMetadata=${metadata != null}',
      );

      _log.debug(
        'getProducedBlockMetadata ok',
        context: {
          'epoch': response?.epoch,
          'slot': response?.slot,
          'hasMetadata': metadata != null,
          if (metadata != null) 'canonical': metadata.canonical,
        },
      );
    } catch (e, st) {
      _log.warn('Failed to log getProducedBlockMetadata response: $e\$st');
      await SentryUtil.captureError(e, st,
          tag: 'getProducedBlockMetadata_logging');
    }
    return response;
  }

  /// Get genesis timestamp from genesis JSON file.
  /// Returns cached value if available, otherwise fetches from URL.
  Future<int?> getGenesisTimestamp() async {
    if (_cachedGenesisTimestamp != null) {
      return _cachedGenesisTimestamp!;
    }

    try {
      final networkType = await _getSelectedNetwork();
      final String genesisUrl;

      switch (networkType) {
        case NetworkType.testnet:
          genesisUrl = AppConfig.testnetGenesisUrl;
        case NetworkType.internal:
          genesisUrl = AppConfig.internalGenesisUrl;
        case NetworkType.custom:
          genesisUrl = AppConfig.customGenesisUrl;
      }

      _log.debug('Fetching genesis timestamp from: $genesisUrl');

      final response = await http.get(Uri.parse(genesisUrl));
      if (response.statusCode != 200) {
        _log.error('Failed to fetch genesis file: HTTP ${response.statusCode}');
        return null;
      }

      final genesisJson = jsonDecode(response.body) as Map<String, dynamic>;
      final timestampStr = genesisJson['timestamp'] as String?;

      if (timestampStr == null) {
        _log.error('Genesis file does not contain timestamp field');
        return null;
      }

      // Parse ISO 8601 timestamp and convert to milliseconds
      final timestamp = DateTime.parse(timestampStr);
      _cachedGenesisTimestamp = timestamp.millisecondsSinceEpoch;

      _log.info(
          'Genesis timestamp cached: ${timestamp.toIso8601String()} (${_cachedGenesisTimestamp}ms)');
      return _cachedGenesisTimestamp!;
    } catch (e, st) {
      _log.error('Failed to get genesis timestamp', error: e, stackTrace: st);
      await SentryUtil.captureError(e, st, tag: 'getGenesisTimestamp');
      return null;
    }
  }

  /// Dispose bridge resources when the app is exiting.
  void dispose() {
    _log.info('Service disposed');
    if (!AndroidForegroundTaskController.instance.isWakelockHeldSync()) {
      RustBackendService.instance.pauseNode();
    }
    _nodeRunning = false;
    _rpc = null;
    _control = null;
    _cachedGenesisTimestamp = null;
  }
}
