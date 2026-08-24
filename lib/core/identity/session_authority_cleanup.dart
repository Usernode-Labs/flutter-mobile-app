import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/identity/participant_id_store.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';

const _reconcilePendingKey = 'account:reconcile_pending';
const _legacySignOutMarkerName = 'signout_pending';

typedef LegacyAuthorityDirectory = Future<Directory> Function();

/// Deletes the obsolete pre-journal sign-out marker without touching user data.
Future<bool> clearLegacySignOutMarker({
  LegacyAuthorityDirectory? directory,
}) async {
  try {
    final root = await (directory ?? getApplicationSupportDirectory)();
    final file = File(
      '${root.path}/${NetworkPrefs.currentNetwork}.$_legacySignOutMarkerName',
    );
    if (await file.exists()) await file.delete();
    return !await file.exists();
  } catch (_) {
    return false;
  }
}

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
