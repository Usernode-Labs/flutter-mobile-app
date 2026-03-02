import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_opacity.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

/// Unified text field component with consistent styling
/// Supports validation, prefixes, suffixes, and helper text
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onTap,
    this.validator,
    this.inputFormatters,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radii = theme.extension<AppRadii>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final opacity = theme.extension<AppOpacity>()!;

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        enabled: enabled,
        border: OutlineInputBorder(
          borderRadius: radii.borderRadiusMedium,
          borderSide: BorderSide(
            color: theme.colorScheme.outline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radii.borderRadiusMedium,
          borderSide: BorderSide(
            color: theme.colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radii.borderRadiusMedium,
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radii.borderRadiusMedium,
          borderSide: BorderSide(
            color: theme.colorScheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radii.borderRadiusMedium,
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: radii.borderRadiusMedium,
          borderSide: BorderSide(
            color:
                theme.colorScheme.outline.withValues(alpha: opacity.disabled),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.space16,
          vertical: spacing.space16,
        ),
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      readOnly: readOnly,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onTap: onTap,
      validator: validator,
      inputFormatters: inputFormatters,
      enabled: enabled,
    );
  }
}
