import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'activity_feed_prototype.stories.g.dart';

const meta = Meta<ActivityFeedPrototype>(
  name: 'Notifications Shell',
  path: 'prototypes/apps',
);

/// Widgetbook-only prototype for validating the activity feed hierarchy,
/// pinned attention treatment, and notification-card rhythm inside a root-tab
/// shell.
class ActivityFeedPrototype extends StatelessWidget {
  const ActivityFeedPrototype({
    super.key,
    this.variant = ActivityFeedVariant.attentionFeed,
    this.appBarSize = TopStatusAppBarSize.large,
    this.nodeStatus = TopStatusNodeStatus.synced,
    this.profileLabel = '25k pts',
  });

  final ActivityFeedVariant variant;
  final TopStatusAppBarSize appBarSize;
  final TopStatusNodeStatus nodeStatus;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          switch (appBarSize) {
            TopStatusAppBarSize.large => TopStatusAppBar.large(
              title: 'Activity',
              profileLabel: profileLabel,
              nodeStatus: nodeStatus,
              onProfilePressed: _noop,
              onNodePressed: _noop,
            ),
            TopStatusAppBarSize.compact => TopStatusAppBar.compact(
              title: 'Activity',
              nodeStatus: nodeStatus,
              onProfilePressed: _noop,
              onNodePressed: _noop,
            ),
            TopStatusAppBarSize.scaffoldCompact => TopStatusAppBar.compact(
              title: 'Activity',
              nodeStatus: nodeStatus,
              onProfilePressed: _noop,
              onNodePressed: _noop,
            ),
          },
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              spacing.space16,
              0,
              spacing.space16,
              spacing.space32,
            ),
            sliver: SliverToBoxAdapter(
              child: _ActivityFeedBody(records: _recordsFor(variant)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _ActivityBottomNav(),
    );
  }
}

enum ActivityFeedVariant {
  attentionFeed,
  pinnedSetup,
  priorityStack,
  longDappRecord,
}

List<_ActivityRecord> _recordsFor(ActivityFeedVariant variant) {
  return switch (variant) {
    ActivityFeedVariant.attentionFeed => _attentionFeedRecords,
    ActivityFeedVariant.pinnedSetup => const [_pinnedSetupRecord],
    ActivityFeedVariant.priorityStack => _priorityStackRecords,
    ActivityFeedVariant.longDappRecord => const [_longDappRecord],
  };
}

class _ActivityFeedBody extends StatelessWidget {
  const _ActivityFeedBody({required this.records});

  final List<_ActivityRecord> records;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.space12,
      children: [
        for (final record in records)
          _ActivityCard(
            routeHint: record.routeHint,
            stateLabel: record.stateLabel,
            timestamp: record.timestamp,
            title: record.title,
            body: record.body,
            unread: record.unread,
            pinned: record.pinned,
            maxBodyLines: record.maxBodyLines,
            onTap: _noop,
          ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.routeHint,
    required this.timestamp,
    required this.title,
    required this.body,
    this.stateLabel,
    this.unread = false,
    this.pinned = false,
    this.maxBodyLines = 2,
    this.onTap,
  });

  final String routeHint;
  final String timestamp;
  final String title;
  final String body;
  final String? stateLabel;
  final bool unread;
  final bool pinned;
  final int maxBodyLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final spacing = theme.extension<AppSpacing>()!;
    final semantic = theme.extension<AppSemanticColors>()!;
    final foreground = pinned
        ? semantic.warning.onColorContainer
        : colors.onSurface;
    final secondaryForeground = pinned
        ? semantic.warning.onColorContainer
        : colors.onSurfaceVariant;

