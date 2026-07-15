import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
/// Depends on nothing but the participant id.
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

  /// Accepts the current version, then refreshes the data that depends on it.
  /// Acceptance is final in the app: no withdrawal action is exposed.
  Future<void> acceptCurrentTerms() async {
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
