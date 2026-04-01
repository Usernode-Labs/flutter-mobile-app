import 'dart:async';

import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/features/dapps/models/dapp_item.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_challenge_provider.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

class DappsScreen extends ConsumerStatefulWidget {
  const DappsScreen({super.key});

  @override
  ConsumerState<DappsScreen> createState() => _DappsScreenState();
}

class _DappsScreenState extends ConsumerState<DappsScreen> {
  SortMode _sortMode = SortMode.popular;
  bool _forceEnabled = false;

  Future<void> _onRefresh() async {
    ref.invalidate(dappsProvider);
    final futures = <Future<Object>>[ref.read(dappsProvider.future)];
    if (ref.read(dappsLiveProvider) || _forceEnabled) {
      ref.invalidate(dappStatsProvider);
      futures.add(ref.read(dappStatsProvider.future));
    }
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final dappsAsync = ref.watch(dappsProvider);
    final dappsLive = ref.watch(dappsLiveProvider);
    final effectiveLive = dappsLive || _forceEnabled;
    final statsAsync = effectiveLive ? ref.watch(dappStatsProvider) : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: _buildSurfaceSlivers(
              dappsAsync,
              statsAsync,
              spacing,
              sizing,
              effectiveLive,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSurfaceSlivers(
    AsyncValue<List<DappItem>> dappsAsync,
    AsyncValue<Map<String, DappStats>>? statsAsync,
    AppSpacing spacing,
    AppSizing sizing,
    bool dappsLive,
  ) {
    final effectiveSort = dappsLive ? _sortMode : SortMode.alpha;

    return [
      SliverPadding(
        padding: EdgeInsets.only(
          left: spacing.space24,
          right: spacing.space24,
          top: spacing.space8,
        ),
        sliver: SliverToBoxAdapter(
          child: _SortBar(
            sortMode: effectiveSort,
            enabled: dappsLive,
            onSortChanged: (mode) => setState(() => _sortMode = mode),
            onForceEnable:
                dappsLive ? null : () => setState(() => _forceEnabled = true),
          ),
        ),
      ),
      ...dappsAsync.when(
        loading: () => [
          SliverToBoxAdapter(
            child: ShimmerHost(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.space24,
                  vertical: spacing.space8,
                ),
                itemCount: 5,
                separatorBuilder: (_, __) => SizedBox(height: spacing.space12),
                itemBuilder: (_, __) => const ShimmerCardSkeleton(),
              ),
            ),
          ),
        ],
        error: (error, _) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: FullPageErrorState(
              message: 'Failed to load dApps',
              detail: '$error',
              onRetry: () => ref.invalidate(dappsProvider),
            ),
          ),
        ],
        data: (_) {
          final sorted = ref.watch(sortedDappsProvider(effectiveSort));

          if (sorted.isEmpty) {
            return [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Symbols.apps_sharp,
                  title: 'No dApps available',
                ),
              ),
            ];
          }

          return [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: spacing.space24),
              sliver: SliverList.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => SizedBox(height: spacing.space8),
                itemBuilder: (_, index) =>
                    _buildDappCard(context, sorted[index], dappsLive),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: spacing.space32)),
          ];
        },
      ),
    ];
  }

  Widget _buildDappCard(
    BuildContext context,
    DappItem dapp,
    bool dappsLive,
  ) {
    final DappStats? stats = dappsLive
        ? (ref.watch(dappStatsProvider).valueOrNull?[dapp.pubkey])
        : null;
    return DappCard(
      name: dapp.name,
      author: dapp.author,
      description: dapp.description ?? DappCard.kDefaultDescription,
      users: stats?.users,
      txns: stats?.txns,
      enabled: dappsLive,
      disabledLabel: dappsLive ? null : 'Coming soon',
      onTap: dappsLive
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DappWebViewScreen(
                    url: dapp.url,
                    name: dapp.name,
                  ),
                ),
              );
            }
          : null,
    );
  }
}

const _sortLabels = {
  SortMode.popular: 'Popular',
  SortMode.users: 'Most users',
  SortMode.txns: 'Most transactions',
  SortMode.alpha: 'A → Z',
};

class _SortBar extends StatefulWidget {
  const _SortBar({
    required this.sortMode,
    required this.onSortChanged,
    this.enabled = true,
    this.onForceEnable,
  });

  final SortMode sortMode;
  final ValueChanged<SortMode> onSortChanged;
  final bool enabled;
  final VoidCallback? onForceEnable;

  @override
  State<_SortBar> createState() => _SortBarState();
}

class _SortBarState extends State<_SortBar> {
  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizing = theme.extension<AppSizing>()!;
    return SizedBox(
      height: sizing.iconContainerRegular, // 48px content slot
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: widget.onForceEnable != null
                ? (_) {
                    _longPressTimer = Timer(
                      const Duration(seconds: 5),
                      widget.onForceEnable!,
                    );
                  }
                : null,
            onLongPressEnd: widget.onForceEnable != null
                ? (_) => _longPressTimer?.cancel()
                : null,
            onLongPressCancel: widget.onForceEnable != null
                ? () => _longPressTimer?.cancel()
                : null,
            child: Text('dApps', style: theme.textTheme.titleMedium),
          ),
          DropdownChip(
            label: _sortLabels[widget.sortMode]!,
            enabled: widget.enabled,
            onTap: () async {
              final labels = _sortLabels.values.toList();
              final modes = _sortLabels.keys.toList();
              final result = await showDropdownSheet(
                context: context,
                labels: labels,
                title: 'Sort',
                selectedIndex: modes.indexOf(widget.sortMode),
              );
              if (result != null) {
                widget.onSortChanged(modes[result]);
              }
            },
          ),
        ],
      ),
    );
  }
}
