import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_opacity.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

/// Unified action button component for consistent quick actions across the app
/// Supports icon + label layout with optional badge and multiple size variants
class AppActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final String? badge;
  final AppActionButtonSize size;

  const AppActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.badge,
    this.size = AppActionButtonSize.regular,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionColor = color ?? theme.colorScheme.primary;
    final sizing = theme.extension<AppSizing>()!;
    final opacity = theme.extension<AppOpacity>()!;
    final radii = theme.extension<AppRadii>()!;
    final spacing = theme.extension<AppSpacing>()!;

    final iconSize = switch (size) {
      AppActionButtonSize.compact => sizing.iconContainerSmall,
      AppActionButtonSize.regular => sizing.iconContainerRegular,
      AppActionButtonSize.large => sizing.iconContainerLarge,
    };

    final iconInnerSize = switch (size) {
      AppActionButtonSize.compact => sizing.iconSmall,
      AppActionButtonSize.regular => sizing.iconRegular,
      AppActionButtonSize.large => sizing.iconLarge,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: actionColor.withValues(alpha: opacity.medium),
              borderRadius: radii.borderRadiusLarge,
              child: InkWell(
                onTap: onTap,
                borderRadius: radii.borderRadiusLarge,
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: actionColor,
                    size: iconInnerSize,
                  ),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.space8,
                    vertical: spacing.space4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: radii.borderRadiusFull,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.space8),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

enum AppActionButtonSize {
  compact,
  regular,
  large,
}
