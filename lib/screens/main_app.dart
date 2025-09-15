import 'package:crypto_mobile_app/screens/home/home_screen.dart';
import 'package:crypto_mobile_app/screens/node/node_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto_mobile_app/utils/sentry.dart';
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

    final body = Scaffold(
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

    // Overlay a tiny debug menu button in debug/profile builds only
    if (kDebugMode || kProfileMode) {
      return Stack(
        children: [
          body,
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: _DebugMenuButton(),
              ),
            ),
          ),
        ],
      );
    }

    return body;
  }
}

class _DebugMenuButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.9),
      elevation: 2,
      shape: const StadiumBorder(),
      child: PopupMenuButton<_DebugAction>(
        tooltip: 'Debug menu',
        icon: Icon(Icons.bug_report, color: colorScheme.primary),
        onSelected: (a) async {
          switch (a) {
            case _DebugAction.sentryMessage:
              await SentryUtil.captureMessage('Debug: test message from menu');
              break;
            case _DebugAction.sentryHandledError:
              try {
                throw Exception('Debug: test exception (handled)');
              } catch (e, st) {
                await SentryUtil.captureError(e, st, tag: 'debug-menu');
              }
              break;
          }
          // Provide a tiny UX hint
          if (context.mounted) {
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.showSnackBar(
              const SnackBar(content: Text('Debug action sent')),
            );
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _DebugAction.sentryMessage,
            child: Text('Send Sentry test message'),
          ),
          PopupMenuItem(
            value: _DebugAction.sentryHandledError,
            child: Text('Send Sentry handled exception'),
          ),
        ],
      ),
    );
  }
}

enum _DebugAction { sentryMessage, sentryHandledError }
