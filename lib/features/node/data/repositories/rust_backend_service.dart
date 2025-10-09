import 'dart:io' show Platform;
import 'dart:convert';

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/transfer_funds.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/third_party/usernode_core/account.dart';
import 'package:crypto_mobile_app/src/rust/third_party/usernode_core/transaction.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/node.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

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
    Log.i('RUST', 'Init FRB');
    try {
      await RustLib.init(
        externalLibrary: Platform.isIOS
            ? ExternalLibrary.process(iKnowHowToUseIt: true)
            : null,
      );
      _initialized = true;
      Log.i('RUST', 'Init complete');
      SentryUtil.addBreadcrumb(
          category: 'backend', message: 'FRB init complete');
    } on PanicException catch (e, st) {
      final msg = e.toString();
      // Handle duplicate tracing subscriber setup from Rust side gracefully
      if (msg.contains('SetGlobalDefaultError') ||
          msg.contains(
              'global default trace dispatcher has already been set')) {
        Log.w('RUST',
            'Tracing subscriber already set in Rust; continuing initialization');
        _initialized = true; // library loaded; only tracing init failed
        SentryUtil.addBreadcrumb(
          category: 'backend',
          message: 'FRB init: tracing already set; ignored',
        );
      } else {
        Log.e('RUST', 'FRB init failed', e, st);
        rethrow;
      }
    }
  }

  /// Build and start the Rust node, then expose an RPC client.
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<void> startNode({int? httpPort}) async {
    if (!_initialized) {
      await init();
    }
    if (_nodeRunning) return;
    Log.i('RUST', 'Starting node${httpPort != null ? ' on $httpPort' : ''}');
    SentryUtil.addBreadcrumb(
      category: 'backend',
      message: 'Starting node',
      data: {'httpPort': httpPort},
    );

    final builder = NodeBuilder();
    if (httpPort != null) {
      builder.httpServer(port: httpPort);
    }

    builder.enableBlockProducer();
    builder.mempoolAutoinsertInterval(secs: BigInt.from(1));

    _node = builder.build();
    _rpc = _node!.rpc();

    // Run the node in a background thread.
    _node!.runForeverInNewThread();
    _nodeRunning = true;
    Log.i('RUST', 'Node started');
    await SentryUtil.captureMessage('Node started');
  }

  Future<void> stopNode() async {
    if (!_initialized && !_nodeRunning) return;
    // Currently frb-generated API does not expose a graceful shutdown; dispose bridge.
    Log.w('RUST', 'Stopping node (dropping references; FRB stays initialized)');
    SentryUtil.addBreadcrumb(category: 'backend', message: 'Stopping node');
    _nodeRunning = false;
    _node = null;
    _rpc = null;
  }

  /// Start node if there is an active account; otherwise do nothing.
  Future<bool> startForActiveAccount() async {
    Log.d('RUST', 'startForActiveAccount begin');
    SentryUtil.addBreadcrumb(
        category: 'backend', message: 'startForActiveAccount begin');
    final repo = await AccountsRepository.create();
    final hasAny = await repo.hasAny();
    if (!hasAny) {
      SentryUtil.addBreadcrumb(
          category: 'backend', message: 'no accounts; skipping start');
      return false;
    }
    if (!_initialized) {
      await init();
    }
    if (_nodeRunning) return true;
    await startNode();
    Log.d('RUST', 'startForActiveAccount done');
    await SentryUtil.captureMessage('Backend started for active account');
    return true;
  }

  /// Restart node using current active account context.
  Future<void> restartForActiveAccount() async {
    Log.i('RUST', 'Restarting node for active account');
    SentryUtil.addBreadcrumb(
        category: 'backend', message: 'restartForActiveAccount');
    await stopNode();
    await startForActiveAccount();
  }

  /// Obtain the RPC client for ad-hoc calls.
  NodeRpcClient? get rpc => _rpc;

  /// Convenience helper to fetch node status via RPC.
  Future<RpcStatusResp?> getStatus() async {
    Log.d('RUST', 'getStatus called');
    SentryUtil.addBreadcrumb(category: 'rpc', message: 'getStatus called');
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcStatusResp? status;
    try {
      status = await r.status();
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic (e.g., stdout transport failure in process mode).
      Log.e('RUST', 'FRB panic during getStatus', e, st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_getStatus');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      Log.w('RUST', 'RPC getStatus failed: $e\n$st');
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
      Log.d('RUST', 'getStatus response: $json');

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
      Log.w('RUST', 'Failed to encode getStatus to JSON: $e\n$st');
      // Report handled error to Sentry with context
      await SentryUtil.captureError(e, st, tag: 'getStatus');
    }
    Log.d('RUST', 'getStatus ok');
    return status;
  }

  /// Convenience helper to fetch blockchain blocks via RPC.
  Future<RpcListBlockchainResp?> listBlockchain({
    int? limit,
    bool? fromTip,
  }) async {
    Log.d('RUST', 'listBlockchain called');
    SentryUtil.addBreadcrumb(category: 'rpc', message: 'listBlockchain called');
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcListBlockchainResp? blockchain;
    try {
      blockchain = await r.listBlockchain(
        limit: limit,
        fromTip: fromTip,
      );
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic.
      Log.e('RUST', 'FRB panic during listBlockchain', e, st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_listBlockchain');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      Log.w('RUST', 'RPC listBlockchain failed: $e\n$st');
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
            'batches': block.batches.length,
          };
        } catch (e) {
          return {'error': 'Failed to parse block: $e'};
        }
      }).toList() ?? [];

      final fullResponse = {
        'totalBlocks': totalBlocks.toString(),
        'itemsCount': itemsCount,
        'blocks': blocks,
        if (blockchain?.rootHash != null) 'rootHash': blockchain!.rootHash.toString(),
        if (blockchain?.tipHash != null) 'tipHash': blockchain!.tipHash.toString(),
        if (blockchain == null) 'nullBlockchain': true,
      };

      final json = jsonEncode(fullResponse);
      Log.d('RUST', 'listBlockchain response: $json');

      await SentryUtil.captureMessageWithData('rpc.listBlockchain', {
        'totalBlocks': totalBlocks.toString(),
        'itemsCount': itemsCount,
        if (blockchain == null) 'nullBlockchain': true,
      });

      SentryUtil.addBreadcrumb(
        category: 'rpc',
        message: 'listBlockchain ok',
        data: {
          'totalBlocks': totalBlocks.toString(),
          'itemsCount': itemsCount,
        },
      );
    } catch (e, st) {
      Log.w('RUST', 'Failed to log listBlockchain response: $e\n$st');
      await SentryUtil.captureError(e, st, tag: 'listBlockchain_logging');
    }

    Log.d('RUST', 'listBlockchain ok');
    return blockchain;
  }

  /// Convenience helper to fetch mempool transactions via RPC.
  Future<RpcListMempoolResp?> listMempool({
    PublicKeyHash? owner,
    int? limit,
    bool? idsOnly,
    TransactionHash? cursorAfter,
  }) async {
    Log.d('RUST', 'listMempool called');
    SentryUtil.addBreadcrumb(category: 'rpc', message: 'listMempool called');
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
      Log.e('RUST', 'FRB panic during listMempool', e, st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_listMempool');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      Log.w('RUST', 'RPC listMempool failed: $e\n$st');
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
      final transactions = mempool?.entries.map((tx) => {
        'id': tx.id.toString(),
        'fee': tx.fee.toString(),
        'inputs': tx.inputs.length,
        'outputs': tx.outputs.length,
        'sizeBytes': tx.sizeBytes,
      }).toList() ?? [];

      final fullResponse = {
        'count': count.toString(),
        'orphans': orphans.toString(),
        'totalSize': totalSize.toString(),
        'entriesCount': entriesCount,
        'transactions': transactions,
        if (mempool == null) 'nullMempool': true,
      };

      final json = jsonEncode(fullResponse);
      Log.d('RUST', 'listMempool response: $json');

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
      Log.w('RUST', 'Failed to log listMempool response: $e\n$st');
      await SentryUtil.captureError(e, st, tag: 'listMempool_logging');
    }

    Log.d('RUST', 'listMempool ok');
    return mempool;
  }

  /// Convenience helper to fetch epoch rewards via RPC.
  Future<RpcEpochRewardsResp?> epochRewards({
    int? epoch,
  }) async {
    Log.d('RUST', 'epochRewards called');
    SentryUtil.addBreadcrumb(category: 'rpc', message: 'epochRewards called');
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcEpochRewardsResp? rewards;
    try {
      rewards = await r.epochRewards(
        epoch: epoch,
      );
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic.
      Log.e('RUST', 'FRB panic during epochRewards', e, st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_epochRewards');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      Log.w('RUST', 'RPC epochRewards failed: $e\n$st');
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

      final fullResponse = {
        'epoch': epochNum,
        'rewardPerBlock': rewardPerBlock.toString(),
        'producedInEpoch': producedInEpoch,
        'winsInEpoch': winsInEpoch,
        'earnedSoFar': earnedSoFar.toString(),
        'expectedTotal': expectedTotal.toString(),
        if (producerPubkey != null) 'producerPubkey': producerPubkey,
        if (rewards == null) 'nullRewards': true,
      };

      final json = jsonEncode(fullResponse);
      Log.d('RUST', 'epochRewards response: $json');

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
      Log.w('RUST', 'Failed to log epochRewards response: $e\n$st');
      await SentryUtil.captureError(e, st, tag: 'epochRewards_logging');
    }

    Log.d('RUST', 'epochRewards ok');
    return rewards;
  }

  /// Convenience helper to fetch UTXOs by owner via RPC.
  Future<RpcListUtxosByOwnerResp?> listUtxosByOwner({
    required PublicKeyHash owner,
    int? limit,
  }) async {
    Log.d('RUST', 'listUtxosByOwner called');
    SentryUtil.addBreadcrumb(category: 'rpc', message: 'listUtxosByOwner called');
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
      Log.e('RUST', 'FRB panic during listUtxosByOwner', e, st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_listUtxosByOwner');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      Log.w('RUST', 'RPC listUtxosByOwner failed: $e\n$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_listUtxosByOwner');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final itemsCount = utxos?.items.length ?? 0;

      Log.d('RUST', 'listUtxosByOwner response: itemsCount=$itemsCount');

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
      Log.w('RUST', 'Failed to log listUtxosByOwner response: $e\n$st');
      await SentryUtil.captureError(e, st, tag: 'listUtxosByOwner_logging');
    }

    Log.d('RUST', 'listUtxosByOwner ok');
    return utxos;
  }

  /// Convenience helper to transfer funds via RPC.
  Future<RpcTransferFundsResp?> transferFunds({
    required PublicKeyHash fromPkHash,
    required BigInt amount,
    required PublicKeyHash toPkHash,
  }) async {
    Log.d('RUST', 'transferFunds called');
    SentryUtil.addBreadcrumb(category: 'rpc', message: 'transferFunds called');
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
      Log.e('RUST', 'FRB panic during transferFunds', e, st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_transferFunds');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      Log.w('RUST', 'RPC transferFunds failed: $e\n$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_transferFunds');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final queued = response?.queued ?? false;
      final error = response?.error;

      Log.d('RUST', 'transferFunds response: queued=$queued, error=$error');

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
      Log.w('RUST', 'Failed to log transferFunds response: $e\n$st');
      await SentryUtil.captureError(e, st, tag: 'transferFunds_logging');
    }

    Log.d('RUST', 'transferFunds ok');
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
