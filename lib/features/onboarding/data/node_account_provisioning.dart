import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log =
    LoggingService.instance.withTag('usernode/NodeAccountProvisioning');

/// Ensures the signed-in user's platform-allocated on-chain account is
/// imported locally, fetching it from `POST /wallet/provision` when no
/// local account exists yet.
///
/// The retired v2 registration flow imported a server-allocated secret key;
/// the v4 provisioning endpoint restores exactly that: the backend returns
/// the user's allocated account (the same one on every device — migrated
/// users and reinstalls included), allocating one from the season pool for
/// fresh users. A client-generated random key cannot work here: the backend
/// rejects wallets without a matching `onchain_accounts` row (zkPassport
/// completion, slot-outcome attribution), so the account must come from the
/// platform.
///
/// Returns `true` when an account was imported, `false` when one already
/// existed. Throws ([LeaderboardApiException], [AccountImportException],
/// network errors) on failure so the caller can surface it; onboarding must
/// not proceed without an account or the router loops back to onboarding
/// forever (`hasAny == false`).
Future<bool> ensureLocalNodeAccount(WidgetRef ref) async {
  final repo = await AccountsRepository.create();
  if (await repo.hasAny()) {
    _log.trace('Account already exists - nothing to provision');
    return false;
  }

  final api = ref.read(leaderboardApiServiceProvider);
  final provisioned = await api.provisionWallet();
  _log.info('Wallet provisioned', context: {
    'address': provisioned.address,
    'newlyAllocated': provisioned.newlyAllocated,
  });

  await repo.importFromSecretKey(
    name: 'Node Account',
    secretKey: provisioned.secretKey,
  );

  // The participant id was persisted at login, when no account existed yet,
  // so it lives in the pre-account storage bucket. Read it BEFORE switching
  // buckets and re-save it under the new account's bucket, or it resolves
  // null after the next restart and ZK backend completion gets skipped.
  final participantId = await loadParticipantId();

  // The new on-chain account is now active — switch the storage bucket so
  // account-scoped data is written under this identity.
  await refreshActiveAccountBucket(guest: false);

  if (participantId != null) {
    await saveParticipantId(participantId);
  } else {
    _log.warn('No persisted participant id to migrate into account bucket');
  }

  // Let the router and account-gated UI see the new state immediately.
  // backendLifecycleProvider watches hasAnyAccountProvider and starts the
  // node when it flips false -> true.
  ref.invalidate(hasAnyAccountProvider);
  ref.invalidate(accountsProvider);
  ref.invalidate(activeAccountProvider);
  ref.invalidate(participantIdProvider);

  _log.info('Imported platform-allocated node account');
  return true;
}
