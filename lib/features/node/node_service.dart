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
import 'package:crypto_mobile_app/core/identity/block_production_store.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/wallet_tx.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' show Memo;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' show enableLogging;
import 'package:crypto_mobile_app/src/rust/tracing.dart' show TracingLevel;
import 'package:crypto_mobile_app/src/rust/node.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/staking_preference_store.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/models/backend_rpc_response.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

final _log = LoggingService.instance.withTag('usernode/NodeService');
const _viewOnlyTransactionError =
    'Transactions are disabled in view-only mode.';

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
  bool _nodePaused = false;
  bool _terminalResetRequested = false;
  bool? _runtimeViewOnly;
  String? _instanceId;
  String? _cachedPeerId;
  int? _cachedGenesisTimestamp;
  int? _nodeClockDriftMs;
  int? _lastNodeTimeMs;
  int? _lastNodeClockSampleSystemTimeMs;

  NodeControl? _control;
  NodeRpcClient? _rpc;
  bool get isRunning => _nodeRunning;
  bool get isRuntimeActive => _nodeRunning && !_nodePaused;
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
  ///
  /// Identity gate: every start path (bootstrap, wake, foreground task,
  /// alarms, lifecycle) funnels through here. Only a signed-in, ready identity
  /// is currently admitted. The internal keyless/view-only construction is
  /// intentionally retained for a future explicit guest-node product mode,
  /// but no caller may bypass this gate today.
  ///
  /// The gate is checked at entry AND re-checked after the (long) internal
  /// start: a login can close the gate while a start is in flight, and the
  /// runtime it built holds the pre-login account's key — tear it down
  /// instead of returning it as a success.
  ///
  /// [freshRuntime] (reconciler only): never adopt an already-running global
  /// node — its block-producer key was fixed at build time for whichever
  /// account was active then and cannot be swapped. The existing runtime is
  /// shut down and a new one is built under the now-active account.
  Future<bool> startNode({
    int? httpPort,
    bool freshRuntime = false,
  }) async {
    if (_terminalResetRequested) {
      _log.warn('startNode refused: terminal reset is in progress');
      return false;
    }
    if (!IdentitySnapshots.current.allowsNodeStart) {
      _log.warn('startNode refused: identity is '
          '${IdentitySnapshots.current.phase.name}; a signed-in, ready '
          'identity is required');
      return false;
    }
    if (_startNodeCompleter != null) {
      _log.debug('startNode already in progress; waiting for existing start');
      return _startNodeCompleter!.future;
    }

    final completer = Completer<bool>();
    _startNodeCompleter = completer;
    try {
      final started = await _startNodeInternal(
        httpPort: httpPort,
        freshRuntime: freshRuntime,
      );
      if (started && _terminalResetRequested) {
        _log.warn('startNode: terminal reset began mid-start; '
            'signalling the just-started node to shut down');
        signalShutdownForTerminalReset();
        completer.complete(false);
        return false;
      }
      if (started && !IdentitySnapshots.current.allowsNodeStart) {
        // The identity became unsettled while the start was in flight; the
        // runtime captured the pre-transition account's key. Settle waiters
        // first (stopNode waits on this completer), then tear down.
        _log.warn('startNode: identity became unsettled mid-start; '
            'stopping the just-started node');
        if (identical(_startNodeCompleter, completer)) {
          _startNodeCompleter = null;
        }
        completer.complete(false);
        await stopNode();
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
    int? httpPort,
    bool freshRuntime = false,
  }) async {
    if (!_initialized) {
      await init();
    }

    // Resolve keyless authority before consulting local/global runtime state
    // or loading an account secret. SharedPreferences is cached per engine,
    // so refresh the durable guest flag at this security boundary.
    final guestSession =
        IdentitySnapshots.current.phase == IdentityPhase.guest ||
            await AuthGuestFlag().isGuest(reload: true);
    final viewOnly = AppConfig.viewOnly || guestSession;

    if (_nodeRunning) {
      if (viewOnly) {
        if (_runtimeViewOnly == true) {
          _log.trace('Keyless view-only node already running');
          return true;
        }
        _log.warn('View-only start found a locally tracked runtime; '
            'shutting it down before rebuilding without account keys');
        _control?.shutdown();
        final wentDown = await _waitForGlobalNodeDown();
        if (!wentDown) {
          _log.error('Tracked node did not shut down; refusing to accept '
              'unknown producer authority in view-only mode');
          return false;
        }
        _nodeRunning = false;
        _nodePaused = false;
        _runtimeViewOnly = null;
        _rpc = null;
        _control = null;
        _cachedPeerId = null;
        _clearNodeClockDrift();
      } else {
        _log.trace('Node already running');
        unawaited(
          ObservabilityReportingService.instance.reportNodeInitialized(
            resetStaticContext: false,
          ),
        );
        return true;
      }
    }

    String? accountId;
    String? secretKey;
    String? linkedWalletOwnerAddress;
    if (!viewOnly) {
      // Only producer-capable starts may resolve and materialize an account
      // secret. Guest/view-only starts stay keyless even when an old account
      // remains in the registry.
      final repo = await AccountsRepository.create();
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
      accountId = account.id;
      _log.debug('Active account: ${account.id} (${account.name})');

      final identity = IdentitySnapshots.current;
      if (identity.hasLinkedOnChainAccount &&
          identity.accountId == account.id &&
          identity.address == account.address) {
        linkedWalletOwnerAddress = account.address;
      } else {
        _log.warn(
          'Active account is not attached to the authenticated social user; '
          'wallet owner tracking will remain disabled',
        );
      }

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

    // First try to reuse an already-running *global* node (shared across Dart
    // isolates / FlutterEngines in the same process) by grabbing its RPC client.
    // This avoids spinning up a second node when another engine already started it.
    final existing = Node.getGlobal();
    if (existing case (final rpc, final control)) {
      if (viewOnly) {
        // Producer status is nullable, so probing cannot positively establish
        // that an inherited runtime is keyless. Rebuild it instead. This also
        // removes any wallet signer retained by the previous identity.
        _log.warn('View-only start found an existing global node; '
            'shutting it down before rebuilding without account keys');
        control.shutdown();
        final wentDown = await _waitForGlobalNodeDown();
        if (!wentDown) {
          _log.error('Existing global node did not shut down; refusing to '
              'enter view-only mode with unknown producer authority');
          return false;
        }
      } else if (freshRuntime) {
        // A reconciler start must bind BOTH runtime identities (block
        // producer + wallet signer) to the reconciled account. The producer
        // key of an existing runtime was fixed at build time and cannot be
        // swapped, so the existing node is torn down and rebuilt. Waiting
        // for it to actually go down avoids two producers racing.
        _log.warn('Fresh-runtime start found an existing global node; '
            'shutting it down before rebuilding');
        control.shutdown();
        final wentDown = await _waitForGlobalNodeDown();
        if (!wentDown) {
          _log.error('Existing global node did not shut down; refusing to '
              'bind the reconciled account to a runtime with unknown keys');
          return false;
        }
      } else {
        if (_terminalResetRequested) return false;
        _rpc = rpc;
        _control = control;
        _nodeRunning = true;
        _nodePaused = false;
        _runtimeViewOnly = false;
        control.resume();
        await _cachePeerIdFromRpc(rpc);

        final signerOk = await _configureWalletSigner(secretKey!, accountId!);
        if (!signerOk) {
          // The reused runtime still holds whichever signer it was left
          // with — possibly a previous account's. Running like that lets
          // wallet RPC sends sign as the wrong account; tear down instead.
          _teardownRuntimeAfterFailedBind();
          return false;
        }
        _log.info('Reused previously started node');
        unawaited(
          ObservabilityReportingService.instance.reportNodeInitialized(
            resetStaticContext: true,
          ),
        );
        return true;
      }
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
      if (_terminalResetRequested) return false;

      if (linkedWalletOwnerAddress != null) {
        builder.walletOwnerAddress(address: linkedWalletOwnerAddress);
        _log.info('Tracking the linked social user wallet owner');
      }

      final delegated =
          !viewOnly && await StakingPreferenceStore.active().isDelegated();

      // Keep keyless/view-only construction below the admission gate for
      // explicit VIEW_ONLY builds and a future guest-node product mode.
      // Current guest identities never reach this branch through startNode.
      if (viewOnly) {
        _log.info(guestSession
            ? 'Keyless guest safety mode; skipping block producer configuration'
            : 'VIEW_ONLY enabled; skipping block producer configuration');
      } else if (delegated) {
        _log.info('Stake is delegated; node runs without a block producer');
      } else if (Platform.isIOS) {
        // Block production is disabled entirely on iOS: the platform cannot
        // keep the app alive reliably enough to honor won slots (no alarms,
        // no foreground service), so producing there only creates missed
        // slots. The node still runs, syncs, and signs wallet transactions.
        _log.info('iOS: block production disabled; node runs non-producing');
      } else if (!await loadBlockProductionReleased()) {
        // Onboarding flow alignment: producing blocks is a released
        // capability. Until the platform releases this user's keys
        // (bp_released on /me and /wallet/provision, persisted per account
        // bucket by the reconciler), the node runs non-producing — it still
        // syncs and signs wallet transactions for dapps.
        _log.info('Block production not released for this account; '
            'node runs non-producing');
      } else {
        _log.trace(
          'Configuring block producer with user secret key (length: ${secretKey!.length})',
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
      // Configure persistent node storage path so wallet cache state survives restarts.
      // Use network-specific paths to avoid conflicts when switching networks.
      final appSupportDir = await getApplicationSupportDirectory();
      final networkType = await _getSelectedNetwork();
      if (_terminalResetRequested) return false;
      // TODO(trust-refactor): Bind authenticated genesis/chain identity and
      // namespace storage by that binding outside this lifecycle refactor.
      final nodeStoragePath =
          '${appSupportDir.path}/${networkType.name}_usernode_node_storage.sqlite';
      _log.trace('Using node storage path: $nodeStoragePath');
      builder.nodeStoragePath(path: nodeStoragePath);

      // Keep persistent VRF storage separate until it is folded into general node storage.
      final vrfPath =
          '${appSupportDir.path}/${networkType.name}_usernode_vrf_storage.sqlite';
      _log.trace('Using VRF storage path: $vrfPath');
      builder.vrfStoragePath(path: vrfPath);

      if (_terminalResetRequested) return false;
      final node = builder.build();
      _rpc = node.rpc();

      // Run the node in a background thread.
      if (_terminalResetRequested) return false;
      _control = node.runForeverInNewThread();
      if (_terminalResetRequested) {
        _control?.shutdown();
        _clearLocalRuntimeState();
        return false;
      }
      _nodeRunning = true;
      _nodePaused = false;
      _runtimeViewOnly = viewOnly;

      // Cache peer ID once on startup.
      // Prefer RPC status so callers don't depend on holding a Node handle.
      // Wait a bit for the node to be ready before trying to cache peer ID
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await _cachePeerIdFromRpc(_rpc!);
      } catch (e) {
        _log.warn('Failed to cache peer ID (node may still be starting): $e');
      }

      if (!viewOnly) {
        final signerOk = await _configureWalletSigner(secretKey!, accountId!);
        if (!signerOk) {
          // The producer key is correct (set at build), but wallet RPC sends
          // would fail or — worse, after a future reuse — sign under a stale
          // signer. A start that cannot bind the signer is a failed start;
          // the reconciler must not commit `ready` on top of it.
          _teardownRuntimeAfterFailedBind();
          return false;
        }
      }

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
      return false;
    }
  }

  /// Returns true when the signer was bound. A false return means the
  /// runtime is left with whatever signer it previously held — callers must
  /// treat the start as failed (see call sites).
  Future<bool> _configureWalletSigner(
      String secretKey, String accountId) async {
    const maxAttempts = 5;
    const retryDelay = Duration(milliseconds: 500);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_terminalResetRequested) return false;
      try {
        _log.debug(
          'Configuring wallet signer for account $accountId '
          '(attempt $attempt/$maxAttempts)...',
        );
        final resp = await _rpc!.walletSetSignerFromSecret(
          secretKey: secretKey,
        );
        if (_terminalResetRequested) return false;

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

  /// Shuts down a runtime whose identity binding failed mid-start. Direct
  /// shutdown (not [stopNode]) because this runs INSIDE the start that
  /// [stopNode] would wait on.
  void _teardownRuntimeAfterFailedBind() {
    _control?.shutdown();
    _clearLocalRuntimeState();
  }

  void _clearLocalRuntimeState() {
    _nodeRunning = false;
    _nodePaused = false;
    _runtimeViewOnly = null;
    _rpc = null;
    _control = null;
    _cachedPeerId = null;
    _clearNodeClockDrift();
  }

  /// Polls until [Node.getGlobal] reports the process-wide node as down
  /// (shutdown is signal-based and completes asynchronously). Returns false
  /// on timeout.
  Future<bool> _waitForGlobalNodeDown() async {
    const timeout = Duration(seconds: 10);
    const pollInterval = Duration(milliseconds: 100);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (Node.getGlobal() == null) return true;
      await Future.delayed(pollInterval);
    }
    return Node.getGlobal() == null;
  }

  Future<void> resumeNode() async {
    if (_terminalResetRequested) {
      _log.warn('resumeNode refused: terminal reset is in progress');
      return;
    }
    // Same gate as startNode: resume is a secondary "make the runtime
    // operate" path (ZK pipeline, lifecycle foreground) and must not wake a
    // suspended runtime while account ownership is unsettled.
    if (!IdentitySnapshots.current.allowsNodeStart) {
      _log.warn('resumeNode refused: identity is '
          '${IdentitySnapshots.current.phase.name}');
      return;
    }
    if (IdentitySnapshots.current.phase == IdentityPhase.guest &&
        _runtimeViewOnly != true) {
      _log.warn('resumeNode refused: guest runtime is not confirmed keyless');
      return;
    }
    _log.info('Resuming node');
    final wasPaused = _nodePaused;
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
    _nodePaused = true;
    _control?.pause();
    if (wasRuntimeActive) {
      await ObservabilityReportingService.instance
          .pauseMobileContextSnapshotReportingForNodePause();
    }
  }

  Future<void> stopNode() async {
    // A start in flight has already captured an account key while
    // `_nodeRunning` is still false — a stop that returned now would leave
    // that node running AFTER the caller believes everything is down (the
    // exact wrong-key window login suspension exists to close). Wait it
    // out, then stop whatever it produced.
    await waitForStartCompletion();

    // `Node.getGlobal()` crosses the FRB boundary. During early auth/session
    // restore (and in no-load tests), suspension can run before this service
    // has initialized FRB. With no locally tracked runtime, keep that path a
    // no-op instead of calling through an uninitialized bridge.
    if (!_initialized && !_nodeRunning) return;

    final global = Node.getGlobal();
    if (!_nodeRunning && global == null) return;
    // Currently frb-generated API does not expose a graceful shutdown; dispose bridge.
    _log.warn(
      'Stopping node (dropping references; FRB stays initialized)',
    );
    Object? shutdownError;
    StackTrace? shutdownStack;
    try {
      if (global case (_, final globalControl)) {
        try {
          globalControl.shutdown();
          final wentDown = await _waitForGlobalNodeDown();
          if (!wentDown) {
            throw StateError('process-global node did not shut down');
          }
        } catch (error, stackTrace) {
          shutdownError = error;
          shutdownStack = stackTrace;
        }
      } else {
        try {
          _control?.shutdown();
        } catch (error, stackTrace) {
          shutdownError = error;
          shutdownStack = stackTrace;
        }
      }
    } finally {
      // Never retain a locally "running" façade after shutdown was requested.
      // The error is still rethrown below so identity transitions remain
      // fail-closed until a later retry confirms the process-global node down.
      _clearLocalRuntimeState();
    }
    if (shutdownError != null) {
      Error.throwWithStackTrace(shutdownError, shutdownStack!);
    }
  }

  /// Irreversibly fences this façade and sends the existing synchronous Rust
  /// shutdown signal without waiting for the runtime to retire.
  ///
  /// Android process death owns final teardown. iOS remains in an inert app
  /// surface after this call, so no start or resume path is allowed to reopen
  /// the runtime in this process.
  void signalShutdownForTerminalReset() {
    _terminalResetRequested = true;

    NodeControl? control = _control;
    if (_initialized) {
      try {
        control = Node.getGlobalControl() ?? control;
      } catch (error) {
        _log.warn('Could not resolve process-global node during reset: $error');
      }
    }

    try {
      control?.shutdown();
    } catch (error) {
      _log.warn('Could not signal node shutdown during reset: $error');
    } finally {
      _clearLocalRuntimeState();
    }
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
      _updateNodeClockDriftFromStatus(
        status,
        requestStartedAtMs: requestStartedAtMs,
        responseReceivedAtMs: responseReceivedAtMs,
      );
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
      if (!includeVrfDetails) {
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
      _nodeRunning = false;
      _rpc = null;
      _control = null;
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
    required PublicKeyHash fromPkHash,
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

    _log.trace(
      'transferFunds called with params: fromPkHash=[PublicKeyHash], amount=$amount, toPkHash=[PublicKeyHash]',
    );
    final r = _rpc;
    if (r == null) return null;

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

  /// Transfer funds and surface ordered wallet-send progress events.
  Stream<WalletTxSendEvent> transferFundsEvents({
    required PublicKeyHash fromPkHash,
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

    _log.trace(
      'transferFundsEvents called with params: fromPkHash=[PublicKeyHash], amount=$amount, toPkHash=[PublicKeyHash]',
    );
    final r = _rpc;
    if (r == null) {
      yield const WalletTxSendEvent.rejected(
        error: 'Node RPC unavailable',
        state: RpcWalletTxSendState.ready,
      );
      return;
    }

    var emitted = false;
    var terminalEmitted = false;
    try {
      final events = r.wallet().txSend(
            fromPkHash: fromPkHash,
            amount: amount,
            toPkHash: toPkHash,
            memo: Memo.fromUtf8Str(s: ''),
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
      _nodeRunning = false;
      _rpc = null;
      _control = null;
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
