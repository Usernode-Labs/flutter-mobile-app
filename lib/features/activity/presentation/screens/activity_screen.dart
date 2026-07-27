import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/activity/data/models/social_dev_run_transition.dart';
import 'package:crypto_mobile_app/features/activity/presentation/activity_presentation.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_feed_provider.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_providers.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 200) {
      unawaited(ref.read(activityFeedProvider.notifier).loadMore());
    }
  }

  Future<void> _refresh() async {
    final hadEntries = ref.read(activityFeedProvider).entries.isNotEmpty;
    final loaded = await ref.read(activityFeedProvider.notifier).refresh();
    if (!loaded && hadEntries && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).activityLoadError),
        ),
      );
    }
  }

  Future<void> _markRead(ActivityFeedEntry entry) async {
    try {
      await ref.read(activityFeedProvider.notifier).markRead(entry);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).activityMarkReadError),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityFeedProvider);
    final l10n = AppLocalizations.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      // SafeArea/top inset is owned by TopStatusAppBar.large; adding one here
      // would double-inset the pinned root-tab header.
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            TopStatusAppBar.large(
              title: l10n.navActivity,
              nodeStatus: ref.watch(topStatusChromeNodeStatusProvider),
              onProfilePressed: () => context.push(AppRoutes.profile),
              onNodePressed: () => context.push(AppRoutes.mainNode),
            ),
            ..._contentSlivers(state, l10n, spacing),
          ],
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    ActivityFeedState state,
    AppLocalizations l10n,
    AppSpacing spacing,
  ) {
    if (state.phase == ActivityFeedPhase.loading) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            spacing.space16,
            0,
            spacing.space16,
            spacing.space32,
          ),
          sliver: SliverToBoxAdapter(
            child: ShimmerHost(
              child: Column(
                spacing: spacing.space12,
                children: [
                  for (var index = 0; index < 4; index++)
                    const AppCard(
                      padding: EdgeInsets.zero,
                      child: ShimmerListTile(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (state.phase == ActivityFeedPhase.error) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: FullPageErrorState(
            message: l10n.activityLoadError,
            onRetry: () => unawaited(_refresh()),
            retryLabel: l10n.retry,
          ),
        ),
      ];
    }

    if (state.entries.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Symbols.inbox_sharp,
            title: l10n.activityEmptyTitle,
            subtitle: l10n.activityEmptyBody,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        sliver: SliverList.separated(
          itemCount: state.entries.length,
          separatorBuilder: (_, __) => SizedBox(height: spacing.space12),
          itemBuilder: (context, index) {
            final entry = state.entries[index];
            return _ActivityCard(
              entry: entry,
              isMarkingRead: state.markingReadSequences.contains(
                entry.inboxSequence,
              ),
              writesEnabled: ref.watch(activityWritesEnabledProvider),
              now: ref.read(activityClockProvider)(),
              onMarkRead: () => unawaited(_markRead(entry)),
            );
          },
        ),
      ),
      if (state.isLoadingMore)
        SliverPadding(
          padding: EdgeInsets.all(spacing.space16),
          sliver: const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      SliverToBoxAdapter(child: SizedBox(height: spacing.space32)),
    ];
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.entry,
    required this.isMarkingRead,
    required this.writesEnabled,
    required this.now,
    required this.onMarkRead,
  });

  final ActivityFeedEntry entry;
  final bool isMarkingRead;
  final bool writesEnabled;
  final DateTime now;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final l10n = AppLocalizations.of(context);
    final visual = _visualFor(entry, colors);
    final canMarkRead = entry.isUnread && writesEnabled && !isMarkingRead;
    final time = _relativeTimeCopy(
      l10n,
      activityRelativeTime(entry.occurredAt, now),
    );

    return AppCard(
      color: colors.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(vertical: spacing.space8),
      onTap: canMarkRead ? onMarkRead : null,
      child: ListTile(
        isThreeLine: true,
        leading: IconBadge(
          icon: visual.icon,
          backgroundColor: visual.background,
          iconColor: visual.foreground,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.isGeneric ? l10n.navActivity : l10n.activitySourceSocial} • $time',
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: spacing.space4),
            Row(
              children: [
                if (entry.isUnread) ...[
                  Semantics(
                    label: l10n.activitySemanticUnread,
                    child: ExcludeSemantics(
                      child: SizedBox.square(
                        dimension: spacing.space8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.onSurface,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.space8),
                ],
                Expanded(
                  child: Text(
                    l10n.activityItemTitle(entry.titleCopy.name),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: entry.isUnread ? FontWeight.w700 : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Text(
          l10n.activityItemBody(entry.bodyCopy.name),
          style: textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isMarkingRead
            ? SizedBox.square(
                dimension: sizing.iconRegular,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }
}

({IconData icon, Color background, Color foreground}) _visualFor(
  ActivityFeedEntry entry,
  ColorScheme colors,
) {
  final status = entry.transition?.status;
  return switch (status) {
    SocialDevRunStatus.needsInput => (
        icon: Symbols.help_sharp,
        background: colors.tertiaryContainer,
        foreground: colors.onTertiaryContainer,
      ),
    SocialDevRunStatus.succeeded => (
        icon: Symbols.check_circle_sharp,
        background: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
      ),
    SocialDevRunStatus.failed => (
        icon: Symbols.error_sharp,
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
      ),
    SocialDevRunStatus.cancelled => (
        icon: Symbols.cancel_sharp,
        background: colors.surfaceContainerHighest,
        foreground: colors.onSurfaceVariant,
      ),
    null => (
        icon: Symbols.notifications_sharp,
        background: colors.surfaceContainerHighest,
        foreground: colors.onSurfaceVariant,
      ),
  };
}

String _relativeTimeCopy(
  AppLocalizations l10n,
  ActivityRelativeTime relativeTime,
) {
  return switch (relativeTime.unit) {
    ActivityRelativeTimeUnit.now => l10n.timeJustNow,
    ActivityRelativeTimeUnit.minutes => l10n.timeMinutesAgo(relativeTime.value),
    ActivityRelativeTimeUnit.hours => l10n.timeHoursAgo(relativeTime.value),
    ActivityRelativeTimeUnit.days => l10n.timeDaysAgo(relativeTime.value),
  };
}
