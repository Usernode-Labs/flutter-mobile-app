import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';

ChallengePresentationLabels challengePresentationLabels(AppLocalizations l10n) {
  return ChallengePresentationLabels(
    phaseNotDone: l10n.challengePhaseNotDone,
    phaseInProgress: l10n.challengePhaseInProgress,
    phaseSubmitted: l10n.challengePhaseSubmitted,
    phaseWaitingReview: l10n.challengePhaseWaitingReview,
    phaseDone: l10n.challengePhaseDone,
    bandFeatured: l10n.challengeBandFeatured,
    bandToday: l10n.challengeBandToday,
    bandThisWeek: l10n.challengeBandThisWeek,
    bandSeason: l10n.challengeBandSeason,
  );
}

AtomicChallengeDetailLabels atomicChallengeDetailLabels(
  AppLocalizations l10n,
) {
  return AtomicChallengeDetailLabels(
    backTooltip: l10n.walletBack,
    whyItMatters: l10n.challengeSectionTheWhy,
    task: l10n.challengeSectionTask,
    available: l10n.challengeSectionAvailable,
    howPointsWork: l10n.challengeSectionHowPointsWork,
    rules: l10n.challengeSectionRules,
  );
}
