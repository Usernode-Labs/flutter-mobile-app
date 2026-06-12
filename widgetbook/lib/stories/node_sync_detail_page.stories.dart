import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/node/screens/widgets/node_sync_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

part 'node_sync_detail_page.stories.g.dart';

const meta = Meta<NodeSyncDetailPage>(path: 'prototypes/pages/node');

final _syncingOverview = NodeSyncOverviewData(
  statusLabel: 'Syncing',
  tone: NodeSyncTone.syncing,
  chainLabel: 'Testnet · Chain 1',
  lastCheckedLabel: 'Last checked at 09:30:18',
  copyChainTooltip: 'Copy chain ID',
);

final _syncedOverview = NodeSyncOverviewData(
  statusLabel: 'Synced',
  tone: NodeSyncTone.synced,
  chainLabel: 'Testnet · Chain 1',
  lastCheckedLabel: 'Last checked at 09:30:18',
  copyChainTooltip: 'Copy chain ID',
);

const _syncingProgress = NodeSyncProgressData(
  title: 'Syncing blocks 12,842/17,280',
  percentLabel: '74%',
  progress: 0.74,
  supportingLabel: 'Fetch 100% · Apply 74%',
);

const _syncedProgress = NodeSyncProgressData(
  title: 'Chain synced 17,280/17,280',
  percentLabel: '100%',
  progress: 1,
  supportingLabel: 'Fetch 100% · Apply 100%',
);

final _sections = [
  NodeSyncDetailSectionData(
    title: 'Network',
    rows: [
      NodeSyncDetailRowData(
        icon: Symbols.hub_sharp,
        title: 'Peers',
        subtitle: '8 of 12 connected',
        trailing: const NodeSyncValueTrailing(text: '8', showChevron: true),
        onTap: () {},
      ),
      NodeSyncDetailRowData(
        icon: Symbols.collections_bookmark_sharp,
        title: 'Epoch 176',
        subtitle: 'Global slot 12,842',
        trailing: const NodeSyncValueTrailing(text: '74%', showChevron: true),
        onTap: () {},
      ),
      NodeSyncDetailRowData(
        icon: Symbols.account_tree_sharp,
        title: 'Mempool',
        subtitle: '12 tx · 48.2 KB',
        trailing: const NodeSyncValueTrailing(text: '12', showChevron: true),
        onTap: () {},
      ),
    ],
  ),
  NodeSyncDetailSectionData(
    title: 'Chain state',
    rows: [
      const NodeSyncDetailRowData(
        icon: Symbols.casino_sharp,
        title: 'VRF',
        subtitle: 'Evaluated 12,842 of 17,280 slots',
        trailing: NodeSyncStatusTrailing(
          text: 'Evaluating',
          variant: StatusBadgeVariant.info,
        ),
      ),
      NodeSyncDetailRowData(
        icon: Symbols.tag_sharp,
        title: 'Best tip',
        subtitle: '8f2c1a44...9d20ef',
        trailing: const NodeSyncStatusTrailing(
          text: 'Synced',
          variant: StatusBadgeVariant.success,
        ),
        onTap: () {},
      ),
    ],
  ),
];

final $Syncing = _Story(
  name: 'Syncing',
  args: _Args(
    title: StringArg('Node Status'),
    overview: Arg.fixed(_syncingOverview),
    progress: Arg.fixed(_syncingProgress),
    sections: Arg.fixed(_sections),
    onBackTap: Arg.fixed(() {}),
    onSettingsTap: Arg.fixed(() {}),
    onCopyChainTap: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'Syncing',
      args: _Args.fixed(
        title: 'Node Status',
        overview: _syncingOverview,
        progress: _syncingProgress,
        sections: _sections,
        onBackTap: () {},
        onSettingsTap: () {},
        onCopyChainTap: () {},
      ),
    ),
    _Scenario(
      name: 'Synced',
      args: _Args.fixed(
        title: 'Node Status',
        overview: _syncedOverview,
        progress: _syncedProgress,
        sections: _sections,
        onBackTap: () {},
        onSettingsTap: () {},
        onCopyChainTap: () {},
      ),
    ),
  ],
);

final $Synced = _Story(
  name: 'Synced',
  args: _Args(
    title: StringArg('Node Status'),
    overview: Arg.fixed(_syncedOverview),
    progress: Arg.fixed(_syncedProgress),
    sections: Arg.fixed(_sections),
    onBackTap: Arg.fixed(() {}),
    onSettingsTap: Arg.fixed(() {}),
    onCopyChainTap: Arg.fixed(() {}),
  ),
);
