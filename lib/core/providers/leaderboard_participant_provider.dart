import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/participant_id_store.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';

export 'package:crypto_mobile_app/core/identity/participant_id_store.dart';

/// The participant ID (v4 `user.id`) of the current identity.
///
/// Carried on the [Identity] snapshot for authenticated identities; falls
/// back to the active bucket's persisted value for local-only sessions.
/// Rebuilds on every identity transition (login, logout, reconcile, season
/// rollover) because it watches the snapshot itself.
final participantIdProvider = FutureProvider<int?>((ref) async {
  final identity = ref.watch(identityProvider);
  return identity.participantId ?? await loadParticipantId();
});

/// In-memory season/event selection shared across all leaderboard providers.
final seasonEventContextProvider = StateProvider<SeasonEventContext>(
  (ref) => const SeasonEventContext(),
);
