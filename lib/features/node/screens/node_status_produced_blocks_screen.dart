import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/core/providers/node_data_providers.dart';
import 'package:crypto_mobile_app/core/providers/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

class NodeStatusProducedBlocksScreen extends ConsumerStatefulWidget {
  const NodeStatusProducedBlocksScreen({super.key});

  @override
  ConsumerState<NodeStatusProducedBlocksScreen> createState() =>
      _NodeStatusProducedBlocksScreenState();
}

class _NodeStatusProducedBlocksScreenState
    extends ConsumerState<NodeStatusProducedBlocksScreen> {
  Timer? _autoTimer;
  bool _refreshing = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _active = _isActiveTab();
    if (_active) _startTimer();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  bool _isActiveTab() {
    try {
      return ref.read(currentHomeTabProvider) == 0;
    } catch (_) {
      return true;
    }
  }

  void _startTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _active && !_refreshing) {
        _refresh();
      }
    });
  }

  void _stopTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await Future.wait([
        ref.read(nodeBlockchainProvider.notifier).refresh(),
        ref.read(nodeStatusProvider.notifier).refresh(),
      ]);
    } finally {
      if (mounted) {
        _refreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentHomeTabProvider);
    final shouldBeActive = currentTab == 0;
    if (shouldBeActive != _active) {
      _active = shouldBeActive;
      if (_active) {
        _startTimer();
      } else {
        _stopTimer();
      }
    }

    final blockchainAsync = ref.watch(nodeBlockchainProvider);
    final status = ref.watch(nodeStatusProvider).value;
    final rewardsAsync = ref.watch(epochRewardsProvider);
    final rewardPerBlock = rewardsAsync.value?.rewardPerBlock ?? BigInt.zero;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppAppBar(title: l10n.producedBlocksTitle),
      body: _buildBody(
        context,
        blockchainAsync: blockchainAsync,
        bestTipSlot: status?.globalSlot,
        rewardPerBlock: rewardPerBlock,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required AsyncValue<RpcListBlockchainResp?> blockchainAsync,
    required int? bestTipSlot,
    required BigInt rewardPerBlock,
  }) {
    final blockchain = blockchainAsync.valueOrNull;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);

    // Loading — no cached data yet.
    if (blockchain == null && blockchainAsync.isLoading) {
      return ShimmerHost(
        child: Column(
          children: List.generate(
            6,
            (_) => const ShimmerListTile(isThreeLine: false),
          ),
        ),
      );
    }

    // Error — failed with no cached data.
    if (blockchain == null) {
      return FullPageErrorState(
        message: l10n.producedBlocksNoData,
        onRetry: _refresh,
      );
    }

    final items = blockchain.items.take(100).toList();

    // Empty — data loaded but no blocks.
    if (items.isEmpty) {
      return EmptyState(
        icon: Symbols.deployed_code_sharp,
        title: l10n.producedBlocksNoData,
      );
    }

    // Data — list of blocks.
    final rewardText = '+${Utils.formatBigInt(rewardPerBlock)} TKN';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: spacing.space32),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final block = items[i];
          final isBestTip =
              bestTipSlot != null && block.globalSlot == bestTipSlot;
          return _buildBlockTile(context, block, isBestTip, rewardText);
        },
      ),
    );
  }

  Widget _buildBlockTile(
    BuildContext context,
    RpcStatusBlockInfo block,
    bool isBestTip,
    String rewardText,
  ) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return ListTile(
      title: Row(
        children: [
          Text('Block #${block.height}'),
          if (isBestTip) ...[
            SizedBox(width: spacing.space8),
            const StatusBadge(
              label: 'BEST TIP',
              variant: StatusBadgeVariant.info,
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${Utils.timestampToTimeAgo(block.timestamp)} · '
        'Epoch ${block.epoch} · Slot ${block.globalSlot}',
      ),
      trailing: Text(
        rewardText,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.tertiary,
        ),
      ),
      onTap: () => context.push(AppRoutes.mainNodeBlockDetails, extra: block),
    );
  }
}
