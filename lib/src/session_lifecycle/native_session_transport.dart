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

  static const _channelName = 'com.usernode.app/native_session';
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
    final raw = await _channel.invokeMethod<Object?>(
      'bootstrapInteractiveRoot',
      <String, Object?>{'mobileApiBaseUrl': mobileApiBaseUrl},
    );
    final value = _exactMap(
      raw,
      const {'processRootProof', 'processTransportClaim'},
      'native process root bootstrap',
    );
    final proof = value['processRootProof'];
    final transportClaim = value['processTransportClaim'];
    if (proof is! Uint8List ||
        proof.length != 32 ||
        transportClaim is! Uint8List ||
        transportClaim.length != 32) {
      throw const NativeSessionException(
        'process_root_proof_invalid',
        'The native process-root proof is invalid.',
      );
    }
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
    final claim = result['installClaim'];
    if (claim is! Uint8List || claim.length != 32) {
      throw const NativeSessionException(
        'native_install_claim_invalid',
        'The native credential install claim is invalid.',
      );
    }
    return claim;
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
            value.length != 2 ||
            value['installClaim'] is! Uint8List ||
            (value['installClaim']! as Uint8List).length != 32) {
          break;
        }
        return value;
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
        !const {'completed', 'retry', 'ignored'}.contains(outcome)) {
      throw const NativeSessionException(
        'native_producer_wake_result_invalid',
        'The native producer wake result is invalid.',
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
    final claim = value['installClaim'];
    if (claim is! Uint8List || claim.length != 32) {
      throw const NativeSessionException(
        'native_policy_claim_invalid',
        'The native producer policy claim is invalid.',
      );
    }
    return claim;
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
    try {
      return await _channel.invokeMethod<Object?>(
        method,
        <String, Object?>{
          ...arguments,
          'processTransportClaim': claim,
        },
      );
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

  Future<void> foregroundResume();
}

Future<_NativeSessionRuntime> _bootstrapNativeSessionRuntime() async {
  final platform = _NativeSessionPlatformPort();
  final exchange = _NativeSessionExchangeTransport(
    mobileApiBaseUrl: AppConfig.mobileApiBaseUrl,
  );
  try {
    return await _NativeSessionCompositionRoot.bootstrap(
      platform: platform,
      exchange: exchange,
    );
  } catch (error) {
    exchange.close();
    return _FailingNativeSessionBridgeIngress(_asNativeSessionException(error));
  }
}

const _nativeDelegationAddress =
    'B62qiTKpEPjGTSHZrtM8uXiKgn8So916pLmNJKDhKeyBQL9TDb3nvBG';

final class _NativeSessionEffects implements _SessionEffectSink {
  _NativeSessionEffects({
    required native.ProcessRootClient root,
    required native.SessionNativeClient session,
    required _NativeSessionPlatformPort platform,
    required SessionIdentityProjection identity,
  })  : _root = root,
        _session = session,
        _platform = platform,
        _identity = identity,
        _revision = _platformRevision(BigInt.parse(identity.nativeRevision));

  final native.ProcessRootClient _root;
  final native.SessionNativeClient _session;
  final _NativeSessionPlatformPort _platform;
  final SessionIdentityProjection _identity;
  final int _revision;
  final Stopwatch _stallClock = Stopwatch()..start();
  _NativeSyncProgress? _lastSyncProgress;
  int? _unchangedSinceMs;

  @override
  Future<SessionNodeStatus> readNodeStatus() async {
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
    final balance = await native.nativeWalletBalance(
      root: _root,
      session: _session,
    );
    final delegation = _delegationSnapshot();
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
  Future<SessionDelegationSnapshot> readDelegation() async =>
      _delegationSnapshot();

  @override
  Future<SessionDelegationSnapshot> setDelegated(bool delegated) async {
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
    return _delegationSnapshot();
  }

  SessionDelegationSnapshot _delegationSnapshot() {
    final state = native.nativeDelegationState(
      root: _root,
      session: _session,
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
  Future<SessionSleepSnapshot> readSleep() async =>
      SessionSleepSnapshot(enabled: AppSleepStateStore.isEnabled);

  @override
  Future<SessionSleepSnapshot> setSleepEnabled(bool enabled) async {
    await AppSleepStateStore.setEnabled(enabled);
    if (!enabled) {
      await native.setNativeRuntimePaused(
        root: _root,
        session: _session,
        paused: false,
      );
    }
    return SessionSleepSnapshot(enabled: enabled);
  }

  @override
  Future<SessionSleepSnapshot> setSleeping(bool sleeping) async {
    final effective = sleeping && AppSleepStateStore.isEnabled;
    await native.setNativeRuntimePaused(
      root: _root,
      session: _session,
      paused: effective,
    );
    await AppSleepStateStore.setSleeping(effective);
    return SessionSleepSnapshot(enabled: AppSleepStateStore.isEnabled);
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

final class _NativeSessionCompositionRoot
    implements _NativeSessionRuntime, NativeSessionBridgeIngress {
  _NativeSessionCompositionRoot._({
    required native.ProcessRootClient root,
    required _NativeSessionPlatformPort platform,
    required _NativeSessionExchangeTransport exchange,
    required _SessionCompositionRoot sessions,
    required native.SessionNativeClient? nativeSession,
    required int? nativeReadyRevision,
  })  : _root = root,
        _platform = platform,
        _exchange = exchange,
        _sessions = sessions,
        _nativeSession = nativeSession,
        _nativeReadyRevision = nativeReadyRevision {
    _platform.bindRetirementHandler(_retireFromNative);
    _sessions.bindTopLevelAdmissionGate(_topLevelAdmissionBarrier);
  }

  Future<void>? _topLevelAdmissionBarrier() {
    if (_terminallyRetired) {
      throw const NativeSessionException(
        'native_session_terminally_retired',
        'The native session was retired; relaunch is required.',
      );
    }
    return _resumeValidation;
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
            nativeSession: null,
            nativeReadyRevision: null,
          );
        },
        ready: (nativeRevision, identity, _) async {
          final session = native.currentNativeSession(
            root: root,
            expectedRevision: nativeRevision,
          );
          return _readyRoot(
            root: root,
            platform: platform,
            exchange: exchange,
            nativeRevision: nativeRevision,
            identity: identity,
            session: session,
          );
        },
        recoverableReady: (nativeRevision, identity) async {
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
                nativeSession: null,
                nativeReadyRevision: null,
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
              _validateAdoption(adopted, nativeRevision, identity);
              final session = native.currentNativeSession(
                root: root,
                expectedRevision: nativeRevision,
              );
              return _readyRoot(
                root: root,
                platform: platform,
                exchange: exchange,
                nativeRevision: nativeRevision,
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
    required native.NativeIdentity identity,
    required native.SessionNativeClient session,
  }) async {
    final projection = _readyProjection(nativeRevision, identity);
    final effects = _NativeSessionEffects(
      root: root,
      session: session,
      platform: platform,
      identity: projection,
    );
    final readyRevision = _platformRevision(nativeRevision);
    final runtime = _NativeSessionCompositionRoot._(
      root: root,
      platform: platform,
      exchange: exchange,
      sessions: _SessionCompositionRoot(projection, readyEffects: effects),
      nativeSession: session,
      nativeReadyRevision: readyRevision,
    );
    try {
      final retiredRevision = await platform.runInteractiveProducerWake(
        expectedRevision: readyRevision,
        refreshPolicy: true,
      );
      if (retiredRevision != null) {
        await runtime._retireFromNative(retiredRevision);
      }
    } catch (error) {
      // Rust has already recovered/adopted this exact Ready. Keep its private
      // session and revision so foreground resume can retry and an exact realm
      // can still retire it; replacing this runtime with a failing signed-out
      // ingress would strand native authority.
      LoggingService.instance.warn(
        'Recovered native Ready; producer wake will retry on foreground resume '
        '(${error.runtimeType})',
        tag: 'usernode/NativeSession',
      );
    }
    return runtime;
  }

  final native.ProcessRootClient _root;
  final _NativeSessionPlatformPort _platform;
  final _NativeSessionExchangeTransport _exchange;
  final _SessionCompositionRoot _sessions;
  final Random _random = Random.secure();

  native.SessionNativeClient? _nativeSession;
  int? _nativeReadyRevision;
  String? _realmMarker;
  String? _realmClaim;
  Future<void>? _resumeValidation;
  Future<void>? _nativeRetirement;
  bool _terminallyRetired = false;
  final _terminalRetirements = StreamController<void>.broadcast(sync: true);
  final _transitions = _NativeSessionTransitionSlot();

  @override
  NativeSessionBridgeIngress get bridge => this;

  @override
  bool get terminallyRetired => _terminallyRetired;

  @override
  Stream<void> get terminalRetirements => _terminalRetirements.stream;

  @override
  SessionFeatureAccessView get sessions => _sessions.view;

  @override
  Future<void> foregroundResume() {
    final active = _resumeValidation;
    if (active != null) return active;
    late Future<void> validation;
    validation = _performForegroundResume().whenComplete(() {
      if (identical(_resumeValidation, validation)) _resumeValidation = null;
    });
    _resumeValidation = validation;
    return validation;
  }

  Future<void> _performForegroundResume() async {
    final access = _sessions.view.current;
    if (access.identity.status != SessionProjectionStatus.ready) return;
    try {
      final retiredRevision = await _platform.runInteractiveProducerWake(
        expectedRevision: int.parse(access.identity.nativeRevision),
        refreshPolicy: true,
      );
      if (retiredRevision != null) {
        await _retireFromNative(retiredRevision);
      }
    } catch (error) {
      // A retry leaves Rust Ready and is attempted again at the next bounded
      // resume. Keep this method non-throwing because lifecycle delivery has
      // no awaiting error owner.
      LoggingService.instance.warn(
        'Native producer wake will retry (${error.runtimeType})',
        tag: 'usernode/NativeSession',
      );
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
    // Android wake paths can terminate. The process latch also covers iOS and
    // foreground Android paths with an inert surface until natural relaunch.
    _latchTerminalRetirement();
    final signedOut = SessionIdentityProjection.signedOut(
      nativeRevision: nativeRevision.toString(),
    );
    await _sessions.retireAfterDrain(signedOut);
    _nativeSession = null;
    _nativeReadyRevision = null;
    _realmMarker = null;
    _realmClaim = null;
  }

  void _latchTerminalRetirement() {
    if (_terminallyRetired) return;
    _terminallyRetired = true;
    _terminalRetirements.add(null);
  }

  Future<void> _retireDefinitivelyAbsent(String realmMarker) async {
    if (_terminallyRetired) return;
    try {
      await logoutNativeSession(realmMarker: realmMarker);
    } finally {
      // Even an unexpected local retirement failure must not reopen a process
      // whose server credential is definitively absent.
      _latchTerminalRetirement();
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
    final resumeValidation = _resumeValidation;
    if (resumeValidation != null) await resumeValidation;
    if (_terminallyRetired) {
      throw const NativeSessionException(
        'native_session_terminally_retired',
        'The native session was retired; relaunch is required.',
      );
    }
    _validateRealmMarker(realmMarker);
    if (_realmMarker != realmMarker ||
        _realmClaim == null ||
        _realmClaim != realmSessionClaim ||
        _nativeSession == null) {
      throw const NativeSessionException(
        'native_session_realm_mismatch',
        'The native session belongs to a different page realm.',
      );
    }
    final access = _sessions.view.current;
    if (access.identity.status != SessionProjectionStatus.ready) {
      throw const NativeSessionException(
        'native_session_not_ready',
        'There is no ready native session.',
      );
    }
    try {
      return await access.operations.run(
        (operation) => body(access.identity, operation),
      );
    } catch (error) {
      final sessionError = _asNativeSessionException(error);
      if (const {
        'native_credential_definitively_absent',
        'native_credential_expired',
      }.contains(sessionError.code)) {
        await _retireDefinitivelyAbsent(realmMarker);
        throw sessionError;
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, Object?>> establishNativeSession({
    required Map<String, dynamic> payload,
    required String realmMarker,
  }) async {
    _validateRealmMarker(realmMarker);
    if (_terminallyRetired) {
      throw const NativeSessionException(
        'native_session_terminally_retired',
        'The native session was retired; relaunch is required.',
      );
    }
    _transitions.beginEstablish(realmMarker);
    var outcome = _nativeSession == null
        ? _NativeEstablishOutcome.notCommitted
        : _NativeEstablishOutcome.ready;
    String? installedAttemptId;
    try {
      final intent = _NativeSessionEstablishIntent.fromBridgePayload(payload);
      final rawTicket = await _platform.redeemHandoff(intent.attemptId);
      final ticket = _NativeSessionTicketEnvelope.fromNativeHandoff(
        rawTicket,
        expectedAttemptId: intent.attemptId,
      );
      final exchangeRequest = await _platform.prepareExchange(ticket);
      final exchangeResult = await _exchange.exchange(exchangeRequest);
      final claimBytes = await _platform.installCredential(
        ticket: ticket,
        exchange: exchangeResult,
      );
      installedAttemptId = ticket.attemptId;

      late native.NativeEstablishResult receipt;
      try {
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
        // From here onward Rust is durably Ready. Receipt validation or
        // publication failures must retain the exact vault record for logout.
        outcome = _NativeEstablishOutcome.ready;
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
      final current = _sessions.view.current.identity;
      if (current.status == SessionProjectionStatus.signedOut) {
        // Install all private authority before any synchronous publication.
        // A queued terminal intent retains B only long enough to retire it;
        // Ready is never opened or published in that case.
        _nativeSession = session;
        _nativeReadyRevision = _platformRevision(receipt.nativeRevision);
        _realmMarker = realmMarker;
        _realmClaim = realmClaim;
        if (!_transitions.hasTerminalIntentFor(realmMarker)) {
          try {
            final effects = _NativeSessionEffects(
              root: _root,
              session: session,
              platform: _platform,
              identity: projection,
            );
            final retiredRevision = await _platform.runInteractiveProducerWake(
              expectedRevision: _platformRevision(receipt.nativeRevision),
              refreshPolicy: true,
            );
            if (retiredRevision != null) {
              await _retireFromNative(retiredRevision);
              throw const NativeSessionException(
                'native_session_not_ready',
                'The native credential was retired during establishment.',
              );
            }
            // Logout may have queued while the platform wake was in flight.
            // Recheck at the final synchronous publication boundary so the
            // committed Ready remains private for exact terminal cleanup.
            if (!_transitions.hasTerminalIntentFor(realmMarker)) {
              _sessions.login(
                projection,
                effects: effects,
              );
            }
          } catch (_) {
            // Establishment is already durably Ready at this point. Retain
            // its exact private session/revision/realm for same-realm terminal
            // cleanup even though Ready was never published.
            rethrow;
          }
        }
      } else {
        _requireSameProjection(current, projection);
        _nativeSession = session;
        _nativeReadyRevision = _platformRevision(receipt.nativeRevision);
        _realmMarker = realmMarker;
        _realmClaim = realmClaim;
      }

      return _establishResponse(receipt, realmClaim);
    } catch (error) {
      if (outcome == _NativeEstablishOutcome.notCommitted &&
          installedAttemptId != null) {
        // Until exact cleanup succeeds, make any queued logout take the
        // fail-closed retirement path instead of treating the vault as empty.
        outcome = _NativeEstablishOutcome.ready;
        try {
          await _platform.discardUncommittedCredential(
            attemptId: installedAttemptId,
          );
          outcome = _NativeEstablishOutcome.notCommitted;
        } catch (cleanupError) {
          throw _asNativeSessionException(cleanupError);
        }
      }
      throw _asNativeSessionException(error);
    } finally {
      _transitions.finishEstablish(outcome);
    }
  }

  @override
  Future<void> prepareForLogin({required String realmMarker}) async {
    _validateRealmMarker(realmMarker);
    if (_terminallyRetired) {
      throw const NativeSessionException(
        'native_session_terminally_retired',
        'The native session was retired; relaunch is required.',
      );
    }
    final currentStatus = _sessions.view.current.identity.status;
    if (currentStatus == SessionProjectionStatus.signedOut &&
        _nativeSession == null &&
        !_transitions.establishmentInFlight) {
      return;
    }

    // Unlike explicit logout, this root terminal does not require the old
    // realm claim. A recovered Ready may have been created before this Social
    // document existed. The trusted caller marker proves only that the new
    // request comes from the configured top frame.
    final establishCompleted = _transitions.beginRootLogout();
    try {
      if (currentStatus == SessionProjectionStatus.ready) {
        await _sessions.logoutAfterDrain(() async {
          if (establishCompleted != null) await establishCompleted;
          return _commitRootNativeLogout();
        });
      } else {
        final outcome = establishCompleted == null
            ? _NativeEstablishOutcome.ready
            : await establishCompleted;
        if (outcome == _NativeEstablishOutcome.notCommitted &&
            _nativeSession == null) {
          _nativeReadyRevision = null;
          _realmMarker = null;
          _realmClaim = null;
          _transitions.finishLogout(succeeded: true);
          return;
        }
        final signedOut = await _commitRootNativeLogout();
        _sessions.replaceSignedOut(signedOut);
      }

      _nativeSession = null;
      _nativeReadyRevision = null;
      _realmMarker = null;
      _realmClaim = null;
      _transitions.finishLogout(succeeded: true);
    } catch (error) {
      // Keep the root terminal intent closed so only this preflight can retry;
      // no successor establishment may pass a failed retirement boundary.
      _transitions.finishLogout(succeeded: false);
      throw _asNativeSessionException(error);
    }
  }

  @override
  Future<void> logoutNativeSession({required String realmMarker}) async {
    _validateRealmMarker(realmMarker);
    if (_terminallyRetired) {
      throw const NativeSessionException(
        'native_session_terminally_retired',
        'The native session was retired; relaunch is required.',
      );
    }
    final currentStatus = _sessions.view.current.identity.status;
    if (currentStatus == SessionProjectionStatus.ready) {
      if (!_transitions.authorizesLogoutRealm(realmMarker) &&
          (_realmMarker != realmMarker || _realmClaim == null)) {
        throw const NativeSessionException(
          'native_session_realm_mismatch',
          'The native session belongs to a different page realm.',
        );
      }
    } else if (!_transitions.authorizesLogoutRealm(realmMarker) &&
        !(_nativeSession != null &&
            _nativeReadyRevision != null &&
            _realmMarker == realmMarker &&
            _realmClaim != null)) {
      throw const NativeSessionException(
        'native_session_not_ready',
        'There is no ready native session to log out.',
      );
    }

    // This is the sole terminal-intent slot. If establishment is still in
    // flight, only its trusted realm may queue logout behind it. A Ready
    // replay closes admission below before waiting for that exact attempt.
    final establishCompleted = _transitions.beginLogout(realmMarker);
    try {
      if (currentStatus == SessionProjectionStatus.ready) {
        await _sessions.logoutAfterDrain(() async {
          if (establishCompleted != null) await establishCompleted;
          return _commitRealmNativeLogout(realmMarker);
        });
      } else {
        final outcome = establishCompleted == null
            ? _NativeEstablishOutcome.ready
            : await establishCompleted;
        if (outcome == _NativeEstablishOutcome.notCommitted &&
            _nativeSession == null) {
          _nativeReadyRevision = null;
          _realmMarker = null;
          _realmClaim = null;
          _transitions.finishLogout(succeeded: true);
          return;
        }
        final signedOut = await _commitRealmNativeLogout(realmMarker);
        _sessions.replaceSignedOut(
          signedOut,
        );
      }

      _nativeSession = null;
      _nativeReadyRevision = null;
      _realmMarker = null;
      _realmClaim = null;
      _transitions.finishLogout(succeeded: true);
    } catch (error) {
      // A failed logout stays closed. The exact opaque session remains only so
      // the same realm can retry Rust's idempotent durable logout/retirement.
      _transitions.finishLogout(succeeded: false);
      throw _asNativeSessionException(error);
    }
  }

  Future<SessionIdentityProjection> _commitRealmNativeLogout(
    String realmMarker,
  ) {
    if (!_transitions.hasTerminalIntentFor(realmMarker) ||
        _realmClaim == null) {
      throw const NativeSessionException(
        'native_session_realm_mismatch',
        'The native session belongs to a different page realm.',
      );
    }
    return _commitNativeLogout();
  }

  Future<SessionIdentityProjection> _commitRootNativeLogout() {
    if (!_transitions.hasRootTerminalIntent) {
      throw const NativeSessionException(
        'native_session_transition_in_progress',
        'Native login preparation does not own the terminal transition.',
      );
    }
    return _commitNativeLogout();
  }

  Future<SessionIdentityProjection> _commitNativeLogout() async {
    final session = _nativeSession;
    if (session == null) {
      throw const NativeSessionException(
        'native_session_not_ready',
        'There is no ready native session to log out.',
      );
    }
    final readyRevision = _nativeReadyRevision;
    if (readyRevision == null) {
      throw const NativeSessionException(
        'native_session_not_ready',
        'There is no exact native Ready revision to retire.',
      );
    }
    final serverRevocation = await _platform.revokeCredentialOnServer(
      expectedRevision: readyRevision,
    );
    if (serverRevocation == _NativeCredentialServerRevocation.uncertain) {
      throw const NativeSessionException(
        'native_credential_revocation_uncertain',
        'The server could not confirm native credential revocation.',
      );
    }
    final result = await native.logoutNativeSession(
      root: _root,
      session: session,
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
        readyRevision: readyRevision,
      );
    } finally {
      commitment.fillRange(0, commitment.length, 0);
    }
    return SessionIdentityProjection.signedOut(
      nativeRevision: _canonicalRevision(result.nativeRevision),
    );
  }

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

/// The single accepted establishment and the single terminal intent behind it.
/// This is deliberately not a queue: a second transition is rejected, while
/// either the exact realm or the trusted process root may retire the accepted
/// attempt.
enum _NativeEstablishOutcome { notCommitted, ready }

final class _NativeSessionTransitionSlot {
  Completer<_NativeEstablishOutcome>? _establish;
  String? _establishRealm;
  String? _terminalRealm;
  var _rootTerminalIntent = false;
  var _logoutInFlight = false;

  bool get establishmentInFlight => _establish != null;

  bool get hasRootTerminalIntent => _rootTerminalIntent;

  bool authorizesLogoutRealm(String realmMarker) =>
      _establishRealm == realmMarker || _terminalRealm == realmMarker;

  bool hasTerminalIntentFor(String realmMarker) =>
      _rootTerminalIntent || _terminalRealm == realmMarker;

  void beginEstablish(String realmMarker) {
    if (_rootTerminalIntent || _terminalRealm != null) {
      throw const NativeSessionException(
        'native_session_logout_pending',
        'Native logout must finish before another session can be established.',
      );
    }
    if (_establish != null || _logoutInFlight) {
      throw const NativeSessionException(
        'native_session_transition_in_progress',
        'A native session transition is already in progress.',
      );
    }
    _establish = Completer<_NativeEstablishOutcome>();
    _establishRealm = realmMarker;
  }

  void finishEstablish(_NativeEstablishOutcome outcome) {
    final establish = _establish;
    _establish = null;
    _establishRealm = null;
    if (establish != null && !establish.isCompleted) {
      establish.complete(outcome);
    }
  }

  Future<_NativeEstablishOutcome>? beginLogout(String realmMarker) {
    if (_logoutInFlight) {
      throw const NativeSessionException(
        'native_session_transition_in_progress',
        'A native session transition is already in progress.',
      );
    }
    if (_rootTerminalIntent) {
      throw const NativeSessionException(
        'native_session_logout_pending',
        'Native login preparation must finish before another transition.',
      );
    }
    if ((_establishRealm != null && _establishRealm != realmMarker) ||
        (_terminalRealm != null && _terminalRealm != realmMarker)) {
      throw const NativeSessionException(
        'native_session_realm_mismatch',
        'The native session belongs to a different page realm.',
      );
    }
    _terminalRealm = realmMarker;
    _logoutInFlight = true;
    return _establish?.future;
  }

  Future<_NativeEstablishOutcome>? beginRootLogout() {
    if (_logoutInFlight) {
      throw const NativeSessionException(
        'native_session_transition_in_progress',
        'A native session transition is already in progress.',
      );
    }
    _rootTerminalIntent = true;
    _logoutInFlight = true;
    return _establish?.future;
  }

  void finishLogout({required bool succeeded}) {
    _logoutInFlight = false;
    if (succeeded) {
      _terminalRealm = null;
      _rootTerminalIntent = false;
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
  Future<void> foregroundResume() => Future<void>.value();

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
    accountId: _canonicalString(identity.accountId, 'native account id'),
    address: _canonicalString(identity.address, 'native address'),
    publicKey: _canonicalString(identity.publicKey, 'native public key'),
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
  native.NativeIdentity expectedIdentity,
) {
  if (receipt.protocol != 2 ||
      receipt.nativeRevision != expectedRevision ||
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
