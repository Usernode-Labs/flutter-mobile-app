import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

/// Visual variant for [ResultPage].
enum ResultPageVariant {
  /// Green check — success outcome.
  success,

  /// Red error — failure outcome.
  failure,

  /// Blue info — informational.
  info,
}

/// A full-page centered layout for displaying an outcome (success, failure,
/// or informational) with icon, title, optional subtitle, and action buttons.
///
/// Replaces hand-rolled transaction result screens with a consistent layout.
///
/// Presentation-only — takes all state via constructor params.
class ResultPage extends StatelessWidget {
  const ResultPage({
    super.key,
    required this.variant,
    this.icon,
    required this.title,
    this.subtitle,
    this.primaryAction,
    this.secondaryAction,
  });

  /// Determines the icon and color scheme.
  final ResultPageVariant variant;

  /// Override the default icon per variant.
  final IconData? icon;

  /// The headline text.
  final String title;

  /// Optional secondary description.
  final String? subtitle;

  /// Optional primary action (e.g. "Done" button).
  final Widget? primaryAction;

  /// Optional secondary action (e.g. "View Details" button).
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final (IconData defaultIcon, Color circleBg, Color iconColor) =
        switch (variant) {
      ResultPageVariant.success => (
          Symbols.check_sharp,
          semantic.success.colorContainer,
          semantic.success.onColorContainer,
        ),
      ResultPageVariant.failure => (
          Symbols.close_sharp,
          colors.errorContainer,
          colors.onErrorContainer,
        ),
      ResultPageVariant.info => (
          Symbols.info_sharp,
          semantic.technical.colorContainer,
          semantic.technical.onColorContainer,
        ),
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: circleBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon ?? defaultIcon,
                      size: sizing.iconDisplay,
                      color: iconColor,
                    ),
                  ),
                  SizedBox(height: spacing.space24),
                  Text(
                    title,
                    style: textTheme.headlineMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: spacing.space12),
                    Text(
                      subtitle!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            if (primaryAction != null)
              SizedBox(
                width: double.infinity,
                height: sizing.buttonHeightLarge,
                child: primaryAction,
              ),
            if (secondaryAction != null) ...[
              SizedBox(height: spacing.space8),
              SizedBox(
                width: double.infinity,
                height: sizing.buttonHeightLarge,
                child: secondaryAction,
              ),
            ],
            SizedBox(height: spacing.space32),
          ],
        ),
      ),
    );
  }
}
