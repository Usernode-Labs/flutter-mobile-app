import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/widgets/node_status_icon.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';

/// Unified AppBar component with consistent styling across the app
/// Follows Material Design 3 principles with transparent background and no elevation
class AppAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool centerTitle;
  final bool showNodeStatus;

  const AppAppBar({
    super.key,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.leading,
    this.centerTitle = false,
    this.showNodeStatus = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final radii = Theme.of(context).extension<AppRadii>()!;

    // Build default actions with node status icon
    final defaultActions = <Widget>[
      if (showNodeStatus) const NodeStatusIcon(),
    ];

    // Combine custom actions with default actions
    final combinedActions = [
      if (actions != null) ...actions!,
      ...defaultActions,
    ];

    return AppBar(
      shape: ShapeBorder.lerp(
        RoundedRectangleBorder(
          borderRadius: radii.borderRadiusLargeIncreased,
        ),
        null,
        0,
      ),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: title != null
          ? Text(
              title!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            )
          : null,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      elevation: 1,
      shadowColor: Colors.black.withAlpha(100),
      actions: combinedActions.isNotEmpty ? combinedActions : null,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );
}
