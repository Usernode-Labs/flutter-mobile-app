import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/design/design_tokens.dart';

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
    final height = switch (size) {
      AppButtonSize.small => kButtonHeightSmall,
      AppButtonSize.regular => kButtonHeightRegular,
      AppButtonSize.large => kButtonHeightLarge,
    };

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == AppButtonVariant.filled
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: kIconSmall),
                const SizedBox(width: kSpace8),
              ],
              Text(label),
            ],
          );

    return SizedBox(
      height: height,
      child: switch (variant) {
        AppButtonVariant.filled => FilledButton(
            onPressed: isLoading ? null : onPressed,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadiusFull),
              ),
            ),
            child: child,
          ),
        AppButtonVariant.outlined => OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadiusFull),
              ),
            ),
            child: child,
          ),
        AppButtonVariant.text => TextButton(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadiusFull),
              ),
            ),
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
