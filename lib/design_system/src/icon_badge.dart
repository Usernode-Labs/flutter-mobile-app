import 'package:flutter/material.dart';

import '../tokens/app_sizing.dart';

/// A square container with rounded corners and a centered icon.
///
/// Commonly used as a leading element in list rows and metric tiles.
/// Defaults to 3-layer model (48px container, 40px surface, 24px icon).
///
/// The 3-layer model separates layout allocation ([size]) from the visible
/// colored surface ([surfaceSize]), creating breathing room around the badge.
/// To opt out (flush surface = 2-layer look), pass
/// `surfaceSize: sizing.iconContainerRegular`.
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
  /// Defaults to [AppSizing.iconContainerSmall] (40px), creating a 3-layer
  /// layout: outer transparent container → centered colored surface → icon.
  /// Pass [AppSizing.iconContainerRegular] for a flush 2-layer look.
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
