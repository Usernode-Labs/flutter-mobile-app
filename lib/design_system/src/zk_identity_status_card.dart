import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/core/widgets/app_card.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'icon_badge.dart';

/// A single row of proof detail data for [ZkIdentityStatusCard].
class ZkIdentityStatusStep {
  const ZkIdentityStatusStep({
    required this.label,
    required this.icon,
    required this.value,
    this.monospace = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final String value;

  /// When true, the value is rendered in monospace font (e.g. proof ID hex).
  final bool monospace;

  /// Optional tap handler (e.g. copy to clipboard).
  final VoidCallback? onTap;
}

/// Data model for [ZkIdentityStatusCard].
class ZkIdentityStatusData {
  const ZkIdentityStatusData({required this.steps});

  final List<ZkIdentityStatusStep> steps;
}

/// A card showing proof detail rows as [ListTile]s with [IconBadge] leading.
///
/// Follows the same pattern as [BlockProductionStatusCard]:
/// [AppCard] → [Column] of [ListTile] rows.
///
/// Presentation-only — takes all state via constructor params.
class ZkIdentityStatusCard extends StatelessWidget {
  const ZkIdentityStatusCard({super.key, required this.data});

  final ZkIdentityStatusData data;

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
          for (final step in data.steps) _StepRow(step: step),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final ZkIdentityStatusStep step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    final valueStyle = step.monospace
        ? textTheme.bodyMedium?.copyWith(
            fontFamily: kMonoFontFamily,
            color: colors.onSurfaceVariant,
          )
        : textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          );

    return ListTile(
      leading: IconBadge(
        icon: step.icon,
        size: sizing.iconContainerSmall,
      ),
      title: Text(
        step.label,
        style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
      ),
      trailing: Text(step.value, style: valueStyle),
      onTap: step.onTap,
    );
  }
}
