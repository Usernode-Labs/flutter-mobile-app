import 'package:flutter/foundation.dart';

/// The complete owner of Android runtime and scheduling work.
///
/// The Rust journal issues this tuple. Alarm IDs, engine IDs and operation
/// IDs are diagnostics only and never extend its authority.
@immutable
class RuntimeOwner {
  const RuntimeOwner({
    required this.sessionId,
    required this.runtimeGeneration,
    required this.accountId,
    required this.address,
  });

  static const sessionIdKey = 'session_id';
  static const runtimeGenerationKey = 'runtime_generation';
  static const accountIdKey = 'account_id';
  static const addressKey = 'address';

  final String sessionId;
  final int runtimeGeneration;
  final String accountId;
  final String address;

  Map<String, dynamic> toMap() => {
        sessionIdKey: sessionId,
        runtimeGenerationKey: runtimeGeneration,
        accountIdKey: accountId,
        addressKey: address,
      };

  static RuntimeOwner? fromMap(Map<dynamic, dynamic>? value) {
    if (value == null) return null;
    final sessionId = _nonEmptyString(value[sessionIdKey]);
    final generation = value[runtimeGenerationKey];
    final accountId = _nonEmptyString(value[accountIdKey]);
    final address = _nonEmptyString(value[addressKey]);
    if (sessionId == null ||
        generation is! int ||
        generation <= 0 ||
        accountId == null ||
        address == null) {
      return null;
    }
    return RuntimeOwner(
      sessionId: sessionId,
      runtimeGeneration: generation,
      accountId: accountId,
      address: address,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeOwner &&
          sessionId == other.sessionId &&
          runtimeGeneration == other.runtimeGeneration &&
          accountId == other.accountId &&
          address == other.address;

  @override
  int get hashCode => Object.hash(
        sessionId,
        runtimeGeneration,
        accountId,
        address,
      );
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
