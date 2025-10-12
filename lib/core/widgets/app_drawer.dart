import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final location =
        GoRouter.of(context).routeInformationProvider.value.location ?? '';

    Widget item({
      required IconData icon,
      required String label,
      required String route,
      bool push = false,
    }) {
      final selected = location.startsWith(route);
      return ListTile(
        leading: Icon(icon, color: selected ? colorScheme.primary : null),
        title: Text(
          label,
          style: selected
              ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
              : theme.textTheme.bodyLarge,
        ),
        selected: selected,
        selectedTileColor: colorScheme.surfaceContainerLow,
        onTap: () {
          Navigator.of(context).pop();
          if (push) {
            context.push(route);
          } else {
            context.go(route);
          }
        },
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Usernode',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Primary
            item(icon: Icons.home_outlined, label: 'Home', route: '/main/home'),
            item(
                icon: Icons.hub_outlined,
                label: 'Node Status',
                route: '/main/node'),
            item(
                icon: Icons.apps_outage_outlined,
                label: 'dApps',
                route: '/main/dapps'),
            item(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Wallet',
                route: '/main/wallet'),
            item(
                icon: Icons.person_outline,
                label: 'Profile',
                route: '/main/profile'),

            const Divider(),

            // Secondary
            item(
                icon: Icons.grid_view,
                label: 'Produced Blocks',
                route: '/main/node/produced-blocks',
                push: true),
            item(
                icon: Icons.grid_on,
                label: 'Won Slots',
                route: '/main/node/won-slots',
                push: true),
            item(
                icon: Icons.settings_outlined,
                label: 'Settings',
                route: '/settings',
                push: true),
          ],
        ),
      ),
    );
  }
}
