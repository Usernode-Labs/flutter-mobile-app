import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/profile/providers/token_allocation_provider.dart';

/// DRAFT profile screen scaffold.
///
/// This draft focuses on the season token-allocation reveal — the "little win"
/// card that hides the amount until the user taps **Reveal**. The rest of the
/// profile (score gauge, season selector, completed-challenge and leaderboard
/// tabs) is intentionally out of scope here; see the Widgetbook prototype
/// `prototypes/pages/challenges/TestnetProfilePageDemo` for the intended full
/// composition. A follow-up will flesh this out and swap the mocked
/// [tokenAllocationProvider] for the real rewards API.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final allocation = ref.watch(tokenAllocationProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // TODO(l10n): localize the title once profile strings are added.
          const TopAppBar(title: 'Profile'),
          SliverPadding(
            padding: EdgeInsets.all(spacing.space16),
            sliver: SliverToBoxAdapter(
              child: allocation.when(
                data: (data) => TokenAllocationReveal(
                  // Grouping-separated amount, e.g. 1250 -> "1,250".
                  amount: NumberFormat.decimalPattern().format(data.amount),
                  unitLabel: data.unit,
                  revealed: data.acknowledged,
                  onReveal: () =>
                      ref.read(tokenAllocationProvider.notifier).acknowledge(),
                ),
                loading: () => const ShimmerCardSkeleton(),
                // DRAFT: a real error state (FullPageErrorState / retry) should
                // be added when the rewards API is wired.
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
