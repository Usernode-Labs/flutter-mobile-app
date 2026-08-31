// Models used by the zkPassport demo integration.

enum ZkPassportPipelineStatus {
  idle,
  processing,
  success,
  failure,
}

enum ZkPassportPipelinePhase {
  idle,
  launching,
  waiting,
  resuming,
  proofReceived,
  verifyingOuter,
  wrapping,
  verifyingWrapped,
  success,
  failed,
  timedOut,
}

enum ZkPassportRequestOutcome {
  delivered,
  rejected,
  discarded,
}

/// Identifies one launch even if the bridge reuses a request ID.
///
/// [createdAtMs] remains the wall-clock value used for expiry. [nonce] is a
/// persisted random generation token used only for exact equality.
class ZkPassportRequestVersion {
  const ZkPassportRequestVersion({
    required this.requestId,
    required this.createdAtMs,
    required this.nonce,
  });

  final String requestId;
  final int createdAtMs;
  final String nonce;

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'request_created_at_ms': createdAtMs,
        'request_nonce': nonce,
      };

  static ZkPassportRequestVersion? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final requestId = _optionalString(json['request_id']);
    final createdAtMs = _optionalInt(json['request_created_at_ms']);
    final nonce = _optionalString(json['request_nonce']);
    if (requestId == null || createdAtMs == null || nonce == null) {
      return null;
    }
    return ZkPassportRequestVersion(
      requestId: requestId,
      createdAtMs: createdAtMs,
      nonce: nonce,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ZkPassportRequestVersion &&
        requestId == other.requestId &&
        createdAtMs == other.createdAtMs &&
        nonce == other.nonce;
  }

  @override
  int get hashCode => Object.hash(requestId, createdAtMs, nonce);
}

class ZkPassportPipelineState {
  const ZkPassportPipelineState({
    required this.status,
    required this.phase,
    required this.message,
    required this.updatedAtMs,
    this.requestId,
    this.fetchOuterProofMs,
    this.verifyOuterMs,
    this.wrapOuterMs,
    this.verifyWrappedMs,
    this.resumeAttemptCount,
    this.outerPublicInputsHex,
  });

  final ZkPassportPipelineStatus status;
  final ZkPassportPipelinePhase phase;
  final String message;
  final int updatedAtMs;
  final String? requestId;
  final int? fetchOuterProofMs;
  final int? verifyOuterMs;
  final int? wrapOuterMs;
  final int? verifyWrappedMs;
  final int? resumeAttemptCount;
  final List<String>? outerPublicInputsHex;

  static ZkPassportPipelineState idle() {
    return ZkPassportPipelineState(
      status: ZkPassportPipelineStatus.idle,
      phase: ZkPassportPipelinePhase.idle,
      message: '',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      outerPublicInputsHex: null,
    );
  }

  ZkPassportPipelineState copyWith({
    ZkPassportPipelineStatus? status,
    ZkPassportPipelinePhase? phase,
    String? message,
    int? updatedAtMs,
    String? requestId,
    int? fetchOuterProofMs,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    int? resumeAttemptCount,
    List<String>? outerPublicInputsHex,
  }) {
    return ZkPassportPipelineState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      message: message ?? this.message,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      requestId: requestId ?? this.requestId,
      fetchOuterProofMs: fetchOuterProofMs ?? this.fetchOuterProofMs,
      verifyOuterMs: verifyOuterMs ?? this.verifyOuterMs,
      wrapOuterMs: wrapOuterMs ?? this.wrapOuterMs,
      verifyWrappedMs: verifyWrappedMs ?? this.verifyWrappedMs,
      resumeAttemptCount: resumeAttemptCount ?? this.resumeAttemptCount,
      outerPublicInputsHex: outerPublicInputsHex ?? this.outerPublicInputsHex,
    );
  }
}

class ZkPassportRuntimeSession {
  const ZkPassportRuntimeSession({
    required this.requestId,
    required this.facematchStrict,
    required this.phase,
    required this.createdAtMs,
    required this.lastProgressAtMs,
    required this.resumeAttemptCount,
    this.requestNonce,
    this.userPublicKey,
    this.launchEpoch,
    this.launchBucket,
    this.launchParticipantId,
  });

  final String requestId;
  final bool facematchStrict;
  final ZkPassportPipelinePhase phase;
  final int createdAtMs;
  final int lastProgressAtMs;
  final int resumeAttemptCount;
  final String? requestNonce;
  final String? userPublicKey;

