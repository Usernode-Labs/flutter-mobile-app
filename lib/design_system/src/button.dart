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

  /// White fill (`surfaceContainerLowest`), no border — for use on dark/colored
  /// backgrounds.
  surface,
}

/// A design system button backed by M3 Material components.
///
/// Supports two sizes ([ButtonSize]) and three variants ([ButtonVariant]).
/// Provides ink splash, focus/hover states, and accessibility semantics via
/// [FilledButton] / [OutlinedButton].
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
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final height = size == ButtonSize.small
        ? sizing.buttonHeightSmall
        : sizing.buttonHeightRegular;

    final shape = RoundedRectangleBorder(borderRadius: radii.borderRadiusFull);
    final padding = EdgeInsets.symmetric(horizontal: spacing.space16);

    final baseStyle = ButtonStyle(
      shape: WidgetStatePropertyAll(shape),
      fixedSize: WidgetStatePropertyAll(Size.fromHeight(height)),
      padding: WidgetStatePropertyAll(padding),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    switch (variant) {
      case ButtonVariant.tonal:
        // FilledButton.tonal defaults match our tonal spec — no overrides.
        final style = baseStyle;
        if (leadingIcon != null) {
          return FilledButton.tonalIcon(
            onPressed: onTap,
            style: style,
            icon: leadingIcon!,
            label: Text(label),
          );
        }
        return FilledButton.tonal(
          onPressed: onTap,
          style: style,
          child: Text(label),
        );

      case ButtonVariant.outlined:
        final style = baseStyle.copyWith(
          backgroundColor:
              WidgetStatePropertyAll(colors.surfaceContainerLowest),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.outlineVariant),
          ),
        );
        if (leadingIcon != null) {
          return OutlinedButton.icon(
            onPressed: onTap,
            style: style,
            icon: leadingIcon!,
            label: Text(label),
          );
        }
        return OutlinedButton(
          onPressed: onTap,
          style: style,
          child: Text(label),
        );

      case ButtonVariant.surface:
        final style = baseStyle.copyWith(
          backgroundColor:
              WidgetStatePropertyAll(colors.surfaceContainerLowest),
          foregroundColor: WidgetStatePropertyAll(colors.onSurface),
        );
        if (leadingIcon != null) {
          return FilledButton.icon(
            onPressed: onTap,
            style: style,
            icon: leadingIcon!,
            label: Text(label),
          );
        }
        return FilledButton(
          onPressed: onTap,
          style: style,
          child: Text(label),
        );
    }
  }
}
