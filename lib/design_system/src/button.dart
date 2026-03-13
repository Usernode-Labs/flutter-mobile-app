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

  /// 56px height.
  large,
}

/// Button visual variant.
enum ButtonVariant {
  /// Highest-emphasis CTA — `primary` fill, `onPrimary` text.
  primary,

  /// Soft tonal fill (`secondaryContainer`) with no border (default).
  tonal,

  /// Transparent fill with `outlineVariant` border, pill shape.
  outlined,

  /// White fill (`surfaceContainerLowest`), no border — for use on dark/colored
  /// backgrounds.
  surface,
}

/// A design system button backed by M3 Material components.
///
/// Supports three sizes ([ButtonSize]) and four variants ([ButtonVariant]).
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
    this.isLoading = false,
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

  /// When true, replaces the label with a spinner and disables tap.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final height = switch (size) {
      ButtonSize.small => sizing.buttonHeightSmall,
      ButtonSize.regular => sizing.buttonHeightRegular,
      ButtonSize.large => sizing.buttonHeightLarge,
    };

    final shape = RoundedRectangleBorder(borderRadius: radii.borderRadiusFull);
    final padding = EdgeInsets.symmetric(horizontal: spacing.space16);

    final effectiveOnTap = isLoading ? null : onTap;
    final child = isLoading
        ? SizedBox.square(
            dimension: sizing.iconSmall,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == ButtonVariant.primary
                  ? colors.onPrimary
                  : colors.onSurface,
            ),
          )
        : Text(label);

    final baseStyle = ButtonStyle(
      shape: WidgetStatePropertyAll(shape),
      fixedSize: WidgetStatePropertyAll(Size.fromHeight(height)),
      padding: WidgetStatePropertyAll(padding),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    switch (variant) {
      case ButtonVariant.primary:
        final style = baseStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(colors.primary),
          foregroundColor: WidgetStatePropertyAll(colors.onPrimary),
        );
        if (!isLoading && leadingIcon != null) {
          return FilledButton.icon(
            onPressed: effectiveOnTap,
            style: style,
            icon: leadingIcon!,
            label: child,
          );
        }
        return FilledButton(
          onPressed: effectiveOnTap,
          style: style,
          child: child,
        );

      case ButtonVariant.tonal:
        // FilledButton.tonal defaults match our tonal spec — no overrides.
        final style = baseStyle;
        if (!isLoading && leadingIcon != null) {
          return FilledButton.tonalIcon(
            onPressed: effectiveOnTap,
            style: style,
            icon: leadingIcon!,
            label: child,
          );
        }
        return FilledButton.tonal(
          onPressed: effectiveOnTap,
          style: style,
          child: child,
        );

      case ButtonVariant.outlined:
        final style = baseStyle.copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.outlineVariant),
          ),
        );
        if (!isLoading && leadingIcon != null) {
          return OutlinedButton.icon(
            onPressed: effectiveOnTap,
            style: style,
            icon: leadingIcon!,
            label: child,
          );
        }
        return OutlinedButton(
          onPressed: effectiveOnTap,
          style: style,
          child: child,
        );

      case ButtonVariant.surface:
        final style = baseStyle.copyWith(
          backgroundColor:
              WidgetStatePropertyAll(colors.surfaceContainerLowest),
          foregroundColor: WidgetStatePropertyAll(colors.onSurface),
        );
        if (!isLoading && leadingIcon != null) {
          return FilledButton.icon(
            onPressed: effectiveOnTap,
            style: style,
            icon: leadingIcon!,
            label: child,
          );
        }
        return FilledButton(
          onPressed: effectiveOnTap,
          style: style,
          child: child,
        );
    }
  }
}
