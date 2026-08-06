// Bucket-scoped "block production released" flag (onboarding flow
// alignment). Producing blocks is a released capability: the platform
// keeps the queue (`bp_requested_at` / `bp_released_at` on the user) and
// surfaces the decision as `bp_released` on `GET /me` and
// `POST /wallet/provision`. The wallet always works for dapp transactions;
// this flag only gates whether the node is built with a block-producer key
// (see NodeService).

import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

const _bpReleasedKey = 'bp:released';

/// Reads the released flag for the ACTIVE bucket. Defaults to FALSE when
/// never persisted — a node must not produce until the platform has said so
/// at least once.
Future<bool> loadBlockProductionReleased() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(NetworkPrefs.prefixAccountKey(_bpReleasedKey)) ?? false;
}

/// Persists the released flag into an explicit account [bucket]. Written by
/// the account reconciler (off the provision response) and refreshed
/// whenever `/me` is fetched, so an admin release takes effect on the next
/// profile sync + node (re)start.
Future<void> installBlockProductionReleasedInBucket({
  required bool released,
  required String bucket,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(
    NetworkPrefs.prefixAccountKeyFor(_bpReleasedKey, bucket),
    released,
  );
}
