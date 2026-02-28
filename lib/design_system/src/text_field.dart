import 'package:flutter/material.dart';

import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// A design system text field wrapping M3 [TextField] with ThemeExtension
/// tokens for consistent styling.
///
/// Uses `OutlineInputBorder` with `AppRadii.borderRadiusMedium` and colors
/// from `colorScheme`.
///
/// Presentation-only — takes all state via constructor params.
class DSTextField extends StatelessWidget {
  const DSTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;

    final border = OutlineInputBorder(
      borderRadius: radii.borderRadiusMedium,
      borderSide: BorderSide(color: colors.outline),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: radii.borderRadiusMedium,
      borderSide: BorderSide(color: colors.primary, width: 2),
    );

    final errorBorder = OutlineInputBorder(
      borderRadius: radii.borderRadiusMedium,
      borderSide: BorderSide(color: colors.error),
    );

    final disabledBorder = OutlineInputBorder(
      borderRadius: radii.borderRadiusMedium,
      borderSide: BorderSide(
        color: colors.outline.withValues(alpha: opacity.disabled),
      ),
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: border,
        enabledBorder: border,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        disabledBorder: disabledBorder,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.space16,
          vertical: spacing.space12,
        ),
      ),
    );
  }
}
