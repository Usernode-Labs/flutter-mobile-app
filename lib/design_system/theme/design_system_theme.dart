import 'package:flutter/material.dart';

import '../tokens/app_animation.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

/// Wraps a child widget tree with all design system ThemeExtensions.
///
/// Usage:
/// ```dart
/// DesignSystemTheme(
///   child: MaterialApp(...),
/// )
/// ```
///
/// Migration: Once proven, move extensions into `lib/core/config/theme.dart`
/// and delete this wrapper.
class DesignSystemTheme extends StatelessWidget {
  const DesignSystemTheme({
    super.key,
    required this.child,
    this.spacing,
    this.radii,
    this.elevation,
    this.opacity,
    this.sizing,
    this.animation,
  });

  final Widget child;
  final AppSpacing? spacing;
  final AppRadii? radii;
  final AppElevation? elevation;
  final AppOpacity? opacity;
  final AppSizing? sizing;
  final AppAnimation? animation;

  /// All standard design system extensions.
  static List<ThemeExtension> standardExtensions() => [
        AppSpacing.standard(),
        AppRadii.standard(),
        AppElevation.standard(),
        AppOpacity.standard(),
        AppSizing.standard(),
        AppAnimation.standard(),
      ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        extensions: [
          spacing ?? AppSpacing.standard(),
          radii ?? AppRadii.standard(),
          elevation ?? AppElevation.standard(),
          opacity ?? AppOpacity.standard(),
          sizing ?? AppSizing.standard(),
          animation ?? AppAnimation.standard(),
        ],
      ),
      child: child,
    );
  }
}
