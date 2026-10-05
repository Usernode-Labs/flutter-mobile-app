part of 'package:crypto_mobile_app/main.dart';

final class _NativeSessionEstablishIntent {
  const _NativeSessionEstablishIntent._({required this.attemptId});

  final String attemptId;

  factory _NativeSessionEstablishIntent.fromBridgePayload(
    Map<String, dynamic> payload,
  ) {
    final args = _exactMap(
      payload['args'],
      const {'attemptId', 'desiredRuntime'},
      'establishNativeSession args',
    );
    final attemptId = _canonicalString(args['attemptId'], 'attemptId');
    if (args['desiredRuntime'] != 'running' ||
        !RegExp(r'^nsa_[A-Za-z0-9_-]{43}$').hasMatch(attemptId)) {
      throw const NativeSessionException(
        'native_establish_request_invalid',
        'The native establishment request is invalid.',
      );
    }
    return _NativeSessionEstablishIntent._(attemptId: attemptId);
  }
}

final class _NativeSessionTicketEnvelope {
  _NativeSessionTicketEnvelope._({
    required this.protocol,
    required this.attemptId,
    required this.desiredRuntime,
    required this.ticket,
    required this.requestDigest,
    required this.exchangeChallenge,
    required this.networkId,
    required this.chainId,
    required this.issuedAt,
    required this.expiresAt,
  });

  final int protocol;
  final String attemptId;
  final String desiredRuntime;
  final String ticket;
  final String requestDigest;
  final String exchangeChallenge;
  final String networkId;
  final String chainId;
  final String issuedAt;
  final String expiresAt;

  Map<String, Object?> get platformValue => {
        'protocol': protocol,
        'attemptId': attemptId,
        'desiredRuntime': desiredRuntime,
        'ticket': ticket,
        'requestDigest': requestDigest,
        'exchangeChallenge': exchangeChallenge,
        'network': {
          'id': networkId,
          'chainId': chainId,
        },
        'issuedAt': issuedAt,
        'expiresAt': expiresAt,
      };

  native.NativeEstablishTicket get rustValue => native.NativeEstablishTicket(
        protocol: protocol,
        attemptId: attemptId,
        desiredRuntime: native.DesiredRuntime.running,
        ticket: ticket,
        requestDigest: requestDigest,
        exchangeChallenge: exchangeChallenge,
        network: native.NativeNetworkTicket(id: networkId, chainId: chainId),
        issuedAt: issuedAt,
        expiresAt: expiresAt,
      );

  static const _ticketKeys = <String>{
    'protocol',
    'attemptId',
    'desiredRuntime',
    'ticket',
    'requestDigest',
    'exchangeChallenge',
    'network',
    'issuedAt',
    'expiresAt',
  };

  factory _NativeSessionTicketEnvelope.fromNativeHandoff(
    Object? raw, {
    required String expectedAttemptId,
  }) {
    final ticket = _exactMap(
      raw,
      _ticketKeys,
      'nativeEstablishTicket',
    );
    final network = _exactMap(
      ticket['network'],
      const {'id', 'chainId'},
      'nativeEstablishTicket.network',
    );
    final protocol = ticket['protocol'];
    final attemptId = _canonicalString(
      ticket['attemptId'],
      'nativeEstablishTicket.attemptId',
    );
    final desiredRuntime = _canonicalString(
      ticket['desiredRuntime'],
      'nativeEstablishTicket.desiredRuntime',
    );
    final networkId = _canonicalString(
      network['id'],
      'nativeEstablishTicket.network.id',
    );
    if (protocol is! int ||
        protocol != 2 ||
        attemptId != expectedAttemptId ||
        desiredRuntime != 'running' ||
        networkId != 'testnet') {
      throw const NativeSessionException(
        'native_establish_request_mismatch',
        'The native handoff ticket does not match its request.',
      );
    }
    return _NativeSessionTicketEnvelope._(
      protocol: protocol,
      attemptId: attemptId,
      desiredRuntime: desiredRuntime,
      ticket:
          _canonicalString(ticket['ticket'], 'nativeEstablishTicket.ticket'),
      requestDigest: _canonicalString(
        ticket['requestDigest'],
        'nativeEstablishTicket.requestDigest',
      ),
      exchangeChallenge: _canonicalString(
        ticket['exchangeChallenge'],
        'nativeEstablishTicket.exchangeChallenge',
      ),
      networkId: networkId,
      chainId: _canonicalString(
        network['chainId'],
        'nativeEstablishTicket.network.chainId',
      ),
      issuedAt: _canonicalString(
        ticket['issuedAt'],
        'nativeEstablishTicket.issuedAt',
      ),
      expiresAt: _canonicalString(
        ticket['expiresAt'],
        'nativeEstablishTicket.expiresAt',
      ),
    );
  }

  @override
  String toString() => '_NativeSessionTicketEnvelope(<redacted>)';
}

enum _NativeCredentialServerRevocation { definitivelyAbsent, uncertain }

