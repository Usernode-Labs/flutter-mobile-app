import 'package:crypto_mobile_app/core/widgets/clock_drift_warning_overlay.dart';
import 'package:crypto_mobile_app/features/node/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'package:go_router/go_router.dart';

class MainApp extends StatefulWidget {
  final AppFeature? initialFeature;
  final Widget? child; // when using go_router ShellRoute
  final String? currentLocation; // provided by ShellRoute
  const MainApp(
      {super.key, this.initialFeature, this.child, this.currentLocation});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  Widget _screenFor(AppFeature f) {
    switch (f) {
      case AppFeature.settings:
        return const SettingsScreen();
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
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final location = widget.currentLocation ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    // Include all enabled features in bottom navigation
    final active = FeatureFlags.ordered.where(FeatureFlags.isEnabled).toList();

    // Clamp current index to available items and align with router location when child provided.
    int index = _currentIndex;
    final maxIndex = active.isEmpty ? 0 : active.length - 1;
    if (index > maxIndex) index = maxIndex;
    if (index < 0) index = 0;

    // If using ShellRoute (child provided), derive index from current location path
    if (widget.child != null) {
      final idxFromLoc =
          active.indexWhere((f) => location.startsWith(_pathFor(f)));
      if (idxFromLoc >= 0) index = idxFromLoc;
    }
    final screens = active.map(_screenFor).toList(growable: false);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: widget.child ?? screens[index]),
          const ClockDriftWarningOverlay(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, -4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: NavigationBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedIndex: index,
          height: 55,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          onDestinationSelected: (i) {
            setState(() => _currentIndex = i);
            final target = active[i];
            final path = _pathFor(target);
            if (widget.child != null) context.go(path);
          },
          destinations: [
            for (final f in active)
              switch (f) {
                AppFeature.settings => const NavigationDestination(
                    icon: Icon(Symbols.settings_sharp),
                    selectedIcon: Icon(Symbols.settings_sharp, fill: 1),
                    label: 'Settings',
                  ),
                AppFeature.node => NavigationDestination(
                    icon: const Icon(Symbols.hub_sharp),
                    selectedIcon: const Icon(Symbols.hub_sharp, fill: 1),
                    label: l10n?.node ?? 'Node',
                  ),
              }
          ],
        ),
      ),
    );
  }

  String _pathFor(AppFeature f) {
    switch (f) {
      case AppFeature.node:
        return '/main/node';
      case AppFeature.settings:
        return '/main/settings';
    }
  }
}
