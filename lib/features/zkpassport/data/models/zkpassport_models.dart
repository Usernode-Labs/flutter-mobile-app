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
    this.userPublicKey,
  });

  final String requestId;
  final bool facematchStrict;
  final ZkPassportPipelinePhase phase;
  final int createdAtMs;
  final int lastProgressAtMs;
  final int resumeAttemptCount;
  final String? userPublicKey;

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
      if (userPublicKey != null && userPublicKey!.trim().isNotEmpty)
        'userPublicKey': userPublicKey,
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
      userPublicKey: _optionalString(json['userPublicKey']),
    );
  }

  ZkPassportRuntimeSession copyWith({
    String? requestId,
    bool? facematchStrict,
    ZkPassportPipelinePhase? phase,
    int? createdAtMs,
    int? lastProgressAtMs,
    int? resumeAttemptCount,
    String? userPublicKey,
  }) {
    return ZkPassportRuntimeSession(
      requestId: requestId ?? this.requestId,
      facematchStrict: facematchStrict ?? this.facematchStrict,
      phase: phase ?? this.phase,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastProgressAtMs: lastProgressAtMs ?? this.lastProgressAtMs,
      resumeAttemptCount: resumeAttemptCount ?? this.resumeAttemptCount,
      userPublicKey: userPublicKey ?? this.userPublicKey,
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
  });

  final bool registered;
  final String? nullifierHex;
  final int? registeredAtMs;
  final bool? facematchVerified;
  final int? verifyOuterMs;
  final int? wrapOuterMs;
  final int? verifyWrappedMs;

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
  final String? nullifierHex;
  final int? nullifierType;
  final int? uniqueIdentifierType;
  final String? oprfPkHash;
  final String? error;
  final int finalizedAtMs;

  bool get success => status == 'result_ok' && outerProofB64Url != null;

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

class ZkPassportOuterProofPublicInputs {
  const ZkPassportOuterProofPublicInputs({
    required this.semanticInputCount,
    required this.nullifierTypeHex,
    required this.scopedNullifierHex,
    required this.oprfPkHashHex,
  });

  // SDK 0.14 / utils 0.36 trailing semantic public input layout:
  // nullifier_type, scoped_nullifier, oprf_pk_hash.
  static const int outerCount4SemanticPublicInputCount = 9;
  static const int outerCount5SemanticPublicInputCount = 10;

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
    if (inputs.length <= oprfPkHashIndex) {
      return const ZkPassportOuterProofValidation._(
        publicInputs: null,
        errorMessage:
            'Outer proof verified, but SDK 0.14 public inputs were incomplete; cannot derive scoped nullifier and OPRF public key hash.',
        normalizedBridgeNullifierHex: null,
      );
    }

    final nullifierTypeHex = _normalizeHexField(inputs[nullifierTypeIndex]);
    if (nullifierTypeHex == null) {
      return const ZkPassportOuterProofValidation._(
        publicInputs: null,
        errorMessage:
            'Outer proof verified, but nullifier_type was missing from SDK 0.14 public inputs.',
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
            'Outer proof verified, but scoped_nullifier was missing from SDK 0.14 public inputs.',
        normalizedBridgeNullifierHex: null,
      );
    }

    final oprfPkHashHex = _normalizeHexField(inputs[oprfPkHashIndex]);
    if (oprfPkHashHex == null) {
      return const ZkPassportOuterProofValidation._(
        publicInputs: null,
        errorMessage:
            'Outer proof verified, but oprf_pk_hash was missing from SDK 0.14 public inputs.',
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
  if (hex.isEmpty) {
    return null;
  }
  return '0x$hex';
}