  /// Identity that launched this session, captured at launch time and
  /// persisted with it. Resume/polling/finalization validate the CURRENT
  /// identity against these before acting: [launchBucket] +
  /// [launchParticipantId] identify the launching user durably (they
  /// survive process restarts, unlike [launchEpoch], which is only
  /// meaningful within the process that wrote it). Null on sessions
  /// persisted by older app versions — validation fails open for those.
  final int? launchEpoch;
  final String? launchBucket;
  final int? launchParticipantId;

  ZkPassportRequestVersion? get requestVersion {
    final nonce = requestNonce;
    if (nonce == null) return null;
    return ZkPassportRequestVersion(
      requestId: requestId,
      createdAtMs: createdAtMs,
      nonce: nonce,
    );
  }

  bool get isTerminal =>
      phase == ZkPassportPipelinePhase.success ||
      phase == ZkPassportPipelinePhase.failed ||
      phase == ZkPassportPipelinePhase.timedOut;

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'facematchStrict': facematchStrict,
      'phase': phase.name,
      'createdAtMs': createdAtMs,
      'lastProgressAtMs': lastProgressAtMs,
      'resumeAttemptCount': resumeAttemptCount,
      if (requestNonce != null) 'requestNonce': requestNonce,
      if (userPublicKey != null && userPublicKey!.trim().isNotEmpty)
        'userPublicKey': userPublicKey,
      if (launchEpoch != null) 'launchEpoch': launchEpoch,
      if (launchBucket != null && launchBucket!.trim().isNotEmpty)
        'launchBucket': launchBucket,
      if (launchParticipantId != null)
        'launchParticipantId': launchParticipantId,
    };
  }

  static ZkPassportRuntimeSession? fromJson(Map<String, dynamic> json) {
    final requestIdRaw = json['requestId'];
    final facematchStrict = json['facematchStrict'] == true;
    final phaseRaw = json['phase'];
    final createdAtRaw = json['createdAtMs'];
    final lastProgressRaw = json['lastProgressAtMs'];
    if (requestIdRaw is! String || requestIdRaw.trim().isEmpty) {
      return null;
    }
    if (phaseRaw is! String || phaseRaw.trim().isEmpty) {
      return null;
    }
    ZkPassportPipelinePhase? phase;
    for (final value in ZkPassportPipelinePhase.values) {
      if (value.name == phaseRaw.trim()) {
        phase = value;
        break;
      }
    }
    if (phase == null) {
      return null;
    }
    final createdAtMs = createdAtRaw is int
        ? createdAtRaw
        : (createdAtRaw is String ? int.tryParse(createdAtRaw) : null);
    final lastProgressAtMs = lastProgressRaw is int
        ? lastProgressRaw
        : (lastProgressRaw is String ? int.tryParse(lastProgressRaw) : null);
    if (createdAtMs == null || lastProgressAtMs == null) {
      return null;
    }
    final resumeAttemptRaw = json['resumeAttemptCount'];
    final resumeAttemptCount = resumeAttemptRaw is int
        ? resumeAttemptRaw
        : (resumeAttemptRaw is String
            ? int.tryParse(resumeAttemptRaw) ?? 0
            : 0);

    return ZkPassportRuntimeSession(
      requestId: requestIdRaw.trim(),
      facematchStrict: facematchStrict,
      phase: phase,
      createdAtMs: createdAtMs,
      lastProgressAtMs: lastProgressAtMs,
      resumeAttemptCount: resumeAttemptCount < 0 ? 0 : resumeAttemptCount,
      requestNonce: _optionalString(json['requestNonce']),
      userPublicKey: _optionalString(json['userPublicKey']),
      launchEpoch: _optionalInt(json['launchEpoch']),
      launchBucket: _optionalString(json['launchBucket']),
      launchParticipantId: _optionalInt(json['launchParticipantId']),
    );
  }

  ZkPassportRuntimeSession copyWith({
    String? requestId,
    bool? facematchStrict,
    ZkPassportPipelinePhase? phase,
    int? createdAtMs,
    int? lastProgressAtMs,
    int? resumeAttemptCount,
    String? requestNonce,
    String? userPublicKey,
    int? launchEpoch,
    String? launchBucket,
    int? launchParticipantId,
  }) {
    return ZkPassportRuntimeSession(
      requestId: requestId ?? this.requestId,
      facematchStrict: facematchStrict ?? this.facematchStrict,
      phase: phase ?? this.phase,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastProgressAtMs: lastProgressAtMs ?? this.lastProgressAtMs,
      resumeAttemptCount: resumeAttemptCount ?? this.resumeAttemptCount,
      requestNonce: requestNonce ?? this.requestNonce,
      userPublicKey: userPublicKey ?? this.userPublicKey,
      launchEpoch: launchEpoch ?? this.launchEpoch,
      launchBucket: launchBucket ?? this.launchBucket,
      launchParticipantId: launchParticipantId ?? this.launchParticipantId,
    );
  }
}

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _optionalInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