    return Card(
      color: pinned ? semantic.warning.colorContainer : colors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.space8),
          child: ListTile(
            isThreeLine: true,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.space4,
              children: [
                _ActivityHeader(
                  target: routeHint,
                  timestamp: timestamp,
                  color: secondaryForeground,
                ),
                _ActivityTitle(
                  title: title,
                  unread: unread,
                  emphasized: unread || pinned,
                  color: foreground,
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            subtitle: Text(
              body,
              style: textTheme.bodyMedium?.copyWith(color: secondaryForeground),
              maxLines: maxBodyLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityTitle extends StatelessWidget {
  const _ActivityTitle({
    required this.title,
    required this.unread,
    required this.emphasized,
    required this.color,
    required this.style,
  });

  final String title;
  final bool unread;
  final bool emphasized;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final titleStyle = (style ?? const TextStyle()).copyWith(
      color: color,
      fontWeight: emphasized ? FontWeight.w700 : null,
    );
    final fontSize = titleStyle.fontSize ?? defaultTextStyle.fontSize ?? 14;
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(fontSize) *
        (titleStyle.height ?? defaultTextStyle.height ?? 1.2);

    final titleText = Text(
      title,
      style: titleStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    if (!unread) return titleText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: spacing.space8,
          height: lineHeight,
          child: const Center(child: _UnreadDot()),
        ),
        SizedBox(width: spacing.space8),
        Expanded(child: titleText),
      ],
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return SizedBox(
      width: spacing.space8,
      height: spacing.space8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.onSurface,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({
    required this.target,
    required this.timestamp,
    required this.color,
  });

  final String target;
  final String timestamp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: color);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            target,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: spacing.space12),
        Text(
          timestamp,
          style: style?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

final $Default = _Story(
  name: 'Top app bar shell',
  setup: _phoneSetup,
  args: _Args(
    variant: EnumArg(
      ActivityFeedVariant.attentionFeed,
      values: ActivityFeedVariant.values,
    ),
    appBarSize: EnumArg(
      TopStatusAppBarSize.large,
      values: TopStatusAppBarSize.values,
    ),
    nodeStatus: EnumArg(
      TopStatusNodeStatus.synced,
      values: TopStatusNodeStatus.values,
    ),
    profileLabel: StringArg('25k pts'),
  ),
  scenarios: [
    _Scenario(
      name: 'Attention feed',
      args: _Args.fixed(
        variant: ActivityFeedVariant.attentionFeed,
        appBarSize: TopStatusAppBarSize.large,
        nodeStatus: TopStatusNodeStatus.synced,
        profileLabel: '25k pts',
      ),
    ),
    _Scenario(
      name: 'Pinned setup',
      args: _Args.fixed(
        variant: ActivityFeedVariant.pinnedSetup,
        appBarSize: TopStatusAppBarSize.large,
        nodeStatus: TopStatusNodeStatus.synced,
        profileLabel: '25k pts',
      ),
    ),
    _Scenario(
      name: 'Priority stack',
      args: _Args.fixed(
        variant: ActivityFeedVariant.priorityStack,
        appBarSize: TopStatusAppBarSize.large,
        nodeStatus: TopStatusNodeStatus.connecting,
        profileLabel: '25k pts',
      ),
    ),
    _Scenario(
      name: 'Long dApp record',
      args: _Args.fixed(
        variant: ActivityFeedVariant.longDappRecord,
        appBarSize: TopStatusAppBarSize.large,
        nodeStatus: TopStatusNodeStatus.synced,
        profileLabel: '25k pts',
      ),
    ),
    _Scenario(
      name: 'Compact shell',
      args: _Args.fixed(
        variant: ActivityFeedVariant.attentionFeed,
        appBarSize: TopStatusAppBarSize.compact,
        nodeStatus: TopStatusNodeStatus.connecting,
        profileLabel: '25k pts',
      ),
    ),
  ],
);

class _ActivityBottomNav extends StatelessWidget {
  const _ActivityBottomNav();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return BottomNav(
      selectedIndex: 3,
      onItemSelected: (_) {},
      items: [
        const BottomNavItem(
          icon: Symbols.cards_star_sharp,
          label: 'Challenges',
          indicatorShape: NavIndicatorShape.circle,
        ),
        const BottomNavItem(
          icon: Symbols.action_key_sharp,
          label: 'Apps',
          indicatorShape: NavIndicatorShape.circle,
        ),
        const BottomNavItem(
          icon: Symbols.account_balance_wallet_sharp,
          label: 'Wallet',
          indicatorShape: NavIndicatorShape.circle,
        ),
        BottomNavItem(
          icon: Symbols.receipt_long_sharp,
          label: 'Activity',
          indicatorShape: NavIndicatorShape.circle,
          indicatorColor: colors.onSurface,
          indicatorFillColor: colors.secondaryContainer,
        ),
      ],
    );
  }
}

Widget _phoneSetup(
  BuildContext context,
  Widget child,
  ActivityFeedPrototypeArgs args,
) {
  return SizedBox(width: 390, height: 844, child: child);
}

void _noop() {}

class _ActivityRecord {
  const _ActivityRecord({
    required this.routeHint,
    required this.stateLabel,
    required this.timestamp,
    required this.title,
    required this.body,
    this.unread = false,
    this.pinned = false,
    this.maxBodyLines = 2,
  });

  final String routeHint;
  final String stateLabel;
  final String timestamp;
  final String title;
  final String body;
  final bool unread;
  final bool pinned;
  final int maxBodyLines;
}

const _pinnedSetupRecord = _ActivityRecord(
  routeHint: 'Usernode settings',
  stateLabel: 'needs attention',
  timestamp: 'now',
  title: 'Battery optimization is not set up',
  body:
      'Open Usernode settings and set battery usage to Unrestricted so scheduled block production can wake the phone reliably.',
  pinned: true,
);

const _longDappRecord = _ActivityRecord(
  routeHint: 'zkPass Market in dApps',
  stateLabel: 'settled',
  timestamp: 'yesterday',
  title: 'Offer accepted for zkPass #4821',
  body:
      'The marketplace accepted your signed offer and queued settlement. Review the transaction details before archiving this activity.',
  maxBodyLines: 3,
);

const _attentionFeedRecords = [
  _pinnedSetupRecord,
  _ActivityRecord(
    routeHint: 'Challenges',
    stateLabel: 'new challenge',
    timestamp: 'just now',
    title: 'dApp Improvement is live',
    body:
        'A new challenge is open for improving dApp activity flows in Usernode.',
    unread: true,
  ),
  _ActivityRecord(
    routeHint: 'Give Kudos in Challenges',
    stateLabel: 'ending soon',
    timestamp: '1h left',
    title: 'Give Kudos ends soon',
    body: 'You still have 1 kudos left to give before the challenge closes.',
    unread: true,
  ),
  _ActivityRecord(
    routeHint: 'Kudos in dApps',
    stateLabel: 'received',
    timestamp: '4m ago',
    title: 'New Kudos received',
    body: 'A participant gave you Kudos for your latest contribution.',
    unread: true,
  ),
  _ActivityRecord(
    routeHint: 'Builder Board in dApps',
    stateLabel: 'approval needed',
    timestamp: '9m ago',
    title: 'PR waiting for approval',
    body: 'Review the proposed changes before the merge window closes.',
    unread: true,
    maxBodyLines: 3,
  ),
  _ActivityRecord(
    routeHint: 'Node status',
    stateLabel: 'confirmed',
    timestamp: '27m ago',
    title: 'Block produced',
    body:
        'Slot 1284 confirmed. Reward calculation will update after the epoch checkpoint.',
  ),
  _ActivityRecord(
    routeHint: 'Challenges',
    stateLabel: 'pending',
    timestamp: 'yesterday',
    title: 'Reward pending review',
    body:
        'Your Give Kudos activity was recorded. Points will update after review.',
  ),
];

const _priorityStackRecords = [
  _pinnedSetupRecord,
  _ActivityRecord(
    routeHint: 'Node status',
    stateLabel: 'production warning',
    timestamp: '3m ago',
    title: 'Block production needs attention',
    body:
        'The last scheduled production window did not complete. Keep Usernode open and check node status before the next slot.',
    unread: true,
    pinned: true,
    maxBodyLines: 3,
  ),
  _ActivityRecord(
    routeHint: 'Builder Board in dApps',
    stateLabel: 'approval needed',
    timestamp: '7m ago',
    title: 'PR waiting for approval',
    body: 'Review the proposed changes before the merge window closes.',
    unread: true,
  ),
  _ActivityRecord(
    routeHint: 'Give Kudos in Challenges',
    stateLabel: 'ending soon',
    timestamp: '1h left',
    title: 'Give Kudos ends soon',
    body: 'You still have 1 kudos left to give before the challenge closes.',
    unread: true,
  ),
  _ActivityRecord(
    routeHint: 'Falling Sands',
    stateLabel: 'passive receipt',
    timestamp: '12m ago',
    title: 'Canvas changed nearby',
    body: 'A nearby area changed after your last edit.',
  ),
  _ActivityRecord(
    routeHint: 'Node status',
    stateLabel: 'recorded',
    timestamp: '27m ago',
    title: 'Block produced',
    body:
        'Slot 1284 confirmed. Reward calculation will update after the epoch checkpoint.',
  ),
];