/// Purpose-specific interactive platform port. Android and iOS implement the
/// same closed contract; neither exposes a generic crypto/read API.
final class _NativeSessionPlatformPort {
  _NativeSessionPlatformPort({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channelName = 'com.onhomeroom.app/native_session';
  final MethodChannel _channel;
  Uint8List? _processTransportClaim;
  Future<void> Function(int nativeRevision)? _retirementHandler;
  int? _pendingRetiredRevision;

  void bindRetirementHandler(
    Future<void> Function(int nativeRevision) handler,
  ) {
    _retirementHandler = handler;
    final pending = _pendingRetiredRevision;
    _pendingRetiredRevision = null;
    if (pending != null) unawaited(handler(pending));
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method != 'nativeSessionRetired') {
      throw MissingPluginException('Unknown private native-session callback.');
    }
    final value = _exactMap(
      call.arguments,
      const {'nativeRevision'},
      'native session retirement callback',
    );
    final revision = value['nativeRevision'];
    if (revision is! int || revision < 0) {
      throw const NativeSessionException(
        'native_session_revision_invalid',
        'The native retirement revision is invalid.',
      );
    }
    final handler = _retirementHandler;
    if (handler == null) {
      _pendingRetiredRevision = revision;
    } else {
      await handler(revision);
    }
    return null;
  }

  Future<Uint8List> bootstrapInteractiveRoot({
    required String mobileApiBaseUrl,
  }) async {
    if (_processTransportClaim != null) {
      throw const NativeSessionException(
        'process_root_proof_already_issued',
        'The native process root was already claimed.',
      );
    }
    final raw = await _invokePlatform(
      'bootstrapInteractiveRoot',
      <String, Object?>{'mobileApiBaseUrl': mobileApiBaseUrl},
    );
    final value = _exactMap(
      raw,
      const {'processRootProof', 'processTransportClaim'},
      'native process root bootstrap',
    );
    final proof = _ownedNativeSecret(
      value['processRootProof'],
      code: 'process_root_proof_invalid',
      message: 'The native process-root proof is invalid.',
    );
    final transportClaim = _ownedNativeSecret(
      value['processTransportClaim'],
      code: 'process_root_proof_invalid',
      message: 'The native process-root proof is invalid.',
    );
    _processTransportClaim = transportClaim;
    return proof;
  }

  Future<Map<String, Object?>> prepareExchange(
    _NativeSessionTicketEnvelope ticket,
  ) async {
    final raw = await _invoke(
      'prepareNativeSessionExchange',
      {'nativeEstablishTicket': ticket.platformValue},
    );
    return _stringMap(raw, 'native exchange request');
  }

  Future<Map<String, Object?>> redeemHandoff(String attemptId) async {
    final raw = await _invoke(
      'redeemNativeSessionHandoff',
      {'attemptId': attemptId},
    );
    return _stringMap(raw, 'native handoff ticket');
  }

  Future<void> clearOrphanedSessionState() async {
    await _invoke('clearOrphanedNativeSessionState', const {});
  }

  Future<Uint8List> installCredential({
    required _NativeSessionTicketEnvelope ticket,
    required Map<String, Object?> exchange,
  }) async {
    final raw = await _invoke(
      'installNativeSessionCredential',
      {
        'nativeEstablishTicket': ticket.platformValue,
        'exchange': exchange,
      },
    );
    final result =
        _exactMap(raw, const {'installClaim'}, 'native install result');
    return _ownedNativeSecret(
      result['installClaim'],
      code: 'native_install_claim_invalid',
      message: 'The native credential install claim is invalid.',
    );
  }

  Future<void> discardUncommittedCredential({
    required String attemptId,
  }) async {
    if (attemptId.isEmpty || attemptId.length > 64) {
      throw const NativeSessionException(
        'invalid_native_establishment_cleanup',
        'The native attempt id is invalid.',
      );
    }
    await _invoke(
      'discardUncommittedNativeSessionCredential',
      {'attemptId': attemptId},
    );
  }

  Future<_NativeCredentialServerRevocation> revokeCredentialOnServer({
    required int expectedRevision,
  }) async {
    final raw = await _invoke(
      'revokeNativeSessionCredential',
      {'expectedRevision': expectedRevision},
    );
    final value = _exactMap(
      raw,
      const {'status'},
      'native credential revocation',
    );
    return switch (value['status']) {
      'definitivelyAbsent' =>
        _NativeCredentialServerRevocation.definitivelyAbsent,
      'uncertain' => _NativeCredentialServerRevocation.uncertain,
      _ => throw const NativeSessionException(
          'native_credential_revocation_result_invalid',
          'The native credential revocation result is invalid.',
        ),
    };
  }

  Future<void> retireCredential({
    required String credentialReference,
    required int credentialGeneration,
    required Uint8List vaultCommitment,
    required int readyRevision,
  }) async {
    if (credentialReference.isEmpty ||
        credentialGeneration <= 0 ||
        vaultCommitment.length != 32) {
      throw const NativeSessionException(
        'invalid_native_retirement',
        'The native credential retirement directive is invalid.',
      );
    }
    await _invoke(
      'retireNativeSessionCredential',
      {
        'credentialReference': credentialReference,
        'credentialGeneration': credentialGeneration,
        'vaultCommitment': vaultCommitment,
        'readyRevision': readyRevision,
      },
    );
  }

  Future<Map<String, Object?>> recoverSession({
    required int expectedRevision,
  }) async {
    final raw = await _invoke(
      'recoverNativeSession',
      {'expectedRevision': expectedRevision},
    );
    final value = _stringMap(raw, 'native recovery result');
    final status = value['status'];
    switch (status) {
      case 'present':
        if (value.keys
                .toSet()
                .difference(const {'status', 'installClaim'}).isNotEmpty ||
            value.length != 2) {
          break;
        }
        return {
          'status': 'present',
          'installClaim': _ownedNativeSecret(
            value['installClaim'],
            code: 'native_recovery_result_invalid',
            message: 'The native recovery result is invalid.',
          ),
        };
      case 'absent':
        if (value.keys
                .toSet()
                .difference(const {'status', 'nativeRevision'}).isNotEmpty ||
            value.length != 2 ||
            value['nativeRevision'] is! int) {
          break;
        }
        // `absent` means Rust has durably committed LoggedOut. Complete the
        // same process-root cleanup as a cold LoggedOut snapshot before this
        // API lets its caller publish signed-out.
        await clearOrphanedSessionState();
        return value;
      case 'uncertain':
        if (value.keys.toSet().difference(const {'status'}).isEmpty &&
            value.length == 1) {
          return value;
        }
    }
    throw const NativeSessionException(
      'native_recovery_result_invalid',
      'The native recovery result is invalid.',
    );
  }

  Future<int?> runInteractiveProducerWake({
    required int expectedRevision,
    required bool refreshPolicy,
  }) async {
    final raw = await _invoke(
      'runInteractiveProducerWake',
      {
        'expectedRevision': expectedRevision,
        'refreshPolicy': refreshPolicy,
      },
    );
    final value = _stringMap(raw, 'native producer wake result');
    final outcome = value['outcome'];
    if (outcome == 'retired') {
      if (value.keys.toSet().difference(
            const {'outcome', 'nativeRevision'},
          ).isNotEmpty ||
          value.length != 2 ||
          value['nativeRevision'] is! int ||
          (value['nativeRevision']! as int) < 0) {
        throw const NativeSessionException(
          'native_producer_wake_result_invalid',
          'The native producer wake result is invalid.',
        );
      }
      return value['nativeRevision']! as int;
    }
    if (value.keys.toSet().difference(const {'outcome'}).isNotEmpty ||
        value.length != 1 ||
        outcome is! String ||
        !const {'completed', 'retry', 'ignored', 'credentialAbsent'}
            .contains(outcome)) {
      throw const NativeSessionException(
        'native_producer_wake_result_invalid',
        'The native producer wake result is invalid.',
      );
    }
    if (outcome == 'credentialAbsent') {
      // The platform found the server no longer accepts this credential and
      // left Rust Ready, so the interactive owner retires it like any other
      // definitive absence instead of latching the process.
      throw const NativeSessionException(
        'native_credential_definitively_absent',
        'The authenticated native credential is no longer accepted.',
      );
    }
    if (outcome != 'completed') {
      throw const NativeSessionException(
        'native_producer_wake_incomplete',
        'Native block-production ownership is not ready.',
      );
    }
    return null;
  }

  Future<Uint8List> stageProducerPolicy({
    required int expectedRevision,
    bool? delegated,
  }) async {
    final raw = await _invoke(
      'stageNativeProducerPolicy',
      {
        'delegated': delegated,
        'expectedRevision': expectedRevision,
      },
    );
    final value = _exactMap(
      raw,
      const {'installClaim'},
      'native producer policy stage',
    );
    return _ownedNativeSecret(
      value['installClaim'],
      code: 'native_policy_claim_invalid',
      message: 'The native producer policy claim is invalid.',
    );
  }

  Future<SessionSocialPushStatus> readPushStatus({
    required int expectedRevision,
    required String installationId,
  }) async {
    final raw = await _invoke(
      'getNativePushStatus',
      {
        'installationId': installationId,
        'expectedRevision': expectedRevision,
      },
    );
    return _pushStatus(raw, mutationRevision: 0);
  }

  Future<SessionSocialPushStatus> registerPush({
    required int expectedRevision,
    required SessionSocialPushRegistration request,
  }) async {
    final raw = await _invoke(
      'registerNativePush',
      {
        'installationId': request.installationId,
        'providerToken': request.providerToken,
        'platform': request.platform,
        'permissionStatus': request.permissionStatus,
        'mutationRevision': request.mutationRevision,
        'expectedRevision': expectedRevision,
      },
    );
    return _pushStatus(raw, mutationRevision: request.mutationRevision);
  }

  Future<SessionSocialPushStatus> unregisterPush({
    required int expectedRevision,
    required SessionSocialPushUnregistration request,
  }) async {
    final raw = await _invoke(
      'unregisterNativePush',
      {
        'installationId': request.installationId,
        'mutationRevision': request.mutationRevision,
        'reason': request.reason,
        'expectedRevision': expectedRevision,
      },
    );
    return _pushStatus(raw, mutationRevision: request.mutationRevision);
  }

  Future<int> resolveLegacyZkPassportChallengeId({
    required int expectedRevision,
  }) async {
    final raw = await _invoke(
      'resolveNativeZkPassportChallenge',
      {'expectedRevision': expectedRevision},
    );
    final value = _exactMap(
      raw,
      const {'challengeId'},
      'native zkPassport challenge',
    );
    final challengeId = value['challengeId'];
    if (challengeId is! int || challengeId <= 0) {
      throw const NativeSessionException(
        'invalid_native_zk_completion_response',
        'The authenticated zkPassport challenge response is invalid.',
      );
    }
    return challengeId;
  }

  Future<SessionZkPassportCompletion> completeLegacyZkPassport({
    required int expectedRevision,
    required int challengeId,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) async {
    final raw = await _invoke(
      'completeNativeZkPassport',
      {
        'expectedRevision': expectedRevision,
        'challengeId': challengeId,
        'sessionId': sessionId,
        'nullifierHex': nullifierHex,
        'completedAt': completedAt,
      },
    );
    final value = _exactMap(
      raw,
      const {'challengeId'},
      'native zkPassport completion',
    );
    final returnedChallengeId = value['challengeId'];
    if (returnedChallengeId is! int ||
        returnedChallengeId <= 0 ||
        returnedChallengeId != challengeId) {
      throw const NativeSessionException(
        'invalid_native_zk_completion_response',
        'The authenticated zkPassport completion response is invalid.',
      );
    }
    return SessionZkPassportCompletion(challengeId: returnedChallengeId);
  }

  SessionSocialPushStatus _pushStatus(
    Object? raw, {
    required int mutationRevision,
  }) {
    final value = _stringMap(raw, 'native push status');
    const allowed = {
      'registered',
      'deliveryActive',
      'environment',
      'firebaseProjectId',
      'mutationRevision',
    };
    if (value.keys.any((key) => !allowed.contains(key)) ||
        value['registered'] is! bool ||
        value['deliveryActive'] is! bool ||
        value['environment'] is! String ||
        value['firebaseProjectId'] is! String) {
      throw const NativeSessionException(
        'invalid_native_push_response',
        'The authenticated push response is invalid.',
      );
    }
    final returnedRevision = value['mutationRevision'];
    if (returnedRevision != null && returnedRevision != mutationRevision) {
      throw const NativeSessionException(
        'invalid_native_push_response',
        'The authenticated push response is invalid.',
      );
    }
    return SessionSocialPushStatus(
      registered: value['registered']! as bool,
      deliveryActive: value['deliveryActive']! as bool,
      mutationRevision: returnedRevision as int? ?? mutationRevision,
    );
  }

  Future<Object?> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final claim = _processTransportClaim;
    if (claim == null) {
      throw const NativeSessionException(
        'process_root_unavailable',
        'The native process root is unavailable.',
      );
    }
    return _invokePlatform(
      method,
      <String, Object?>{
        ...arguments,
        'processTransportClaim': claim,
      },
    );
  }

  Future<Map<String, Object?>> restoreWebSession(int expectedRevision) async {
    final raw = await _invoke('restoreNativeWebSession', {
      'expectedRevision': expectedRevision,
    });
    return _exactMap(raw, const {'status', 'protocol', 'userId', 'attemptId'},
        'restored web session');
  }

  Future<Object?> _invokePlatform(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      final details = error.details is Map
          ? (error.details! as Map).cast<Object?, Object?>()
          : const <Object?, Object?>{};
      throw NativeSessionException(
        _canonicalErrorCode(details['code'] ?? error.code),
        error.message ?? 'The native session operation failed.',
        statusCode: details['statusCode'] as int?,
        latestMutationRevision: details['latestMutationRevision'] as int?,
      );
    }
  }
}

/// Exchanges only the public request for the server's installation-encrypted JWE.
final class _NativeSessionExchangeTransport {
  _NativeSessionExchangeTransport({required String mobileApiBaseUrl})
      : _endpoint = Uri.parse(
          '${mobileApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/'
          'auth/native-establish-exchange',
        );

  final Uri _endpoint;
  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 30);

  Future<Map<String, Object?>> exchange(Map<String, Object?> request) async {
    late http.StreamedResponse response;
    late Uint8List bodyBytes;
    try {
      final outbound = http.Request('POST', _endpoint)
        ..followRedirects = false
        ..headers.addAll(const {
          'accept': 'application/json',
          'content-type': 'application/json',
        })
        ..body = jsonEncode(request);
      response = await _client.send(outbound).timeout(_timeout);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw const NativeSessionException(
          'native_exchange_redirect_rejected',
          'The native credential exchange refused a redirect.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(_timeout)) {
        if (bytes.length + chunk.length > 70 * 1024) {
          throw const NativeSessionException(
            'native_exchange_response_too_large',
            'The native exchange response is too large.',
          );
        }
        bytes.add(chunk);
      }
      bodyBytes = bytes.takeBytes();
    } on NativeSessionException {
      rethrow;
    } catch (_) {
      throw const NativeSessionException(
        'native_exchange_unavailable',
        'The native credential exchange is unavailable.',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bodyBytes, allowMalformed: false));
    } catch (_) {
      throw const NativeSessionException(
        'native_exchange_response_invalid',
        'The native exchange response is invalid.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map ? decoded.cast<Object?, Object?>() : null;
      throw NativeSessionException(
        _canonicalErrorCode(error?['code']),
        error?['error'] is String
            ? error!['error']! as String
            : 'The native credential exchange was rejected.',
      );
    }
    final root =
        _exactMap(decoded, const {'success', 'data'}, 'exchange response');
    if (root['success'] != true) {
      throw const NativeSessionException(
        'native_exchange_response_invalid',
        'The native exchange response is invalid.',
      );
    }
    final data = _exactMap(
      root['data'],
      const {
        'protocol',
        'attemptId',
        'requestDigest',
        'credentialReference',
        'credentialGeneration',
        'envelope',
      },
      'exchange response data',
    );
    _exactMap(
      data['envelope'],
      const {'format', 'algorithm', 'encryption', 'keyId', 'compactJwe'},
      'exchange response envelope',
    );
    return data;
  }

  void close() => _client.close();
}

/// Claims the private interactive process root and returns only its closed
/// Social bridge ingress. Bootstrap failure is represented by a permanently
/// failing protocol-2 ingress so runtime health can never select legacy APIs.
abstract interface class _NativeSessionRuntime {
  NativeSessionBridgeIngress get bridge;

  SessionFeatureAccessView get sessions;

  Future<void> appLifecycleStateChanged(AppLifecycleState state);
}

Future<_NativeSessionRuntime> _bootstrapNativeSessionRuntime() async {
  await _waitForInteractiveSessionBootstrapAdmission();
  final platform = _NativeSessionPlatformPort();
  final exchange = _NativeSessionExchangeTransport(
    mobileApiBaseUrl: AppConfig.mobileApiBaseUrl,
  );
  try {
    return await _NativeSessionCompositionRoot.bootstrap(
      platform: platform,
      exchange: exchange,
    );
  } catch (error, stackTrace) {
    exchange.close();
    final failure = _asNativeSessionException(error);
    LoggingService.instance.error(
      'Native session bootstrap failed (${failure.code})',
      tag: 'usernode/NativeSession',
      error: failure,
      stackTrace: stackTrace,
    );
    return _FailingNativeSessionBridgeIngress(failure);
  }
}

