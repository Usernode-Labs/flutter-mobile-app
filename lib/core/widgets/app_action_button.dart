import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/config/design_tokens.dart';

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

    final iconSize = switch (size) {
      AppActionButtonSize.compact => kIconSizeSmall,
      AppActionButtonSize.regular => kIconSizeRegular,
      AppActionButtonSize.large => kIconSizeLarge,
    };

    final iconInnerSize = switch (size) {
      AppActionButtonSize.compact => kIconSmall,
      AppActionButtonSize.regular => kIconRegular,
      AppActionButtonSize.large => kIconLarge,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: actionColor.withValues(alpha: kAlphaMedium),
              borderRadius: kBorderRadiusLarge,
              child: InkWell(
                onTap: onTap,
                borderRadius: kBorderRadiusLarge,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace8,
                    vertical: kSpace4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: kBorderRadiusFull,
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
        const SizedBox(height: kSpace8),
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
