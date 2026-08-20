import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/log_share_provider.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

/// Drops the PROCESS state that a scoped sign-out leaves behind.
///
/// Terminal reset used to be the only cleanup these had: it disposed the
/// provider graph and killed the process. A sign-out keeps both, so every
/// object that captured the retired identity — or that buffers its data
/// without being identity-scoped at all — has to be retired explicitly here,
/// synchronously, before the next identity can be admitted.
///
/// Called from inside the sign-out transition, AFTER the identity namespace
/// and the session prefs are gone, so everything rebuilt here rebuilds against
/// the retired session's absence rather than its leftovers.
Future<void> resetSessionScopedProcessState(Ref ref) async {
  // Identity-agnostic and process-global: the buffer holds whole
  // request/response bodies. Header/credential redaction removes credentials,
  // not identity — profile, wallet and response data stay in the clear, and
  // the next user can both read them in Debug Mode and (because
  // `LogShareController.start` rewinds its cursor to 0) upload them under
  // their own credential.
  HttpDebugLogStore.instance.clear();
  // Disposes any live sharing session (cancelling its flush timer) and resets
  // the cursor; the viewer's URL filter goes with it.
  ref.invalidate(logShareControllerProvider);
  ref.invalidate(httpLogFilterProvider);

  // `AccountsRepository` captures the identity namespace at construction, so
  // the cached instance still addresses the signed-out user's registry.
  // Reconciliation for an already-provisioned successor can finish with
  // `changed == false` and skip its own invalidation, which would leave later
  // bridge signing reading this stale repository.
  ref.invalidate(accountsProvider);

  // The zkPassport rows are bucketed, but these providers watch only the
  // stable repository providers, so their cached values would survive the
  // identity change: the successor would be rendered as the retired user's
  // completed registration, proof nullifier and facematch metadata included.
  //
  // The pipeline controller is deliberately NOT discarded here: its polling
  // worker already re-validates the launch identity on every tick and finalizes
  // a superseded session itself, and invalidating a provider that was never
  // read would construct it just to tear it down.
  ref.invalidate(zkPassportSettingsProvider);
  ref.invalidate(zkPassportIsRegisteredProvider);
  ref.invalidate(zkPassportRegistrationProvider);

  // Error reports raised after this point (and every breadcrumb the successor
  // generates) would otherwise still carry the signed-out account as their
  // Sentry user.
  await SentryUtil.clearUser();
}