class ZkPassportSettings {
  const ZkPassportSettings({
    required this.facematchStrict,
  });

  final bool facematchStrict;

  static const defaults = ZkPassportSettings(facematchStrict: true);

  Map<String, dynamic> toJson() {
    return {
      'facematch_strict': facematchStrict,
    };
  }

  static ZkPassportSettings? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    return ZkPassportSettings(
      facematchStrict: json['facematch_strict'] == true,
    );
  }

  ZkPassportSettings copyWith({
    bool? facematchStrict,
  }) {
    return ZkPassportSettings(
      facematchStrict: facematchStrict ?? this.facematchStrict,
    );
  }
}

class ZkPassportLocalRegistration {
  const ZkPassportLocalRegistration({
    required this.registered,
    required this.nullifierHex,
    required this.registeredAtMs,
    this.facematchVerified,
    this.verifyOuterMs,
    this.wrapOuterMs,
    this.verifyWrappedMs,
    this.requestVersion,
  });

  final bool registered;
  final String? nullifierHex;
  final int? registeredAtMs;
  final bool? facematchVerified;
  final int? verifyOuterMs;
  final int? wrapOuterMs;
  final int? verifyWrappedMs;
  final ZkPassportRequestVersion? requestVersion;

  static ZkPassportLocalRegistration unregistered() {
    return const ZkPassportLocalRegistration(
      registered: false,
      nullifierHex: null,
      registeredAtMs: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registered': registered,
      'nullifier_hex': nullifierHex,
      'registered_at_ms': registeredAtMs,
      if (facematchVerified != null) 'facematch_verified': facematchVerified,
      if (verifyOuterMs != null) 'verify_outer_ms': verifyOuterMs,
      if (wrapOuterMs != null) 'wrap_outer_ms': wrapOuterMs,
      if (verifyWrappedMs != null) 'verify_wrapped_ms': verifyWrappedMs,
      if (requestVersion != null) ...requestVersion!.toJson(),
    };
  }

  static ZkPassportLocalRegistration? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);

    final registered = json['registered'] == true;

    final nullifierRaw = json['nullifier_hex'];
    final nullifier = nullifierRaw is String && nullifierRaw.trim().isNotEmpty
        ? nullifierRaw.trim()
        : null;

    final registeredAtRaw = json['registered_at_ms'];
    final registeredAtMs = registeredAtRaw is int
        ? registeredAtRaw
        : (registeredAtRaw is String ? int.tryParse(registeredAtRaw) : null);

    final facematchRaw = json['facematch_verified'];
    final facematchVerified = facematchRaw is bool ? facematchRaw : null;

    final verifyOuterMs = _parseOptionalInt(json['verify_outer_ms']);
    final wrapOuterMs = _parseOptionalInt(json['wrap_outer_ms']);
    final verifyWrappedMs = _parseOptionalInt(json['verify_wrapped_ms']);

    return ZkPassportLocalRegistration(
      registered: registered,
      nullifierHex: nullifier,
      registeredAtMs: registeredAtMs,
      facematchVerified: facematchVerified,
      verifyOuterMs: verifyOuterMs,
      wrapOuterMs: wrapOuterMs,
      verifyWrappedMs: verifyWrappedMs,
      requestVersion: ZkPassportRequestVersion.fromJson(json),
    );
  }

  static int? _parseOptionalInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}

class ZkPassportSessionStartResponse {
  const ZkPassportSessionStartResponse({
    required this.sessionId,
    required this.status,
    required this.launchUrl,
  });

  final String sessionId;
  final String status;
  final String launchUrl;

