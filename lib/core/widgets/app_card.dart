import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/theme/design_tokens.dart';

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

  /// Compact card with 12px padding
  const AppCard.compact({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
  }) : padding = const EdgeInsets.all(kSpace12);

  /// Regular card with 16px padding
  const AppCard.regular({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
  }) : padding = const EdgeInsets.all(kSpace16);

  /// Spacious card with 24px padding
  const AppCard.spacious({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
  }) : padding = const EdgeInsets.all(kSpace24);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          const SizedBox(height: kSpace12),
        ],
        child,
      ],
    );

    if (onTap != null) {
      return Card(
        elevation: elevation ?? kElevationNone,
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? kBorderRadiusLarge,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? kBorderRadiusLarge,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(kSpace16),
            child: cardContent,
          ),
        ),
      );
    }

    return Card(
      elevation: elevation ?? kElevationNone,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? kBorderRadiusLarge,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(kSpace16),
        child: cardContent,
      ),
    );
  }
}

/// Outlined variant of AppCard with border instead of elevation
class AppCardOutlined extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final String? header;
  final Widget? headerAction;

  const AppCardOutlined({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          const SizedBox(height: kSpace12),
        ],
        child,
      ],
    );

    final container = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? kBorderRadiusLarge,
        border: Border.all(
          color: borderColor ?? theme.colorScheme.outlineVariant,
          width: borderWidth,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(kSpace16),
        child: cardContent,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? kBorderRadiusLarge,
          child: container,
        ),
      );
    }

    return container;
  }
}
