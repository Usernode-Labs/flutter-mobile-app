import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility for network-aware SharedPreferences access.
/// All keys are prefixed with the current network name to achieve
/// complete data isolation between networks (testnet/internal/custom).
class NetworkPrefs {
  static const networkKey = 'network:type';
  static const _globalKeys = {networkKey, 'app:theme_mode'};

  /// Reserved bucket for a guest / no active on-chain account.
  static const guestBucket = 'guest';

  static String? _cachedNetwork;

  /// The active per-identity storage bucket. Set via [setActiveBucket] when the
  /// active on-chain account or guest state changes; defaults to [guestBucket].
  static String _activeBucket = guestBucket;

  static const _allowedNetworks = {'testnet', 'internal', 'custom'};

  static String _normalizeNetwork(String? network) {
    if (network == null || network.isEmpty) return 'testnet';
    return _allowedNetworks.contains(network) ? network : 'testnet';
  }

  /// Get the current network type synchronously (after initialization).
  static String get currentNetwork => _cachedNetwork ?? 'testnet';

  /// Initialize the network cache. Call this early in app startup.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedNetwork = _normalizeNetwork(prefs.getString(networkKey));
  }

  /// Get the current network type from storage.
  static Future<String> getNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedNetwork = _normalizeNetwork(prefs.getString(networkKey));
    return _cachedNetwork!;
  }

  /// Mirrors the network already committed by the durable session journal.
  /// Invalid journal values fail closed instead of silently selecting testnet.
  static Future<void> adoptAuthorityNetwork(String network) async {
    if (!_allowedNetworks.contains(network)) {
      throw ArgumentError.value(network, 'network', 'unsupported network');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(networkKey, network);
    if (prefs.getString(networkKey) != network) {
      throw StateError('Session authority network could not be persisted');
    }
    _cachedNetwork = network;
  }

  /// Drops process-local routing state after the durable preference wipe.
  /// The next cold launch therefore starts from the same default network and
  /// guest bucket that an empty preference store represents.
  static void resetForApplicationReset() {
    _cachedNetwork = null;
    _activeBucket = guestBucket;
  }

  /// Prefix a key with the current network name.
  /// Global keys (network:type, app:theme_mode) are not prefixed.
  static String prefixKey(String key) {
    if (_globalKeys.contains(key)) return key;
    return '$currentNetwork:$key';
  }

  /// Prefix a key with a specific network name.
  static String prefixKeyWith(String key, String network) {
    if (_globalKeys.contains(key)) return key;
    return '$network:$key';
  }

  /// The active per-identity bucket (a hash of the on-chain address, or
  /// [guestBucket]).
  static String get activeBucket => _activeBucket;

  /// The bucket name for an on-chain [address]: first 16 hex chars of
  /// sha256(address). Exposed so callers can address a bucket without
  /// activating it (ownership checks, cross-bucket migrations).
  static String bucketForAddress(String address) =>
      sha256.convert(utf8.encode(address)).toString().substring(0, 16);

  /// Sets the active bucket from the on-chain [address]. A guest session, or the
  /// absence of an address, resolves to [guestBucket] so no on-chain identity's
  /// data is loaded. See [bucketForAddress] for the naming scheme.
  static void setActiveBucket(String? address, {required bool guest}) {
    if (guest || address == null || address.isEmpty) {
      _activeBucket = guestBucket;
      return;
    }
    _activeBucket = bucketForAddress(address);
  }

  /// Prefix an account-scoped key with the current network AND active identity
  /// bucket for per-identity isolation: `"<network>:acct:<bucket>:<key>"`.
  /// Global keys pass through unchanged.
  ///
  /// Use for identity-specific state (onboarding flag, season context, produced
  /// blocks, caches). Do NOT use for the account registry itself (index /
  /// active id) — those must resolve the bucket, so keep them on
  /// [prefixKey]/[prefixKeyWith].
  static String prefixAccountKey(String key) {
    if (_globalKeys.contains(key)) return key;
    return '$currentNetwork:acct:$_activeBucket:$key';
  }

  /// Prefix an account-scoped key with an explicitly named [bucket] instead of
  /// the active one. Used for cross-bucket migrations (e.g. moving data
  /// written under [guestBucket] before an account existed into the account's
  /// bucket) where "whatever bucket is active" is exactly the wrong address.
  static String prefixAccountKeyFor(String key, String bucket) {
    return prefixAccountKeyForIn(key, bucket, currentNetwork);
  }

  /// Prefixes an account key from explicit journal-owned routing.
  static String prefixAccountKeyForIn(
    String key,
    String bucket,
    String network,
  ) {
    if (_globalKeys.contains(key)) return key;
    return '$network:acct:$bucket:$key';
  }
}
