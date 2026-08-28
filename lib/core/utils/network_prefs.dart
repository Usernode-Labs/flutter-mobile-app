import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Utility for testnet- and identity-scoped SharedPreferences access.
///
/// The `testnet:` prefix is retained as a stable storage namespace even though
/// runtime network selection is no longer supported.
class NetworkPrefs {
  static const currentNetwork = 'testnet';
  static const _globalKeys = {'app:theme_mode'};

  /// Reserved bucket for a guest / no active on-chain account.
  static const guestBucket = 'guest';

  /// The active per-identity storage bucket. Set via [setActiveBucket] when the
  /// active on-chain account or guest state changes; defaults to [guestBucket].
  static String _activeBucket = guestBucket;

  /// Prefix a key with the fixed testnet namespace.
  /// Global keys such as `app:theme_mode` are not prefixed.
  static String prefixKey(String key) {
    if (_globalKeys.contains(key)) return key;
    return '$currentNetwork:$key';
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

  /// Prefix an account-scoped key with the testnet namespace and active
  /// identity bucket for per-identity isolation:
  /// `"testnet:acct:<bucket>:<key>"`.
  /// Global keys pass through unchanged.
  ///
  /// Use for identity-specific state (onboarding flag, season context, produced
  /// blocks, caches). Do NOT use for the account registry itself (index /
  /// active id) — those must resolve the bucket, so keep them on
  /// [prefixKey].
  static String prefixAccountKey(String key) {
    if (_globalKeys.contains(key)) return key;
    return '$currentNetwork:acct:$_activeBucket:$key';
  }

  /// Prefix an account-scoped key with an explicitly named [bucket] instead of
  /// the active one. Used for cross-bucket migrations (e.g. moving data
  /// written under [guestBucket] before an account existed into the account's
  /// bucket) where "whatever bucket is active" is exactly the wrong address.
  static String prefixAccountKeyFor(String key, String bucket) {
    if (_globalKeys.contains(key)) return key;
    return '$currentNetwork:acct:$bucket:$key';
  }
}
