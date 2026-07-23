import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/onboarding/data/repositories/registration_repository.dart';

final _log = LoggingService.instance.withTag('usernode/RegistrationFlow');

/// Outcome of [registerAndApply]. [registration] carries the API result
/// (including the freshly persisted `participant_id`); [backendStartFailed]
/// is `true` when the account was imported but the node failed to start.
class RegistrationFlowResult {
  const RegistrationFlowResult({
    required this.registration,
    required this.backendStartFailed,
  });

  final RegistrationResult registration;
  final bool backendStartFailed;
}

/// Registers against the leaderboard API and applies the result locally:
/// imports the returned account, persists the season context, starts the node,
/// resets registration freshness, and invalidates account/participant providers
/// so the UI reacts immediately.
///
/// Re-importing the same address replaces that account rather than adding a
/// second one (see `AccountsRepository._persistNew`). Restore registration is
/// expected to use the same contact+code, so it resolves to the same address
/// and the running node keeps operating on an unchanged key.
///
/// A restore that resolves to a *different* address switches the active account
/// but cannot rebind the running node — `startNode` returns early when a node
/// is already running (`node_service.dart`). That is the same node-lifecycle
/// limitation tracked for the keyless-node work; restore does not attempt to
/// solve it here.
///
/// Shared by the onboarding import screen and the More > Restore registration
/// entry.
/// Re-throws [RegistrationApiException] / [AccountImportException] (and network
/// errors) unchanged so callers can map them to user-facing messages.
Future<RegistrationFlowResult> registerAndApply({
  required WidgetRef ref,
  required String contact,
  required String code,
}) async {
  final registration = await RegistrationRepository()
      .register(registrationCode: code, identifier: contact);

  final repo = await AccountsRepository.create();
  await repo.importFromSecretKey(
    name: 'API Account',
    secretKey: registration.secretKey,
  );
  // The new on-chain account is now active — switch the storage bucket so the
  // account-scoped data below is written under this identity.
  await refreshActiveAccountBucket(guest: false);

  // Persist the participant ID now that the correct identity's bucket is active.
  // register() deliberately does not do this — the active identity is not
  // settled until importFromSecretKey + the bucket switch above have run, so a
  // restore resolving to a different address would otherwise write it into the
  // previous identity's bucket.
  await saveParticipantId(registration.participantId);

  // Persist season context so cold-start can detect staleness. Registration is
  // at the season level, so we don't persist the season-phase eventId.
  if (registration.seasonId != null) {
    await LeaderboardBootstrap.persistSeasonEvent(SeasonEventContext(
      seasonId: registration.seasonId,
      seasonName: registration.seasonName,
    ));
  }

  var backendStartFailed = false;
  try {
    await RustBackendService.instance.startNode();
    _log.debug('Backend started successfully');
  } catch (e, st) {
    _log.error('Failed to start backend', error: e, stackTrace: st);
    backendStartFailed = true;
  }

  // Reset stale registration state (important for the re-registration flow).
  ref.read(registrationFreshnessProvider.notifier).state =
      RegistrationFreshness.unknown;

  // Let the router and participant-gated UI see the new state immediately.
  ref.invalidate(hasAnyAccountProvider);
  ref.invalidate(participantIdProvider);

  return RegistrationFlowResult(
    registration: registration,
    backendStartFailed: backendStartFailed,
  );
}
