import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

/// What the Challenges tab shows to a tier that cannot take part yet.
///
/// A separate screen rather than a branch inside `ChallengesScreen`: that screen
/// watches the leaderboard bootstrap, challenges, breakdown and ranking
/// providers, and none of that work should run for a user who is only being
/// shown a prompt.
class ChallengesGateScreen extends ConsumerWidget {
  const ChallengesGateScreen({super.key, required this.level});

  final UserLevel level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    // `/me` carries the waiting-list flag. Until it resolves, show the neutral
    // "join" wording rather than claiming a place the user may not have.
    final onWaitlist = ref.watch(meProvider).valueOrNull?.isInWaitlist ?? false;

    final isGuest = level == UserLevel.guest;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space24),
          child: EmptyState(
            icon: isGuest ? Symbols.lock_sharp : Symbols.hourglass_top_sharp,
            title: isGuest
                ? l10n.challengesGuestGateTitle
                : onWaitlist
                    ? l10n.challengesWaitlistJoinedTitle
                    : l10n.challengesWaitlistJoinTitle,
            subtitle: isGuest
                ? l10n.challengesGuestGateBody
                : l10n.challengesWaitlistBody,
            action: isGuest
                ? Button(
                    label: l10n.challengesGuestGateAction,
                    variant: ButtonVariant.primary,
                    onTap: () => context.go(AppRoutes.authLanding),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
