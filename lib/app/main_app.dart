import 'package:crypto_mobile_app/features/home/presentation/screens/home_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/dapps/presentation/screens/dapps_screen.dart';
import 'package:crypto_mobile_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'package:go_router/go_router.dart';

class MainApp extends StatefulWidget {
  final AppFeature? initialFeature;
  final Widget? child; // when using go_router ShellRoute
  final String? currentLocation; // provided by ShellRoute
  const MainApp({super.key, this.initialFeature, this.child, this.currentLocation});

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
      case AppFeature.dapps:
        return const DAppsScreen();
      case AppFeature.profile:
        return const ProfileScreen();
      case AppFeature.node:
        return const NodeStatusScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    // Apply initial feature selection once
    if (widget.initialFeature != null) {
      final active =
          FeatureFlags.ordered.where(FeatureFlags.isEnabled).toList();
      final desired = active.indexOf(widget.initialFeature!);
      if (desired >= 0) {
        _currentIndex = desired;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = widget.currentLocation ?? '';

    // Filter out wallet and profile from bottom navigation
    final active = FeatureFlags.ordered
        .where(FeatureFlags.isEnabled)
        .where((f) => f != AppFeature.wallet && f != AppFeature.profile)
        .toList();

    // Clamp current index to available items and align with router location when child provided.
    int index = _currentIndex;
    final maxIndex = active.isEmpty ? 0 : active.length - 1;
    if (index > maxIndex) index = maxIndex;
    if (index < 0) index = 0;

    // If using ShellRoute (child provided), derive index from current location path
    if (widget.child != null) {
      final idxFromLoc = active.indexWhere((f) => location.startsWith(_pathFor(f)));
      if (idxFromLoc >= 0) index = idxFromLoc;
    }
    final screens = active.map(_screenFor).toList(growable: false);

    return Scaffold(
      body: widget.child ?? screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          final target = active[i];
          final path = _pathFor(target);
          if (widget.child != null) context.go(path);
        },
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
              AppFeature.dapps => NavigationDestination(
                  icon: const Icon(Icons.apps_outlined),
                  selectedIcon: const Icon(Icons.apps),
                  label: l10n.dapps,
                ),
              AppFeature.profile => NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: l10n.profile,
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

  String _pathFor(AppFeature f) {
    switch (f) {
      case AppFeature.home:
        return '/main/home';
      case AppFeature.node:
        return '/main/node';
      case AppFeature.dapps:
        return '/main/dapps';
      case AppFeature.wallet:
        return '/main/wallet';
      case AppFeature.profile:
        return '/main/profile';
    }
  }
}
