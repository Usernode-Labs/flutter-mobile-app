import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🔥 NEW
import 'placeholder_screens.dart';

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    WalletPlaceholder(),
    IdentityPlaceholder(),
    StatusPlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // 🔥 NEW: Get localizations

    return Scaffold(
      body: _screens[_currentIndex],
      // 🔥 CHANGED: Using Material 3 NavigationBar instead of BottomNavigationBar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: l10n.home, // 🔥 NEW: Using localized strings
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: l10n.wallet, // 🔥 NEW: Using localized strings
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: l10n.node, // 🔥 NEW: Using localized strings
          ),
        ],
      ),
    );
  }
}
