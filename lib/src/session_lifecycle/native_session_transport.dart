part of 'session_operation_kernel.dart';

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

  factory _NativeSessionTicketEnvelope.fromBridgePayload(
    Map<String, dynamic> payload,
  ) {
    final args = _exactMap(
      payload['args'],
      const {
        'attemptId',
        'nativeEstablishTicket',
        'desiredRuntime',
      },
      'establishNativeSession args',
    );
    final ticket = _exactMap(
      args['nativeEstablishTicket'],
      _ticketKeys,
      'nativeEstablishTicket',
    );
    final network = _exactMap(
      ticket['network'],
      const {'id', 'chainId'},
      'nativeEstablishTicket.network',
    );
    final attemptId = _canonicalString(args['attemptId'], 'attemptId');
    final protocol = ticket['protocol'];
    final ticketAttemptId = _canonicalString(
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
    if (args['desiredRuntime'] != 'running' ||
        protocol is! int ||
        protocol != 2 ||
        ticketAttemptId != attemptId ||
        desiredRuntime != 'running' ||
        networkId != 'testnet') {
      throw const NativeSessionException(
        'native_establish_request_mismatch',
        'The native establishment request does not match its ticket.',
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

/// Purpose-specific interactive Android port. It has no generic crypto/read API.
final class _AndroidNativeSessionPlatformPort {
  _AndroidNativeSessionPlatformPort({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.usernode.app/native_session_v2';
  final MethodChannel _channel;

  Future<Uint8List> bootstrapInteractiveRoot() async {
    final value = await _invoke(
      'bootstrapInteractiveRoot',
      const <String, Object?>{},
    );
    if (value is! Uint8List || value.length != 32) {
      throw const NativeSessionException(
        'process_root_proof_invalid',
        'The native process-root proof is invalid.',
      );
    }
    return value;
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

  Future<void> retireCredential({
    required String credentialReference,
    required int credentialGeneration,
    required Uint8List vaultCommitment,
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
      },
    );
  }

  Future<Object?> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      throw NativeSessionException(
        _canonicalErrorCode(error.code),
        error.message ?? 'The native session operation failed.',
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
Future<NativeSessionBridgeIngress> bootstrapNativeSessionBridgeIngress() async {
  final platform = _AndroidNativeSessionPlatformPort();
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

final class _NativeSessionCompositionRoot
    implements NativeSessionBridgeIngress {
  _NativeSessionCompositionRoot._({
    required native.ProcessRootClient root,
    required _AndroidNativeSessionPlatformPort platform,
    required _NativeSessionExchangeTransport exchange,
    required _SessionCompositionRoot sessions,
    required native.SessionNativeClient? nativeSession,
  })  : _root = root,
        _platform = platform,
        _exchange = exchange,
        _sessions = sessions,
        _nativeSession = nativeSession;

  static Future<_NativeSessionCompositionRoot> bootstrap({
    required _AndroidNativeSessionPlatformPort platform,
    required _NativeSessionExchangeTransport exchange,
  }) async {
    final proofBytes = await platform.bootstrapInteractiveRoot();
    try {
      final root = native.takeProcessRoot(
        proof: native.ProcessRootProof(token: proofBytes),
      );
      final snapshot = native.processRootSnapshot(root: root);
      return snapshot.when(
        loggedOut: (nativeRevision) => _NativeSessionCompositionRoot._(
          root: root,
          platform: platform,
          exchange: exchange,
          sessions: _SessionCompositionRoot(
            SessionIdentityProjection.signedOut(
              nativeRevision: _canonicalRevision(nativeRevision),
            ),
          ),
          nativeSession: null,
        ),
        ready: (nativeRevision, identity, _) => _NativeSessionCompositionRoot._(
          root: root,
          platform: platform,
          exchange: exchange,
          sessions: _SessionCompositionRoot(
            _readyProjection(nativeRevision, identity),
          ),
          nativeSession: native.currentNativeSession(
            root: root,
            expectedRevision: nativeRevision,
          ),
        ),
        transitionInProgress: (_) => throw const NativeSessionException(
          'native_session_transition_in_progress',
          'A native session transition is already in progress.',
        ),
        recoveryRequired: (_) => throw const NativeSessionException(
          'native_session_recovery_required',
          'The native session requires recovery.',
        ),
      );
    } finally {
      proofBytes.fillRange(0, proofBytes.length, 0);
    }
  }

  final native.ProcessRootClient _root;
  final _AndroidNativeSessionPlatformPort _platform;
  final _NativeSessionExchangeTransport _exchange;
  final _SessionCompositionRoot _sessions;
  final Random _random = Random.secure();

  native.SessionNativeClient? _nativeSession;
  String? _realmMarker;
  String? _realmClaim;
  final _transitions = _NativeSessionTransitionSlot();

  @override
  Future<Map<String, Object?>> establishNativeSession({
    required Map<String, dynamic> payload,
    required String realmMarker,
  }) async {
    _validateRealmMarker(realmMarker);
    _transitions.beginEstablish(realmMarker);
    try {
      final ticket = _NativeSessionTicketEnvelope.fromBridgePayload(payload);
      final exchangeRequest = await _platform.prepareExchange(ticket);
      final exchangeResult = await _exchange.exchange(exchangeRequest);
      final claimBytes = await _platform.installCredential(
        ticket: ticket,
        exchange: exchangeResult,
      );

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
        _realmMarker = realmMarker;
        _realmClaim = realmClaim;
        if (!_transitions.hasTerminalIntentFor(realmMarker)) {
          try {
            _sessions.login(projection);
          } catch (_) {
            _nativeSession = null;
            _realmMarker = null;
            _realmClaim = null;
            rethrow;
          }
        }
      } else {
        _requireSameProjection(current, projection);
        _nativeSession = session;
        _realmMarker = realmMarker;
        _realmClaim = realmClaim;
      }

      return _establishResponse(receipt, realmClaim);
    } catch (error) {
      throw _asNativeSessionException(error);
    } finally {
      _transitions.finishEstablish();
    }
  }

  @override
  Future<void> logoutNativeSession({required String realmMarker}) async {
    _validateRealmMarker(realmMarker);
    final currentStatus = _sessions.view.current.identity.status;
    if (currentStatus == SessionProjectionStatus.ready) {
      if (!_transitions.authorizesLogoutRealm(realmMarker) &&
          (_realmMarker != realmMarker || _realmClaim == null)) {
        throw const NativeSessionException(
          'native_session_realm_mismatch',
          'The native session belongs to a different page realm.',
        );
      }
    } else if (!_transitions.authorizesLogoutRealm(realmMarker)) {
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
          return _commitNativeLogout(realmMarker);
        });
      } else {
        if (establishCompleted != null) await establishCompleted;
        final signedOut = await _commitNativeLogout(realmMarker);
        _sessions.replaceSignedOut(
          signedOut,
        );
      }

      _nativeSession = null;
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

  Future<SessionIdentityProjection> _commitNativeLogout(
    String realmMarker,
  ) async {
    if (!_transitions.hasTerminalIntentFor(realmMarker) ||
        _realmClaim == null) {
      throw const NativeSessionException(
        'native_session_realm_mismatch',
        'The native session belongs to a different page realm.',
      );
    }
    final session = _nativeSession;
    if (session == null) {
      throw const NativeSessionException(
        'native_session_not_ready',
        'There is no ready native session to log out.',
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
/// This is deliberately not a queue: a second establishment or logout is
/// rejected, while an exact-realm logout may wait for the accepted attempt.
final class _NativeSessionTransitionSlot {
  Completer<void>? _establish;
  String? _establishRealm;
  String? _terminalRealm;
  var _logoutInFlight = false;

  bool authorizesLogoutRealm(String realmMarker) =>
      _establishRealm == realmMarker || _terminalRealm == realmMarker;

  bool hasTerminalIntentFor(String realmMarker) =>
      _terminalRealm == realmMarker;

  void beginEstablish(String realmMarker) {
    if (_terminalRealm != null) {
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
    _establish = Completer<void>();
    _establishRealm = realmMarker;
  }

  void finishEstablish() {
    final establish = _establish;
    _establish = null;
    _establishRealm = null;
    if (establish != null && !establish.isCompleted) establish.complete();
  }

  Future<void>? beginLogout(String realmMarker) {
    if (_logoutInFlight) {
      throw const NativeSessionException(
        'native_session_transition_in_progress',
        'A native session transition is already in progress.',
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

  void finishLogout({required bool succeeded}) {
    _logoutInFlight = false;
    if (succeeded) _terminalRealm = null;
  }
}

final class _FailingNativeSessionBridgeIngress
    implements NativeSessionBridgeIngress {
  const _FailingNativeSessionBridgeIngress(this._failure);

  final NativeSessionException _failure;

  @override
  Future<Map<String, Object?>> establishNativeSession({
    required Map<String, dynamic> payload,
    required String realmMarker,
  }) =>
      Future<Map<String, Object?>>.error(_failure);

  @override
  Future<void> logoutNativeSession({required String realmMarker}) =>
      Future<void>.error(_failure);
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
