import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// A design system text field wrapping M3 [TextFormField] with ThemeExtension
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
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
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
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radii = theme.extension<AppRadii>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final opacity = theme.extension<AppOpacity>()!;

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

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      validator: validator,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: minLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        enabled: enabled,
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
          vertical: spacing.space16,
        ),
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
