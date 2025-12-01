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
import 'package:crypto_mobile_app/features/wallet/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/node.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/models/backend_rpc_response.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final _log = LoggingService.instance.withTag(LogTag.rust);

/// A small façade around flutter_rust_bridge generated APIs.
/// Centralizes initialization and access to the Rust node / RPC.
class RustBackendService {
  RustBackendService._();
  static RustBackendService? _instance;
  static RustBackendService get instance =>
      _instance ??= RustBackendService._();

  bool _initialized = false;
  bool _nodeRunning = false;
  String? _instanceId;
  String? _cachedPeerId;

  Node? _node;
  NodeRpcClient? _rpc;
  bool get isRunning => _nodeRunning;
  String? get instanceId => _instanceId;
  void setInstanceId(String id) {
    _instanceId = id;
  }

  /// Initialize flutter_rust_bridge and load the dynamic library.
  /// Call once at app startup (before runApp).
  Future<void> init() async {
    if (_initialized) return;
    try {
      await RustLib.init(
        externalLibrary: Platform.isIOS || Platform.isMacOS
            ? ExternalLibrary.process(iKnowHowToUseIt: true)
            : null,
      );
      _initialized = true;
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
      } else {
        LoggingService.instance
            .error('FRB init failed', error: e, stackTrace: st);
        rethrow;
      }
    }
  }

  /// Start the node using the active account's private key.
  /// Returns true if started successfully, false if no account or error.
  /// Safe to call multiple times; subsequent calls return true if already running.
  Future<bool> startNode({int? httpPort}) async {
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
      SentryUtil.addBreadcrumb(
          category: 'backend', message: 'no accounts; skipping start');
      return false;
    }

    // Retrieve active account
    _log.debug('Retrieving active account...');
    final account = await repo.getActive();

    if (account == null) {
      _log.error('Failed to retrieve active account');
      await SentryUtil.captureMessage(
        'Node start failed: no active account found',
        level: SentryLevel.warning,
      );
      return false;
    }

    _log.debug('Active account: ${account.id} (${account.name})');

    // Get private key for active account
    _log.trace('Retrieving private key for account ${account.id}...');
    final privateKeyHex = await repo.getPrivateKey(account.id);

    if (privateKeyHex == null || privateKeyHex.isEmpty) {
      _log.error(
        'Cannot start node: private key unavailable for account ${account.id}',
      );
      await SentryUtil.captureMessage(
        'Node start failed: private key unavailable',
        level: SentryLevel.error,
      );
      return false;
    }

    // SECURITY: Only log key length, not value
    _log.trace('Private key retrieved (length: ${privateKeyHex.length})');

    // Start node
    try {
      _log.trace('Starting node${httpPort != null ? ' on $httpPort' : ''}');
      SentryUtil.addBreadcrumb(
        category: 'backend',
        message: 'Starting node',
        data: {'httpPort': httpPort},
      );

      final builder = NodeBuilder();
      if (httpPort != null) {
        builder.httpServer(port: httpPort);
      }

      _log.trace(
        'Configuring block producer with user private key (length: ${privateKeyHex.length})',
      );
      builder.blockProducerHex(skHex: privateKeyHex);
      builder.mempoolAutoinsertInterval(secs: BigInt.from(1));

      _node = builder.build();
      _rpc = _node!.rpc();

      // Cache peer ID once on startup (it doesn't change during node lifetime)
      try {
        _cachedPeerId = _node!.peerId().toString();
      } catch (e) {
        _log.warn('Failed to cache peer ID: $e');
        _cachedPeerId = null;
      }

      // Run the node in a background thread.
      _node!.runForeverInNewThread();
      _nodeRunning = true;

      _log.info('Node started with user account block producer');
      await SentryUtil.captureMessage(
          'Backend started for active account ${account.id}');
      return true;
    } catch (e, st) {
      _log.error('Failed to start node with account ${account.id}',
          error: e, stackTrace: st);
      await SentryUtil.captureError(e, st, tag: 'startNode');
      return false;
    }
  }

  Future<void> stopNode() async {
    if (!_initialized && !_nodeRunning) return;
    // Currently frb-generated API does not expose a graceful shutdown; dispose bridge.
    _log.warn(
      'Stopping node (dropping references; FRB stays initialized)',
    );
    SentryUtil.addBreadcrumb(category: 'backend', message: 'Stopping node');
    _nodeRunning = false;
    _node = null;
    _rpc = null;
    _cachedPeerId = null;
  }

  /// Restart node using current active account context.
  Future<void> restartNode() async {
    _log.info('Restarting node');
    SentryUtil.addBreadcrumb(category: 'backend', message: 'restartNode');
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
      _log.warn('RPC getStatusNode failed: $e\$st');
      return null;
    }
  }

  /// Convenience helper to fetch node status via RPC.
  Future<RpcStatusResp?> getStatus({
    bool includeVrfDetails = true,
  }) async {
    _log.trace('getStatus called');
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcStatusResp? status;
    try {
      status = await r.status(
        includeVrfDetails: includeVrfDetails,
      );
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic (e.g., stdout transport failure in process mode).
      _log.error('FRB panic during getStatus', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_getStatus');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      _log.warn('RPC getStatus failed: $e\$st');
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
              'producer_pubkey': bestTip.producerPubkey,
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
                        'producer_pubkey': syncBlocks.bestTip.producerPubkey,
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

      // Always send an event for observability; attach payload when enabled
      if (SentryUtil.logStatusPayload) {
        await SentryUtil.captureMessageWithAttachment(
          'rpc.getStatus',
          filename: 'getStatus.json',
          content: json,
          extras: {
            'peerCount': peerCount,
            'connected': connected,
            'connecting': connecting,
            'disconnected': disconnected,
            'disconnecting': disconnecting,
            'incoming': incoming,
            'outgoing': outgoing,
            if (status == null) 'nullStatus': true,
          },
        );
      } else {
        await SentryUtil.captureMessageWithData('rpc.getStatus', {
          'peerCount': peerCount,
          'connected': connected,
          'connecting': connecting,
          'disconnected': disconnected,
          'disconnecting': disconnecting,
          'incoming': incoming,
          'outgoing': outgoing,
          if (status == null) 'nullStatus': true,
        });
      }

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'getStatus ok',
        data: {
          'peerCount': peerCount,
          'connected': connected,
          'connecting': connecting,
          'disconnected': disconnected,
          'disconnecting': disconnecting,
        },
      );
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
    _log.trace(
      'listBlockchain called with params: limit=$limit, fromTip=$fromTip, epoch=$epoch, blockProducer=$blockProducer',
    );
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcListBlockchainResp? blockchain;
    try {
      blockchain = await r.listBlockchain(
        limit: limit,
        fromTip: fromTip,
        epoch: epoch,
        blockProducer: blockProducer,
      );
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic.
      _log.error('FRB panic during listBlockchain', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_listBlockchain');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance.warn('RPC listBlockchain failed: $e\$st');
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
                'producerPubkey': block.producerPubkey,
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
      LoggingService.instance.debug('listBlockchain response: $json');

      await SentryUtil.captureMessageWithData('rpc.listBlockchain', {
        'totalBlocks': totalBlocks.toString(),
        'itemsCount': itemsCount,
        if (blockchain == null) 'nullBlockchain': true,
      });

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'listBlockchain  ok',
        data: {
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
    _log.trace(
      'listMempool called with params: owner=${owner != null ? '[PublicKeyHash]' : 'null'}, limit=$limit, idsOnly=$idsOnly, cursorAfter=${cursorAfter != null ? '[TransactionHash]' : 'null'}',
    );
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcListMempoolResp? mempool;
    try {
      mempool = await r.listMempool(
        owner: owner,
        limit: limit,
        idsOnly: idsOnly,
        cursorAfter: cursorAfter,
      );
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic.
      _log.error('FRB panic during listMempool', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance.warn('RPC listMempool failed: $e\$st');
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

      await SentryUtil.captureMessageWithData('rpc.listMempool', {
        'count': count.toString(),
        'orphans': orphans.toString(),
        'totalSize': totalSize.toString(),
        'entriesCount': entriesCount,
        if (mempool == null) 'nullMempool': true,
      });

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'listMempool ok',
        data: {
          'count': count.toString(),
          'orphans': orphans.toString(),
          'totalSize': totalSize.toString(),
          'entriesCount': entriesCount,
        },
      );
    } catch (e, st) {
      LoggingService.instance
          .warn('Failed to log listMempool response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'listMempool_logging');
    }
    return mempool;
  }

  /// Convenience helper to fetch epoch rewards via RPC.
  Future<RpcEpochRewardsResp?> epochRewards({
    int? epoch,
  }) async {
    LoggingService.instance
        .trace('epochRewards called with params: epoch=$epoch');
    SentryUtil.addBreadcrumb(
      category: 'rpc',
      message: 'epochRewards called',
      data: {'epoch': epoch},
    );
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
      await SentryUtil.captureError(e, st, tag: 'frb_panic_epochRewards');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance.warn('RPC epochRewards failed: $e\$st');
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
      final producerPubkey = rewards?.producerPubkey;
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
      LoggingService.instance.debug('epochRewards response: $json');

      await SentryUtil.captureMessageWithData('rpc.epochRewards', {
        'epoch': epochNum,
        'rewardPerBlock': rewardPerBlock.toString(),
        'producedInEpoch': producedInEpoch,
        'winsInEpoch': winsInEpoch,
        'earnedSoFar': earnedSoFar.toString(),
        'expectedTotal': expectedTotal.toString(),
        if (rewards == null) 'nullRewards': true,
      });

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'epochRewards ok',
        data: {
          'epoch': epochNum,
          'producedInEpoch': producedInEpoch,
          'winsInEpoch': winsInEpoch,
        },
      );
    } catch (e, st) {
      LoggingService.instance
          .warn('Failed to log epochRewards response: $e\$st');
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
      await SentryUtil.captureError(e, st, tag: 'frb_panic_listUtxosByOwner');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance.warn('RPC listUtxosByOwner failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_listUtxosByOwner');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final itemsCount = utxos?.items.length ?? 0;

      _log.trace(
        'listUtxosByOwner response: itemsCount=$itemsCount',
      );

      // Avoid calling owner.toString() here since PublicKeyHash may be disposed
      await SentryUtil.captureMessageWithData('rpc.listUtxosByOwner', {
        'itemsCount': itemsCount,
        if (limit != null) 'limit': limit,
        if (utxos == null) 'nullUtxos': true,
      });

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'listUtxosByOwner ok',
        data: {
          'itemsCount': itemsCount,
        },
      );
    } catch (e, st) {
      LoggingService.instance
          .warn('Failed to log listUtxosByOwner response: $e\$st');
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
      await SentryUtil.captureError(e, st, tag: 'frb_panic_transferFunds');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance.warn('RPC transferFunds failed: $e\$st');
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

      await SentryUtil.captureMessageWithData('rpc.transferFunds', {
        'queued': queued,
        'fromPkHash': fromPkHash.toString(),
        'toPkHash': toPkHash.toString(),
        'amount': amount.toString(),
        if (error != null) 'error': error,
        if (response == null) 'nullResponse': true,
      });

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'transferFunds ${queued ? 'queued' : 'failed'}',
        data: {
          'queued': queued,
          if (error != null) 'error': error,
        },
      );
    } catch (e, st) {
      LoggingService.instance
          .warn('Failed to log transferFunds response: $e\$st');
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
        LoggingService.instance
            .warn('Cannot get epoch info: blockchain status unavailable');
        return null;
      }

      // Use backend-provided current global slot
      final currentSlot = status!.node.curGlobalSlot;
      if (currentSlot == null) {
        LoggingService.instance
            .warn('Cannot get epoch info: curGlobalSlot unavailable');
        return null;
      }

      // Query epoch rewards with won slots
      final epochRewardsResp = await epochRewards(epoch: epoch);
      if (epochRewardsResp == null) {
        LoggingService.instance
            .warn('Cannot get epoch info: epoch rewards unavailable');
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

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'getEpochsWithData ok',
        data: {'epochsCount': epochsCount},
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

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'getEpochSlotResults ok',
        data: {'epoch': response?.epoch, 'resultsCount': resultsCount},
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

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'getSlotTime ok',
        data: {
          'epoch': response?.epoch,
          'slot': response?.slot,
          'hasTimestamp': response?.timestampMs != null,
        },
      );
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

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'getProducedBlockMetadata ok',
        data: {
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

  /// Dispose bridge resources when the app is exiting.
  void dispose() {
    // Keep FRB initialized for app lifetime to avoid double-init errors.
    _nodeRunning = false;
    _node = null;
    _rpc = null;
  }
}
