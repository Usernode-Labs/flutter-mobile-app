import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/identity/participant_id_store.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';

const _reconcilePendingKey = 'account:reconcile_pending';

/// Clears compatibility artifacts that identify the retiring session while
/// retaining namespaced wallets and all account-scoped user data.
Future<bool> clearCompatibilitySessionAuthority(AuthGuestFlag guestFlag) async {
  if (!await guestFlag.clear()) return false;
  final prefs = await SharedPreferences.getInstance();
  final marker = NetworkPrefs.prefixKey(_reconcilePendingKey);
  await prefs.remove(marker);
  await prefs.reload();
  if (prefs.containsKey(marker)) return false;
  if (!await clearGuestParticipantId()) return false;

  return clearIdentityNamespace();
}
