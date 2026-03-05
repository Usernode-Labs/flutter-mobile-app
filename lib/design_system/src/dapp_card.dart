import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

class DappCard extends StatelessWidget {
  const DappCard({
    super.key,
    required this.name,
    required this.author,
    this.description = 'A decentralized application on the Usernode network.',
    this.onTap,
  });

  final String name;
  final String author;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;

    return Card(
      color: colors.surfaceContainerLowest,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.largeIncreased),
        side: BorderSide(
          color: colors.onSurface.withValues(alpha: borders.opacity),
          width: borders.width,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.space16,
              spacing.space16,
              spacing.space16,
              spacing.space16,
            ),
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
              ],
            ),
          ),
          Divider(indent: spacing.space16, endIndent: spacing.space16),
          ListTile(
            title: Text(
              'Launch Application',
              style: textTheme.labelLarge?.copyWith(
                color: colors.primary,
              ),
            ),
            trailing: Icon(
              Symbols.arrow_forward_sharp,
              size: sizing.iconSmall,
              color: colors.primary,
            ),
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}
