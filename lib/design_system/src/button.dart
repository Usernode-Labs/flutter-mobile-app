import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

/// A design system button built from Flutter primitives.
///
/// Currently supports a secondary (tonal) style — soft background with
/// contrasting text in a pill shape. Additional variants will be added
/// as Figma designs demand them.
///
/// Built bottom-up: [GestureDetector] + [Container] + [Text].
/// No Material Button classes.
class Button extends StatelessWidget {
  const Button({
    super.key,
    required this.label,
    this.onTap,
    this.leadingIcon,
  });

  /// The button label text.
  final String label;

  /// Called when the button is tapped.
  final VoidCallback? onTap;

  /// Optional widget displayed before the label.
  final Widget? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: sizing.buttonHeightRegular,
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: radii.borderRadiusFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              leadingIcon!,
              SizedBox(width: spacing.space8),
            ],
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
