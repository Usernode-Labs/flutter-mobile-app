import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/core/widgets/app_card.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import 'icon_badge.dart';
import 'status_badge.dart';
import 'status_text_trailing.dart';

/// Trailing content for a pipeline step row.
sealed class StepTrailing {
  const StepTrailing();
}

/// A [StatusBadge] trailing (e.g. "Connected" success, "Pending" neutral).
class StepTrailingBadge extends StepTrailing {
  const StepTrailingBadge({required this.label, required this.variant});

  final String label;
  final StatusBadgeVariant variant;
}

/// A plain text trailing (e.g. "in ~12 min", "2 min ago").
class StepTrailingText extends StepTrailing {
  const StepTrailingText({required this.text});

  final String text;
}

/// Status of a single pipeline step.
class PipelineStepStatus {
  const PipelineStepStatus({
    required this.label,
    required this.icon,
    required this.trailing,
  });

  final String label;
  final IconData icon;
  final StepTrailing trailing;
}

/// Data for the four pipeline steps in [BlockProductionStatusCard].
class BlockProductionStatusData {
  const BlockProductionStatusData({
    required this.network,
    required this.vrf,
    required this.nextBlock,
    required this.lastProduced,
  });

  final PipelineStepStatus network;
  final PipelineStepStatus vrf;
  final PipelineStepStatus nextBlock;
  final PipelineStepStatus lastProduced;

  List<PipelineStepStatus> get _steps =>
      [network, vrf, nextBlock, lastProduced];
}

/// A card showing 4 [ListTile] rows for block production pipeline readiness.
///
/// Presentation-only — takes all state via constructor params.
class BlockProductionStatusCard extends StatelessWidget {
  const BlockProductionStatusCard({
    super.key,
    required this.data,
  });

  final BlockProductionStatusData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return AppCard(
      color: colors.surfaceContainerLowest,
      borderRadius: radii.borderRadiusLargeIncreased,
      padding: EdgeInsets.symmetric(vertical: spacing.space8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final step in data._steps) _StepRow(step: step),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final PipelineStepStatus step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    final trailing = switch (step.trailing) {
      StepTrailingBadge(:final label, :final variant) => StatusTextTrailing(
          text: label,
          variant: variant,
        ),
      StepTrailingText(:final text) => Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
    };

    return ListTile(
      leading: IconBadge(
        icon: step.icon,
        size: sizing.iconContainerSmall,
      ),
      title: Text(
        step.label,
        style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
      ),
      trailing: trailing,
    );
  }
}
