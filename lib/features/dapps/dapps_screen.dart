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
    final isError = dappsAsync.hasError;
    final isEmpty =
        dappsAsync.hasValue && (dappsAsync.valueOrNull?.isEmpty ?? true);

    return Scaffold(
      body: ParallaxSurfaceLayout(
        headerHeight: kScreenHeaderHeight,
        onRefresh: _onRefresh,
        surfaceFillsViewport: isError || isEmpty,
        header: _DappsHeader(
          count: dappCount,
          statsAsync: statsAsync,
        ),
        surfaceBody: _buildSurfaceBody(
          dappsAsync,
          statsAsync,
          spacing,
          sizing,
        ),
      ),
    );
  }

  Widget _buildSurfaceBody(
    AsyncValue<List<DappItem>> dappsAsync,
    AsyncValue<Map<String, DappStats>> statsAsync,
    AppSpacing spacing,
    AppSizing sizing,
  ) {
    return dappsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SortBar(
            sortMode: _sortMode,
            onSortChanged: (mode) => setState(() => _sortMode = mode),
            spacing: spacing,
            sizing: sizing,
          ),
          Expanded(
            child: ShimmerHost(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.space16,
                  vertical: spacing.space8,
                ),
                itemCount: 5,
                separatorBuilder: (_, __) => SizedBox(height: spacing.space12),
                itemBuilder: (_, __) => const ShimmerCardSkeleton(),
              ),
            ),
          ),
        ],
      ),
      error: (error, _) => FullPageErrorState(
        message: 'Failed to load dApps',
        detail: '$error',
        onRetry: () => ref.invalidate(dappsProvider),
      ),
      data: (_) {
        final sorted = ref.watch(sortedDappsProvider(_sortMode));

        if (sorted.isEmpty) {
          return const EmptyState(
            icon: Symbols.apps_sharp,
            title: 'No dApps available',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SortBar(
              sortMode: _sortMode,
              onSortChanged: (mode) => setState(() => _sortMode = mode),
              spacing: spacing,
              sizing: sizing,
            ),
            for (var i = 0; i < sorted.length; i++) ...[
              if (i > 0) SizedBox(height: spacing.space12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.space16),
                child: _buildDappCard(context, sorted[i]),
              ),
            ],
            SizedBox(height: spacing.space32),
          ],
        );
      },
    );
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

class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sortMode,
    required this.onSortChanged,
    required this.spacing,
    required this.sizing,
  });

  final SortMode sortMode;
  final ValueChanged<SortMode> onSortChanged;
  final AppSpacing spacing;
  final AppSizing sizing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.space16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('dApps', style: theme.textTheme.titleMedium),
          PopupMenuButton<SortMode>(
            icon: const Icon(Symbols.sort_sharp),
            tooltip: 'Sort',
            onSelected: onSortChanged,
            itemBuilder: (_) => [
              _sortMenuItem(SortMode.popular, 'Popular'),
              _sortMenuItem(SortMode.users, 'Most users'),
              _sortMenuItem(SortMode.txns, 'Most transactions'),
              _sortMenuItem(SortMode.alpha, 'A → Z'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<SortMode> _sortMenuItem(SortMode mode, String label) {
    return PopupMenuItem<SortMode>(
      value: mode,
      child: Row(
        children: [
          if (sortMode == mode)
            Padding(
              padding: EdgeInsets.only(right: spacing.space8),
              child: Icon(Symbols.check_sharp, size: sizing.iconSmall),
            ),
          Text(label),
        ],
      ),
    );
  }
}
