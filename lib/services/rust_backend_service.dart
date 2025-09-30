import 'dart:io' show Platform;
import 'dart:convert';

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/services/accounts_repository.dart';
import 'package:crypto_mobile_app/utils/logger.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/node.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:crypto_mobile_app/utils/sentry.dart';

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

  int? _lastPeerCount;

  /// Initialize flutter_rust_bridge and load the dynamic library.
  /// Call once at app startup (before runApp).
  Future<void> init() async {
    if (_initialized) return;
    Log.i('RUST', 'Init FRB');
    await RustLib.init(
      externalLibrary: Platform.isIOS
          ? ExternalLibrary.process(iKnowHowToUseIt: true)
          : null,
    );
    _initialized = true;
    Log.i('RUST', 'Init complete');
    SentryUtil.addBreadcrumb(category: 'backend', message: 'FRB init complete');
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
    final status = await r.status();
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
              'batches': bestTip.batches.map((b) => {
                'transactions': b.transactions.toString(),
              }).toList(),
            },
            'sync': {
              'blocks': syncBlocks != null ? {
                'best_tip': {
                  'hash': syncBlocks.bestTip.hash.toString(),
                  'height': syncBlocks.bestTip.height,
                  'global_slot': syncBlocks.bestTip.globalSlot,
                  'epoch': syncBlocks.bestTip.epoch,
                  'batches': syncBlocks.bestTip.batches.map((b) => {
                    'transactions': b.transactions.toString(),
                  }).toList(),
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
              } : null,
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

  /// Dispose bridge resources when the app is exiting.
  void dispose() {
    // Keep FRB initialized for app lifetime to avoid double-init errors.
    _nodeRunning = false;
    _node = null;
    _rpc = null;
  }
}
