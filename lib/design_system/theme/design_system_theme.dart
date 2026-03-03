import 'package:flutter/material.dart';

import '../tokens/app_animation.dart';
import '../tokens/app_borders.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

/// Wraps a child widget tree with all design system ThemeExtensions.
///
/// **Deprecated at runtime** — all token extensions are now injected at the
/// app root in `main.dart` via [standardExtensions]. The [build] method and
/// per-screen wrapping are no longer needed. Keep [standardExtensions] as
/// the single factory for the canonical extension list.
class DesignSystemTheme extends StatelessWidget {
  const DesignSystemTheme({
    super.key,
    required this.child,
    this.spacing,
    this.radii,
    this.borders,
    this.elevation,
    this.opacity,
    this.sizing,
    this.animation,
    this.semanticColors,
  });

  final Widget child;
  final AppSpacing? spacing;
  final AppRadii? radii;
  final AppBorders? borders;
  final AppElevation? elevation;
  final AppOpacity? opacity;
  final AppSizing? sizing;
  final AppAnimation? animation;
  final AppSemanticColors? semanticColors;

  /// All standard design system extensions.
  static List<ThemeExtension> standardExtensions({
    AppSemanticColors? semanticColors,
  }) =>
      [
        AppSpacing.standard(),
        AppRadii.standard(),
        AppBorders.standard(),
        AppElevation.standard(),
        AppOpacity.standard(),
        AppSizing.standard(),
        AppAnimation.standard(),
        if (semanticColors != null) semanticColors,
      ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        extensions: [
          spacing ?? AppSpacing.standard(),
          radii ?? AppRadii.standard(),
          borders ?? AppBorders.standard(),
          elevation ?? AppElevation.standard(),
          opacity ?? AppOpacity.standard(),
          sizing ?? AppSizing.standard(),
          animation ?? AppAnimation.standard(),
          if (semanticColors != null) semanticColors!,
        ],
      ),
      child: child,
    );
  }
}
