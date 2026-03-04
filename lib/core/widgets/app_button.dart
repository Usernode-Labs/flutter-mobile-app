import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

/// Unified primary button component
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonSize size;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.size = AppButtonSize.regular,
    this.variant = AppButtonVariant.filled,
  });

  const AppButton.filled({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.filled;

  const AppButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;
    final spacing = theme.extension<AppSpacing>()!;

    final height = switch (size) {
      AppButtonSize.small => sizing.buttonHeightSmall,
      AppButtonSize.regular => sizing.buttonHeightRegular,
      AppButtonSize.large => sizing.buttonHeightLarge,
    };

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == AppButtonVariant.filled
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: sizing.iconSmall),
                SizedBox(width: spacing.space8),
              ],
              Text(label),
            ],
          );

    final pillShape = RoundedRectangleBorder(
      borderRadius: radii.borderRadiusFull,
    );

    return SizedBox(
      height: height,
      child: switch (variant) {
        AppButtonVariant.filled => FilledButton(
            onPressed: isLoading ? null : onPressed,
            style: FilledButton.styleFrom(shape: pillShape),
            child: child,
          ),
        AppButtonVariant.outlined => OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(shape: pillShape),
            child: child,
          ),
        AppButtonVariant.text => TextButton(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(shape: pillShape),
            child: child,
          ),
      },
    );
  }
}

enum AppButtonSize {
  small,
  regular,
  large,
}

enum AppButtonVariant {
  filled,
  outlined,
  text,
}
