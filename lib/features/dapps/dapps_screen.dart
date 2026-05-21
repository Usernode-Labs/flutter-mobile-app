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
  SortMode _sortMode = SortMode.popular;

  Future<void> _onRefresh() async {
    ref.invalidate(dappsProvider);
    ref.invalidate(dappStatsProvider);
    await Future.wait([
      ref.read(dappsProvider.future),
      ref.read(dappStatsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final dappsAsync = ref.watch(dappsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: _buildSurfaceSlivers(
              dappsAsync,
              spacing,
              sizing,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSurfaceSlivers(
    AsyncValue<List<DappItem>> dappsAsync,
    AppSpacing spacing,
    AppSizing sizing,
  ) {
    return [
      SliverPadding(
        padding: EdgeInsets.only(
          left: spacing.space24,
          right: spacing.space24,
          top: spacing.space8,
        ),
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
    final stats = ref.watch(dappStatsProvider).valueOrNull?[dapp.pubkey];
    return DappCard(
      name: dapp.name,
      author: dapp.author,
      description: dapp.description ?? DappCard.kDefaultDescription,
      users: stats?.users,
      txns: stats?.txns,
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

const _sortLabels = {
  SortMode.popular: 'Popular',
  SortMode.users: 'Most users',
  SortMode.txns: 'Most transactions',
  SortMode.alpha: 'A → Z',
};

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
            label: _sortLabels[sortMode]!,
            onTap: () async {
              final labels = _sortLabels.values.toList();
              final modes = _sortLabels.keys.toList();
              final result = await showDropdownSheet(
                context: context,
                labels: labels,
                title: 'Sort',
                selectedIndex: modes.indexOf(sortMode),
              );
              if (result != null) {
                onSortChanged(modes[result]);
              }
            },
          ),
        ],
      ),
    );
  }
}
