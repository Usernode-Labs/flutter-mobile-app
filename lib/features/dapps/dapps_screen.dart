import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/features/dapps/models/dapp_item.dart';
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
  final _scrollFraction = ValueNotifier<double>(0.0);
  SortMode _sortMode = SortMode.popular;

  @override
  void dispose() {
    _scrollFraction.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(dappsProvider);
    ref.invalidate(dappStatsProvider);
    await ref.read(dappsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final dappsAsync = ref.watch(dappsProvider);
    final statsAsync = ref.watch(dappStatsProvider);

    final dappCount = dappsAsync.valueOrNull?.length;

    return Scaffold(
      body: ParallaxSurfaceLayout(
        headerHeight: kScreenHeaderHeight,
        scrollFractionNotifier: _scrollFraction,
        onRefresh: _onRefresh,
        header: _DappsHeader(
          count: dappCount,
          statsAsync: statsAsync,
        ),
        surfaceSlivers: _buildSurfaceSlivers(
          dappsAsync,
          statsAsync,
          spacing,
          sizing,
        ),
      ),
    );
  }

  List<Widget> _buildSurfaceSlivers(
    AsyncValue<List<DappItem>> dappsAsync,
    AsyncValue<Map<String, DappStats>> statsAsync,
    AppSpacing spacing,
    AppSizing sizing,
  ) {
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: spacing.space24),
        sliver: SliverToBoxAdapter(
          child: _SortBar(
            sortMode: _sortMode,
            onSortChanged: (mode) => setState(() => _sortMode = mode),
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
          final sorted = ref.watch(sortedDappsProvider(_sortMode));

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
                    _buildDappCard(context, sorted[index]),
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
  ) {
    return DappCard(
      name: dapp.name,
      author: dapp.author,
      description: dapp.description ??
          'A decentralized application on the Usernode network.',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DappWebViewScreen(
              url: dapp.url,
              name: dapp.name,
            ),
          ),
        );
      },
    );
  }
}

class _DappsHeader extends StatelessWidget {
  const _DappsHeader({
    required this.count,
    required this.statsAsync,
  });

  final int? count;
  final AsyncValue<Map<String, DappStats>> statsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    final countLabel = count != null ? '$count dApps' : '— dApps';

    // Build subtitle: aggregate stats when available, fallback otherwise.
    String subtitle;
    if (statsAsync.hasValue) {
      final stats = statsAsync.requireValue;
      var totalUsers = 0;
      var totalTxns = 0;
      for (final s in stats.values) {
        totalUsers += s.users;
        totalTxns += s.txns;
      }
      subtitle = (totalUsers == 0 && totalTxns == 0)
          ? 'Fetching activity\u2026'
          : '$totalUsers users · $totalTxns txns';
    } else {
      subtitle = 'Fetching activity\u2026';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          countLabel,
          style: theme.textTheme.displaySmall
              ?.copyWith(fontFamily: kMonoFontFamily),
        ),
        SizedBox(height: spacing.space8),
        Text(
          subtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

const _sortLabels = ['Popular', 'Most users', 'Most transactions', 'A → Z'];

class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sortMode,
    required this.onSortChanged,
  });

  final SortMode sortMode;
  final ValueChanged<SortMode> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizing = theme.extension<AppSizing>()!;
    return SizedBox(
      height: sizing.iconContainerRegular, // 48px content slot
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('dApps', style: theme.textTheme.titleMedium),
          DropdownChip(
            label: _sortLabels[sortMode.index],
            onTap: () async {
              final result = await showDropdownSheet(
                context: context,
                labels: _sortLabels,
                title: 'Sort',
                selectedIndex: sortMode.index,
              );
              if (result != null) {
                onSortChanged(SortMode.values[result]);
              }
            },
          ),
        ],
      ),
    );
  }
}
