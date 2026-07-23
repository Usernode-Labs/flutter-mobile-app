import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';

final _log = LoggingService.instance.withTag('usernode/ApiVersion');

/// Storage contract version for locally persisted auth/session state.
///
/// Bump this when previously stored state can no longer be interpreted. A
/// device holding anything other than [kCurrentApiVersion] is treated as a new
/// install: its session is cleared and it is sent back to the welcome screen.
const int kCurrentApiVersion = 3;

const String kApiVersionKey = 'app:api_version';

/// Result of the launch-time version check.
class ApiVersionCheck {
  const ApiVersionCheck({required this.stored, required this.cleared});

  /// The version found on disk, or null when absent.
  final int? stored;

  /// Whether local session state was cleared as a result.
  final bool cleared;

  bool get isCurrent => stored == kCurrentApiVersion;
}

/// Reconciles the stored api-version with [kCurrentApiVersion].
///
/// Must run at the very top of bootstrap, before the pref bucket is resolved
/// and before the node can start: both of those read session state, so
/// clearing it afterwards would be too late to affect them.
///
/// Deliberately does **not** touch secure-storage on-chain accounts. An
/// operator who logs back in is recognised as an operator again.
///
/// The new version is not written here. It is written once auth actually
/// resolves — see `AuthStatusNotifier.completeLogin` / `continueAsGuest` — so
/// an upgrade abandoned midway re-prompts on the next launch instead of
/// silently leaving the user in a half-migrated state.
Future<ApiVersionCheck> reconcileApiVersion({
  SharedPreferences? prefs,
  AuthTokenStore? tokenStore,
  UserTypeStore? userTypeStore,
}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  await p.reload();
  final stored = p.getInt(kApiVersionKey);

  if (stored == kCurrentApiVersion) {
    return ApiVersionCheck(stored: stored, cleared: false);
  }

  _log.info(
    stored == null
        ? 'No api-version found; treating as a new install'
        : 'api-version $stored != $kCurrentApiVersion; treating as incompatible upgrade',
  );

  await (tokenStore ?? AuthTokenStore()).clear();
  await (userTypeStore ?? UserTypeStore(prefs: p)).clear();

  return ApiVersionCheck(stored: stored, cleared: true);
}

/// Records that the device is now on [kCurrentApiVersion].
///
/// Called from the auth state transitions rather than from a screen: every auth
/// route is directly reachable, so a deep-linked login must count as resolving
/// the upgrade just as much as tapping through the landing screen does.
Future<void> markApiVersionCurrent({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  await p.setInt(kApiVersionKey, kCurrentApiVersion);
}
