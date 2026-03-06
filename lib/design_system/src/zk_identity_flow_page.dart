import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_spacing.dart';
import 'top_app_bar.dart';

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
    required this.title,
    required this.steps,
    required this.currentStepIndex,
    this.activeStepContent,
    this.onBack,
  });

  final String title;
  final List<ZkIdentityStepData> steps;
  final int currentStepIndex;
  final Widget? activeStepContent;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          TopAppBar(
            title: title,
            onLeadingTap: onBack,
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space24),
            sliver: SliverList.builder(
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                return _StepTile(
                  index: index,
                  step: step,
                  isLast: index == steps.length - 1,
                );
              },
            ),
          ),
          if (activeStepContent != null)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.space24,
                vertical: spacing.space16,
              ),
              sliver: SliverToBoxAdapter(child: activeStepContent!),
            ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.isLast,
  });

  final int index;
  final ZkIdentityStepData step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final (bgColor, fgColor, icon) = _resolveVisuals(colorScheme);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: bgColor,
              child: Icon(icon, size: 16, color: fgColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: colorScheme.outlineVariant,
              ),
          ],
        ),
        SizedBox(width: spacing.space12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: textTheme.titleSmall?.copyWith(
                    color: step.status == ZkIdentityStepVisualStatus.pending
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.description,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!isLast) SizedBox(height: spacing.space8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  (Color, Color, IconData) _resolveVisuals(ColorScheme colorScheme) {
    return switch (step.status) {
      ZkIdentityStepVisualStatus.completed => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
          Symbols.check_sharp,
        ),
      ZkIdentityStepVisualStatus.active => (
          colorScheme.primary,
          colorScheme.onPrimary,
          Symbols.arrow_forward_sharp,
        ),
      ZkIdentityStepVisualStatus.failed => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          Symbols.close_sharp,
        ),
      ZkIdentityStepVisualStatus.pending => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
          Symbols.radio_button_unchecked_sharp,
        ),
    };
  }
}
