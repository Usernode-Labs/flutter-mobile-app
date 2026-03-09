import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

class DappCard extends StatelessWidget {
  static const kDefaultDescription =
      'A decentralized application on the Usernode network.';

  const DappCard({
    super.key,
    required this.name,
    required this.author,
    this.description = kDefaultDescription,
    this.users,
    this.txns,
    this.onTap,
  });

  final String name;
  final String author;
  final String description;
  final int? users;
  final int? txns;
  final VoidCallback? onTap;

  static final _compactFormat = NumberFormat.compact();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final sizing = theme.extension<AppSizing>()!;
    final borders = theme.extension<AppBorders>()!;

    final borderRadius = BorderRadius.circular(radii.largeIncreased);

    return Card(
      color: colors.surfaceContainerLowest,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: colors.outlineVariant,
          width: borders.width,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                author.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.28,
                ),
              ),
              SizedBox(height: spacing.space16),
              Text(
                name,
                style: textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              SizedBox(height: spacing.space8),
              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: spacing.space8),
              Row(
                children: [
                  if (users != null || txns != null)
                    _StatsRow(
                      users: users,
                      txns: txns,
                      style: textTheme.labelSmall!
                          .copyWith(color: colors.onSurfaceVariant),
                      iconSize: sizing.iconSmall,
                      iconColor: colors.onSurfaceVariant,
                      gap: spacing.space8,
                    ),
                  const Spacer(),
                  Icon(
                    Symbols.arrow_forward_sharp,
                    size: sizing.iconSmall,
                    color: colors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.users,
    required this.txns,
    required this.style,
    required this.iconSize,
    required this.iconColor,
    required this.gap,
  });

  final int? users;
  final int? txns;
  final TextStyle style;
  final double iconSize;
  final Color iconColor;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final fmt = DappCard._compactFormat;
    return Row(
      children: [
        if (users != null) ...[
          Icon(Symbols.group_sharp, size: iconSize, color: iconColor),
          SizedBox(width: gap / 2),
          Text(fmt.format(users), style: style),
        ],
        if (users != null && txns != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gap),
            child: Text('·', style: style),
          ),
        if (txns != null) ...[
          Icon(Symbols.bolt_sharp, size: iconSize, color: iconColor),
          SizedBox(width: gap / 2),
          Text('${fmt.format(txns)} Transactions', style: style),
        ],
      ],
    );
  }
}
