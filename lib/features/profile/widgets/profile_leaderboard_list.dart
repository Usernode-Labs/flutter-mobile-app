import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

class ProfileLeaderboardEntryData {
  const ProfileLeaderboardEntryData({
    required this.rank,
    required this.name,
    required this.points,
    this.isCurrentUser = false,
  });

  final String rank;
  final String name;
  final String points;
  final bool isCurrentUser;
}

class ProfileLeaderboardList extends StatelessWidget {
  const ProfileLeaderboardList({
    super.key,
    required this.entries,
    required this.emptyLabel,
  });

  final List<ProfileLeaderboardEntryData> entries;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        spacing.space16,
        spacing.space12,
        spacing.space16,
        spacing.space32,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.space4),
      itemBuilder: (context, index) {
        return ProfileLeaderboardRow(entry: entries[index]);
      },
    );
  }
}

class ProfileLeaderboardRow extends StatelessWidget {
  const ProfileLeaderboardRow({
    super.key,
    required this.entry,
  });

  final ProfileLeaderboardEntryData entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: entry.isCurrentUser
          ? colors.primaryContainer.withValues(alpha: opacity.strong)
          : Colors.transparent,
      borderRadius: radii.borderRadiusLargeIncreased,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: RankBadge(rank: entry.rank),
        title: Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium,
        ),
        trailing: Text(
          entry.points,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
