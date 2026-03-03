import 'package:flutter/material.dart';

import '../tokens/app_sizing.dart';

/// A square container with rounded corners and a centered icon.
///
/// Commonly used as a leading element in list rows and metric tiles.
/// Defaults to the 3-layer model (48px container, 40px surface, 24px icon)
/// which provides breathing room around the colored surface.
///
/// For flush mode (surface fills the container), pass
/// `size: sizing.iconContainerSmall` (40px outer = 40px surface).
///
/// Presentation-only — takes all state via constructor params.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size,
    this.surfaceSize,
    this.backgroundColor,
    this.iconColor,
    this.borderRadius,
  });

  /// The icon to display.
  final IconData icon;

  /// Outer container size. Defaults to [AppSizing.iconContainerRegular] (48px).
  final double? size;

  /// Colored surface size inside the container.
  ///
  /// Defaults to [AppSizing.iconContainerSmall] (40px). When [size] is larger
  /// than [surfaceSize], the surface is centered within the outer container
  /// (3-layer model with breathing room).
  final double? surfaceSize;

  /// Background color. Defaults to `colorScheme.secondaryContainer`.
  final Color? backgroundColor;

  /// Icon color. Defaults to `colorScheme.onSecondaryContainer`.
  final Color? iconColor;

  /// Corner radius. Defaults to fully rounded (circular).
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    final containerSize = size ?? sizing.iconContainerRegular;
    final effectiveSurfaceSize = surfaceSize ?? sizing.iconContainerSmall;
    final effectiveBg = backgroundColor ?? colors.secondaryContainer;
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(effectiveSurfaceSize / 2);
    final iconWidget = Icon(
      icon,
      size: sizing.iconRegular,
      color: iconColor ?? colors.onSecondaryContainer,
    );

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Center(
        child: Container(
          width: effectiveSurfaceSize,
          height: effectiveSurfaceSize,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: effectiveRadius,
          ),
          child: Center(child: iconWidget),
        ),
      ),
    );
  }
}
