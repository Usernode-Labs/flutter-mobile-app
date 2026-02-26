import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/wallet/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/produced_blocks_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/background_production_settings_screen.dart';
import 'package:crypto_mobile_app/features/dapps/dapps_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/config/theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentNetwork = ref.watch(currentNetworkProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final index = ref.watch(currentHomeTabProvider);

    // Conditional colors based on network
    final backgroundColor = currentNetwork == 'internal'
        ? MaterialTheme.getInternalNetworkBackgroundColor(isDark)
        : theme.colorScheme.surfaceBright;

    final borderColor = currentNetwork == 'internal'
        ? MaterialTheme.getInternalNetworkBorderColor(isDark)
        : theme.colorScheme.outlineVariant;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          ChallengesScreen(),
          ProducedBlocksScreen(),
          WalletScreen(),
          DappsScreen(),
          NodeStatusScreen(),
          BackgroundProductionSettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(
              color: borderColor,
              width: 1,
            ),
          ),
        ),
        child: Theme(
          data: theme.copyWith(
            navigationBarTheme: NavigationBarThemeData(
              labelTextStyle: WidgetStateTextStyle.resolveWith((states) {
                return theme.textTheme.bodySmall?.copyWith(fontSize: 10) ??
                    const TextStyle(fontSize: 10);
              }),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: index,
            labelBehavior: screenWidth < 400
                ? NavigationDestinationLabelBehavior.alwaysHide
                : NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) {
              ref.read(currentHomeTabProvider.notifier).state = i;
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.star_outline),
                selectedIcon: Icon(Icons.star),
                label: 'Challenges',
              ),
              NavigationDestination(
                icon: const Icon(Icons.layers_outlined),
                selectedIcon: const Icon(Icons.layers),
                label: l10n.navProducedBlocks,
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet),
                label: l10n.navWallet,
              ),
              NavigationDestination(
                icon: const Icon(Icons.apps_outlined),
                selectedIcon: const Icon(Icons.apps),
                label: l10n.navDapps,
              ),
              NavigationDestination(
                icon: const Icon(Icons.check_circle_outline),
                selectedIcon: const Icon(Icons.check_circle),
                label: l10n.navNodeStatus,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: l10n.navSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