  factory ZkPassportSessionStartResponse.fromJson(Map<String, dynamic> json) {
    return ZkPassportSessionStartResponse(
      sessionId: (json['session_id'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      launchUrl: (json['launch_url'] as String? ?? '').trim(),
    );
  }
}

class ZkPassportSessionStatusResponse {
  const ZkPassportSessionStatusResponse({
    required this.sessionId,
    required this.status,
    required this.finalAvailable,
    required this.updatedAtMs,
  });

  final String sessionId;
  final String status;
  final bool finalAvailable;
  final int updatedAtMs;

  bool get isTerminal =>
      status == 'result_ok' || status == 'result_error' || status == 'expired';

  factory ZkPassportSessionStatusResponse.fromJson(Map<String, dynamic> json) {
    return ZkPassportSessionStatusResponse(
      sessionId: (json['session_id'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      finalAvailable: json['final_available'] == true,
      updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

class ZkPassportSessionResultResponse {
  const ZkPassportSessionResultResponse({
    required this.sessionId,
    required this.status,
    required this.outerProofB64Url,
    required this.proofName,
    required this.proofVersion,
    required this.proofVkeyHash,
    required this.nullifierHex,
    required this.nullifierType,
    required this.uniqueIdentifierType,
    required this.oprfPkHash,
    required this.error,
    required this.finalizedAtMs,
  });

  final String sessionId;
  final String status;
  final String? outerProofB64Url;
  final String? proofName;
  final String? proofVersion;
  final String? proofVkeyHash;
  final String? nullifierHex;
  final int? nullifierType;
  final int? uniqueIdentifierType;
  final String? oprfPkHash;
  final String? error;
  final int finalizedAtMs;

  bool get success => status == 'result_ok' && outerProofB64Url != null;

  String? validateOuterProofVariant({required bool facematchStrict}) {
    final expected = ZkPassportOuterProofVariant.forFacematch(
      facematchStrict: facematchStrict,
    );
    final normalizedVkeyHash = _normalizeHexField(proofVkeyHash);
    if (proofName == null ||
        proofVersion == null ||
        normalizedVkeyHash == null) {
      return 'Session server returned a proof without complete variant metadata. '
          'Start a new zkPassport verification.';
    }
    if (proofName != expected.proofName ||
        proofVersion != expected.proofVersion ||
        normalizedVkeyHash != expected.proofVkeyHash) {
      return 'Session server returned ${proofName!}@${proofVersion!}, but this '
          'request requires ${expected.proofName}@${expected.proofVersion}. '
          'Start a new zkPassport verification.';
    }
    return null;
  }

  factory ZkPassportSessionResultResponse.fromJson(Map<String, dynamic> json) {
    final proof = _extractOuterProof(
      json['proof'],
      fallbackResult: json['result'],
    );
    final error = _extractError(json);
    final nullifierHex = _extractNullifierHex(json);
    final nullifierType = _extractNullifierType(json);
    final uniqueIdentifierType = _extractUniqueIdentifierType(json);
    final oprfPkHash = _extractOprfPkHash(json);
    return ZkPassportSessionResultResponse(
      sessionId:
          (json['sessionId'] as String? ?? json['session_id'] as String? ?? '')
              .trim(),
      status: (json['status'] as String? ?? '').trim(),
      outerProofB64Url: proof,
      proofName: _extractStringField(json, const [
        'proof_name',
        'proofName',
      ]),
      proofVersion: _extractStringField(json, const [
        'proof_version',
        'proofVersion',
      ]),
      proofVkeyHash: _extractStringField(json, const [
        'proof_vkey_hash',
        'proofVkeyHash',
        'vkey_hash',
        'vkeyHash',
      ]),
      nullifierHex: nullifierHex,
      nullifierType: nullifierType,
      uniqueIdentifierType: uniqueIdentifierType,
      oprfPkHash: oprfPkHash,
      error: error,
      finalizedAtMs:
          (json['finalizedAtMs'] as num? ?? json['finalized_at_ms'] as num?)
                  ?.toInt() ??
              0,
    );
  }

  static String? _extractOuterProof(
    dynamic proofPayload, {
    dynamic fallbackResult,
  }) {
    final direct = _readProofCandidate(proofPayload);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final nestedFromResult = _readProofCandidate(fallbackResult);
    if (nestedFromResult != null && nestedFromResult.isNotEmpty) {
      return nestedFromResult;
    }
    return null;
  }

  static String? _readProofCandidate(dynamic source) {
    if (source is String && source.trim().isNotEmpty) {
      return source.trim();
    }
    if (source is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(source);
    final candidates = [
      map['outer_proof'],
      map['outerProof'],
      map['proof'],
      map['proof_payload'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    final proofs = map['proofs'];
    if (proofs is List) {
      for (final item in proofs) {
        if (item is Map) {
          final encoded = item['proof'];
          if (encoded is String && encoded.trim().isNotEmpty) {
            return encoded.trim();
          }
        }
      }
    }
    return null;
  }

  static String? _extractError(Map<String, dynamic> json) {
    final candidates = [
      json['error'],
      json['message'],
      (json['result'] is Map<String, dynamic>)
          ? (json['result'] as Map<String, dynamic>)['error']
          : null,
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  static String? _extractNullifierHex(Map<String, dynamic> json) {
    return _extractStringField(json, const [
      'nullifier_hex',
      'nullifierHex',
    ]);
  }

  static int? _extractNullifierType(Map<String, dynamic> json) {
    return _extractIntField(json, const [
      'nullifier_type',
      'nullifierType',
    ]);
  }

  static int? _extractUniqueIdentifierType(Map<String, dynamic> json) {
    return _extractIntField(json, const [
      'unique_identifier_type',
      'uniqueIdentifierType',
    ]);
  }

  static String? _extractOprfPkHash(Map<String, dynamic> json) {
    return _extractStringField(json, const [
      'oprf_pk_hash',
      'oprfPkHash',
    ]);
  }

  static String? _extractStringField(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final map in _bridgeResultMaps(json)) {
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  static int? _extractIntField(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final map in _bridgeResultMaps(json)) {
      for (final key in keys) {
        final raw = map[key];
        if (raw is int) {
          return raw;
        }
        if (raw is num) {
          return raw.toInt();
        }
        if (raw is String) {
          final parsed = int.tryParse(raw.trim());
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _bridgeResultMaps(
    Map<String, dynamic> json,
  ) {
    final maps = <Map<String, dynamic>>[json];
    final result = json['result'];
    if (result is Map) {
      maps.add(Map<String, dynamic>.from(result));
    }
    return maps;
  }
}

class ZkPassportOuterProofVariant {
  const ZkPassportOuterProofVariant({
    required this.proofName,
    required this.proofVersion,
    required this.proofVkeyHash,
    required this.semanticPublicInputCount,
    required this.verifierVisiblePublicInputCount,
  });

  static const outerCount4 = ZkPassportOuterProofVariant(
    proofName: 'outer_count_4',
    proofVersion: '0.20.0',
    proofVkeyHash:
        '0x24008eb2af8d866780091c60d602215f5650e50a6c45c992c50ffb0957b1e115',
    semanticPublicInputCount: 9,
    verifierVisiblePublicInputCount: 17,
  );
  static const outerCount5 = ZkPassportOuterProofVariant(
    proofName: 'outer_count_5',
    proofVersion: '0.20.0',
    proofVkeyHash:
        '0x1198dfebe80606e31ccabb351a7f27a9dfc1160e36614523a19a0c3648de2c24',
    semanticPublicInputCount: 10,
    verifierVisiblePublicInputCount: 18,
  );

  final String proofName;
  final String proofVersion;
  final String proofVkeyHash;
  final int semanticPublicInputCount;
  final int verifierVisiblePublicInputCount;

  static ZkPassportOuterProofVariant forFacematch({
    required bool facematchStrict,
  }) {
    return facematchStrict ? outerCount5 : outerCount4;
  }
}

class ZkPassportOuterProofPublicInputs {
  const ZkPassportOuterProofPublicInputs({
    required this.semanticInputCount,
    required this.nullifierTypeHex,
    required this.scopedNullifierHex,
    required this.oprfPkHashHex,
  });

  // SDK 0.16.2 / utils 0.37.5 / circuit v0.20 trailing semantic layout:
  // nullifier_type, scoped_nullifier, oprf_pk_hash.
  static final int outerCount4SemanticPublicInputCount =
      ZkPassportOuterProofVariant.outerCount4.semanticPublicInputCount;
  static final int outerCount5SemanticPublicInputCount =
      ZkPassportOuterProofVariant.outerCount5.semanticPublicInputCount;

  final int semanticInputCount;
  final String nullifierTypeHex;
  final String scopedNullifierHex;
  final String oprfPkHashHex;

  static int semanticInputCountFor({required bool facematchStrict}) {
    return facematchStrict
        ? outerCount5SemanticPublicInputCount
        : outerCount4SemanticPublicInputCount;
  }

  static ZkPassportOuterProofPublicInputs? fromPublicInputsHex(
    List<String>? publicInputsHex, {
    required bool facematchStrict,
  }) {
    return ZkPassportOuterProofValidation.validate(
      publicInputsHex: publicInputsHex,
      facematchStrict: facematchStrict,
    ).publicInputs;
  }
}

class ZkPassportOuterProofValidation {
  const ZkPassportOuterProofValidation._({
    required this.publicInputs,
    required this.errorMessage,
    required this.normalizedBridgeNullifierHex,
  });

  final ZkPassportOuterProofPublicInputs? publicInputs;
  final String? errorMessage;
  final String? normalizedBridgeNullifierHex;

  bool get isValid => publicInputs != null && errorMessage == null;

  static ZkPassportOuterProofValidation validate({
    required List<String>? publicInputsHex,
    required bool facematchStrict,
    String? bridgeNullifierHex,
  }) {
    final inputs = publicInputsHex;
    if (inputs == null || inputs.isEmpty) {
      return const ZkPassportOuterProofValidation._(
        publicInputs: null,
        errorMessage:
            'Outer proof verified, but no public inputs were returned; cannot derive scoped nullifier.',
        normalizedBridgeNullifierHex: null,
      );
    }

    final semanticInputCount =
        ZkPassportOuterProofPublicInputs.semanticInputCountFor(
      facematchStrict: facematchStrict,
    );
    final nullifierTypeIndex = semanticInputCount - 3;
    final scopedNullifierIndex = semanticInputCount - 2;
    final oprfPkHashIndex = semanticInputCount - 1;
    if (inputs.length != semanticInputCount) {
      return ZkPassportOuterProofValidation._(
        publicInputs: null,
        errorMessage: 'Outer proof verified, but ${inputs.length} semantic '
            'public inputs were returned; expected $semanticInputCount for '
            '${facematchStrict ? 'outer_count_5' : 'outer_count_4'}.',
        normalizedBridgeNullifierHex: null,
      );
    }

    final nullifierTypeHex = _normalizeHexField(inputs[nullifierTypeIndex]);
    if (nullifierTypeHex == null) {
      return const ZkPassportOuterProofValidation._(
        publicInputs: null,
        errorMessage:
            'Outer proof verified, but nullifier_type was missing from the v0.20 public inputs.',
        normalizedBridgeNullifierHex: null,
      );
    }

    final scopedNullifierHex = _normalizeHexField(
      inputs[scopedNullifierIndex],
    );
    if (scopedNullifierHex == null) {
      return const ZkPassportOuterProofValidation._(
        publicInputs: null,
        errorMessage:
            'Outer proof verified, but scoped_nullifier was missing from the v0.20 public inputs.',
        normalizedBridgeNullifierHex: null,
      );
    }

    final oprfPkHashHex = _normalizeHexField(inputs[oprfPkHashIndex]);
    if (oprfPkHashHex == null) {
      return const ZkPassportOuterProofValidation._(
        publicInputs: null,
        errorMessage:
            'Outer proof verified, but oprf_pk_hash was missing from the v0.20 public inputs.',
        normalizedBridgeNullifierHex: null,
      );
    }

    final normalizedBridgeNullifierHex = _normalizeHexField(bridgeNullifierHex);
    if (normalizedBridgeNullifierHex != null &&
        normalizedBridgeNullifierHex != scopedNullifierHex) {
      return ZkPassportOuterProofValidation._(
        publicInputs: null,
        errorMessage:
            'Bridge nullifier_hex did not match the verifier-derived scoped_nullifier.',
        normalizedBridgeNullifierHex: normalizedBridgeNullifierHex,
      );
    }

    return ZkPassportOuterProofValidation._(
      publicInputs: ZkPassportOuterProofPublicInputs(
        semanticInputCount: semanticInputCount,
        nullifierTypeHex: nullifierTypeHex,
        scopedNullifierHex: scopedNullifierHex,
        oprfPkHashHex: oprfPkHashHex,
      ),
      errorMessage: null,
      normalizedBridgeNullifierHex: normalizedBridgeNullifierHex,
    );
  }
}

String? _normalizeHexField(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final lower = trimmed.toLowerCase();
  final hex = lower.startsWith('0x') ? lower.substring(2) : lower;
  if (hex.isEmpty || hex.length > 64 || !RegExp(r'^[0-9a-f]+$').hasMatch(hex)) {
    return null;
  }
  return '0x${hex.padLeft(64, '0')}';
}
