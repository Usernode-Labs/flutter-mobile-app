import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

/// The server-issued namespace this install's local account registry is
/// prefixed with.
///
/// The platform derives it from `sha256(users.id + users.email)` and returns
/// it as `identity_hash` on every mobile user payload
/// (`src/services/mobile-identity-hash.js`). It is stable for the life of the
/// account, which is what lets local accounts outlive a sign-out: the same
/// person signing back in resolves the namespace they left, and a different
/// person resolves one of their own and never sees the first user's accounts.
///
/// Persisted rather than derived because boot restore is deliberately
/// network-free (invariant I6) — it cannot call `/me` to learn the namespace,
/// so the value written at login has to survive the restart.
///
/// A null namespace is not an error: it means either no session yet, or a
/// server that predates the field. Both fall back to the unnamespaced legacy
/// keys, which [adoptLegacyRegistryInto] then migrates on the first
/// authenticated read.
const _identityNamespaceKey = 'identity:namespace';

String _key() => NetworkPrefs.prefixKey(_identityNamespaceKey);

String _keyIn(String network) =>
    NetworkPrefs.prefixKeyWith(_identityNamespaceKey, network);

/// Rejects anything that is not a plausible server-issued namespace, so a
/// malformed payload can never widen a storage key into another user's.
String? normalizeIdentityHash(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(trimmed)) return null;
  return trimmed;
}

Future<String?> loadIdentityNamespace() async {
  final prefs = await SharedPreferences.getInstance();
  return normalizeIdentityHash(prefs.getString(_key()));
}

/// Reads the namespace for an explicit [network], for callers that already
/// resolved one and must not race [NetworkPrefs.currentNetwork].
String? readIdentityNamespaceIn(SharedPreferences prefs, String network) =>
    normalizeIdentityHash(prefs.getString(_keyIn(network)));

/// Records the namespace the current session's local state belongs to. Written
/// inside the login transition, before the session token becomes
/// boot-restorable, so a crash can never leave a restorable session pointing
/// at the previous user's registry.
/// Returns whether the namespace is now exactly [identityHash]. Verified by
/// re-reading rather than trusting the write result: this value decides which
/// user's account registry resolves, so a silently dropped write must be
/// visible to the caller instead of being assumed.
Future<bool> saveIdentityNamespace(String? identityHash) async {
  final prefs = await SharedPreferences.getInstance();
  final normalized = normalizeIdentityHash(identityHash);
  if (normalized == null) return clearIdentityNamespace();
  await prefs.setString(_key(), normalized);
  return normalizeIdentityHash(prefs.getString(_key())) == normalized;
}

/// Returns whether the namespace is now absent. See [saveIdentityNamespace]
/// for why this is verified rather than assumed.
Future<bool> clearIdentityNamespace() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_key());
  return prefs.getString(_key()) == null;
}