Future<void> _waitForInteractiveSessionBootstrapAdmission() async {
  if (!Platform.isIOS ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    return;
  }

  final resumed = Completer<void>();
  late final AppLifecycleListener listener;
  listener = AppLifecycleListener(
    onResume: () {
      if (!resumed.isCompleted) resumed.complete();
    },
  );
  try {
    // Close the gap between the initial check and observer registration.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      await resumed.future;
    }
  } finally {
    listener.dispose();
  }
}

const _nativeDelegationAddress =
    'B62qiTKpEPjGTSHZrtM8uXiKgn8So916pLmNJKDhKeyBQL9TDb3nvBG';

final class _NativeSessionEffects implements _SessionEffectSink {
  // Include reads from every effects instance, including a retiring session.
  static final _delegationReadMonitor = SlowOperationMonitor();

  _NativeSessionEffects({
    required native.ProcessRootClient root,
    required native.SessionNativeClient session,
    required _NativeSessionPlatformPort platform,
    required SessionIdentityProjection identity,
    required void Function(Object error, StackTrace stackTrace) onFailure,
  })  : _root = root,
        _session = session,
        _platform = platform,
        _identity = identity,
        _onFailure = onFailure,
        _revision = _platformRevision(BigInt.parse(identity.nativeRevision));

  final native.ProcessRootClient _root;
  final native.SessionNativeClient _session;
  final _NativeSessionPlatformPort _platform;
  final SessionIdentityProjection _identity;
  final void Function(Object error, StackTrace stackTrace) _onFailure;
  final int _revision;
  final Stopwatch _stallClock = Stopwatch()..start();
  _NativeSyncProgress? _lastSyncProgress;
  int? _unchangedSinceMs;

  @override
  void reportFailure(Object error, StackTrace stackTrace) {
    _onFailure(error, stackTrace);
  }

  void _requireWallet() {
    if (!_identity.hasWallet) {
      throw const NativeSessionException(
        'native_wallet_unavailable',
        'This session has no wallet.',
      );
    }
  }

  @override
  Future<SessionNodeStatus> readNodeStatus() async {
    if (!_identity.hasWallet) {
      return const SessionNodeStatus(status: 'unavailable');
    }
    final status = await native.nativeNodeStatus(
      root: _root,
      session: _session,
    );
    final syncing = status.syncState == native.NativeNodeSyncState.syncing;
    final progress = _NativeSyncProgress(
      height: status.bestTipHeight,
      fetched: status.syncFetchDone,
      applied: status.syncApplyDone,
    );
    final now = _stallClock.elapsedMilliseconds;
    var stalled = false;
    if (!syncing) {
      _lastSyncProgress = null;
      _unchangedSinceMs = null;
    } else if (_lastSyncProgress != progress || _unchangedSinceMs == null) {
      _lastSyncProgress = progress;
      _unchangedSinceMs = now;
    } else {
      final blockThreshold = status.blockIntervalMs * 3;
      final threshold =
          max(const Duration(seconds: 60).inMilliseconds, blockThreshold);
      stalled = now - _unchangedSinceMs! >= threshold;
    }
    return SessionNodeStatus(
      status: status.syncState.name,
      chain: status.chainName ?? status.chainId,
      localBestHeight: status.bestTipHeight,
      networkBestHeight: status.networkBestHeight,
      readyPeers: status.connectedPeers,
      totalPeers: status.totalPeers,
      syncStalled: stalled,
      clockDriftMs: status.clockDriftMs,
      walletDataHydrating: status.walletDataHydrating,
    );
  }

  @override
  Future<SessionWalletSnapshot> readWallet() async {
    _requireWallet();
    final balance = await native.nativeWalletBalance(
      root: _root,
      session: _session,
    );
    final delegation = await _delegationSnapshot(caller: 'readWallet');
    return SessionWalletSnapshot(
      address: _identity.address!,
      balance: balance.tracked ? balance.total : null,
      tokenAmount: balance.tracked ? balance.total.toDouble() : null,
      tokenSymbol:
          balance.tracked && balance.total > BigInt.zero ? 'TKN' : 'TOKENS',
      lastUpdatedMs: DateTime.now().millisecondsSinceEpoch,
      delegation: delegation,
    );
  }

  @override
  Future<SessionTransactionSubmission> submitTransaction({
    required String destinationAddress,
    required BigInt amount,
    required String memo,
  }) async {
    _requireWallet();
    final result = await native.nativeWalletSend(
      root: _root,
      session: _session,
      request: native.NativeWalletSendRequest(
        recipientAddress: destinationAddress,
        amount: amount,
        memo: memo,
      ),
    );
    final transactionId = result.transactionId;
    if (result.state != native.NativeWalletSendState.ready ||
        !result.queued ||
        transactionId == null ||
        transactionId.isEmpty) {
      throw NativeSessionException(
        result.state == native.NativeWalletSendState.syncing
            ? 'native_wallet_syncing'
            : 'native_wallet_submission_failed',
        result.error ?? 'The transaction could not be queued.',
      );
    }
    return SessionTransactionSubmission(transactionId: transactionId);
  }

  @override
  Future<SessionMessageSignature> signMessage(String message) async {
    _requireWallet();
    final result = await native.nativeSignMessage(
      root: _root,
      session: _session,
      message: message,
    );
    if (result.address != _identity.address) {
      throw const NativeSessionException(
        'native_signature_identity_mismatch',
        'The native signature belongs to a different identity.',
      );
    }
    return SessionMessageSignature(
      publicKey: result.publicKey,
      signature: result.signature,
    );
  }

  @override
  Future<perf_types.PerfCatalog> readDeviceBenchmarkCatalog() async =>
      native.nativeDeviceBenchmarkCatalog();

  @override
  Future<perf_types.PerfRunHandle> startDeviceBenchmark(
    perf_types.PerfRunProfile profile,
  ) =>
      native.nativeDeviceBenchmarkStart(
        root: _root,
        session: _session,
        request: perf_types.PerfRunRequest(profile: profile),
      );

  @override
  Future<perf_types.PerfRunStatus?> readDeviceBenchmarkStatus(
          int runId) async =>
      native.nativeDeviceBenchmarkStatus(
        root: _root,
        session: _session,
        runId: BigInt.from(runId),
      );

  @override
  Future<perf_types.PerfRunReport?> readDeviceBenchmarkResult(
          int runId) async =>
      native.nativeDeviceBenchmarkResult(
        root: _root,
        session: _session,
        runId: BigInt.from(runId),
      );

  @override
  Future<bool> cancelDeviceBenchmark(int runId) =>
      native.nativeDeviceBenchmarkCancel(
        root: _root,
        session: _session,
        runId: BigInt.from(runId),
      );

  @override
  Future<SessionObservabilityRecordResult> recordObservability({
    required SessionObservabilityKind kind,
    required String event,
    String? payloadJson,
  }) async {
    final result = await native.nativeObservabilityRecord(
      root: _root,
      session: _session,
      kind: native.NativeObservabilityKind.values.byName(kind.name),
      event: event,
      payloadJson: payloadJson,
    );
    return SessionObservabilityRecordResult(
      queued: result.queued,
      discarded: result.discarded,
      reason: result.reason,
    );
  }

  @override
  Future<SessionZkPassportVerifyOuterResult> verifyZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  }) async {
    final result = await native.nativeZkpassportVerifyOuter(
      root: _root,
      session: _session,
      outerProof: outerProof,
      facematchStrict: facematchStrict,
    );
    return SessionZkPassportVerifyOuterResult(
      verified: result.verified,
      elapsedMs: result.elapsedMs.toInt(),
      publicInputsHex: result.publicInputsHex,
      error: result.error,
    );
  }

  @override
  Future<SessionZkPassportWrapOuterResult> wrapZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  }) async {
    final result = await native.nativeZkpassportWrapOuter(
      root: _root,
      session: _session,
      outerProof: outerProof,
      facematchStrict: facematchStrict,
    );
    return SessionZkPassportWrapOuterResult(
      wrapped: result.wrapped,
      elapsedMs: result.elapsedMs.toInt(),
      wrappedProofB64Url: result.wrappedProofB64Url,
      wrappedProofSizeBytes: result.wrappedProofSizeBytes,
      error: result.error,
    );
  }

  @override
  Future<SessionZkPassportVerifyWrappedResult> verifyZkPassportWrapped({
    required List<int> wrappedProof,
    required bool facematchStrict,
  }) async {
    final result = await native.nativeZkpassportVerifyWrapped(
      root: _root,
      session: _session,
      wrappedProof: wrappedProof,
      facematchStrict: facematchStrict,
    );
    return SessionZkPassportVerifyWrappedResult(
      verified: result.verified,
      elapsedMs: result.elapsedMs.toInt(),
      error: result.error,
    );
  }

  @override
  Future<int> resolveLegacyZkPassportChallengeId() =>
      _platform.resolveLegacyZkPassportChallengeId(
        expectedRevision: _revision,
      );

  @override
  Future<SessionZkPassportCompletion> completeLegacyZkPassport({
    required int challengeId,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) =>
      _platform.completeLegacyZkPassport(
        expectedRevision: _revision,
        challengeId: challengeId,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
        completedAt: completedAt,
      );

  @override
  Future<SessionDelegationSnapshot> readDelegation() async {
    _requireWallet();
    return _delegationSnapshot(caller: 'readDelegation');
  }

  @override
  Future<SessionDelegationSnapshot> setDelegated(bool delegated) async {
    _requireWallet();
    final claim = await _platform.stageProducerPolicy(
      expectedRevision: _revision,
      delegated: delegated,
    );
    try {
      await native.applyNativeProducerPolicy(
        root: _root,
        session: _session,
        installClaim: native.NativeProducerPolicyInstallClaim(token: claim),
      );
    } finally {
      claim.fillRange(0, claim.length, 0);
    }
    await _platform.runInteractiveProducerWake(
      expectedRevision: _revision,
      refreshPolicy: false,
    );
    return _delegationSnapshot(caller: 'setDelegated');
  }

  Future<SessionDelegationSnapshot> _delegationSnapshot({
    required String caller,
  }) async {
    const threshold = Duration(seconds: 5);
    final state = await _delegationReadMonitor.run(
      operation: () => native.nativeDelegationState(
        root: _root,
        session: _session,
      ),
      threshold: threshold,
      report: (pendingCallers) => SentryUtil.captureMessageWithData(
        'native_delegation_state exceeded 5s',
        {
          'operation': 'native_delegation_state',
          'caller': caller,
          'threshold_ms': threshold.inMilliseconds,
          'pending_callers': pendingCallers,
        },
        level: SentryLevel.warning,
      ),
    );
    if (state == null || state.epochs.isEmpty) {
      return const SessionDelegationSnapshot(delegated: false);
    }
    final epochs = [...state.epochs]
      ..sort((a, b) => a.epoch.compareTo(b.epoch));
    final effective = epochs.last;
    return SessionDelegationSnapshot(
      delegated: effective.delegated,
      delegateAddress: effective.delegated ? _nativeDelegationAddress : null,
      effectiveEpoch: effective.epoch,
    );
  }

  @override
  Future<SessionSleepySnapshot> readSleepy() async {
    final snapshot = await native.nativeSleepyStatus(
      root: _root,
      session: _session,
    );
    return SessionSleepySnapshot(
      enabled: snapshot.enabled,
      decision: snapshot.decision.toString(),
    );
  }

  @override
  Future<SessionSleepySnapshot> setSleepyEnabled(bool enabled) async {
    final snapshot = await native.nativeSleepy(
      root: _root,
      session: _session,
      enabled: enabled,
    );
    if (Platform.isAndroid && _identity.hasWallet) {
      try {
        await _platform.runInteractiveProducerWake(
          expectedRevision: _revision,
          refreshPolicy: false,
        );
        LoggingService.instance.info(
          'Android sleepy ownership synchronized',
          tag: 'usernode/Sleepy',
          context: {
            'enabled': snapshot.enabled,
            'decision': snapshot.decision.toString(),
            'nativeRevision': _revision,
          },
        );
      } catch (error) {
        // The native coordinator retains foreground retry ownership whenever
        // an alarm transaction cannot be completed. The policy write itself
        // remains valid and the service/watchdog will retry without letting an
        // Android runtime enter an uncommitted sleep.
        LoggingService.instance.warn(
          'Android sleepy ownership will retry (${error.runtimeType})',
          tag: 'usernode/Sleepy',
          context: {
            'enabled': snapshot.enabled,
            'decision': snapshot.decision.toString(),
            'nativeRevision': _revision,
          },
        );
      }
    }
    return SessionSleepySnapshot(
      enabled: snapshot.enabled,
      decision: snapshot.decision.toString(),
    );
  }

  @override
  Future<SessionSocialPushStatus> readSocialPushStatus({
    required String installationId,
  }) =>
      _platform.readPushStatus(
        expectedRevision: _revision,
        installationId: installationId,
      );

  @override
  Future<SessionSocialPushStatus> registerSocialPush(
    SessionSocialPushRegistration request,
  ) =>
      _platform.registerPush(expectedRevision: _revision, request: request);

  @override
  Future<SessionSocialPushStatus> unregisterSocialPush(
    SessionSocialPushUnregistration request,
  ) =>
      _platform.unregisterPush(expectedRevision: _revision, request: request);
}

