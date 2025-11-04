import 'dart:io' show Platform;
import 'dart:convert';

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/transfer_funds.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/node.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
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
        LoggingService.instance.warn(
            'Tracing subscriber already set in Rust; continuing initialization',
            tag: 'RUST');
        _initialized = true; // library loaded; only tracing init failed
      } else {
        LoggingService.instance
            .error('FRB init failed', tag: 'RUST', error: e, stackTrace: st);
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
    LoggingService.instance.trace(
        'Starting node${httpPort != null ? ' on $httpPort' : ''}',
        tag: 'RUST');
    SentryUtil.addBreadcrumb(
      category: 'backend',
      message: 'Starting node',
      data: {'httpPort': httpPort},
    );

    final builder = NodeBuilder();
    if (httpPort != null) {
      builder.httpServer(port: httpPort);
    }

    builder.blockProducerHex(
        skHex:
            "3b40aba2c6f3c53c26d5945e723525d8471d89d7e330e99b223d3e67f12a871e");
    builder.mempoolAutoinsertInterval(secs: BigInt.from(60));

    _node = builder.build();
    _rpc = _node!.rpc();

    // Run the node in a background thread.
    _node!.runForeverInNewThread();
    _nodeRunning = true;
  }

  Future<void> stopNode() async {
    if (!_initialized && !_nodeRunning) return;
    // Currently frb-generated API does not expose a graceful shutdown; dispose bridge.
    LoggingService.instance.warn(
        'Stopping node (dropping references; FRB stays initialized)',
        tag: 'RUST');
    SentryUtil.addBreadcrumb(category: 'backend', message: 'Stopping node');
    _nodeRunning = false;
    _node = null;
    _rpc = null;
  }

  /// Start node if there is an active account; otherwise do nothing.
  Future<bool> startForActiveAccount() async {
    final repo = await AccountsRepository.create();
    LoggingService.instance
        .trace('Checking if any accounts exist...', tag: 'RUST');
    final hasAny = await repo.hasAny();
    LoggingService.instance
        .trace('Account check result: hasAny = $hasAny', tag: 'RUST');
    if (!hasAny) {
      LoggingService.instance
          .trace('No accounts found - skipping node start', tag: 'RUST');
      SentryUtil.addBreadcrumb(
          category: 'backend', message: 'no accounts; skipping start');
      return false;
    }
    LoggingService.instance
        .debug('Account exists - proceeding with node start', tag: 'RUST');
    if (!_initialized) {
      await init();
    }
    if (_nodeRunning) {
      LoggingService.instance.trace('Node already running', tag: 'RUST');
      return true;
    }
    await startNode();
    LoggingService.instance.trace('startForActiveAccount done', tag: 'RUST');
    await SentryUtil.captureMessage('Backend started for active account');
    return true;
  }

  /// Restart node using current active account context.
  Future<void> restartForActiveAccount() async {
    LoggingService.instance
        .info('Restarting node for active account', tag: 'RUST');
    SentryUtil.addBreadcrumb(
        category: 'backend', message: 'restartForActiveAccount');
    await stopNode();
    await startForActiveAccount();
  }

  /// Obtain the RPC client for ad-hoc calls.
  NodeRpcClient? get rpc => _rpc;

  /// Convenience helper to fetch node status via RPC.
  Future<RpcStatusResp?> getStatus() async {
    final r = _rpc;
    if (r == null) return null;

    // Call into FRB with defensive handling for panics / transport errors.
    RpcStatusResp? status;
    try {
      status = await r.status();
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic (e.g., stdout transport failure in process mode).
      LoggingService.instance.error('FRB panic during getStatus',
          tag: 'RUST', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_getStatus');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance.warn('RPC getStatus failed: $e\$st', tag: 'RUST');
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

      // Build block producer data for logging
      Map<String, dynamic>? blockProducerData;
      final blockProducer = status?.blockProducer;
      if (blockProducer != null) {
        try {
          final statusData = blockProducer.status;
          Map<String, dynamic> statusMap = {
            'type': statusData.toString().split('(').first.split('.').last,
          };

          // Extract won slot info if available
          statusData.whenOrNull(
            wonSlotDiscarded: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            wonSlot: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            wonSlotWait: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            wonSlotProduceInit: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            batchesAssemblePending: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            batchesAssembleSuccess: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            dbDiffPending: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            dbDiffSuccess: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            stakeProofWait: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            signingPending: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            produced: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
            injected: (wonSlot) => statusMap['won_slot'] = {
              'global_slot': wonSlot.globalSlot,
              'slot_timestamp': wonSlot.slotTimestamp.toString(),
            },
          );

          blockProducerData = {
            'pub_key': blockProducer.pubKey.toString(),
            'status': statusMap,
          };
        } catch (e) {
          blockProducerData = {
            'error': 'Failed to parse block producer data: $e'
          };
        }
      }

      // Build mempool data for logging
      Map<String, dynamic>? mempoolData;
      final mempool = status?.mempool;
      if (mempool != null) {
        try {
          Map<String, dynamic>? lastReorgData;
          final lastReorg = mempool.lastReorg;
          if (lastReorg != null) {
            lastReorgData = {
              'root': lastReorg.root,
              'blocks_disconnected': lastReorg.blocksDisconnected,
              'blocks_connected': lastReorg.blocksConnected,
              'txs_readmitted_ok': lastReorg.txsReadmittedOk,
              'txs_readmitted_orphaned': lastReorg.txsReadmittedOrphaned,
              'txs_readmitted_conflict': lastReorg.txsReadmittedConflict,
              'connected_removed': lastReorg.connectedRemoved,
              'prepared_count': lastReorg.preparedCount,
              'plan_elapsed_ms': lastReorg.planElapsedMs?.toString(),
              'when': lastReorg.when.toString(),
              'in_progress': lastReorg.inProgress,
            };
          }

          mempoolData = {
            'entries': mempool.entries.toString(),
            'orphans': mempool.orphans.toString(),
            'total_size': mempool.totalSize.toString(),
            'unleased': mempool.unleased?.toString(),
            'leased_for_batcher': mempool.leasedForBatcher?.toString(),
            if (lastReorgData != null) 'last_reorg': lastReorgData,
          };
        } catch (e) {
          mempoolData = {'error': 'Failed to parse mempool data: $e'};
        }
      }

      final fullResponse = {
        'peers': peers,
        if (blockchainData != null) 'blockchain': blockchainData,
        if (blockProducerData != null) 'block_producer': blockProducerData,
        if (mempoolData != null) 'mempool': mempoolData,
      };
      final json = jsonEncode(fullResponse);
      LoggingService.instance.trace('getStatus response: $json', tag: 'RUST');

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
          .warn('Failed to encode getStatus to JSON: $e\$st', tag: 'RUST');
      // Report handled error to Sentry with context
      await SentryUtil.captureError(e, st, tag: 'getStatus');
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
    LoggingService.instance.trace(
        'listBlockchain called with params: limit=$limit, fromTip=$fromTip, epoch=$epoch, blockProducer=$blockProducer',
        tag: 'RUST');
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
      LoggingService.instance.error('FRB panic during listBlockchain',
          tag: 'RUST', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_listBlockchain');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance
          .warn('RPC listBlockchain failed: $e\$st', tag: 'RUST');
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
      LoggingService.instance
          .debug('listBlockchain response: $json', tag: 'RUST');

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
      LoggingService.instance
          .warn('Failed to log listBlockchain response: $e\$st', tag: 'RUST');
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
      LoggingService.instance.error('FRB panic during listMempool',
          tag: 'RUST', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance
          .warn('RPC listMempool failed: $e\$st', tag: 'RUST');
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
      LoggingService.instance.trace('listMempool response: $json', tag: 'RUST');

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
          .warn('Failed to log listMempool response: $e\$st', tag: 'RUST');
      await SentryUtil.captureError(e, st, tag: 'listMempool_logging');
    }
    return mempool;
  }

  /// Convenience helper to fetch epoch rewards via RPC.
  Future<RpcEpochRewardsResp?> epochRewards({
    int? epoch,
  }) async {
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
      LoggingService.instance.error('FRB panic during epochRewards',
          tag: 'RUST', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_epochRewards');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance
          .warn('RPC epochRewards failed: $e\$st', tag: 'RUST');
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
      LoggingService.instance
          .debug('epochRewards response: $json', tag: 'RUST');

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
          .warn('Failed to log epochRewards response: $e\$st', tag: 'RUST');
      await SentryUtil.captureError(e, st, tag: 'epochRewards_logging');
    }
    return rewards;
  }

  /// Convenience helper to fetch UTXOs by owner via RPC.
  Future<RpcListUtxosByOwnerResp?> listUtxosByOwner({
    required PublicKeyHash owner,
    int? limit,
  }) async {
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
      LoggingService.instance.error('FRB panic during listUtxosByOwner',
          tag: 'RUST', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_listUtxosByOwner');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance
          .warn('RPC listUtxosByOwner failed: $e\$st', tag: 'RUST');
      await SentryUtil.captureError(e, st, tag: 'rpc_listUtxosByOwner');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final itemsCount = utxos?.items.length ?? 0;

      LoggingService.instance.trace(
          'listUtxosByOwner response: itemsCount=$itemsCount',
          tag: 'RUST');

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
          .warn('Failed to log listUtxosByOwner response: $e\$st', tag: 'RUST');
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
      LoggingService.instance.error('FRB panic during transferFunds',
          tag: 'RUST', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _nodeRunning = false;
      _rpc = null;
      await SentryUtil.captureError(e, st, tag: 'frb_panic_transferFunds');
      // Return null gracefully so UI can keep rendering with an error message.
      return null;
    } catch (e, st) {
      // Any other error from the bridge/RPC call.
      LoggingService.instance
          .warn('RPC transferFunds failed: $e\$st', tag: 'RUST');
      await SentryUtil.captureError(e, st, tag: 'rpc_transferFunds');
      return null;
    }

    // Log the response for debugging purposes.
    try {
      final queued = response?.queued ?? false;
      final error = response?.error;

      LoggingService.instance.trace(
          'transferFunds response: queued=$queued, error=$error',
          tag: 'RUST');

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
          .warn('Failed to log transferFunds response: $e\$st', tag: 'RUST');
      await SentryUtil.captureError(e, st, tag: 'transferFunds_logging');
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
