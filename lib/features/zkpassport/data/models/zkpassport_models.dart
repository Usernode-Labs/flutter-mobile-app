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
  });

  final String requestId;
  final bool facematchStrict;
  final ZkPassportPipelinePhase phase;
  final int createdAtMs;
  final int lastProgressAtMs;
  final int resumeAttemptCount;

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
    );
  }

  ZkPassportRuntimeSession copyWith({
    String? requestId,
    bool? facematchStrict,
    ZkPassportPipelinePhase? phase,
    int? createdAtMs,
    int? lastProgressAtMs,
    int? resumeAttemptCount,
  }) {
    return ZkPassportRuntimeSession(
      requestId: requestId ?? this.requestId,
      facematchStrict: facematchStrict ?? this.facematchStrict,
      phase: phase ?? this.phase,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastProgressAtMs: lastProgressAtMs ?? this.lastProgressAtMs,
      resumeAttemptCount: resumeAttemptCount ?? this.resumeAttemptCount,
    );
  }
}

class ZkPassportSettings {
  const ZkPassportSettings({
    required this.facematchStrict,
  });

  final bool facematchStrict;

  static const defaults = ZkPassportSettings(facematchStrict: false);

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
  });

  final bool registered;
  final String? nullifierHex;
  final int? registeredAtMs;

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

    return ZkPassportLocalRegistration(
      registered: registered,
      nullifierHex: nullifier,
      registeredAtMs: registeredAtMs,
    );
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
    required this.error,
    required this.finalizedAtMs,
  });

  final String sessionId;
  final String status;
  final String? outerProofB64Url;
  final String? nullifierHex;
  final int? nullifierType;
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
    return ZkPassportSessionResultResponse(
      sessionId:
          (json['sessionId'] as String? ?? json['session_id'] as String? ?? '')
              .trim(),
      status: (json['status'] as String? ?? '').trim(),
      outerProofB64Url: proof,
      nullifierHex: nullifierHex,
      nullifierType: nullifierType,
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
    final result = json['result'];
    if (result is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(result);
    final candidates = [
      map['nullifier_hex'],
      map['nullifierHex'],
      map['scoped_nullifier'],
      map['scopedNullifier'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  static int? _extractNullifierType(Map<String, dynamic> json) {
    final result = json['result'];
    if (result is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(result);
    final raw = map['nullifier_type'] ?? map['nullifierType'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw.trim());
    }
    return null;
  }
}
