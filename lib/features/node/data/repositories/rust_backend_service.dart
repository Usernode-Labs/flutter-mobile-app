import 'dart:io' show Platform, HttpServer, InternetAddress, ContentType;
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/transfer_funds.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
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
  bool _didAutoReconnect = false; // ensure we only auto-reconnect once

  Node? _node;
  NodeRpcClient? _rpc;
  bool get isRunning => _nodeRunning;
  String? get instanceId => _instanceId;
  void setInstanceId(String id) {
    _instanceId = id;
  }

  // Localnet-only hardcoded peers (matches tools/localnet/.env)
  // Used to avoid contacting any external peers during testing.
  static const String _kLocalnetSeedPeerId =
      '2cA8oHe9QNHcmobR4d1f1HHKwbJoS8Mbh9M8jTxoECXScqnvSK4';
  static const String _kLocalnetBatcher1PeerId =
      '2aV3E9dYkNGLQ6Jq7XiWWAWZndu6SNqgYh5nP3MSMr3fPbBAt2e';

  HttpServer? _peersServer;
  int? _peersPort;

  Future<String> _ensureLocalPeersServer() async {
    if (_peersServer == null) {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _peersServer = server;
      _peersPort = server.port;
      server.listen((req) async {
        try {
          if (req.uri.path == '/peers.txt') {
            final body = ('/$_kLocalnetSeedPeerId/http/127.0.0.1/39001\n'
                '/$_kLocalnetBatcher1PeerId/http/127.0.0.1/39002\n');
            req.response.headers.contentType = ContentType.text;
            req.response.write(body);
          } else {
            req.response.statusCode = 404;
          }
        } finally {
          await req.response.close();
        }
      });
    }
    return 'http://127.0.0.1:${_peersPort}/peers.txt';
  }

  /// Identity: HTTP helper to register identity (beta, mocked proof)
  Future<bool> registerIdentityHttp({
    required String baseUrl,
    required String uniqueIdHex,
    required String stakingPkHash,
    required String feePayer,
    int? fee,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/identity/register');
      final bodyMap = {
        'unique_id': uniqueIdHex,
        'staking_pk_hash': stakingPkHash,
        'fee_payer': feePayer,
        if (fee != null) 'fee': fee,
        'proof': base64Encode(utf8.encode('simulated-proof')),
      };
      final body = jsonEncode(bodyMap);
      LoggingService.instance.info(
          'POST /identity/register url=${uri.toString()} body=${bodyMap.toString()}',
          tag: 'RUST');
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'}, body: body);
      final ok = resp.statusCode == 200;
      String bodyOut;
      String? txId;
      try {
        final Map<String, dynamic> parsed = jsonDecode(resp.body);
        bodyOut = parsed.toString();
        txId = (parsed['tx_id'] as String?);
      } catch (_) {
        bodyOut = resp.body;
      }
      LoggingService.instance.info(
          'identity.register response status=${resp.statusCode} body=$bodyOut',
          tag: 'RUST');
      if (txId != null && txId!.isNotEmpty) {
        LoggingService.instance
            .info('identity.register tx_id=$txId', tag: 'RUST');
      }
      return ok;
    } catch (e, st) {
      LoggingService.instance.error('registerIdentityHttp failed',
          tag: 'RUST', error: e, stackTrace: st);
      return false;
    }
  }

  /// Identity: HTTP helper to fetch identity leaf by unique_id (hex)
  Future<Map<String, dynamic>?> identityGetHttp({
    required String baseUrl,
    required String uniqueIdHex,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/identity/get/$uniqueIdHex');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e, st) {
      LoggingService.instance.error('identityGetHttp failed',
          tag: 'RUST', error: e, stackTrace: st);
      return null;
    }
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
    // Important for private testing: run in seed mode so the node does not
    // auto-connect to hard-coded public peers. We will operate as an isolated
    // single-node network (or connect only to explicitly provided peers).
    // Do not mark as seed; we want to dial our provided peers only.
    // Disable peer discovery so the node does not attempt to connect
    // to any external/default peers beyond what we provide explicitly.
    builder.p2PNoDiscovery();
    if (httpPort != null) {
      builder.httpServer(port: httpPort);
    }

    // Do not enable batcher on the mobile app; it submits locally to its
    // own mempool and peers propagate to the host batcher.

    // Localnet-only peers/genesis: ALWAYS 127.0.0.1 for dev.
    // Gate on availability to avoid chain_id mismatches and stale peer lists.
    Future<String> _fetchWithRetry(String url, {int attempts = 20}) async {
      for (var i = 0; i < attempts; i++) {
        try {
          final resp = await http.get(Uri.parse(url));
          if (resp.statusCode == 200 && resp.body.isNotEmpty) {
            return resp.body;
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 500));
      }
      throw Exception('fetch failed: $url');
    }

    // Prefetch peers to ensure the file is present and non-empty
    // Point to local host peers list served by the node setup
    final peersUrl = 'http://127.0.0.1:8088/peers.txt';
    final peersTxt = await _fetchWithRetry(peersUrl);
    final peerLines = peersTxt
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList(growable: false);
    LoggingService.instance
        .debug('Peers from $peersUrl: ${peerLines.length}', tag: 'RUST');
    if (peerLines.isEmpty) {
      throw Exception('no peers in $peersUrl');
    }
    await builder.initialPeersFromUrl(url: peersUrl);

    // Fetch custom genesis and embed inline so chain_id matches host nodes
    final genesisBody =
        await _fetchWithRetry('http://127.0.0.1:8088/custom-genesis.json');
    builder.genesisJsonInline(json: genesisBody);
    LoggingService.instance
        .debug('Embedded localnet genesis (fetched)', tag: 'RUST');

    // Use a default dev signer (was present previously) for local testing.
    builder.blockProducerHex(
        skHex:
            "1c0f48a5fa846d5e1a7f490e71d3b7176be0d3d7150a89dfaf275ada470a5c13");
    builder.mempoolAutoinsertInterval(secs: BigInt.from(1));

    _node = builder.build();
    _rpc = _node!.rpc();

    // Run the node in a background thread.
    _node!.runForeverInNewThread();
    _nodeRunning = true;

    // Schedule a one-shot reconnect shortly after startup so that
    // (a) Android has granted INTERNET and (b) genesis/peers are in place.
    // This avoids lingering Disconnected peers on first boot.
    if (!_didAutoReconnect) {
      _didAutoReconnect = true;
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          LoggingService.instance
              .debug('Auto-reconnect after startup', tag: 'RUST');
          await restartForActiveAccount();
        } catch (e, st) {
          LoggingService.instance.error('Auto-reconnect failed',
              tag: 'RUST', error: e, stackTrace: st);
        }
      });
    }
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
    // Dev override: start backend even if no accounts exist, so localnet
    // connectivity can be verified without onboarding.
    if (!_initialized) {
      await init();
    }
    if (_nodeRunning) {
      LoggingService.instance.trace('Node already running', tag: 'RUST');
      return true;
    }
    // Enable HTTP server on a fixed local port for in-app HTTP RPC calls
    // used by identity beta testing UI. This is safe in dev and does not
    // expose external interfaces on mobile; it binds to localhost.
    await startNode(httpPort: 39000);
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
              })
          .toList(growable: false);

      Map<String, dynamic>? blockchainData;
      final bc = status?.blockchain;
      if (bc != null) {
        try {
          final tip = bc.bestTip;
          final syncBlocks = bc.sync.blocks;
          blockchainData = {
            'best_tip': {
              'hash': tip.hash,
              'height': tip.height,
              'global_slot': tip.globalSlot,
              'epoch': tip.epoch,
            },
            'sync': syncBlocks == null
                ? null
                : {
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
            if (lastReorgData != null) 'last_reorg': lastReorgData,
          };
        } catch (e) {
          mempoolData = {'error': 'Failed to parse mempool data: $e'};
        }
      }

      final out = {
        'peers': peers,
        if (blockchainData != null) 'blockchain': blockchainData,
        if (blockProducerData != null) 'block_producer': blockProducerData,
        if (mempoolData != null) 'mempool': mempoolData,
      };
      LoggingService.instance.info('[STATUS] ${jsonEncode(out)}', tag: 'RUST');
    } catch (e) {
      // ignore logging errors
    }
    return status;
  }

  // ---- Snapshot-parity RPC wrappers used by the UI controllers ----

  Future<RpcListMempoolResp?> listMempool({
    PublicKeyHash? owner,
    int? limit,
    bool? idsOnly,
    TransactionHash? cursorAfter,
  }) async {
    final r = _rpc;
    if (r == null) return null;
    return r.listMempool(
      owner: owner,
      limit: limit,
      idsOnly: idsOnly,
      cursorAfter: cursorAfter,
    );
  }

  Future<RpcListBlockchainResp?> listBlockchain({
    int? limit,
    bool? fromTip,
    int? epoch,
    AccountPublicKey? blockProducer,
  }) async {
    final r = _rpc;
    if (r == null) return null;
    return r.listBlockchain(
      limit: limit,
      fromTip: fromTip,
      epoch: epoch,
      blockProducer: blockProducer,
    );
  }

  Future<RpcEpochRewardsResp?> epochRewards(
      {int? epoch, bool? includeWonSlots}) async {
    final r = _rpc;
    if (r == null) return null;
    return r.epochRewards(epoch: epoch, includeWonSlots: includeWonSlots);
  }

  Future<RpcListUtxosByOwnerResp?> listUtxosByOwner({
    required PublicKeyHash owner,
    int? limit,
  }) async {
    final r = _rpc;
    if (r == null) return null;
    return r.listUtxosByOwner(owner: owner, limit: limit);
  }

  Future<RpcTransferFundsResp?> transferFunds({
    required PublicKeyHash fromPkHash,
    required BigInt amount,
    required PublicKeyHash toPkHash,
  }) async {
    final r = _rpc;
    if (r == null) return null;
    return r.transferFunds(
        fromPkHash: fromPkHash, amount: amount, toPkHash: toPkHash);
  }
}
