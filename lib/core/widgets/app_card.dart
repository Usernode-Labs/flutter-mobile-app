import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_elevation.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

/// Unified card component with consistent styling across the app
/// Supports different padding variants, optional headers, and elevation levels
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final String? header;
  final Widget? headerAction;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
  });

  /// Compact card — padding resolved from theme in [build].
  const AppCard.compact({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
  }) : padding = null;

  /// Regular card — padding resolved from theme in [build].
  const AppCard.regular({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
  }) : padding = null;

  /// Spacious card — padding resolved from theme in [build].
  const AppCard.spacious({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
  }) : padding = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final elev = theme.extension<AppElevation>()!;
    final radii = theme.extension<AppRadii>()!;

    final effectiveRadius = borderRadius ?? radii.borderRadiusLarge;
    final effectiveElevation = elevation ?? elev.none;
    final effectivePadding = padding ?? EdgeInsets.all(spacing.space16);

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                header!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (headerAction != null) headerAction!,
            ],
          ),
          SizedBox(height: spacing.space12),
        ],
        child,
      ],
    );

    if (onTap != null) {
      return Card(
        elevation: effectiveElevation,
        color: color,
        shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: Padding(
            padding: effectivePadding,
            child: cardContent,
          ),
        ),
      );
    }

    return Card(
      elevation: effectiveElevation,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
      child: Padding(
        padding: effectivePadding,
        child: cardContent,
      ),
    );
  }
}
