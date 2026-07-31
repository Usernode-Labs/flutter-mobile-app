import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/block_producer_status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/wallet.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/identity/wallet_identity_lease.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/wallet_tx.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' show enableLogging;
import 'package:crypto_mobile_app/src/rust/tracing.dart' show TracingLevel;
import 'package:crypto_mobile_app/src/rust/node.dart' show NodeControl;
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'package:crypto_mobile_app/src/rust/node/mobile.dart';
import 'package:crypto_mobile_app/src/rust/node/runtime.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/models/backend_rpc_response.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

final _log = LoggingService.instance.withTag('usernode/NodeService');
const _viewOnlyTransactionError =
    'Transactions are disabled in view-only mode.';

class _NodeStartRequest {
  const _NodeStartRequest({
    required this.authority,
    required this.httpPort,
    required this.freshRuntime,
  });

  final NodeStartAuthority authority;
  final int? httpPort;
  final bool freshRuntime;

  bool equivalentTo(_NodeStartRequest other) =>
      httpPort == other.httpPort &&
      freshRuntime == other.freshRuntime &&
      authority.sameRequestAuthorityAs(other.authority);
}

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
  _NodeStartRequest? _startNodeRequest;
  Future<void>? _stopNodeInFlight;
  int _startIntentGeneration = 0;
  bool _nodeRunning = false;
  bool _nodePaused = false;
  bool _pauseRequested = false;
  NodeRuntimeAuthority? _runtimeAuthority;
  int _runtimeGeneration = 0;
  String? _instanceId;
  String? _cachedPeerId;
  int? _cachedGenesisTimestamp;
  int? _nodeClockDriftMs;
  int? _lastNodeTimeMs;
  int? _lastNodeClockSampleSystemTimeMs;

  NodeControl? _control;
  NodeRpcClient? _rpc;
  NodeHandle? _nodeHandle;
  NodeHandle? _shutdownInFlightHandle;
  int? _shutdownInFlightGeneration;
  bool get isRunning => _nodeRunning;
  bool get isRuntimeActive => _nodeRunning && !_nodePaused;
  int get runtimeGeneration => _runtimeGeneration;
  String? get instanceId => _instanceId;
  int? get nodeClockDriftMs => _nodeClockDriftMs;
  int? get lastNodeTimeMs => _lastNodeTimeMs;
  int? get lastNodeClockSampleSystemTimeMs => _lastNodeClockSampleSystemTimeMs;
  void setInstanceId(String id) {
    _instanceId = id;
  }

  void _clearNodeClockDrift() {
    _nodeClockDriftMs = null;
    _lastNodeTimeMs = null;
    _lastNodeClockSampleSystemTimeMs = null;
  }

  void _updateNodeClockDriftFromStatus(
    RpcStatusResp? status, {
    required int requestStartedAtMs,
    required int responseReceivedAtMs,
  }) {
    final rustTimeMs = status?.node.timeMs.toInt();
    if (rustTimeMs == null) return;

    final requestLatencyMs = requestStartedAtMs <= responseReceivedAtMs
        ? responseReceivedAtMs - requestStartedAtMs
        : 0;
    final sampleSystemTimeMs = responseReceivedAtMs;
    final driftMs = sampleSystemTimeMs - rustTimeMs;

    _nodeClockDriftMs = driftMs;
    _lastNodeTimeMs = rustTimeMs;
    _lastNodeClockSampleSystemTimeMs = sampleSystemTimeMs;

    _log.debug('Updated node clock drift', context: {
      'rustTimeMs': rustTimeMs,
      'systemSampleTimeMs': sampleSystemTimeMs,
      'systemReceivedTimeMs': responseReceivedAtMs,
      'requestLatencyMs': requestLatencyMs,
      'driftMs': driftMs,
    });
  }

  Future<int?> ensureNodeClockDrift() async {
    if (_nodeClockDriftMs != null) return _nodeClockDriftMs;
    await getStatusNode();
    return _nodeClockDriftMs;
  }

  Future<int?> refreshNodeClockDriftMs() async {
    if (!_nodeRunning) return _nodeClockDriftMs;
    await getStatusNode();
    return _nodeClockDriftMs;
  }

  Future<int?> resolveNodeClockDriftMs({
    bool refresh = true,
  }) async {
    if (refresh) {
      final refreshed = await refreshNodeClockDriftMs();
      if (refreshed != null) return refreshed;
    }
    return _nodeClockDriftMs ?? await ensureNodeClockDrift();
  }

  Future<int?> resolveCurrentRustTimeMs() async {
    final clockDriftMs = await resolveNodeClockDriftMs();
    if (clockDriftMs == null) return null;

    final localNowMs = DateTime.now().millisecondsSinceEpoch;
    return rustTimeMsFromLocalTimeMs(
      localNowMs,
      clockDriftMs: clockDriftMs,
    );
  }

  int localTimeMsFromRustTimeMs(
    int rustTimeMs, {
    required int clockDriftMs,
  }) =>
      rustTimeMs + clockDriftMs;

  int rustTimeMsFromLocalTimeMs(
    int localTimeMs, {
    required int clockDriftMs,
  }) =>
      localTimeMs - clockDriftMs;

  Future<void> _cachePeerIdFromRpc(NodeRpcClient rpc) async {
    try {
      final requestStartedAtMs = DateTime.now().millisecondsSinceEpoch;
      final status = await rpc.status(includeVrfDetails: false);
      if (!identical(_rpc, rpc)) return;
      final responseReceivedAtMs = DateTime.now().millisecondsSinceEpoch;
      _updateNodeClockDriftFromStatus(
        status,
        requestStartedAtMs: requestStartedAtMs,
        responseReceivedAtMs: responseReceivedAtMs,
      );
      _cachedPeerId = status?.node.peerId.toString();
    } catch (e, st) {
      _log.error(
          '_cachePeerIdFromRpc: Failed to cache peer ID from RPC status()',
          error: e,
          stackTrace: st);
      if (identical(_rpc, rpc)) {
        _cachedPeerId = null;
      }
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
  ///
  /// Identity gate: every start path (bootstrap, wake, foreground task,
  /// alarms, lifecycle) funnels through here, so this is where "never run
  /// the node while account ownership is unsettled" is enforced. While the
  /// identity is reconciling (a sign-in or season rollover whose account
  /// reconcile has not completed), the active account may still belong to a
  /// previous user — refuse to start. The [NodeAccountReconciler] is the one
  /// caller that supplies a reconciliation [authority], which names the exact
  /// identity, network, account, and address it just confirmed.
  ///
  /// The gate is checked at entry AND re-checked after the (long) internal
  /// start: a login can close the gate while a start is in flight, and the
  /// runtime it built holds the pre-login account's key — tear it down
  /// instead of returning it as a success.
  ///
  /// Reconciliation authorities always imply [freshRuntime]: a block-producer
  /// key is fixed when its runtime is built and cannot be swapped by changing
  /// only the wallet signer.
  Future<bool> startNode({
    int? httpPort,
    bool freshRuntime = false,
    NodeStartAuthority? authority,
  }) async {
    final resolvedAuthority =
        authority ?? NodeStartAuthority.capture(IdentitySnapshots.current);
    if (resolvedAuthority == null || !resolvedAuthority.isCurrent) {
      final phase = IdentitySnapshots.current.phase;
      _log.warn('startNode refused: identity is '
          '${phase.name} or its start authority is stale');
      return false;
    }
    final startIntentGeneration = _startIntentGeneration;
    final stopInFlight = _stopNodeInFlight;
    if (stopInFlight != null) {
      _log.debug('Waiting for node shutdown before starting');
      try {
        await stopInFlight;
      } catch (_) {
        // Shutdown retained its exact handle fail-closed. A later explicit
        // start can retry cleanup; this request must not overlap it.
        return false;
      }
      if (!resolvedAuthority.isCurrent ||
          startIntentGeneration != _startIntentGeneration) {
        return false;
      }
      return startNode(
        httpPort: httpPort,
        freshRuntime: freshRuntime,
        authority: resolvedAuthority,
      );
    }
    final request = _NodeStartRequest(
      authority: resolvedAuthority,
      httpPort: httpPort,
      freshRuntime: freshRuntime || resolvedAuthority.isReconciliation,
    );
    final inFlight = _startNodeCompleter;
    final inFlightRequest = _startNodeRequest;
    if (inFlight != null) {
      if (inFlightRequest != null && inFlightRequest.equivalentTo(request)) {
        _log.debug('Joining equivalent node start already in progress');
        return inFlight.future;
      }
      _log.debug('Waiting for a different node start before retrying');
      try {
        await inFlight.future;
      } catch (_) {
        // The original caller owns that error. This request revalidates its
        // own authority and then gets an independent attempt.
      }
      if (!resolvedAuthority.isCurrent ||
          startIntentGeneration != _startIntentGeneration) {
        return false;
      }
      return startNode(
        httpPort: httpPort,
        freshRuntime: request.freshRuntime,
        authority: resolvedAuthority,
      );
    }

    final completer = Completer<bool>();
    _startNodeCompleter = completer;
    _startNodeRequest = request;
    try {
      final started = await _startNodeInternal(
        authority: resolvedAuthority,
        startIntentGeneration: startIntentGeneration,
        httpPort: httpPort,
        freshRuntime: request.freshRuntime,
      );
      if (started &&
          (!resolvedAuthority.isCurrent ||
              startIntentGeneration != _startIntentGeneration)) {
        // Keep waiters blocked while tearing down the exact runtime produced
        // by this start. Waking a queued successor first would let a generic
        // stop race forward and shut that successor down instead.
        _log.warn('startNode: authority or lifecycle intent changed '
            'mid-start; stopping the just-started node');
        await _shutdownTrackedRuntime();
        completer.complete(false);
        return false;
      }
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
        _startNodeRequest = null;
      }
    }
  }

  /// Completes when any in-flight [startNode] call has finished (its result
  /// and errors are swallowed — callers re-check [isRunning] afterwards).
  ///
  /// Used to serialize account switches with node startup: a start in
  /// progress has already captured the (possibly old) active account's key
  /// while [isRunning] is still false, so a switcher must wait for it to
  /// settle before deciding whether to bounce the node.
  Future<void> waitForStartCompletion() async {
    final completer = _startNodeCompleter;
    if (completer == null) return;
    try {
      await completer.future;
    } catch (_) {
      // The starter surfaces its own error; the waiter only needs quiescence.
    }
  }

  Future<bool> _startNodeInternal({
    required NodeStartAuthority authority,
    required int startIntentGeneration,
    int? httpPort,
    bool freshRuntime = false,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (!authority.isCurrent ||
        startIntentGeneration != _startIntentGeneration) {
      return false;
    }

    // Resolve keyless authority before consulting local/global runtime state
    // or loading an account secret. SharedPreferences is cached per engine,
    // so refresh the durable guest flag at this security boundary.
    final guestSession =
        authority.identityLease.identity.phase == IdentityPhase.guest ||
            await AuthGuestFlag().isGuest(reload: true);
    if (!authority.isCurrent) return false;
    final viewOnly = AppConfig.viewOnly || guestSession;

    if (_nodeRunning && _nodeHandle != null) {
      final reusable = !freshRuntime &&
          _nodeHandle!.isActive() &&
          _runtimeAuthority?.matchesStart(
                authority,
                keyless: viewOnly,
                currentGeneration: _runtimeGeneration,
              ) ==
              true;
      if (reusable) {
        _log.trace('Node already running');
        unawaited(
          ObservabilityReportingService.instance.reportNodeInitialized(
            resetStaticContext: false,
          ),
        );
        return true;
      }

      _log.warn('Node start found a locally tracked runtime with a different '
          'authority; shutting it down before rebuilding');
      await _shutdownTrackedRuntime();
      if (!authority.isCurrent) return false;
    } else if (_nodeHandle != null) {
      // A previous RPC failure may have marked the local facade unavailable
      // while retaining the exact native owner. Reap that handle before
      // attempting another start.
      await _shutdownTrackedRuntime();
      if (!authority.isCurrent) return false;
    } else if (_nodeRunning) {
      // This can only happen across a hot-reload/schema transition. There is
      // no exact handle that this engine is allowed to stop.
      _log.warn('Dropping inconsistent local node state without touching the '
          'process-wide mobile slot');
      _clearLocalRuntimeState();
    }

    String? accountId;
    String? secretKey;
    if (!viewOnly) {
      // Only producer-capable starts may resolve and materialize an account
      // secret. Guest/view-only starts stay keyless even when an old account
      // remains in the registry.
      final expectedAccount = authority.accountScope;
      if (expectedAccount == null) {
        _log.error('Producer start has no explicit account authority');
        return false;
      }
      final repo = await AccountsRepository.create(network: authority.network);
      _log.trace('Checking if any accounts exist...');
      final hasAny = await repo.hasAny();
      _log.trace('Account check result: hasAny = $hasAny');
      if (!hasAny) {
        _log.trace('No accounts found - skipping node start');
        return false;
      }

      _log.debug('Retrieving active account...');
      final account = await repo.getActive();
      if (account == null) {
        _log.error('Failed to retrieve active account');
        return false;
      }
      if (account.id != expectedAccount.accountId ||
          account.address != expectedAccount.address) {
        _log.error('Active account does not match node start authority');
        return false;
      }
      accountId = account.id;
      _log.debug('Active account: ${account.id} (${account.name})');

      _log.trace('Retrieving secret key for account ${account.id}...');
      secretKey = await repo.getSecretKey(account.id);
      if (secretKey == null || secretKey.isEmpty) {
        _log.error(
          'Cannot start node: secret key unavailable for account ${account.id}',
        );
        return false;
      }
      // SECURITY: Only log key length, not value.
      _log.trace('Secret key retrieved (length: ${secretKey.length})');
    }
    NodeHandle? startedHandle;

    // Start node
    try {
      _log.trace('Starting node${httpPort != null ? ' on $httpPort' : ''}');

      const maxSlotAttempts = 3;
      for (var attempt = 1; attempt <= maxSlotAttempts; attempt++) {
        // NodeBuilder is moved into every native lifecycle call. A lost CAS
        // must therefore rebuild all configuration rather than retrying with
        // the consumed bridge object.
        final builder = await _createNodeBuilder(
          authority: authority,
          httpPort: httpPort,
          viewOnly: viewOnly,
          guestSession: guestSession,
          secretKey: secretKey,
        );
        // Builder preparation is inert. This is the one exact authority check
        // at the irreversible process-wide lifecycle boundary for each try.
        if (!authority.isCurrent ||
            startIntentGeneration != _startIntentGeneration) {
          return false;
        }

        // An ambient handle has no Dart-side identity authority. It is only a
        // CAS target and is never adopted as this service's runtime.
        final current = MobileNode.current();
        if (current == null) {
          // FIXME(native-node-authority): getOrStart cannot distinguish
          // "started from the observed empty slot" from "reused a runtime
          // installed by another engine in the empty-slot race". Add native
          // empty-slot CAS or authority metadata so this proof is explicit.
          startedHandle = await MobileNode.getOrStart(builder: builder);
        } else {
          startedHandle = await MobileNode.replaceIfCurrent(
            current: current,
            builder: builder,
          );
        }

        if (startedHandle != null) break;
        _log.warn(
          'Node replacement lost the process-wide handle race '
          '(attempt $attempt/$maxSlotAttempts)',
        );
      }

      final handle = startedHandle;
      if (handle == null) {
        _log.error('Node start could not acquire the process-wide mobile slot');
        return false;
      }

      final rpc = handle.rpc();
      final control = handle.control();
      if (!authority.isCurrent ||
          startIntentGeneration != _startIntentGeneration ||
          !handle.isActive()) {
        await _shutdownUntrackedStart(handle);
        return false;
      }

      if (!viewOnly) {
        final signerOk = await _configureWalletSigner(
          rpc,
          secretKey!,
          accountId!,
          authority,
          startIntentGeneration,
        );
        if (!signerOk ||
            !authority.isCurrent ||
            startIntentGeneration != _startIntentGeneration) {
          // The producer key is correct (set at build), but wallet RPC sends
          // would fail or — worse, after a future reuse — sign under a stale
          // signer. A start that cannot bind the signer is a failed start;
          // the reconciler must not commit `ready` on top of it.
          await _shutdownUntrackedStart(handle);
          return false;
        }
      }

      if (!authority.isCurrent ||
          startIntentGeneration != _startIntentGeneration ||
          !handle.isActive()) {
        await _shutdownUntrackedStart(handle);
        return false;
      }

      _bindRuntimeAuthority(
        authority,
        keyless: viewOnly,
        handle: handle,
        rpc: rpc,
        control: control,
      );
      // Peer ID and clock drift are useful cached metadata, not startup
      // authority. Keep this read off the critical publication path and only
      // let it update the cache while [rpc] is still the bound facade.
      unawaited(_cachePeerIdFromRpc(rpc));

      _log.info(viewOnly
          ? 'Node started in keyless view-only mode'
          : 'Node started with user account block producer');
      unawaited(
        ObservabilityReportingService.instance.reportNodeInitialized(
          resetStaticContext: true,
        ),
      );
      return true;
    } catch (e, st) {
      _log.error(
          'Failed to start node${accountId == null ? '' : ' with account $accountId'}',
          error: e,
          stackTrace: st);
      await SentryUtil.captureError(e, st, tag: 'startNode');
      final handle = startedHandle;
      if (handle != null) {
        await _shutdownUntrackedStart(handle);
      }
      return false;
    }
  }

  Future<NodeBuilder> _createNodeBuilder({
    required NodeStartAuthority authority,
    required int? httpPort,
    required bool viewOnly,
    required bool guestSession,
    required String? secretKey,
  }) async {
    final builder = NodeBuilder();
    if (httpPort != null) {
      builder.httpServer(port: httpPort);
    }

    await _configureNetworkFromUrls(builder, authority.network);

    // A guest session is treated as view-only: the node still runs and syncs,
    // but never produces blocks — a returning operator's leftover keys must
    // not operate while browsing as a guest.
    if (viewOnly) {
      _log.info(guestSession
          ? 'Guest session; node runs non-producing (no block producer)'
          : 'VIEW_ONLY enabled; skipping block producer configuration');
    } else {
      _log.trace(
        'Configuring block producer with user secret key '
        '(length: ${secretKey!.length})',
      );
      builder.blockProducerSecretKey(secretKey: secretKey);
    }
    if (!viewOnly && AppConfig.observabilityHubBaseUrl.isNotEmpty) {
      _log.info(
        'Enabling observability hub HTTP intake',
        context: {'base_url': AppConfig.observabilityHubBaseUrl},
      );
      builder.enableObservabilityHubHttp(
        baseUrl: AppConfig.observabilityHubBaseUrl,
      );
    } else if (AppConfig.observabilityHubBaseUrl.isNotEmpty) {
      _log.info('Skipping observability hub HTTP intake in view-only mode');
    }
    if (AppConfig.enableRealProver) {
      _log.info('Forcing real prover mode');
      builder.enableRealProver();
    }
    if (!viewOnly) {
      builder.mempoolAutoinsertInterval(secs: BigInt.from(1));
    }

    final appSupportDir = await getApplicationSupportDirectory();
    // TODO this should include the hash of the genesis block
    final nodeStoragePath =
        '${appSupportDir.path}/${authority.network}_usernode_node_storage.sqlite';
    _log.trace('Using node storage path: $nodeStoragePath');
    builder.nodeStoragePath(path: nodeStoragePath);

    // Keep persistent VRF storage separate until it is folded into general
    // node storage.
    final vrfPath =
        '${appSupportDir.path}/${authority.network}_usernode_vrf_storage.sqlite';
    _log.trace('Using VRF storage path: $vrfPath');
    builder.vrfStoragePath(path: vrfPath);
    return builder;
  }

  /// Returns true when the signer was bound. A false return means the
  /// runtime is left with whatever signer it previously held — callers must
  /// treat the start as failed (see call sites).
  Future<bool> _configureWalletSigner(
    NodeRpcClient rpc,
    String secretKey,
    String accountId,
    NodeStartAuthority authority,
    int startIntentGeneration,
  ) async {
    const maxAttempts = 5;
    const retryDelay = Duration(milliseconds: 500);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      // Applying a signing key is the effect boundary. Revalidate immediately
      // before every retry rather than guarding unrelated waits and reads.
      if (!authority.isCurrent ||
          startIntentGeneration != _startIntentGeneration) {
        return false;
      }
      try {
        _log.debug(
          'Configuring wallet signer for account $accountId '
          '(attempt $attempt/$maxAttempts)...',
        );
        final resp = await rpc.walletSetSignerFromSecret(
          secretKey: secretKey,
        );

        if (resp != null && resp.ok) {
          _log.info('Wallet signer configured for account $accountId');
          return true;
        }

        final error =
            resp?.error ?? (resp == null ? 'null response' : 'ok=false');
        _log.warn('Wallet signer attempt $attempt failed: $error');
      } catch (e) {
        _log.warn('Wallet signer attempt $attempt exception: $e');
      }

      if (attempt < maxAttempts) {
        await Future.delayed(retryDelay);
      }
    }
    _log.error(
      'Wallet signer configuration failed after $maxAttempts attempts '
      'for account $accountId — refusing to run with an unbound signer',
    );
    return false;
  }

  Future<NodeExit?> _shutdownExactHandle(NodeHandle handle) =>
      MobileNode.shutdown(handle: handle);

  void _requestExactHandleStopBestEffort(NodeHandle handle) {
    try {
      try {
        handle.control().shutdown();
      } catch (shutdownError) {
        // If the graceful shutdown bridge failed before applying its signal,
        // pausing the same exact runtime is the remaining fail-closed action.
        try {
          handle.control().pause();
        } catch (pauseError) {
          _log.error(
            'Exact node shutdown and pause fallbacks both failed',
            error: '$shutdownError; $pauseError',
          );
        }
      }
    } catch (error, stackTrace) {
      _log.error(
        'Could not acquire exact node control for shutdown fallback',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _shutdownTrackedRuntime() async {
    final handle = _nodeHandle;
    if (handle == null) {
      _clearLocalRuntimeState();
      return;
    }
    final generation = _runtimeGeneration;
    if (_isCurrentRuntime(handle, generation)) {
      _nodePaused = true;
      _shutdownInFlightHandle = handle;
      _shutdownInFlightGeneration = generation;
    }

    try {
      final exit = await _shutdownExactHandle(handle);
      if (exit == null) {
        _log.warn('Tracked node handle was already replaced; local ownership '
            'will be detached without touching the replacement');
      }
      _clearLocalRuntimeStateIfCurrent(handle, generation);
    } catch (_) {
      _requestExactHandleStopBestEffort(handle);
      if (_isCurrentRuntime(handle, generation)) {
        // Retain the exact handle and authority fail-closed. A later stop or
        // replacement can retry without ever falling back to ambient state.
        _nodePaused = true;
      }
      rethrow;
    } finally {
      if (identical(_shutdownInFlightHandle, handle) &&
          _shutdownInFlightGeneration == generation) {
        _shutdownInFlightHandle = null;
        _shutdownInFlightGeneration = null;
      }
    }
  }

  void _bindRuntimeAuthority(
    NodeStartAuthority start, {
    required bool keyless,
    required NodeHandle handle,
    required NodeRpcClient rpc,
    required NodeControl control,
  }) {
    if (_pauseRequested) {
      // Apply the native lifecycle intent before publishing any Dart facade.
      // If this throws, the caller still owns an untracked handle and can
      // tear it down without leaving partially-bound service state.
      control.pause();
    }
    _runtimeGeneration++;
    final generation = _runtimeGeneration;
    _nodeHandle = handle;
    _rpc = rpc;
    _control = control;
    _nodeRunning = true;
    _nodePaused = _pauseRequested;
    _runtimeAuthority = NodeRuntimeAuthority(
      network: start.network,
      accountScope: keyless ? null : start.accountScope,
      generation: generation,
    );
    _monitorNodeExit(handle, generation);
  }

  bool _isCurrentRuntime(NodeHandle handle, int generation) =>
      identical(_nodeHandle, handle) && _runtimeGeneration == generation;

  void _clearLocalRuntimeStateIfCurrent(
    NodeHandle handle,
    int generation,
  ) {
    if (_isCurrentRuntime(handle, generation)) {
      _clearLocalRuntimeState();
    }
  }

  void _clearLocalRuntimeState() {
    final invalidated = _nodeRunning ||
        _rpc != null ||
        _control != null ||
        _nodeHandle != null ||
        _runtimeAuthority != null;
    _nodeRunning = false;
    _nodePaused = false;
    _runtimeAuthority = null;
    _rpc = null;
    _control = null;
    _nodeHandle = null;
    _shutdownInFlightHandle = null;
    _shutdownInFlightGeneration = null;
    _cachedPeerId = null;
    _clearNodeClockDrift();
    if (invalidated) _runtimeGeneration++;
  }

  void _monitorNodeExit(NodeHandle handle, int generation) {
    unawaited(() async {
      NodeExit exit;
      try {
        exit = await handle.wait();
      } catch (error, stackTrace) {
        if (!_isCurrentRuntime(handle, generation)) return;
        _log.error(
          'Failed while monitoring the node driver',
          error: error,
          stackTrace: stackTrace,
        );
        _clearLocalRuntimeStateIfCurrent(handle, generation);
        return;
      }

      if (!_isCurrentRuntime(handle, generation)) return;
      final expected = identical(_shutdownInFlightHandle, handle) &&
          _shutdownInFlightGeneration == generation;
      if (!expected) {
        _log.error(
          'Node driver exited unexpectedly',
          context: {'exit': exit.toString(), 'generation': generation},
        );
      }
      _clearLocalRuntimeStateIfCurrent(handle, generation);
    }());
  }

  void _markRuntimeUnavailableForRpc(NodeRpcClient rpc) {
    if (!identical(_rpc, rpc)) return;
    // Keep the exact handle, control, and generation so pause/stop/restart can
    // still target this runtime. Fail closed natively before withdrawing the
    // unusable RPC facade; a Dart-only `_nodePaused` flag is not sufficient.
    try {
      _control?.pause();
    } catch (error, stackTrace) {
      _log.error(
        'Failed to pause exact runtime after RPC panic',
        error: error,
        stackTrace: stackTrace,
      );
      final handle = _nodeHandle;
      if (handle != null) {
        _requestExactHandleStopBestEffort(handle);
      }
    }
    _nodeRunning = false;
    _nodePaused = true;
    _rpc = null;
    _cachedPeerId = null;
    _clearNodeClockDrift();
  }

  Future<void> _shutdownUntrackedStart(NodeHandle handle) async {
    try {
      await _shutdownExactHandle(handle);
      if (_nodeHandle == null) {
        _cachedPeerId = null;
        _clearNodeClockDrift();
      }
    } catch (error, stackTrace) {
      _log.error(
        'Failed to shut down an unbound node start',
        error: error,
        stackTrace: stackTrace,
      );
      _requestExactHandleStopBestEffort(handle);
      _retainUnboundHandle(handle);
    }
  }

  void _retainUnboundHandle(NodeHandle handle) {
    final current = _nodeHandle;
    if (current != null && !identical(current, handle)) {
      _log.error('Cannot retain failed start handle over a newer local owner');
      return;
    }
    if (identical(current, handle)) return;

    _runtimeGeneration++;
    final generation = _runtimeGeneration;
    _nodeHandle = handle;
    _nodeRunning = false;
    _nodePaused = true;
    _runtimeAuthority = null;
    _rpc = null;
    _control = null;
    _monitorNodeExit(handle, generation);
  }

  Future<void> resumeNode() async {
    // This is the desired app lifecycle state, independent of whether a
    // runtime has finished binding yet. An in-flight start will observe it.
    _pauseRequested = false;
    final authority = NodeStartAuthority.capture(IdentitySnapshots.current);
    final keyless = AppConfig.viewOnly ||
        IdentitySnapshots.current.phase == IdentityPhase.guest;
    final runtime = _runtimeAuthority;
    if (authority == null ||
        !authority.isCurrent ||
        !_nodeRunning ||
        _nodeHandle?.isActive() != true ||
        runtime == null ||
        !runtime.matchesStart(
          authority,
          keyless: keyless,
          currentGeneration: _runtimeGeneration,
        )) {
      _log.warn('resumeNode refused: identity is '
          '${IdentitySnapshots.current.phase.name} or runtime authority does '
          'not match');
      return;
    }
    _log.info('Resuming node');
    final wasPaused = _nodePaused;
    // No await between the complete authority comparison and the effect.
    _nodePaused = false;
    _control?.resume();
    if (wasPaused && _nodeRunning) {
      await ObservabilityReportingService.instance
          .resumeMobileContextSnapshotReportingAfterNodeResume();
    }
  }

  Future<void> pauseNode() async {
    _log.info('Pausing node');
    final wasRuntimeActive = isRuntimeActive;
    // Publish the lifecycle intent synchronously. A start that binds after
    // this call will pause its control before exposing the runtime as active.
    _pauseRequested = true;
    _nodePaused = true;
    _control?.pause();
    if (wasRuntimeActive) {
      await ObservabilityReportingService.instance
          .pauseMobileContextSnapshotReportingForNodePause();
    }
  }

  Future<void> stopNode() {
    // Every stop invocation revokes starts requested before it, even when the
    // native shutdown itself is already coalesced with an earlier stop.
    _startIntentGeneration++;
    final inFlight = _stopNodeInFlight;
    if (inFlight != null) return inFlight;

    late Future<void> stop;
    stop = _stopNodeInternal().whenComplete(() {
      if (identical(_stopNodeInFlight, stop)) {
        _stopNodeInFlight = null;
      }
    });
    _stopNodeInFlight = stop;
    return stop;
  }

  Future<void> _stopNodeInternal() async {
    // A start in flight has already captured an account key while
    // `_nodeRunning` is still false — a stop that returned now would leave
    // that node running AFTER the caller believes everything is down (the
    // exact wrong-key window login suspension exists to close). Wait it
    // out, then stop whatever it produced.
    await waitForStartCompletion();

    final handle = _nodeHandle;
    if (handle == null) {
      // Never recapture and stop MobileNode.current(): it may be a newer
      // runtime owned by another engine/generation.
      if (_nodeRunning ||
          _rpc != null ||
          _control != null ||
          _runtimeAuthority != null) {
        _log.warn('Dropping local node facade with no exact shutdown handle');
        _clearLocalRuntimeState();
      }
      return;
    }

    _log.warn('Stopping the exactly tracked mobile node');
    await _shutdownTrackedRuntime();
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
  Future<void> _configureNetworkFromUrls(
    NodeBuilder builder,
    String network,
  ) async {
    final retries = BigInt.from(AppConfig.loadGenesisNbRetries);
    final networkType = switch (network) {
      'internal' => NetworkType.internal,
      'custom' => NetworkType.custom,
      _ => NetworkType.testnet,
    };

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

  /// Clears cached service state so the next bootstrap starts from a clean slate.
  Future<void> resetForAppRestart() async {
    await stopNode();
    _initialized = false;
    _initCompleter = null;
    _startNodeCompleter = null;
    _startNodeRequest = null;
    _pauseRequested = false;
    _instanceId = null;
    _cachedGenesisTimestamp = null;
  }

  /// Obtain the RPC client for ad-hoc calls.
  NodeRpcClient? get rpc => _rpc;

  /// Get the node's P2P peer ID.
  /// Returns the cached peer ID that was retrieved on node startup.
  /// Returns null if the node is not running or peer ID was not cached.
  String? getPeerId() {
    return _cachedPeerId;
  }

  bool _shouldSkipRpc(String methodName) {
    if (!_nodePaused) {
      return false;
    }

    _log.debug('$methodName skipped: node is paused');
    return true;
  }

  Future<RpcStatusNode?> getStatusNode() async {
    _log.trace('getStatusNode called');
    if (_shouldSkipRpc('getStatusNode')) return null;
    final r = _rpc;
    if (r == null) return null;
    try {
      final requestStartedAtMs = DateTime.now().millisecondsSinceEpoch;
      final status = await r.status(includeVrfDetails: false);
      final responseReceivedAtMs = DateTime.now().millisecondsSinceEpoch;
      if (identical(_rpc, r)) {
        _updateNodeClockDriftFromStatus(
          status,
          requestStartedAtMs: requestStartedAtMs,
          responseReceivedAtMs: responseReceivedAtMs,
        );
      }
      return status?.node;
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getStatusNode', error: e, stackTrace: st);
      _markRuntimeUnavailableForRpc(r);
      await SentryUtil.captureError(e, st, tag: 'frb_panic_getStatusNode');
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
    if (_shouldSkipRpc('getStatus')) return null;
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
      final requestStartedAtMs = DateTime.now().millisecondsSinceEpoch;
      status = await r.status(
        includeVrfDetails: includeVrfDetails,
      );
      final responseReceivedAtMs = DateTime.now().millisecondsSinceEpoch;
      if (!includeVrfDetails && identical(_rpc, r)) {
        _updateNodeClockDriftFromStatus(
          status,
          requestStartedAtMs: requestStartedAtMs,
          responseReceivedAtMs: responseReceivedAtMs,
        );
      }
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
      _markRuntimeUnavailableForRpc(r);
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
    if (_shouldSkipRpc('getBlockProducerStatus')) return null;
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
      _markRuntimeUnavailableForRpc(r);
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
    if (_shouldSkipRpc('listBlockchain')) return null;
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
      _markRuntimeUnavailableForRpc(r);
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
    if (_shouldSkipRpc('listMempool')) return null;
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
      _markRuntimeUnavailableForRpc(r);
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
    if (_shouldSkipRpc('epochRewards')) return null;
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
      _markRuntimeUnavailableForRpc(r);
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
    if (_shouldSkipRpc('listUtxosByOwner')) return null;
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
      _markRuntimeUnavailableForRpc(r);
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

  /// Convenience helper to fetch wallet balance from the local wallet cache.
  Future<RpcWalletBalanceResp?> walletBalance({
    required PublicKeyHash owner,
  }) async {
    _log.trace(
      'walletBalance called with params: owner=[PublicKeyHash]',
    );
    if (_shouldSkipRpc('walletBalance')) return null;
    final r = _rpc;
    if (r == null) return null;

    RpcWalletBalanceResp? balance;
    try {
      balance = await r.wallet().balance(owner: owner);
    } on PanicException catch (e, st) {
      _log.error('FRB panic during walletBalance', error: e, stackTrace: st);
      _markRuntimeUnavailableForRpc(r);
      await SentryUtil.captureError(e, st, tag: 'frb_panic_walletBalance');
      return null;
    } catch (e, st) {
      _log.warn('RPC walletBalance failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_walletBalance');
      return null;
    }

    try {
      _log.trace(
        'walletBalance response: tracked=${balance?.tracked}, baseTotal=${balance?.baseTotal}, baseAvailable=${balance?.baseAvailable}',
      );
      _log.debug(
        'walletBalance ok',
        context: {
          'tracked': balance?.tracked,
          'baseTotal': balance?.baseTotal.toString(),
          'baseAvailable': balance?.baseAvailable.toString(),
          'baseUtxos': balance?.baseUtxos.toString(),
        },
      );
    } catch (e, st) {
      _log.warn('Failed to log walletBalance response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'walletBalance_logging');
    }
    return balance;
  }

  /// Convenience helper to transfer funds via RPC.
  Future<RpcWalletTxSendResp?> transferFunds({
    required WalletIdentityLease authority,
    required BigInt amount,
    required PublicKeyHash toPkHash,
  }) async {
    if (AppConfig.viewOnly) {
      _log.info('Skipping transferFunds in view-only mode');
      return const RpcWalletTxSendResp(
        state: RpcWalletTxSendState.ready,
        queued: false,
        error: _viewOnlyTransactionError,
      );
    }

    _log.trace('transferFunds called with params: '
        'fromPkHash=[leased identity], amount=$amount, '
        'toPkHash=[PublicKeyHash]');
    final r = _rpc;
    if (r == null || !_walletEffectIsAuthorized(authority)) return null;
    final fromPkHash = frb_types.publicKeyHashFromString(s: authority.address);

    // Call into FRB with defensive handling for panics / transport errors.
    RpcWalletTxSendResp? response;
    try {
      final rpcResponse = await r.transferFunds(
        fromPkHash: fromPkHash,
        amount: amount,
        toPkHash: toPkHash,
      );
      response = rpcResponse;
    } on PanicException catch (e, st) {
      // FRB surfaced a Rust-side panic.
      _log.error('FRB panic during transferFunds', error: e, stackTrace: st);
      // Mark backend as not running and drop RPC handle to avoid cascading failures.
      _markRuntimeUnavailableForRpc(r);
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

  /// Transfer funds and surface ordered wallet-send progress events.
  Stream<WalletTxSendEvent> transferFundsEvents({
    required WalletIdentityLease authority,
    required BigInt amount,
    required PublicKeyHash toPkHash,
  }) async* {
    if (AppConfig.viewOnly) {
      _log.info('Skipping transferFundsEvents in view-only mode');
      yield const WalletTxSendEvent.rejected(
        error: _viewOnlyTransactionError,
        state: RpcWalletTxSendState.ready,
      );
      return;
    }

    _log.trace('transferFundsEvents called with params: '
        'fromPkHash=[leased identity], amount=$amount, '
        'toPkHash=[PublicKeyHash]');
    final r = _rpc;
    if (r == null || !_walletEffectIsAuthorized(authority)) {
      yield const WalletTxSendEvent.rejected(
        error: 'Wallet authority changed; please retry.',
        state: RpcWalletTxSendState.ready,
      );
      return;
    }
    final fromPkHash = frb_types.publicKeyHashFromString(s: authority.address);

    var emitted = false;
    var terminalEmitted = false;
    try {
      final events = r.wallet().txSend(
            fromPkHash: fromPkHash,
            amount: amount,
            toPkHash: toPkHash,
            memo: frb_types.Memo.fromUtf8Str(s: ''),
          );
      await for (final event in events) {
        emitted = true;
        event.when(
          syncing: () {},
          queued: (_) {
            terminalEmitted = true;
          },
          rejected: (_, __) {
            terminalEmitted = true;
          },
        );
        yield event;
      }
    } on PanicException catch (e, st) {
      _log.error('FRB panic during transferFundsEvents',
          error: e, stackTrace: st);
      _markRuntimeUnavailableForRpc(r);
      await SentryUtil.captureError(e, st,
          tag: 'frb_panic_transferFundsEvents');
      yield const WalletTxSendEvent.rejected(
        error: 'Node RPC unavailable',
        state: RpcWalletTxSendState.ready,
      );
      return;
    } catch (e, st) {
      _log.warn('RPC transferFundsEvents failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_transferFundsEvents');
      yield WalletTxSendEvent.rejected(
        error: e.toString(),
        state: RpcWalletTxSendState.ready,
      );
      return;
    }

    if (!emitted) {
      yield const WalletTxSendEvent.rejected(
        error: 'Transfer stream closed without a result',
        state: RpcWalletTxSendState.ready,
      );
    } else if (!terminalEmitted) {
      yield const WalletTxSendEvent.rejected(
        error: 'Transfer stream closed before a final result',
        state: RpcWalletTxSendState.syncing,
      );
    }
  }

  /// Sends a wallet transaction through the one identity-aware effect gate.
  ///
  /// Callers may prepare or confirm a transaction for an arbitrary amount of
  /// time. The exact authority is revalidated here, immediately before the
  /// Rust RPC transport starts, and the sender is derived from that authority
  /// rather than accepted as caller input.
  Future<RpcWalletTxSendResp?> sendTransaction({
    required WalletIdentityLease authority,
    required BigInt amount,
    required PublicKeyHash toPkHash,
    required frb_types.Memo memo,
  }) async {
    if (AppConfig.viewOnly) {
      return const RpcWalletTxSendResp(
        state: RpcWalletTxSendState.ready,
        queued: false,
        error: _viewOnlyTransactionError,
      );
    }

    final r = _rpc;
    if (r == null || !_walletEffectIsAuthorized(authority)) {
      return const RpcWalletTxSendResp(
        state: RpcWalletTxSendState.ready,
        queued: false,
        error: 'Wallet authority changed; please retry.',
      );
    }

    final fromPkHash = frb_types.publicKeyHashFromString(s: authority.address);
    try {
      return await r.wallet().txSendResult(
            fromPkHash: fromPkHash,
            amount: amount,
            toPkHash: toPkHash,
            memo: memo,
          );
    } on PanicException catch (e, st) {
      _log.error('FRB panic during sendTransaction', error: e, stackTrace: st);
      _markRuntimeUnavailableForRpc(r);
      await SentryUtil.captureError(e, st, tag: 'frb_panic_sendTransaction');
      return const RpcWalletTxSendResp(
        state: RpcWalletTxSendState.ready,
        queued: false,
        error: 'Node RPC unavailable',
      );
    }
  }

  bool _walletEffectIsAuthorized(WalletIdentityLease authority) =>
      authority.isCurrent &&
      _nodeRunning &&
      !_nodePaused &&
      _nodeHandle?.isActive() == true &&
      _runtimeAuthority?.generation == _runtimeGeneration &&
      _runtimeAuthority?.accountScope == authority.accountScope;

  /// Captures exact authority for node-local reads from the currently-bound
  /// wallet runtime. Stable explorer data needs only [WalletDataScope].
  WalletRuntimeLease? captureWalletRuntimeLease({
    required WalletIdentityLease authority,
    required WalletDataScope dataScope,
  }) {
    final runtime = _runtimeAuthority;
    if (!authority.isCurrent ||
        !_nodeRunning ||
        _nodeHandle?.isActive() != true ||
        dataScope.accountScope != authority.accountScope ||
        runtime == null ||
        runtime.generation != _runtimeGeneration ||
        runtime.accountScope != authority.accountScope) {
      return null;
    }
    return WalletRuntimeLease(
      dataScope: dataScope,
      runtimeGeneration: runtime.generation,
    );
  }

  bool isWalletRuntimeLeaseCurrent(WalletRuntimeLease lease) {
    final currentWallet =
        WalletIdentityLease.capture(IdentitySnapshots.current);
    final runtime = _runtimeAuthority;
    return currentWallet?.accountScope == lease.accountScope &&
        runtime?.accountScope == lease.accountScope &&
        runtime?.generation == lease.runtimeGeneration &&
        _runtimeGeneration == lease.runtimeGeneration &&
        _nodeRunning &&
        _nodeHandle?.isActive() == true;
  }

  /// Query backend for epoch information with VRF status awareness
  ///
  /// This method combines status and epochRewards calls to provide comprehensive
  /// epoch information including VRF calculation status (inferred from response).
  ///
  /// Returns null if backend is unavailable or calls fail.
  Future<BackendRPCResponse?> getEpochInfo({int? epoch}) async {
    if (_shouldSkipRpc('getEpochInfo')) return null;
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
    if (_shouldSkipRpc('getEpochsWithData')) return null;
    final r = _rpc;
    if (r == null) return null;

    RpcEpochsWithDataResp? response;
    try {
      response = await r.epochsWithData();
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getEpochsWithData',
          error: e, stackTrace: st);
      _markRuntimeUnavailableForRpc(r);
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
    if (_shouldSkipRpc('getEpochSlotResults')) return null;
    final r = _rpc;
    if (r == null) return null;

    RpcEpochSlotResultsResp? response;
    try {
      response = await r.epochSlotResults(epoch: epoch);
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getEpochSlotResults',
          error: e, stackTrace: st);
      _markRuntimeUnavailableForRpc(r);
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

  /// Convenience helper to fetch the per-slot lifecycle drill-down for an
  /// epoch. Returns one [RpcSlotDetail] per slot in the epoch, including
  /// the flattened block-producer flow summary fields (build/sign/inject
  /// timings, terminal flow outcome, discard reason).
  ///
  /// Returns `null` when the RPC client is unavailable or the call fails.
  Future<RpcEpochSlotDetailsResp?> getEpochSlotDetails({
    required int epoch,
  }) async {
    _log.trace('getEpochSlotDetails called with params: epoch=$epoch');
    if (_shouldSkipRpc('getEpochSlotDetails')) return null;
    final r = _rpc;
    if (r == null) return null;

    RpcEpochSlotDetailsResp? response;
    try {
      response = await r.epochSlotDetails(epoch: epoch);
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getEpochSlotDetails',
          error: e, stackTrace: st);
      _markRuntimeUnavailableForRpc(r);
      await SentryUtil.captureError(e, st,
          tag: 'frb_panic_getEpochSlotDetails');
      return null;
    } catch (e, st) {
      _log.warn('RPC getEpochSlotDetails failed: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'rpc_getEpochSlotDetails');
      return null;
    }

    try {
      final detailsCount = response?.details.length ?? 0;
      _log.debug(
        'getEpochSlotDetails ok',
        context: {'epoch': response?.epoch, 'detailsCount': detailsCount},
      );
    } catch (e, st) {
      _log.warn('Failed to log getEpochSlotDetails response: $e\$st');
      await SentryUtil.captureError(e, st, tag: 'getEpochSlotDetails_logging');
    }
    return response;
  }

  /// Convenience helper to fetch slot time via RPC.
  Future<RpcSlotTimeResp?> getSlotTime({
    required int epoch,
    required int slot,
  }) async {
    _log.trace('getSlotTime called with params: epoch=$epoch, slot=$slot');
    if (_shouldSkipRpc('getSlotTime')) return null;
    final r = _rpc;
    if (r == null) return null;

    RpcSlotTimeResp? response;
    try {
      response = await r.slotTime(epoch: epoch, slot: slot);
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getSlotTime', error: e, stackTrace: st);
      _markRuntimeUnavailableForRpc(r);
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
    if (_shouldSkipRpc('getProducedBlockMetadata')) return null;
    final r = _rpc;
    if (r == null) return null;

    RpcProducedBlockMetadataResp? response;
    try {
      response = await r.producedBlockMetadata(epoch: epoch, slot: slot);
    } on PanicException catch (e, st) {
      _log.error('FRB panic during getProducedBlockMetadata',
          error: e, stackTrace: st);
      _markRuntimeUnavailableForRpc(r);
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
      unawaited(pauseNode());
    }
    _cachedGenesisTimestamp = null;
  }
}
