import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

class ZkIdentityStepData {
  const ZkIdentityStepData({
    required this.label,
    required this.description,
    required this.status,
  });

  final String label;
  final String description;

  /// One of: pending, active, completed, failed.
  final ZkIdentityStepVisualStatus status;
}

enum ZkIdentityStepVisualStatus {
  pending,
  active,
  completed,
  failed,
}

class ZkIdentityFlowPage extends StatelessWidget {
  const ZkIdentityFlowPage({
    super.key,
    required this.steps,
    required this.currentStepIndex,
    this.centerActiveContent = false,
    this.activeStepContent,
    this.bottomAction,
    this.onBack,
  });

  final List<ZkIdentityStepData> steps;
  final int currentStepIndex;

  /// When true, hides step label/description and centers [activeStepContent]
  /// vertically — matching [ResultPage] layout.
  final bool centerActiveContent;
  final Widget? activeStepContent;

  /// Rendered in [Scaffold.bottomNavigationBar] with safe-area padding.
  final Widget? bottomAction;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final currentStep =
        currentStepIndex < steps.length ? steps[currentStepIndex] : null;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Symbols.arrow_back_sharp),
                  onPressed: onBack,
                ),
              ],
            ),
          ),
          _SegmentedProgressBar(steps: steps),
          if (centerActiveContent)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.space16),
                  child: activeStepContent ?? const SizedBox.shrink(),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: spacing.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: spacing.space24),
                    if (currentStep != null) ...[
                      Text(
                        currentStep.label,
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: spacing.space4),
                      Text(
                        currentStep.description,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (activeStepContent != null) ...[
                        SizedBox(height: spacing.space24),
                        activeStepContent!,
                      ],
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: bottomAction != null
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.space16,
                  vertical: spacing.space12,
                ),
                child: bottomAction,
              ),
            )
          : null,
    );
  }
}

class _SegmentedProgressBar extends StatelessWidget {
  const _SegmentedProgressBar({required this.steps});

  final List<ZkIdentityStepData> steps;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space16,
        vertical: spacing.space8,
      ),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _segmentColor(steps[i].status, colorScheme),
                  borderRadius: radii.borderRadiusFull,
                ),
              ),
            ),
            if (i < steps.length - 1) SizedBox(width: spacing.space4),
          ],
        ],
      ),
    );
  }

  Color _segmentColor(
    ZkIdentityStepVisualStatus status,
    ColorScheme colorScheme,
  ) {
    return switch (status) {
      ZkIdentityStepVisualStatus.completed ||
      ZkIdentityStepVisualStatus.active =>
        colorScheme.primary,
      ZkIdentityStepVisualStatus.failed => colorScheme.error,
      ZkIdentityStepVisualStatus.pending => colorScheme.outlineVariant,
    };
  }
}
