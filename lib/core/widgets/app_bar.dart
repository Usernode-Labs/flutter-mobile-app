import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/providers/notifications_provider.dart';
import 'package:crypto_mobile_app/core/widgets/notification_badge.dart';

/// Unified AppBar component with consistent styling across the app
/// Follows Material Design 3 principles with transparent background and no elevation
class AppAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool centerTitle;
  final bool showNotifications;

  const AppAppBar({
    super.key,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.leading,
    this.centerTitle = false,
    this.showNotifications = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsState = ref.watch(notificationsProvider);

    // Build default actions with only notifications icon
    final defaultActions = showNotifications
        ? [
            IconButton(
              icon: NotificationBadge(
                count: notificationsState.unreadCount,
                child: Icon(
                  notificationsState.unreadCount > 0
                      ? Icons.notifications
                      : Icons.notifications_outlined,
                ),
              ),
              onPressed: () => context.push('/notifications'),
              tooltip: 'Notifications',
            ),
          ]
        : <Widget>[];

    // Combine custom actions with default actions
    final combinedActions = [
      if (actions != null) ...actions!,
      ...defaultActions,
    ];

    return AppBar(
      shape: ShapeBorder.lerp(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
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
