import 'package:flutter/material.dart';

/// Unified AppBar for wallet-related screens
/// Provides consistent styling and behavior across all wallet screens
class WalletAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final Widget? leading;

  const WalletAppBar({
    super.key,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      centerTitle: false,
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );
}
