import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/profile/presentation/screens/profile_screen.dart';

/// Unified AppBar component with consistent styling across the app
/// Follows Material Design 3 principles with transparent background and no elevation
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool centerTitle;
  final bool showWalletAndProfile;

  const AppAppBar({
    super.key,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.leading,
    this.centerTitle = false,
    this.showWalletAndProfile = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build default actions with wallet and profile icons
    final defaultActions = showWalletAndProfile
        ? [
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                );
              },
              tooltip: 'Wallet',
            ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              tooltip: 'Profile',
            ),
          ]
        : <Widget>[];

    // Combine custom actions with default actions
    final combinedActions = [
      if (actions != null) ...actions!,
      ...defaultActions,
    ];

    return AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: title != null
          ? Text(
              title!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            )
          : null,
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: centerTitle,
      actions: combinedActions.isNotEmpty ? combinedActions : null,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );
}
