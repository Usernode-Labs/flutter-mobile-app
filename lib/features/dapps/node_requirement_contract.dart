/// Exact native bridge request accepted by `requiresNode`.
///
/// Page wrappers must release guards explicitly. A JavaScript finalizer may
/// call the same release shape as a best-effort backup; native additionally
/// retires guards when their document realm, WebView, or session disappears.
sealed class NodeRequirementRequest {
  const NodeRequirementRequest({required this.scope});

  static final RegExp _scopePattern = RegExp(r'^[A-Za-z][A-Za-z0-9._-]{0,63}$');

  final String scope;

  factory NodeRequirementRequest.fromBridgeArgs(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('args must be an object');
    }
    final requiredValue = value['required'];
    if (requiredValue is! bool) {
      throw const FormatException('args.required must be a bool');
    }
    final scope = value['scope'];
    if (scope is! String || !_scopePattern.hasMatch(scope)) {
      throw const FormatException(
        'args.scope must be a canonical node-requirement scope',
      );
    }

    if (requiredValue) {
      _rejectUnknownKeys(value, const {'required', 'scope'});
      return NodeRequirementAcquire(scope: scope);
    }

    _rejectUnknownKeys(value, const {'required', 'scope', 'guardId'});
    final guardId = value['guardId'];
    if (guardId is! String ||
        guardId.isEmpty ||
        guardId.length > 128 ||
        guardId.trim() != guardId) {
      throw const FormatException(
        'args.guardId must be a non-empty canonical string',
      );
    }
    return NodeRequirementRelease(scope: scope, guardId: guardId);
  }
}

final class NodeRequirementAcquire extends NodeRequirementRequest {
  const NodeRequirementAcquire({required super.scope});
}

final class NodeRequirementRelease extends NodeRequirementRequest {
  const NodeRequirementRelease({
    required super.scope,
    required this.guardId,
  });

  final String guardId;
}

void _rejectUnknownKeys(
  Map<String, dynamic> value,
  Set<String> allowed,
) {
  final unknown = value.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) {
    throw FormatException('args contains unsupported field ${unknown.first}');
  }
}
