import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

/// Button size — controls height.
enum ButtonSize {
  /// 40px height.
  small,

  /// 48px height (default).
  regular,
}

/// Button visual variant.
enum ButtonVariant {
  /// Soft tonal fill (`secondaryContainer`) with no border (default).
  tonal,

  /// White fill with `outlineVariant` border, pill shape.
  outlined,
}

/// A design system button built from Flutter primitives.
///
/// Supports two sizes ([ButtonSize]) and two variants ([ButtonVariant]).
///
/// Built bottom-up: [GestureDetector] + [Container] + [Text].
class Button extends StatelessWidget {
  const Button({
    super.key,
    required this.label,
    this.onTap,
    this.leadingIcon,
    this.size = ButtonSize.regular,
    this.variant = ButtonVariant.tonal,
  });

  /// The button label text.
  final String label;

  /// Called when the button is tapped.
  final VoidCallback? onTap;

  /// Optional widget displayed before the label.
  final Widget? leadingIcon;

  /// Button height. Defaults to [ButtonSize.regular] (48px).
  final ButtonSize size;

  /// Visual variant. Defaults to [ButtonVariant.tonal].
  final ButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final height = size == ButtonSize.small
        ? sizing.buttonHeightSmall
        : sizing.buttonHeightRegular;

    final isOutlined = variant == ButtonVariant.outlined;

    final fillColor =
        isOutlined ? colors.surfaceContainerLowest : colors.secondaryContainer;
    final contentColor =
        isOutlined ? colors.onSurface : colors.onSecondaryContainer;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        decoration: BoxDecoration(
          color: fillColor,
          border: isOutlined ? Border.all(color: colors.outlineVariant) : null,
          borderRadius: radii.borderRadiusFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              leadingIcon!,
              SizedBox(width: spacing.space8),
            ],
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
