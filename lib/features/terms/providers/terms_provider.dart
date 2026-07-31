import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('usernode/Terms');

/// Result of a terms lookup.
///
/// [LeaderboardNotifier] already spends `AsyncData(null)` on "dependencies not
/// satisfied", so a bare `CurrentTerms?` would make "no participant yet",
/// "nothing published", and "loaded" indistinguishable at the call site. This
/// wrapper keeps those apart.
class TermsSnapshot {
  const TermsSnapshot({required this.terms, required this.owner});

  /// Null when the backend has nothing published (HTTP 404).
  final CurrentTerms? terms;
  final AuthenticatedUserLease owner;

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
  bool watchDeps() => ref.watch(authenticatedUserLeaseProvider) != null;

  @override
  Future<TermsSnapshot> fetch(AuthenticatedUserLease owner) async {
    final service = ref.read(leaderboardApiServiceProvider);
    return TermsSnapshot(
      terms: await service.getCurrentTerms(authority: owner),
      owner: owner,
    );
  }

  /// Accepts the current version, then refreshes the data that depends on it.
  /// Acceptance is final in the app: no withdrawal action is exposed.
  Future<void> acceptCurrentTerms() async {
    final snapshot = state.valueOrNull;
    final terms = snapshot?.terms;
    if (terms == null) {
      throw StateError('Cannot submit consent before terms are loaded.');
    }
    final owner = snapshot!.owner;
    if (!owner.isCurrent) {
      throw const StaleIdentityLeaseException();
    }

    final appVersion = await ref.read(termsAppVersionProvider.future);
    final service = ref.read(leaderboardApiServiceProvider);
    await service.postTermsConsent(
      termsVersionId: terms.id,
      appVersion: appVersion,
      authority: owner,
    );

    if (!canPublish(owner)) return;

    // Invalidate rather than silentRefresh: the latter swallows errors and
    // preserves the last-good value, which here is the pre-consent state — the
    // profile would keep claiming tokens are withheld after a successful accept.
    // Deliberately not refreshAllLeaderboardData(): its 5s throttle can drop
    // this refresh entirely.
    ref.invalidateSelf();
    ref.invalidate(rankingProvider);
  }
}

final authenticatedUserLeaseProvider = Provider<AuthenticatedUserLease?>((ref) {
  final identity = ref.watch(identityProvider);
  return AuthenticatedUserLease.capture(identity);
});

final termsAppVersionProvider = FutureProvider<String>((ref) {
  return _resolveAppVersion();
});

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
