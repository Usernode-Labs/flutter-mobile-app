import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';

/// The More tab: destinations that do not warrant their own nav slot.
///
/// Settings and Node Status are sibling pages in the HomeScreen `IndexedStack`,
/// so they are opened by switching [currentHomeTabProvider] rather than by
/// pushing a route — that keeps their existing "am I the active tab?" listeners
/// working. Profile is a real route and is pushed.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: spacing.space12),
          children: [
            ListSectionHeader(title: l10n.navMore),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Symbols.person_sharp),
                    title: Text(l10n.moreProfile),
                    trailing: const Icon(Symbols.chevron_right),
                    onTap: () => context.push(AppRoutes.profile),
                  ),
                  ListTile(
                    leading: const Icon(Symbols.lan_sharp),
                    title: Text(l10n.moreNodeStatus),
                    trailing: const Icon(Symbols.chevron_right),
                    onTap: () => ref
                        .read(currentHomeTabProvider.notifier)
                        .state = HomeTab.nodeStatus,
                  ),
                  ListTile(
                    leading: const Icon(Symbols.settings_sharp),
                    title: Text(l10n.moreSettings),
                    trailing: const Icon(Symbols.chevron_right),
                    onTap: () => ref
                        .read(currentHomeTabProvider.notifier)
                        .state = HomeTab.settings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
