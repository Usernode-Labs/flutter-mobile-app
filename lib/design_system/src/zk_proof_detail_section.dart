import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A row of label–value data for a zero-knowledge proof result.
///
/// When [onTap] is non-null the row renders as a tappable target with a
/// trailing copy icon — typically used for copyable identifiers like Proof ID.
typedef ZkProofRow = ({
  IconData icon,
  String label,
  String value,
  bool monospace,
  VoidCallback? onTap,
});

/// A presentation-only slot widget that renders proof details inside a
/// category-colored container (e.g. the footer of [ChallengeRewardCard]).
///
/// Displays a heading, description, and a list of label–value rows.
/// Colors are passed in so the widget adapts to any category container.
class ZkProofDetailSection extends StatelessWidget {
  const ZkProofDetailSection({
    super.key,
    required this.heading,
    required this.description,
    required this.onColor,
    required this.dimOnColor,
    this.rows = const [],
  });

  /// Section heading, e.g. "Your Proof".
  final String heading;

  /// Explanatory text, e.g. "Your passport was verified…".
  final String description;

  /// Primary on-color from the category container.
  final Color onColor;

  /// Dimmed on-color (typically 80% alpha) for secondary text.
  final Color dimOnColor;

  /// Label–value rows. When [ZkProofRow.monospace] is true the value
  /// renders in the mono font family (e.g. for hex identifiers).
  final List<ZkProofRow> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: textTheme.labelLarge?.copyWith(color: onColor),
        ),
        SizedBox(height: spacing.space8),
        Text(
          description,
          style: textTheme.bodySmall?.copyWith(color: dimOnColor),
        ),
        if (rows.isNotEmpty) ...[
          SizedBox(height: spacing.space12),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: spacing.space8),
            _buildRow(context, rows[i], textTheme, sizing, spacing,
                radii: radii),
          ],
        ],
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    ZkProofRow row,
    TextTheme textTheme,
    AppSizing sizing,
    AppSpacing spacing, {
    required AppRadii radii,
  }) {
    final content = Row(
      children: [
        Icon(row.icon, size: sizing.iconSmall, color: dimOnColor),
        SizedBox(width: spacing.space12),
        Expanded(
          child: Text(
            row.label,
            style: textTheme.bodySmall?.copyWith(color: dimOnColor),
          ),
        ),
        Text(
          row.value,
          style: textTheme.bodySmall?.copyWith(
            color: onColor,
            fontFamily: row.monospace ? kMonoFontFamily : null,
          ),
        ),
        if (row.onTap != null) ...[
          SizedBox(width: spacing.space4),
          Icon(Icons.content_copy, size: sizing.iconSmall, color: dimOnColor),
        ],
      ],
    );

    if (row.onTap != null) {
      return InkWell(
        onTap: row.onTap,
        borderRadius: radii.borderRadiusXSmall,
        child: content,
      );
    }
    return content;
  }
}
