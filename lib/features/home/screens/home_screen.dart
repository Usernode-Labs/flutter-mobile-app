import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/produced_blocks_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/background_production_settings_screen.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ProducedBlocksScreen(),
          NodeStatusScreen(),
          BackgroundProductionSettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.layers_outlined),
            selectedIcon: const Icon(Icons.layers),
            label: l10n.navProducedBlocks,
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
    );
  }
}
