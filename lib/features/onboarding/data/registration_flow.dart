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
/// imports the returned account (overwriting any existing one), persists the
/// season context, (re)starts the node, resets registration freshness, and
/// invalidates account/participant providers so the UI reacts immediately.
///
/// Shared by the onboarding import screen and the participant-recovery dialog.
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
