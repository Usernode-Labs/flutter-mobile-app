import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/wallet/screens/wallet_screen.dart';
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
    final index = ref.watch(currentHomeTabProvider);
    final isInternal = currentNetwork == 'internal';

    final textTheme = theme.textTheme;
    final dsTheme = ColorIsExpensiveTheme(textTheme).light().copyWith(
          extensions: DesignSystemTheme.standardExtensions(
            semanticColors: AppSemanticColors.light(),
          ),
        );

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          ChallengesScreen(),
          WalletScreen(),
          DappsScreen(),
          NodeStatusScreen(),
          BackgroundProductionSettingsScreen(),
        ],
      ),
      bottomNavigationBar: Theme(
        data: dsTheme,
        child: Builder(
          builder: (context) {
            final semantic = Theme.of(context).extension<AppSemanticColors>()!;

            final items = [
              BottomNavItem(
                icon: Symbols.cards_star_sharp,
                label: l10n.navChallenges,
                indicatorShape: NavIndicatorShape.circle,
                indicatorColor: semantic.flash.color,
                indicatorFillColor: semantic.flash.colorContainer,
              ),
              BottomNavItem(
                icon: Symbols.account_balance_wallet_sharp,
                label: l10n.navWallet,
                indicatorShape: NavIndicatorShape.circle,
                indicatorColor: semantic.flash.color,
                indicatorFillColor: semantic.flash.colorContainer,
              ),
              BottomNavItem(
                icon: Symbols.action_key_sharp,
                label: l10n.navDapps,
                indicatorShape: NavIndicatorShape.blob,
                indicatorColor: semantic.community.color,
                indicatorFillColor: semantic.community.colorContainer,
              ),
              BottomNavItem(
                icon: Symbols.check_circle_sharp,
                label: l10n.navNodeStatus,
                indicatorShape: NavIndicatorShape.hexagon,
                indicatorColor: semantic.technical.color,
                indicatorFillColor: semantic.technical.colorContainer,
              ),
              BottomNavItem(
                icon: Symbols.settings_sharp,
                label: l10n.navSettings,
                indicatorShape: NavIndicatorShape.hexagon,
                indicatorColor: semantic.technical.color,
                indicatorFillColor: semantic.technical.colorContainer,
              ),
            ];

            Widget bottomNav = BottomNav(
              items: items,
              selectedIndex: index,
              onItemSelected: (i) {
                ref.read(currentHomeTabProvider.notifier).state = i;
              },
              topBorder: !isInternal,
            );

            if (isInternal) {
              bottomNav = Container(
                decoration: BoxDecoration(
                  color: MaterialTheme.getInternalNetworkBackgroundColor(
                    isDark,
                  ),
                  border: Border(
                    top: BorderSide(
                      color: MaterialTheme.getInternalNetworkBorderColor(
                        isDark,
                      ),
                    ),
                  ),
                ),
                child: bottomNav,
              );
            }

            return bottomNav;
          },
        ),
      ),
    );
  }
}
