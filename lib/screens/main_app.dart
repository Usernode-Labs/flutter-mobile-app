import 'package:crypto_mobile_app/screens/home/home_screen.dart';
import 'package:crypto_mobile_app/screens/node/node_status_screen.dart';
import 'package:flutter/material.dart';
import '../gen_l10n/app_localizations.dart';
import 'wallet/wallet_screen.dart';
import 'package:crypto_mobile_app/config/feature_flags.dart';

class MainApp extends StatefulWidget {
  final AppFeature? initialFeature;
  const MainApp({super.key, this.initialFeature});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  Widget _screenFor(AppFeature f) {
    switch (f) {
      case AppFeature.home:
        return const HomeScreen();
      case AppFeature.wallet:
        return const WalletScreen();
      case AppFeature.node:
        return const NodeStatusScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    // Apply initial feature selection once
    if (widget.initialFeature != null) {
      final active = FeatureFlags.ordered.where(FeatureFlags.isEnabled).toList();
      final desired = active.indexOf(widget.initialFeature!);
      if (desired >= 0) {
        _currentIndex = desired;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final active = FeatureFlags.ordered.where(FeatureFlags.isEnabled).toList();
    // Clamp current index to available items without relying on num.clamp casting.
    int index = _currentIndex;
    final maxIndex = active.isEmpty ? 0 : active.length - 1;
    if (index > maxIndex) index = maxIndex;
    if (index < 0) index = 0;
    final screens = active.map(_screenFor).toList(growable: false);

    return Scaffold(
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          for (final f in active)
            switch (f) {
              AppFeature.home => NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: l10n.home,
                ),
              AppFeature.wallet => NavigationDestination(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: const Icon(Icons.account_balance_wallet),
                  label: l10n.wallet,
                ),
              AppFeature.node => NavigationDestination(
                  icon: const Icon(Icons.hub_outlined),
                  selectedIcon: const Icon(Icons.hub),
                  label: l10n.node,
                ),
            }
        ],
      ),
    );
  }
}
