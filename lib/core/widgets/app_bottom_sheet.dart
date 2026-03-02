import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_opacity.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

/// Unified bottom sheet component with consistent styling
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? headerAction;
  final bool showCloseButton;
  final double? maxHeightFraction;

  const AppBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.headerAction,
    this.showCloseButton = true,
    this.maxHeightFraction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final opacity = theme.extension<AppOpacity>()!;
    final radii = theme.extension<AppRadii>()!;
    final maxHeight = maxHeightFraction != null
        ? MediaQuery.of(context).size.height * maxHeightFraction!
        : MediaQuery.of(context).size.height * 0.67;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(bottom: spacing.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 32,
                height: 4,
                margin: EdgeInsets.only(
                  top: spacing.space12,
                  bottom: spacing.space16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: opacity.secondary),
                  borderRadius: radii.borderRadiusFull,
                ),
              ),

              // Header
              if (title != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    spacing.space24,
                    spacing.space8,
                    spacing.space12,
                    spacing.space16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title!,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (subtitle != null) ...[
                              SizedBox(height: spacing.space4),
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (headerAction != null)
                        headerAction!
                      else if (showCloseButton)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                ),

              // Content
              Flexible(
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show bottom sheet with standard styling
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    Widget? headerAction,
    bool showCloseButton = true,
    double? maxHeightFraction,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    final theme = Theme.of(context);
    final radii = theme.extension<AppRadii>()!;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radii.borderRadiusTopXLarge,
      ),
      builder: (ctx) => AppBottomSheet(
        title: title,
        subtitle: subtitle,
        headerAction: headerAction,
        showCloseButton: showCloseButton,
        maxHeightFraction: maxHeightFraction,
        child: child,
      ),
    );
  }
}
