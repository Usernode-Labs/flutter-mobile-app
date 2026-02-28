import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';

/// A square container with rounded corners and a centered icon.
///
/// Commonly used as a leading element in list rows and metric tiles.
/// Defaults to 48px with `secondaryContainer` background.
///
/// Presentation-only — takes all state via constructor params.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size,
    this.backgroundColor,
    this.iconColor,
    this.borderRadius,
  });

  /// The icon to display.
  final IconData icon;

  /// Container size. Defaults to [AppSizing.iconContainerRegular] (48px).
  final double? size;

  /// Background color. Defaults to `colorScheme.secondaryContainer`.
  final Color? backgroundColor;

  /// Icon color. Defaults to `colorScheme.onSecondaryContainer`.
  final Color? iconColor;

  /// Corner radius. Defaults to [AppRadii.borderRadiusMedium].
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    final containerSize = size ?? sizing.iconContainerRegular;

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.secondaryContainer,
        borderRadius: borderRadius ?? radii.borderRadiusMedium,
      ),
      child: Center(
        child: Icon(
          icon,
          size: sizing.iconRegular,
          color: iconColor ?? colors.onSecondaryContainer,
        ),
      ),
    );
  }
}
