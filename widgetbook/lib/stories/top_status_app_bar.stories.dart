import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'top_status_app_bar.stories.g.dart';

const meta = Meta<TopStatusAppBarPreview>(path: 'live app/widgets/navigation');

final $Large = _Story(
  name: 'Large',
  args: _Args(
    title: StringArg('Season 1'),
    size: EnumArg(
      TopStatusAppBarSize.large,
      values: TopStatusAppBarSize.values,
    ),
    profileLabel: StringArg('25k pts'),
    nodeStatus: EnumArg(
      TopStatusNodeStatus.synced,
      values: TopStatusNodeStatus.values,
    ),
    onProfilePressed: Arg.fixed(() {}),
    onNodePressed: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'Large synced',
      args: _Args.fixed(
        title: 'Season 1',
        size: TopStatusAppBarSize.large,
        profileLabel: '25k pts',
        nodeStatus: TopStatusNodeStatus.synced,
      ),
    ),
    _Scenario(
      name: 'Large connecting',
      args: _Args.fixed(
        title: 'Season 1',
        size: TopStatusAppBarSize.large,
        profileLabel: '25k pts',
        nodeStatus: TopStatusNodeStatus.connecting,
      ),
    ),
    _Scenario(
      name: 'Compact offline',
      args: _Args.fixed(
        title: 'Season 1',
        size: TopStatusAppBarSize.compact,
        nodeStatus: TopStatusNodeStatus.offline,
      ),
    ),
  ],
  setup: _sliverSetup,
);

final $LargeCollapsed = _Story(
  name: 'Large collapsed',
  args: _Args(
    title: StringArg('Season 1'),
    size: EnumArg(
      TopStatusAppBarSize.large,
      values: TopStatusAppBarSize.values,
    ),
    profileLabel: StringArg('25k pts'),
    nodeStatus: EnumArg(
      TopStatusNodeStatus.synced,
      values: TopStatusNodeStatus.values,
    ),
    onProfilePressed: Arg.fixed(() {}),
    onNodePressed: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'Collapsed synced',
      args: _Args.fixed(
        title: 'Season 1',
        size: TopStatusAppBarSize.large,
        profileLabel: '25k pts',
        nodeStatus: TopStatusNodeStatus.synced,
      ),
    ),
  ],
  setup: _collapsedSliverSetup,
);

final $Compact = _Story(
  name: 'Compact',
  args: _Args(
    title: StringArg('Season 1'),
    size: EnumArg(
      TopStatusAppBarSize.compact,
      values: TopStatusAppBarSize.values,
    ),
    nodeStatus: EnumArg(
      TopStatusNodeStatus.synced,
      values: TopStatusNodeStatus.values,
    ),
    onProfilePressed: Arg.fixed(() {}),
    onNodePressed: Arg.fixed(() {}),
  ),
  setup: _sliverSetup,
);

Widget _collapsedSliverSetup(
  BuildContext context,
  Widget child,
  TopStatusAppBarPreviewArgs args,
) {
  return _buildSliverPreview(
    context,
    child,
    controller: ScrollController(initialScrollOffset: 120),
  );
}

Widget _sliverSetup(
  BuildContext context,
  Widget child,
  TopStatusAppBarPreviewArgs args,
) {
  return _buildSliverPreview(context, child);
}

Widget _buildSliverPreview(
  BuildContext context,
  Widget child, {
  ScrollController? controller,
}) {
  final colors = Theme.of(context).colorScheme;

  return Material(
    color: colors.surfaceContainerLow,
    child: CustomScrollView(
      controller: controller,
      slivers: [
        child,
        SliverList.builder(
          itemCount: 32,
          itemBuilder: (context, index) =>
              ListTile(title: Text('Challenge row ${index + 1}')),
        ),
      ],
    ),
  );
}

class TopStatusAppBarPreview extends StatelessWidget {
  const TopStatusAppBarPreview({
    super.key,
    required this.title,
    required this.size,
    required this.onProfilePressed,
    required this.onNodePressed,
    this.profileLabel = 'Profile',
    this.nodeStatus = TopStatusNodeStatus.synced,
    this.backgroundColor,
    this.forceTransparent = false,
  });

  final String title;
  final TopStatusAppBarSize size;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onNodePressed;
  final String? profileLabel;
  final TopStatusNodeStatus nodeStatus;
  final Color? backgroundColor;
  final bool forceTransparent;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TopStatusAppBarSize.large => TopStatusAppBar.large(
        title: title,
        profileLabel: profileLabel ?? 'Profile',
        nodeStatus: nodeStatus,
        onProfilePressed: onProfilePressed,
        onNodePressed: onNodePressed,
        backgroundColor: backgroundColor,
        forceTransparent: forceTransparent,
      ),
      TopStatusAppBarSize.compact => TopStatusAppBar.compact(
        title: title,
        nodeStatus: nodeStatus,
        onProfilePressed: onProfilePressed,
        onNodePressed: onNodePressed,
        backgroundColor: backgroundColor,
        forceTransparent: forceTransparent,
      ),
      TopStatusAppBarSize.scaffoldCompact => TopStatusAppBar.scaffoldCompact(
        title: title,
        nodeStatus: nodeStatus,
        onProfilePressed: onProfilePressed,
        onNodePressed: onNodePressed,
        backgroundColor: backgroundColor,
        forceTransparent: forceTransparent,
      ),
    };
  }
}