final class _NativeSyncProgress {
  const _NativeSyncProgress({
    required this.height,
    required this.fetched,
    required this.applied,
  });

  final int height;
  final int fetched;
  final int applied;

  @override
  bool operator ==(Object other) =>
      other is _NativeSyncProgress &&
      height == other.height &&
      fetched == other.fetched &&
      applied == other.applied;

  @override
  int get hashCode => Object.hash(height, fetched, applied);
}

final class _NativeReadyBinding {
  const _NativeReadyBinding({
    required this.session,
    required this.readyRevision,
    required this.projection,
    required this.effects,
    required this.attemptId,
    this.realmMarker,
    this.realmClaim,
  }) : assert((realmMarker == null) == (realmClaim == null));

  final native.SessionNativeClient session;
  final int readyRevision;
  final SessionIdentityProjection projection;
  final _SessionEffectSink effects;
  final String attemptId;
  final String? realmMarker;
  final String? realmClaim;

  bool authorizesRealm(String marker, [String? claim]) =>
      realmMarker == marker &&
      realmClaim != null &&
      (claim == null || realmClaim == claim);
}

enum _NativeCommitDisposition { notCommitted, uncertain, ready }

enum _NativeTerminalKind { processRoot, localLogout }

final class _NativeTerminalIntent {
  const _NativeTerminalIntent.processRoot()
      : kind = _NativeTerminalKind.processRoot;

  const _NativeTerminalIntent.localLogout()
      : kind = _NativeTerminalKind.localLogout;

  final _NativeTerminalKind kind;
}

final class _NativeEstablishAttempt {
  _NativeEstablishAttempt(this.realmMarker, {this.priorBinding})
      : disposition = priorBinding == null
            ? _NativeCommitDisposition.notCommitted
            : _NativeCommitDisposition.ready,
        binding = priorBinding;

  final String realmMarker;
  final _NativeReadyBinding? priorBinding;
  final Completer<void> settled = Completer<void>();
  _NativeCommitDisposition disposition;
  _NativeReadyBinding? binding;
  _NativeTerminalIntent? terminalIntent;

  void markUncertain() {
    disposition = _NativeCommitDisposition.uncertain;
  }

  void restorePreCommitState() {
    disposition = priorBinding == null
        ? _NativeCommitDisposition.notCommitted
        : _NativeCommitDisposition.ready;
    binding = priorBinding;
  }

  void retainReady(_NativeReadyBinding value) {
    binding = value;
    disposition = _NativeCommitDisposition.ready;
  }
}

sealed class _NativeAuthorityState {
  const _NativeAuthorityState();
}

final class _NativeSignedOut extends _NativeAuthorityState {
  const _NativeSignedOut();
}

final class _NativeEstablishing extends _NativeAuthorityState {
  const _NativeEstablishing(this.attempt);

  final _NativeEstablishAttempt attempt;
}

final class _NativeReady extends _NativeAuthorityState {
  const _NativeReady(this.binding);

  final _NativeReadyBinding binding;
}

final class _NativeClosing extends _NativeAuthorityState {
  _NativeClosing({required this.intent, required this.binding});

  final _NativeTerminalIntent intent;
  final _NativeReadyBinding? binding;
  Future<void>? active;
  bool retryable = false;
}

final class _NativeRecoveryRequired extends _NativeAuthorityState {
  const _NativeRecoveryRequired();
}

_NativeAuthorityState _settledEstablishState(
  _NativeEstablishAttempt attempt,
) {
  final terminal = attempt.terminalIntent;
  switch (attempt.disposition) {
    case _NativeCommitDisposition.notCommitted:
      return terminal == null
          ? const _NativeSignedOut()
          : _NativeClosing(intent: terminal, binding: null);
    case _NativeCommitDisposition.uncertain:
      return const _NativeRecoveryRequired();
    case _NativeCommitDisposition.ready:
      final binding = attempt.binding;
      if (binding == null) return const _NativeRecoveryRequired();
      return terminal == null
          ? _NativeReady(binding)
          : _NativeClosing(intent: terminal, binding: binding);
  }
}

enum _ForegroundAdmissionPhase { open, suspended, validating, terminal }

final class _ForegroundAdmissionGate {
  _ForegroundAdmissionPhase _phase = _ForegroundAdmissionPhase.open;
  Future<void>? _validation;
  int _generation = 0;

  Future<void>? barrier() {
    switch (_phase) {
      case _ForegroundAdmissionPhase.open:
        return null;
      case _ForegroundAdmissionPhase.validating:
        return _validation;
      case _ForegroundAdmissionPhase.suspended:
        throw const SessionAdmissionClosedException();
      case _ForegroundAdmissionPhase.terminal:
        throw const NativeSessionException(
          'native_session_terminally_retired',
          'The native session was retired; relaunch is required.',
        );
    }
  }

  void suspend() {
    if (_phase == _ForegroundAdmissionPhase.terminal) return;
    _generation++;
    _phase = _ForegroundAdmissionPhase.suspended;
  }

  Future<void> resume(Future<void> Function() validate) {
    // Open means the app never left the foreground, so there is nothing to
    // revalidate.
    if (_phase == _ForegroundAdmissionPhase.terminal ||
        _phase == _ForegroundAdmissionPhase.open) {
      return Future<void>.value();
    }
    final active = _validation;
    if (_phase == _ForegroundAdmissionPhase.validating && active != null) {
      return active;
    }

    final previous = _validation;
    final generation = ++_generation;
    _phase = _ForegroundAdmissionPhase.validating;
    late Future<void> validation;
    validation = (() async {
      if (previous != null) await previous;
      if (_generation != generation ||
          _phase != _ForegroundAdmissionPhase.validating) {
        return;
      }
      await validate();
    })()
        .whenComplete(() {
      if (_generation == generation &&
          _phase == _ForegroundAdmissionPhase.validating &&
          identical(_validation, validation)) {
        _validation = null;
        _phase = _ForegroundAdmissionPhase.open;
      }
    });
    _validation = validation;
    return validation;
  }

  Future<void> waitUntilOpen() async {
    while (true) {
      final current = barrier();
      if (current == null) return;
      await current;
    }
  }

  void retire() {
    _generation++;
    _validation = null;
    _phase = _ForegroundAdmissionPhase.terminal;
  }
}

