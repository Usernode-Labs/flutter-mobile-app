import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('usernode/Terms');

/// Result of a terms lookup.
///
/// [LeaderboardNotifier] already spends `AsyncData(null)` on "dependencies not
/// satisfied", so a bare `CurrentTerms?` would make "no participant yet",
/// "nothing published", and "loaded" indistinguishable at the call site. This
/// wrapper keeps those apart.
class TermsSnapshot {
  const TermsSnapshot(this.terms);

  /// Null when the backend has nothing published (HTTP 404).
  final CurrentTerms? terms;

  bool get isPublished => terms != null;
}

/// The currently published terms plus this participant's consent.
///
/// Deliberately **not** scoped to season/event. Consent is global, so binding it
/// to `seasonEventContextProvider` the way [RankingController] does would refetch
/// and flicker every time the user changes scope in the season picker.
///
/// Depends on nothing but the participant id. Whether the *gate* may appear yet
/// (onboarding still running, for instance) is a presentation question answered
/// by `TermsGateOverlay`, which keeps this logic free of `providers.dart` and
/// therefore unit-testable.
class CurrentTermsController extends LeaderboardNotifier<TermsSnapshot> {
  @override
  bool watchDeps() => ref.watch(participantIdProvider).valueOrNull != null;

  @override
  Future<TermsSnapshot> fetch() async {
    final participantId = ref.read(participantIdProvider).value!;
    final service = ref.read(leaderboardApiServiceProvider);
    return TermsSnapshot(
      await service.getCurrentTerms(participantId: participantId),
    );
  }

  /// Records [status] for the current version, then refreshes the data that
  /// depends on it. Throws if the POST fails so the caller can surface it.
  Future<void> submitConsent(String status) async {
    final terms = state.valueOrNull?.terms;
    if (terms == null) {
      throw StateError('Cannot submit consent before terms are loaded.');
    }
    final participantId = ref.read(participantIdProvider).valueOrNull;
    if (participantId == null) {
      throw StateError('Cannot submit consent without a participant.');
    }

    final service = ref.read(leaderboardApiServiceProvider);
    await service.postTermsConsent(
      participantId: participantId,
      termsVersionId: terms.id,
      status: status,
      appVersion: await _resolveAppVersion(),
    );

    // Invalidate rather than silentRefresh: the latter swallows errors and
    // preserves the last-good value, which here is the pre-consent state — the
    // profile would keep claiming tokens are withheld after a successful accept.
    // Deliberately not refreshAllLeaderboardData(): its 5s throttle can drop
    // this refresh entirely.
    ref.invalidateSelf();
    ref.invalidate(rankingProvider);
  }
}

final currentTermsProvider =
    AsyncNotifierProvider<CurrentTermsController, TermsSnapshot?>(
  CurrentTermsController.new,
);

/// Whether to show the terms gate on launch.
///
/// True only when a published version has never been answered. A refusal counts
/// as an answer, so refusers are not re-prompted until a new version ships —
/// which resets `consent.status` server-side, so nothing is cached here.
///
/// **Fails open.** A load error or missing participant yields false. The gate is
/// consent capture, not access control: the backend independently forces
/// `total_tokens` to 0 until acceptance, so a user who never sees the gate still
/// cannot obtain tokens. Failing closed would strand offline users on a screen
/// whose content comes from the very request that just failed.
final termsGateProvider = Provider<bool>((ref) {
  // Writes are rejected with HTTP 503 in view-only builds, so both Accept and
  // Refuse would fail behind a no-back gate, trapping the user permanently.
  if (AppConfig.viewOnly) return false;

  final snapshot = ref.watch(currentTermsProvider);
  return snapshot.maybeWhen(
    data: (value) => value?.terms?.awaitingResponse ?? false,
    orElse: () => false,
  );
});

/// App version for the consent audit trail. Never fails the submission: a
/// missing version is worth far less than a lost consent record.
Future<String> _resolveAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (e) {
    _log.warn('Could not resolve app version: $e');
    return 'unknown';
  }
}
