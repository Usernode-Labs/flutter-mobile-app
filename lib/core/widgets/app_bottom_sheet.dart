import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/theme/design_tokens.dart';

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
    final maxHeight = maxHeightFraction != null
        ? MediaQuery.of(context).size.height * maxHeightFraction!
        : MediaQuery.of(context).size.height * 0.67;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.only(bottom: kSpace16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(top: kSpace12, bottom: kSpace16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: kAlphaSecondary),
                  borderRadius: kBorderRadiusFull,
                ),
              ),

              // Header
              if (title != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    kSpace24,
                    kSpace8,
                    kSpace12,
                    kSpace16,
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
                              const SizedBox(height: kSpace4),
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
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: kBorderRadiusTopXLarge,
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