final class _NativeSessionCompositionRoot
    implements _NativeSessionRuntime, NativeSessionBridgeIngress {
  _NativeSessionCompositionRoot._({
    required native.ProcessRootClient root,
    required _NativeSessionPlatformPort platform,
    required _NativeSessionExchangeTransport exchange,
    required _SessionCompositionRoot sessions,
    required _NativeAuthorityState authority,
  })  : _root = root,
        _platform = platform,
        _exchange = exchange,
        _sessions = sessions,
        _authority = authority {
    _platform.bindRetirementHandler(_retireFromNative);
    _sessions.bindTopLevelAdmissionGate(_foregroundAdmission.barrier);
  }

  static Future<_NativeSessionCompositionRoot> bootstrap({
    required _NativeSessionPlatformPort platform,
    required _NativeSessionExchangeTransport exchange,
  }) async {
    final proofBytes = await platform.bootstrapInteractiveRoot(
      mobileApiBaseUrl: AppConfig.mobileApiBaseUrl,
    );
    try {
      final root = native.takeProcessRoot(
        proof: native.ProcessRootProof(token: proofBytes),
      );
      final snapshot = native.processRootSnapshot(root: root);
      return await snapshot.when(
        loggedOut: (nativeRevision) async {
          // Rust LoggedOut is the authoritative crash-recovery boundary. Do
          // not publish signed-out state while an orphaned platform credential
          // or producer selector can still survive from an interrupted close.
          await platform.clearOrphanedSessionState();
          return _NativeSessionCompositionRoot._(
            root: root,
            platform: platform,
            exchange: exchange,
            sessions: _SessionCompositionRoot(
              SessionIdentityProjection.signedOut(
                nativeRevision: _canonicalRevision(nativeRevision),
              ),
            ),
            authority: const _NativeSignedOut(),
          );
        },
        ready: (nativeRevision, attemptId, identity, runtimeStatus) async {
          _logNativeRuntimeStatus(runtimeStatus, source: 'warm_ready');
          final session = native.currentNativeSession(
            root: root,
            expectedRevision: nativeRevision,
          );
          return _readyRoot(
            root: root,
            platform: platform,
            exchange: exchange,
            nativeRevision: nativeRevision,
            attemptId: attemptId,
            identity: identity,
            session: session,
          );
        },
        recoverableReady: (nativeRevision, attemptId, identity) async {
          final recovery = await platform.recoverSession(
            expectedRevision: _platformRevision(nativeRevision),
          );
          switch (recovery['status']) {
            case 'absent':
              return _NativeSessionCompositionRoot._(
                root: root,
                platform: platform,
                exchange: exchange,
                sessions: _SessionCompositionRoot(
                  SessionIdentityProjection.signedOut(
                    nativeRevision:
                        (recovery['nativeRevision']! as int).toString(),
                  ),
                ),
                authority: const _NativeSignedOut(),
              );
            case 'uncertain':
              throw const NativeSessionException(
                'native_session_recovery_uncertain',
                'The native credential could not be validated yet.',
              );
            case 'present':
              final claim = recovery['installClaim']! as Uint8List;
              late native.NativeEstablishResult adopted;
              try {
                adopted = await native.adoptNativeSession(
                  root: root,
                  expectedRevision: nativeRevision,
                  installClaim: native.NativeCredentialInstallClaim(
                    token: claim,
                  ),
                );
              } finally {
                claim.fillRange(0, claim.length, 0);
              }
              _validateAdoption(
                adopted,
                nativeRevision,
                attemptId,
                identity,
              );
              _logNativeRuntimeStatus(
                adopted.runtimeStatus,
                source: 'cold_recovery',
              );
              final session = native.currentNativeSession(
                root: root,
                expectedRevision: nativeRevision,
              );
              return _readyRoot(
                root: root,
                platform: platform,
                exchange: exchange,
                nativeRevision: nativeRevision,
                attemptId: attemptId,
                identity: identity,
                session: session,
              );
          }
          throw const NativeSessionException(
            'native_recovery_result_invalid',
            'The native recovery result is invalid.',
          );
        },
        transitionInProgress: (_) async {
          // TODO(session-lifecycle): A rare cold Android background-start/UI
          // overlap can reach this state. Keep bootstrap fail-closed and
          // require a relaunch; do not add a second recovery coordinator.
          throw const NativeSessionException(
            'native_session_transition_in_progress',
            'A native session transition is already in progress.',
          );
        },
        recoveryRequired: (_) async => throw const NativeSessionException(
          'native_session_recovery_required',
          'The native session requires recovery.',
        ),
      );
    } finally {
      proofBytes.fillRange(0, proofBytes.length, 0);
    }
  }

  static Future<_NativeSessionCompositionRoot> _readyRoot({
    required native.ProcessRootClient root,
    required _NativeSessionPlatformPort platform,
    required _NativeSessionExchangeTransport exchange,
    required BigInt nativeRevision,
    required String attemptId,
    required native.NativeIdentity identity,
    required native.SessionNativeClient session,
  }) async {
    final projection = _readyProjection(nativeRevision, identity);
    late final _NativeSessionCompositionRoot runtime;
    final effects = _NativeSessionEffects(
      root: root,
      session: session,
      platform: platform,
      identity: projection,
      onFailure: (error, stackTrace) =>
          runtime._handleEffectFailure(error, stackTrace),
    );
    final readyRevision = _platformRevision(nativeRevision);
    final binding = _NativeReadyBinding(
      session: session,
      readyRevision: readyRevision,
      projection: projection,
      effects: effects,
      attemptId: attemptId,
    );
    runtime = _NativeSessionCompositionRoot._(
      root: root,
      platform: platform,
      exchange: exchange,
      sessions: _SessionCompositionRoot(projection, readyEffects: effects),
      authority: _NativeReady(binding),
    );
    // The first Flutter frame starts foreground reconciliation. Until then,
    // node-backed operations are closed, but constructing the trusted UI no
    // longer waits for producer-policy HTTP or Android alarm ownership.
    runtime._foregroundAdmission.suspend();
    return runtime;
  }

  final native.ProcessRootClient _root;
  final _NativeSessionPlatformPort _platform;
  final _NativeSessionExchangeTransport _exchange;
  final _SessionCompositionRoot _sessions;
  final Random _random = Random.secure();

  _NativeAuthorityState _authority;
  final _ForegroundAdmissionGate _foregroundAdmission =
      _ForegroundAdmissionGate();
  Future<void>? _nativeRetirement;
  final _terminalRetirements = StreamController<void>.broadcast(sync: true);

  @override
  NativeSessionBridgeIngress get bridge => this;

  @override
  bool get terminallyRetired => _authority is _NativeRecoveryRequired;

  @override
  Stream<void> get terminalRetirements => _terminalRetirements.stream;

  @override
  SessionFeatureAccessView get sessions => _sessions.view;

  @override
  Future<void> appLifecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      return _foregroundAdmission.resume(_performForegroundResume);
    }
    // Inactive is not background: Android reports it for system dialogs such
    // as runtime permission prompts. Suspending here would force a full
    // producer wake on the way back. Real backgrounding reports hidden next.
    if (state == AppLifecycleState.inactive) return Future<void>.value();
    final sleepyTransition = _sessions.prepareForAppBackground();
    _foregroundAdmission.suspend();
    return sleepyTransition.onError((error, stackTrace) {
      LoggingService.instance.error(
        'Could not enable sleepy mode for app background',
        tag: 'usernode/Sleepy',
        error: error,
        stackTrace: stackTrace,
      );
    });
  }

  Future<void> _performForegroundResume() async {
    final authority = _authority;
    if (authority is! _NativeReady) return;
    if (!authority.binding.projection.hasWallet) return;
    var sleepyReconciled = false;
    try {
      // Make foreground-only transaction-surface leases effective before any
      // producer wake can decide to commit an Android sleep.
      await _sessions.reconcileAfterForegroundResume();
      sleepyReconciled = true;
    } catch (_) {
      // The coordinator logs the complete failure and the next lifecycle or
      // lease transition retries the desired policy.
    }
    if (terminallyRetired || (Platform.isAndroid && sleepyReconciled)) return;
    // Android sleepy reconciliation already enters the native wake
    // coordinator. Other platforms, or a failed Rust sleepy call, still need
    // the explicit producer wake/retirement check.
    if (authority.binding.projection.hasWallet) {
      try {
        final retiredRevision = await _platform.runInteractiveProducerWake(
          expectedRevision: authority.binding.readyRevision,
          refreshPolicy: true,
        );
        if (retiredRevision != null) {
          await _retireFromNative(retiredRevision);
        }
      } catch (error) {
        if (_isDefinitiveCredentialAbsence(error)) {
          // The server ended this session while the app was closed or in the
          // background. Retire it inside foreground validation so the page is
          // admitted only after signed-out is published.
          await _retireDefinitivelyAbsentLogged();
          return;
        }
        // A retry leaves Rust Ready and is attempted again at the next bounded
        // resume. Keep this method non-throwing because lifecycle delivery has
        // no awaiting error owner.
        LoggingService.instance.warn(
          'Native producer wake will retry (${error.runtimeType})',
          tag: 'usernode/NativeSession',
        );
      }
    }
  }

  Future<void> _retireFromNative(int nativeRevision) {
    final active = _nativeRetirement;
    if (active != null) return active;
    late Future<void> retirement;
    retirement = _commitNativeRetirement(nativeRevision).whenComplete(() {
      if (identical(_nativeRetirement, retirement)) _nativeRetirement = null;
    });
    _nativeRetirement = retirement;
    return retirement;
  }

  Future<void> _commitNativeRetirement(int nativeRevision) async {
    // Rust deliberately leaves warm definitive absence as RecoveryRequired so
    // Android wake paths can terminate. The process latch also closes native
    // operations on iOS and foreground Android until natural relaunch: Rust
    // refuses every session mutation from RecoveryRequired, so no sign-in can
    // succeed in this process either. Interactive iOS wakes avoid this state
    // by reporting absence to the owner (see _retireDefinitivelyAbsent).
    _enterRecoveryRequired();
    final signedOut = SessionIdentityProjection.signedOut(
      nativeRevision: nativeRevision.toString(),
    );
    await _sessions.closeAndDrain();
    _sessions.publishSignedOut(signedOut);
  }

  void _enterRecoveryRequired() {
    if (_authority is _NativeRecoveryRequired) return;
    _authority = const _NativeRecoveryRequired();
    _foregroundAdmission.retire();
    unawaited(_sessions.closeAndDrain());
    _terminalRetirements.add(null);
  }

  void _handleEffectFailure(Object error, StackTrace _) {
    if (_authority is! _NativeReady || !_isDefinitiveCredentialAbsence(error)) {
      return;
    }
    // Close admission before releasing the failing effect lease. Retirement
    // then drains that exact scope without any per-feature failure guards.
    unawaited(_sessions.closeAndDrain());
    unawaited(_retireDefinitivelyAbsentLogged());
  }

  Future<void> _retireDefinitivelyAbsentLogged() =>
      _retireDefinitivelyAbsent().catchError(
        (Object retirementError, StackTrace _) {
          LoggingService.instance.warn(
            'Definitive native credential retirement failed '
            '(${retirementError.runtimeType})',
            tag: 'usernode/NativeSession',
          );
        },
      );

  /// Retires a Ready session whose server credential is definitively absent:
  /// the account was deleted, the session was revoked or signed out elsewhere,
  /// or its lease ended. This is the ordinary root retirement, so on success
  /// Rust has durably committed LoggedOut and the platform vault is clear,
  /// which is the same state a cold launch would recover. The process stays
  /// usable and a later sign-in may establish a new session.
  Future<void> _retireDefinitivelyAbsent() async {
    if (_authority is! _NativeReady) return;
    try {
      await _retireAuthority(const _NativeTerminalIntent.processRoot());
    } catch (_) {
      // A retirement that did not complete leaves native state unknown. Even
      // an unexpected local failure must not reopen a process whose server
      // credential is definitively absent, so latch until relaunch.
      _enterRecoveryRequired();
      rethrow;
    }
  }

  @override
  Future<T> runSessionOperation<T>({
    required String realmMarker,
    required String realmSessionClaim,
    required FutureOr<T> Function(
      SessionIdentityProjection identity,
      SessionOperation operation,
    ) body,
  }) async {
    await _foregroundAdmission.waitUntilOpen();
    _validateRealmMarker(realmMarker);
    final authority = _authority;
    if (authority is _NativeRecoveryRequired) {
      _throwTerminallyRetired();
    }
    if (authority is! _NativeReady) {
      throw const NativeSessionException(
        'native_session_not_ready',
        'There is no ready native session.',
      );
    }
    if (!authority.binding.authorizesRealm(
      realmMarker,
      realmSessionClaim,
    )) {
      throw const NativeSessionException(
        'native_session_realm_mismatch',
        'The native session belongs to a different page realm.',
      );
    }
    final access = _sessions.view.current;
    return access.operations.run(
      (operation) => body(access.identity, operation),
    );
  }

  @override
  Future<Map<String, Object?>> establishNativeSession({
    required Map<String, dynamic> payload,
    required String realmMarker,
  }) async {
    _validateRealmMarker(realmMarker);
    final intent = _NativeSessionEstablishIntent.fromBridgePayload(payload);
    final attempt = _beginEstablish(intent, realmMarker);
    String? installedAttemptId;
    try {
      final rawTicket = await _platform.redeemHandoff(intent.attemptId);
      final ticket = _NativeSessionTicketEnvelope.fromNativeHandoff(
        rawTicket,
        expectedAttemptId: intent.attemptId,
      );
      final exchangeRequest = await _platform.prepareExchange(ticket);
      final exchangeResult = await _exchange.exchange(exchangeRequest);
      installedAttemptId = ticket.attemptId;
      attempt.markUncertain();
      final claimBytes = await _platform.installCredential(
        ticket: ticket,
        exchange: exchangeResult,
      );
      // Rust has not been invoked yet, so exact platform cleanup can still
      // prove this attempt non-authoritative if a later preparation step fails.
      attempt.restorePreCommitState();

      late native.NativeEstablishResult receipt;
      try {
        // Once the mutation is invoked, an error cannot prove Rust did not
        // commit. Only cold recovery may resolve that uncertainty.
        attempt.markUncertain();
        receipt = await native.establishNativeSession(
          root: _root,
          request: native.NativeEstablishRequest(
            attemptId: ticket.attemptId,
            nativeEstablishTicket: ticket.rustValue,
            desiredRuntime: native.DesiredRuntime.running,
            installClaim: native.NativeCredentialInstallClaim(
              token: claimBytes,
            ),
          ),
        );
      } finally {
        claimBytes.fillRange(0, claimBytes.length, 0);
      }

      _validateReceipt(receipt, ticket);
      final projection = _readyProjection(
        receipt.nativeRevision,
        receipt.identity,
      );
      final session = native.currentNativeSession(
        root: _root,
        expectedRevision: receipt.nativeRevision,
      );
      final realmClaim = _newRealmClaim();
      final prior = attempt.priorBinding;
      if (prior != null) {
        _requireSameProjection(prior.projection, projection);
      }
      final effects = prior?.effects ??
          _NativeSessionEffects(
            root: _root,
            session: session,
            platform: _platform,
            identity: projection,
            onFailure: _handleEffectFailure,
          );
      final binding = _NativeReadyBinding(
        session: session,
        readyRevision: _platformRevision(receipt.nativeRevision),
        projection: projection,
        effects: effects,
        attemptId: ticket.attemptId,
        realmMarker: realmMarker,
        realmClaim: realmClaim,
      );
      final response = _establishResponse(receipt, realmClaim);

      // The committed Rust receipt is the publication boundary. Publish its
      // complete authority bundle before the best-effort producer wake so a
      // retryable scheduling failure cannot create a second Ready sub-state.
      attempt.retainReady(binding);
      final publish = prior == null && attempt.terminalIntent == null;
      if (publish) {
        _sessions.publishReady(projection, effects: effects);
      }
      // Settle synchronously with publication. A terminal call during the
      // following wake therefore observes Ready and closes its admission.
      _finishEstablish(attempt);

      if (publish && projection.hasWallet) {
        int? retiredRevision;
        var credentialAbsent = false;
        try {
          retiredRevision = await _platform.runInteractiveProducerWake(
            expectedRevision: binding.readyRevision,
            refreshPolicy: true,
          );
        } catch (error) {
          credentialAbsent = _isDefinitiveCredentialAbsence(error);
          if (!credentialAbsent) {
            LoggingService.instance.warn(
              'Native producer wake will retry (${error.runtimeType})',
              tag: 'usernode/NativeSession',
            );
          }
        }
        if (retiredRevision != null || credentialAbsent) {
          if (retiredRevision != null) {
            await _retireFromNative(retiredRevision);
          } else {
            await _retireDefinitivelyAbsentLogged();
          }
          throw const NativeSessionException(
            'native_session_not_ready',
            'The native credential was retired during establishment.',
          );
        }
      }

      if (publish) {
        await _sessions.reconcileAfterForegroundResume();
      }

      return response;
    } catch (error) {
      if (attempt.disposition == _NativeCommitDisposition.notCommitted &&
          installedAttemptId != null) {
        attempt.markUncertain();
        try {
          await _platform.discardUncommittedCredential(
            attemptId: installedAttemptId,
          );
          attempt.restorePreCommitState();
        } catch (cleanupError) {
          throw _asNativeSessionException(cleanupError);
        }
      }
      throw _asNativeSessionException(error);
    } finally {
      _finishEstablish(attempt);
    }
  }

  @override
  Future<Map<String, Object?>> restoreWebSession(
      {required String realmMarker}) async {
    _validateRealmMarker(realmMarker);
    await _foregroundAdmission.waitUntilOpen();
    final authority = _authority;
    if (authority is _NativeSignedOut) return const {'status': 'absent'};
    if (authority is! _NativeReady) {
      throw const NativeSessionException(
          'native_session_not_ready', 'The native session is not ready.');
    }
    try {
      // A root-owned operation is needed before this document has a realm
      // claim. Holding the exact runner makes terminal retirement drain cookie
      // installation before it can publish a successor identity.
      return await _sessions.view.current.operations.run((_) async {
        final restored =
            await _platform.restoreWebSession(authority.binding.readyRevision);
        if (restored['status'] != 'restored' ||
            restored['protocol'] != 2 ||
            restored['userId'] !=
                authority.binding.projection.participantId.toString() ||
            restored['attemptId'] != authority.binding.attemptId) {
          throw const NativeSessionException('invalid_native_web_session',
              'The restored web session is invalid.');
        }
        return restored;
      });
    } catch (error, stackTrace) {
      var failure = _asNativeSessionException(error);
      // The managed native revision gate also rejects a locally elapsed
      // lease, before the HTTP owner can ask the server. This operation holds
      // the exact runner, so that refusal cannot describe a successor session.
      if (failure.code == 'native_session_not_current') {
        failure = const NativeSessionException('native_credential_expired',
            'The native session is no longer current.');
      }
      _handleEffectFailure(failure, stackTrace);
      if (_isDefinitiveCredentialAbsence(failure)) {
        return const {'status': 'absent'};
      }
      rethrow;
    }
  }

  @override
  Future<void> prepareForLogin({required String realmMarker}) async {
    _validateRealmMarker(realmMarker);
    // Root terminals do not require the old realm claim: a recovered Ready
    // may predate this Social document. The bridge validates the executing
    // configured top frame before presenting its marker.
    await _retireAuthority(const _NativeTerminalIntent.processRoot());
  }

  @override
  Future<void> logoutNativeSession({required String realmMarker}) async {
    _validateRealmMarker(realmMarker);
    // The trusted top frame may have booted offline and never acquired a
    // session claim. Like prepareForLogin, logout retires the process root.
    await _retireAuthority(const _NativeTerminalIntent.localLogout());
  }

  _NativeEstablishAttempt _beginEstablish(
    _NativeSessionEstablishIntent intent,
    String realmMarker,
  ) {
    final current = _authority;
    if (current is _NativeRecoveryRequired) _throwTerminallyRetired();
    if (current is _NativeClosing) {
      throw const NativeSessionException(
        'native_session_logout_pending',
        'Native logout must finish before another session can be established.',
      );
    }
    if (current is _NativeEstablishing) {
      throw const NativeSessionException(
        'native_session_transition_in_progress',
        'A native session transition is already in progress.',
      );
    }

    _NativeReadyBinding? prior;
    if (current is _NativeReady) {
      if (current.binding.attemptId != intent.attemptId) {
        throw const NativeSessionException(
          'native_session_not_ready',
          'The existing native session must be retired before establishment.',
        );
      }
      prior = current.binding;
    }
    final attempt = _NativeEstablishAttempt(
      realmMarker,
      priorBinding: prior,
    );
    _authority = _NativeEstablishing(attempt);
    return attempt;
  }

  void _finishEstablish(_NativeEstablishAttempt attempt) {
    final current = _authority;
    if (current is _NativeEstablishing && identical(current.attempt, attempt)) {
      final settled = _settledEstablishState(attempt);
      if (settled is _NativeRecoveryRequired) {
        _enterRecoveryRequired();
      } else {
        _authority = settled;
      }
    }
    if (!attempt.settled.isCompleted) attempt.settled.complete();
  }

  Future<void> _retireAuthority(_NativeTerminalIntent intent) async {
    final current = _authority;
    if (current is _NativeRecoveryRequired) _throwTerminallyRetired();
    if (current is _NativeSignedOut) {
      // Also permits retrying WebView cleanup after native retirement.
      return;
    }

    if (current is _NativeEstablishing) {
      final attempt = current.attempt;
      if (attempt.terminalIntent != null) {
        throw const NativeSessionException(
          'native_session_transition_in_progress',
          'A native session transition is already in progress.',
        );
      }
      attempt.terminalIntent = intent;
      if (attempt.priorBinding != null) {
        // A replay may keep Ready published while it refreshes the realm claim.
        // Close that exact admission before waiting for the replay to settle.
        _sessions.closeAndDrain();
      }
      await attempt.settled.future;
      return _continueClosing(intent);
    }

    if (current is _NativeReady) {
      final closing = _NativeClosing(intent: intent, binding: current.binding);
      _authority = closing;
      return _startClosing(closing);
    }

    if (current is _NativeClosing) {
      if (!_sameTerminalIntent(current.intent, intent)) {
        throw const NativeSessionException(
          'native_session_logout_pending',
          'Another native terminal transition already owns the session.',
        );
      }
      if (!identical(current.intent, intent) && !current.retryable) {
        throw const NativeSessionException(
          'native_session_transition_in_progress',
          'A native session transition is already in progress.',
        );
      }
      return _startClosing(current);
    }

    throw const NativeSessionException(
      'native_session_transition_in_progress',
      'A native session transition is already in progress.',
    );
  }

  Future<void> _continueClosing(_NativeTerminalIntent intent) {
    final current = _authority;
    if (current is _NativeRecoveryRequired) _throwTerminallyRetired();
    if (current is! _NativeClosing ||
        !_sameTerminalIntent(current.intent, intent)) {
      throw const NativeSessionException(
        'native_session_transition_in_progress',
        'The native terminal transition lost ownership.',
      );
    }
    return _startClosing(current);
  }

  Future<void> _startClosing(_NativeClosing closing) {
    if (closing.active != null) {
      throw const NativeSessionException(
        'native_session_transition_in_progress',
        'A native session transition is already in progress.',
      );
    }
    // Admission closes synchronously, before the first await in the terminal
    // transition. Private Ready and SignedOut scopes are already closed.
    final drain = _sessions.closeAndDrain();
    final future = _commitClosing(closing, drain);
    closing.active = future;
    return future;
  }

  Future<void> _commitClosing(
    _NativeClosing closing,
    Future<void> drain,
  ) async {
    try {
      await drain;
      final binding = closing.binding;
      if (binding == null) {
        if (identical(_authority, closing)) {
          _authority = const _NativeSignedOut();
        }
        return;
      }
      final signedOut = await _commitNativeLogout(
        binding,
        requireServerRevocation:
            closing.intent.kind == _NativeTerminalKind.processRoot,
      );
      if (!identical(_authority, closing)) return;
      _sessions.publishSignedOut(signedOut);
      _authority = const _NativeSignedOut();
    } catch (error) {
      if (identical(_authority, closing)) {
        closing.active = null;
        closing.retryable = true;
      }
      throw _asNativeSessionException(error);
    }
  }

  Future<SessionIdentityProjection> _commitNativeLogout(
    _NativeReadyBinding binding, {
    required bool requireServerRevocation,
  }) async {
    // Explicit phone logout is a local terminal operation. The web shell
    // attempts remote revocation, but connectivity must not retain secrets.
    // Login/replacement still requires the existing server boundary.
    if (requireServerRevocation) {
      final serverRevocation = await _platform.revokeCredentialOnServer(
        expectedRevision: binding.readyRevision,
      );
      if (serverRevocation == _NativeCredentialServerRevocation.uncertain) {
        throw const NativeSessionException(
          'native_credential_revocation_uncertain',
          'The server could not confirm native credential revocation.',
        );
      }
    }
    final result = await native.logoutNativeSession(
      root: _root,
      session: binding.session,
    );
    final retirement = result.credentialRetirement;
    final commitment = retirement.vaultCommitment;
    try {
      await _platform.retireCredential(
        credentialReference: retirement.credentialReference,
        credentialGeneration: _credentialGeneration(
          retirement.credentialGeneration,
        ),
        vaultCommitment: commitment,
        readyRevision: binding.readyRevision,
      );
    } finally {
      commitment.fillRange(0, commitment.length, 0);
    }
    return SessionIdentityProjection.signedOut(
      nativeRevision: _canonicalRevision(result.nativeRevision),
    );
  }

  bool _sameTerminalIntent(
    _NativeTerminalIntent left,
    _NativeTerminalIntent right,
  ) =>
      left.kind == right.kind;

  Never _throwTerminallyRetired() => throw const NativeSessionException(
        'native_session_terminally_retired',
        'The native session was retired; relaunch is required.',
      );

  String _newRealmClaim() {
    final bytes = Uint8List(32);
    try {
      for (var index = 0; index < bytes.length; index++) {
        bytes[index] = _random.nextInt(256);
      }
      return 'nsr_${base64UrlEncode(bytes).replaceAll('=', '')}';
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}

final class _FailingNativeSessionBridgeIngress
    implements _NativeSessionRuntime, NativeSessionBridgeIngress {
  _FailingNativeSessionBridgeIngress(this._failure)
      : _sessions = _SessionCompositionRoot(
          SessionIdentityProjection.signedOut(nativeRevision: '0'),
        );

  final NativeSessionException _failure;
  final _SessionCompositionRoot _sessions;

  @override
  NativeSessionBridgeIngress get bridge => this;

  @override
  bool get terminallyRetired => false;

  @override
  Stream<void> get terminalRetirements => const Stream<void>.empty();

  @override
  SessionFeatureAccessView get sessions => _sessions.view;

  @override
  Future<void> appLifecycleStateChanged(AppLifecycleState state) =>
      Future<void>.value();

  @override
  Future<Map<String, Object?>> establishNativeSession({
    required Map<String, dynamic> payload,
    required String realmMarker,
  }) =>
      Future<Map<String, Object?>>.error(_failure);

  @override
  Future<void> prepareForLogin({required String realmMarker}) =>
      Future<void>.error(_failure);

  @override
  Future<Map<String, Object?>> restoreWebSession(
          {required String realmMarker}) =>
      Future<Map<String, Object?>>.error(_failure);

  @override
  Future<void> logoutNativeSession({required String realmMarker}) =>
      Future<void>.error(_failure);

  @override
  Future<T> runSessionOperation<T>({
    required String realmMarker,
    required String realmSessionClaim,
    required FutureOr<T> Function(
      SessionIdentityProjection identity,
      SessionOperation operation,
    ) body,
  }) =>
      Future<T>.error(_failure);
}

SessionIdentityProjection _readyProjection(
  BigInt nativeRevision,
  native.NativeIdentity identity,
) {
  final participantId = int.tryParse(identity.participantId);
  if (participantId == null ||
      participantId <= 0 ||
      participantId.toString() != identity.participantId) {
    throw const NativeSessionException(
      'native_session_identity_invalid',
      'The native session identity is invalid.',
    );
  }
  return SessionIdentityProjection.ready(
    nativeRevision: _canonicalRevision(nativeRevision),
    participantId: participantId,
    accountId: identity.accountId == null
        ? null
        : _canonicalString(identity.accountId, 'native account id'),
    address: identity.address == null
        ? null
        : _canonicalString(identity.address, 'native address'),
    publicKey: identity.publicKey == null
        ? null
        : _canonicalString(identity.publicKey, 'native public key'),
  );
}

void _validateReceipt(
  native.NativeEstablishResult receipt,
  _NativeSessionTicketEnvelope ticket,
) {
  if (receipt.protocol != 2 ||
      receipt.attemptId != ticket.attemptId ||
      receipt.receiptStatus != native.NativeReceiptStatus.committedReady) {
    throw const NativeSessionException(
      'native_session_receipt_invalid',
      'The native establishment receipt is invalid.',
    );
  }
  _canonicalRevision(receipt.nativeRevision);
}

void _validateAdoption(
  native.NativeEstablishResult receipt,
  BigInt expectedRevision,
  String expectedAttemptId,
  native.NativeIdentity expectedIdentity,
) {
  if (receipt.protocol != 2 ||
      receipt.nativeRevision != expectedRevision ||
      receipt.attemptId != expectedAttemptId ||
      receipt.receiptStatus != native.NativeReceiptStatus.committedReady ||
      receipt.identity.participantId != expectedIdentity.participantId ||
      receipt.identity.accountId != expectedIdentity.accountId ||
      receipt.identity.address != expectedIdentity.address) {
    throw const NativeSessionException(
      'native_session_adoption_invalid',
      'The recovered native session does not match durable identity.',
    );
  }
}

void _logNativeRuntimeStatus(
  native.NativeRuntimeStatus status, {
  required String source,
}) {
  final details = status.when(
    notStarted: () => const <String, Object?>{'state': 'not_started'},
    running: () => const <String, Object?>{'state': 'running'},
    startFailed: (validatedCode) => <String, Object?>{
      'state': 'start_failed',
      'code': switch (validatedCode) {
        native.NativeStartFailureCode.nodeStartFailed => 'node_start_failed',
      },
    },
  );
  LoggingService.instance.info(
    'Native node runtime status',
    tag: 'usernode/NativeSession',
    context: <String, Object?>{'source': source, ...details},
  );
}

Map<String, Object?> _establishResponse(
  native.NativeEstablishResult receipt,
  String realmClaim,
) =>
    Map<String, Object?>.unmodifiable({
      'protocol': 2,
      'attemptId': receipt.attemptId,
      'nativeRevision': _canonicalRevision(receipt.nativeRevision),
      'identity': Map<String, Object?>.unmodifiable({
        'participantId': receipt.identity.participantId,
        'accountId': receipt.identity.accountId,
        'address': receipt.identity.address,
      }),
      'runtimeStatus': Map<String, Object?>.unmodifiable(
        receipt.runtimeStatus.when(
          notStarted: () => const <String, Object?>{'state': 'notStarted'},
          running: () => const <String, Object?>{'state': 'running'},
          startFailed: (validatedCode) => <String, Object?>{
            'state': 'startFailed',
            'validatedCode': switch (validatedCode) {
              native.NativeStartFailureCode.nodeStartFailed =>
                'node_start_failed',
            },
          },
        ),
      ),
      'receiptStatus': 'committedReady',
      'realmSessionClaim': realmClaim,
    });

void _requireSameProjection(
  SessionIdentityProjection current,
  SessionIdentityProjection next,
) {
  if (current.nativeRevision != next.nativeRevision ||
      current.participantId != next.participantId ||
      current.accountId != next.accountId ||
      current.address != next.address) {
    throw const NativeSessionException(
      'native_session_state_mismatch',
      'The native session state changed during establishment.',
    );
  }
}

void _validateRealmMarker(String marker) {
  if (marker.isEmpty || marker.length > 256 || marker.trim() != marker) {
    throw const NativeSessionException(
      'native_session_realm_invalid',
      'The native session page realm is invalid.',
    );
  }
}

String _canonicalRevision(BigInt revision) {
  if (revision.isNegative || revision > _maxU64) {
    throw const NativeSessionException(
      'native_session_revision_invalid',
      'The native session revision is invalid.',
    );
  }
  return revision.toString();
}

int _credentialGeneration(BigInt generation) {
  if (generation <= BigInt.zero || generation > _maxPlatformInt) {
    throw const NativeSessionException(
      'invalid_native_retirement',
      'The native credential retirement directive is invalid.',
    );
  }
  return generation.toInt();
}

int _platformRevision(BigInt revision) {
  if (revision.isNegative || revision > _maxPlatformLong) {
    throw const NativeSessionException(
      'native_session_revision_invalid',
      'The native session revision is invalid.',
    );
  }
  return revision.toInt();
}

NativeSessionException _asNativeSessionException(Object error) {
  if (error is NativeSessionException) return error;
  if (error is AnyhowException) {
    return NativeSessionException(
      _canonicalErrorCode(error.message),
      'The secure native session operation failed.',
    );
  }
  return const NativeSessionException(
    'native_session_failed',
    'The secure native session operation failed.',
  );
}

/// Whether the server no longer accepts the session's credential.
bool _isDefinitiveCredentialAbsence(Object error) => const {
      'native_credential_definitively_absent',
      'native_credential_expired',
    }.contains(_asNativeSessionException(error).code);

final BigInt _maxU64 = BigInt.parse('18446744073709551615');
final BigInt _maxPlatformInt = BigInt.from(0x7fffffff);
final BigInt _maxPlatformLong = BigInt.parse('9223372036854775807');

Map<String, Object?> _exactMap(Object? raw, Set<String> keys, String label) {
  final map = _stringMap(raw, label);
  if (map.keys.toSet().difference(keys).isNotEmpty ||
      map.length != keys.length) {
    throw NativeSessionException(
      'native_session_object_invalid',
      '$label has unexpected fields.',
    );
  }
  return map;
}

Map<String, Object?> _stringMap(Object? raw, String label) {
  if (raw is! Map || raw.keys.any((key) => key is! String)) {
    throw NativeSessionException(
      'native_session_object_invalid',
      '$label must be an object.',
    );
  }
  return raw.cast<String, Object?>();
}

String _canonicalString(Object? raw, String label) {
  if (raw is! String || raw.isEmpty || raw.trim() != raw) {
    throw NativeSessionException(
      'native_session_string_invalid',
      '$label must be a canonical string.',
    );
  }
  return raw;
}

String _canonicalErrorCode(Object? raw) {
  if (raw is String && RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(raw)) return raw;
  return 'native_session_failed';
}

/// StandardMethodCodec may expose typed-data results as unmodifiable views.
/// Copy opaque native values at the platform boundary so their sole Dart owner
/// can reliably wipe them after the one authorized use.
Uint8List _ownedNativeSecret(
  Object? raw, {
  required String code,
  required String message,
}) {
  if (raw is! Uint8List || raw.length != 32) {
    throw NativeSessionException(code, message);
  }
  return Uint8List.fromList(raw);
}

/// Drives the composition root through credential retirement and the sign-in
/// that follows it.
///
/// Like [runSessionLifecycleOrderingSelfCheck], this accepts nothing and
/// returns only inert event labels. The real platform port runs over a
/// scripted in-memory channel. Rust calls still go through the generated API,
/// so the caller installs a Rust API double with `RustLib.initMock` first.
Future<List<String>> runNativeRetirementRecoverySelfCheck() async {
  const realm = 'trusted-realm';
  final events = <String>[];

  Future<void> signIn(_RetirementSelfCheck check, String label) async {
    await check.root.prepareForLogin(realmMarker: realm);
    final receipt = await check.root.establishNativeSession(
      payload: _selfCheckEstablishPayload,
      realmMarker: realm,
    );
    _expectSelfCheck(
      receipt['receiptStatus'] == 'committedReady' &&
          check.root.sessions.current.identity.participantId == 2,
      '$label: the next sign-in did not establish',
    );
    events.add(label);
  }

  // Relaunch holding a wallet session that the server already ended. The
  // first foreground wake finds the credential absent.
  var check = await _RetirementSelfCheck.start(
    wakeOutcome: 'credentialAbsent',
  );
  await check.root.appLifecycleStateChanged(AppLifecycleState.resumed);
  _expectSelfCheck(
    !check.root.terminallyRetired &&
        check.signedOut &&
        check.channel.calls.contains('retireNativeSessionCredential'),
    'absence found at launch did not retire the old session cleanly',
  );
  final launchRestore = await check.root.restoreWebSession(realmMarker: realm);
  _expectSelfCheck(
    launchRestore['status'] == 'absent',
    'the page restored a session the server ended',
  );
  events.add('launch-absence-signed-out');
  await signIn(check, 'launch-absence-sign-in-established');

  // A walletless session has no producer wake. The page's restore is the
  // first authenticated call and finds the credential absent.
  check = await _RetirementSelfCheck.start(wallet: false);
  await check.root.appLifecycleStateChanged(AppLifecycleState.resumed);
  final restore = await check.root.restoreWebSession(realmMarker: realm);
  await check.untilRetirementSettles();
  _expectSelfCheck(
    restore['status'] == 'absent' &&
        !check.root.terminallyRetired &&
        check.signedOut,
    'absence found by restore did not retire the old session cleanly',
  );
  events.add('restore-absence-signed-out');
  await signIn(check, 'restore-absence-sign-in-established');

  // The server ends the session while it is in use.
  check = await _RetirementSelfCheck.start();
  await check.root.appLifecycleStateChanged(AppLifecycleState.resumed);
  await check.failManagedCallWithAbsence();
  await check.untilRetirementSettles();
  _expectSelfCheck(
    !check.root.terminallyRetired && check.signedOut,
    'absence found while signed in did not retire the session cleanly',
  );
  events.add('signed-in-absence-signed-out');
  await signIn(check, 'signed-in-absence-sign-in-established');

  // Rust retired the session itself, as an iOS background wake does. Rust
  // refuses every session mutation until relaunch, so the latch stays.
  check = await _RetirementSelfCheck.start();
  await check.root.appLifecycleStateChanged(AppLifecycleState.resumed);
  await check.channel.deliverRetirement(2);
  _expectSelfCheck(
    check.root.terminallyRetired && check.signedOut,
    'native retirement did not latch the process',
  );
  await _expectSelfCheckTerminallyRetired(
    () => check.root.prepareForLogin(realmMarker: realm),
    'native retirement admitted a sign-in',
  );
  await _expectSelfCheckTerminallyRetired(
    () => check.root.establishNativeSession(
      payload: _selfCheckEstablishPayload,
      realmMarker: realm,
    ),
    'native retirement admitted an establishment',
  );
  events.add('native-retirement-latched');

  // A definitive absence whose local retirement fails leaves native state
  // unknown, so the process still latches.
  check = await _RetirementSelfCheck.start(retirementFails: true);
  await check.root.appLifecycleStateChanged(AppLifecycleState.resumed);
  final latched = check.root.terminalRetirements.first;
  await check.failManagedCallWithAbsence();
  await latched;
  await _expectSelfCheckTerminallyRetired(
    () => check.root.prepareForLogin(realmMarker: realm),
    'a failed retirement admitted a sign-in',
  );
  events.add('failed-retirement-latched');

  return List<String>.unmodifiable(events);
}

final _selfCheckEstablishPayload = <String, dynamic>{
  'args': <String, Object?>{
    'attemptId': 'nsa_${'A' * 43}',
    'desiredRuntime': 'running',
  },
};

/// One Ready process root, recovered at launch as `_readyRoot` builds it.
final class _RetirementSelfCheck {
  _RetirementSelfCheck._(this.channel, this.root);

  final _SelfCheckNativeChannel channel;
  final _NativeSessionCompositionRoot root;

  static Future<_RetirementSelfCheck> start({
    bool wallet = true,
    String wakeOutcome = 'completed',
    bool retirementFails = false,
  }) async {
    final channel = _SelfCheckNativeChannel((method, arguments) {
      switch (method) {
        case 'bootstrapInteractiveRoot':
          return {
            'processRootProof': Uint8List(32),
            'processTransportClaim': Uint8List(32),
          };
        case 'runInteractiveProducerWake':
          return {'outcome': wakeOutcome};
        case 'restoreNativeWebSession':
          // The server rejected the bearer and the vault deleted it.
          throw PlatformException(
              code: 'native_credential_definitively_absent');
        case 'revokeNativeSessionCredential':
          return {'status': 'definitivelyAbsent'};
        case 'retireNativeSessionCredential':
          if (retirementFails) {
            throw PlatformException(code: 'native_retirement_mismatch');
          }
          return null;
        case 'redeemNativeSessionHandoff':
          return _selfCheckTicket(arguments['attemptId']! as String);
        case 'prepareNativeSessionExchange':
          return {'request': 'self-check'};
        case 'installNativeSessionCredential':
          return {'installClaim': Uint8List(32)};
      }
      throw PlatformException(
        code: 'self_check_unexpected_call',
        message: method,
      );
    });
    final platform = _NativeSessionPlatformPort(
      channel: MethodChannel(
        '${_NativeSessionPlatformPort._channelName}.self_check',
        const StandardMethodCodec(),
        channel,
      ),
    );
    await platform.bootstrapInteractiveRoot(
      mobileApiBaseUrl: 'https://self-check.invalid',
    );
    final identity = wallet
        ? SessionIdentityProjection.ready(
            nativeRevision: '1',
            participantId: 1,
            accountId: 'account-a',
            address: 'address-a',
            publicKey: 'public-key-a',
          )
        : SessionIdentityProjection.ready(
            nativeRevision: '1', participantId: 1);
    late final _NativeSessionCompositionRoot root;
    final effects = _ClosedSessionEffectSink(
      (error, stackTrace) => root._handleEffectFailure(error, stackTrace),
      (enabled) async =>
          SessionSleepySnapshot(enabled: enabled, decision: 'self_check'),
    );
    root = _NativeSessionCompositionRoot._(
      root: _SelfCheckProcessRoot(),
      platform: platform,
      exchange: _SelfCheckExchange(),
      sessions: _SessionCompositionRoot(identity, readyEffects: effects),
      authority: _NativeReady(
        _NativeReadyBinding(
          session: _SelfCheckNativeSession(),
          readyRevision: 1,
          projection: identity,
          effects: effects,
          attemptId: 'self-check-recovered',
        ),
      ),
    );
    // As after cold recovery, the first frame's resume opens admission.
    root._foregroundAdmission.suspend();
    return _RetirementSelfCheck._(channel, root);
  }

  bool get signedOut =>
      root.sessions.current.identity.status ==
      SessionProjectionStatus.signedOut;

  /// Waits for a retirement that runs behind its trigger to settle.
  Future<void> untilRetirementSettles() async {
    final authority = root._authority;
    if (authority is _NativeClosing) await authority.active;
  }

  /// A managed account request whose bearer the server no longer accepts.
  Future<void> failManagedCallWithAbsence() async {
    try {
      await root.sessions.current.operations.run<void>(
        (operation) => _SessionEffectSelfCheckSink.run<void>(
          operation,
          () => throw const NativeSessionException(
            'native_credential_definitively_absent',
            'self-check managed request',
          ),
        ),
      );
    } on NativeSessionException {
      // The request reports its own failure; retirement runs separately.
    }
  }
}

Map<String, Object?> _selfCheckTicket(String attemptId) => {
      'protocol': 2,
      'attemptId': attemptId,
      'desiredRuntime': 'running',
      'ticket': 'self-check-ticket',
      'requestDigest': 'self-check-request-digest',
      'exchangeChallenge': 'self-check-exchange-challenge',
      'network': {'id': 'testnet', 'chainId': 'self-check-chain'},
      'issuedAt': '2026-01-01T00:00:00Z',
      'expiresAt': '2026-01-01T00:05:00Z',
    };

Future<void> _expectSelfCheckTerminallyRetired(
  Future<Object?> Function() body,
  String message,
) async {
  try {
    await body();
  } on NativeSessionException catch (error) {
    if (error.code == 'native_session_terminally_retired') return;
    rethrow;
  }
  throw StateError(message);
}

/// The platform side of the private channel, answering from a script.
final class _SelfCheckNativeChannel implements BinaryMessenger {
  _SelfCheckNativeChannel(this._answer);

  static const _codec = StandardMethodCodec();
  final Object? Function(String method, Map<Object?, Object?> arguments)
      _answer;
  final List<String> calls = <String>[];
  MessageHandler? _flutterHandler;

  @override
  Future<ByteData?> send(String channel, ByteData? message) async {
    final call = _codec.decodeMethodCall(message);
    calls.add(call.method);
    try {
      return _codec.encodeSuccessEnvelope(
        _answer(call.method, call.arguments as Map<Object?, Object?>),
      );
    } on PlatformException catch (error) {
      return _codec.encodeErrorEnvelope(
        code: error.code,
        message: error.message,
      );
    }
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    _flutterHandler = handler;
  }

  /// Delivers `nativeSessionRetired` the way the platform does after Rust
  /// retires the session.
  Future<void> deliverRetirement(int nativeRevision) async {
    await _flutterHandler!(
      _codec.encodeMethodCall(
        MethodCall('nativeSessionRetired', {'nativeRevision': nativeRevision}),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SelfCheckExchange implements _NativeSessionExchangeTransport {
  @override
  Future<Map<String, Object?>> exchange(Map<String, Object?> request) async =>
      const {'credentialReference': 'self-check-credential'};

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SelfCheckProcessRoot implements native.ProcessRootClient {
  bool _disposed = false;

  @override
  void dispose() => _disposed = true;

  @override
  bool get isDisposed => _disposed;
}
