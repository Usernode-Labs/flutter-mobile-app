import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';

final _log =
    LoggingService.instance.withTag('usernode/NodeAccountProvisioning');

/// Ensures a local on-chain account exists for the signed-in user, creating
/// one on-device when none does.
///
/// The retired v2 registration flow imported a server-generated secret key;
/// with platform auth (v4) there is no registration endpoint, so the key pair
/// is generated locally instead. The backend learns the wallet address later
/// through flows that submit it (e.g. zkPassport completion).
///
/// Returns `true` when a new account was created, `false` when one already
/// existed. Throws ([AccountImportException] or FFI errors) on failure so the
/// caller can surface it; onboarding must not proceed without an account or
/// the router loops back to onboarding forever (`hasAny == false`).
Future<bool> ensureLocalNodeAccount(WidgetRef ref) async {
  final repo = await AccountsRepository.create();
  if (await repo.hasAny()) {
    _log.trace('Account already exists - nothing to provision');
    return false;
  }

  final generated = accountGenerateRandom();
  await repo.importFromSecretKey(
    name: 'Node Account',
    secretKey: generated.secretKey,
  );

  // The new on-chain account is now active — switch the storage bucket so
  // account-scoped data is written under this identity.
  await refreshActiveAccountBucket(guest: false);

  // Let the router and account-gated UI see the new state immediately.
  // backendLifecycleProvider watches hasAnyAccountProvider and starts the
  // node when it flips false -> true.
  ref.invalidate(hasAnyAccountProvider);
  ref.invalidate(accountsProvider);
  ref.invalidate(activeAccountProvider);

  _log.info('Provisioned local node account for fresh sign-up');
  return true;
}
