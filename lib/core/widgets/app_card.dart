import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_elevation.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

enum _PaddingVariant { compact, regular, spacious }

/// Unified card component with consistent styling across the app
/// Supports different padding variants, optional headers, and elevation levels
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final _PaddingVariant _paddingVariant;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final String? header;
  final Widget? headerAction;

  /// When true, draws an `outlineVariant` hairline border (M3's outlined-card
  /// convention). Use for cards on a white surface (white-on-white), where
  /// fill contrast alone is insufficient — see SURFACES.md § Separation. Note
  /// the stroke is subtle on pure white (~1.7:1); on a grey canvas it reads as
  /// intended.
  final bool bordered;

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
    this.bordered = false,
  }) : _paddingVariant = _PaddingVariant.regular;

  /// Compact card — 12px padding resolved from theme in [build].
  const AppCard.compact({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
    this.bordered = false,
  })  : padding = null,
        _paddingVariant = _PaddingVariant.compact;

  /// Regular card — 16px padding resolved from theme in [build].
  const AppCard.regular({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
    this.bordered = false,
  })  : padding = null,
        _paddingVariant = _PaddingVariant.regular;

  /// Spacious card — 24px padding resolved from theme in [build].
  const AppCard.spacious({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.header,
    this.headerAction,
    this.bordered = false,
  })  : padding = null,
        _paddingVariant = _PaddingVariant.spacious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final elev = theme.extension<AppElevation>()!;
    final radii = theme.extension<AppRadii>()!;

    final effectiveRadius = borderRadius ?? radii.borderRadiusLarge;
    final borderSide = bordered
        ? BorderSide(color: theme.colorScheme.outlineVariant)
        : BorderSide.none;
    final effectiveElevation = elevation ?? elev.none;
    final effectivePadding = padding ??
        EdgeInsets.all(switch (_paddingVariant) {
          _PaddingVariant.compact => spacing.space12,
          _PaddingVariant.regular => spacing.space16,
          _PaddingVariant.spacious => spacing.space24,
        });

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

    // Single Card definition (shape/side/elevation declared once). When the
    // card is tappable, the InkWell wraps the padded content; the ripple is
    // clipped to the card radius. Avoids duplicate Card paths that can drift
    // out of sync.
    Widget body = Padding(padding: effectivePadding, child: cardContent);
    if (onTap != null) {
      body = InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        child: body,
      );
    }

    return Card(
      elevation: effectiveElevation,
      color: color,
      clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: effectiveRadius,
        side: borderSide,
      ),
      child: body,
    );
  }
}
