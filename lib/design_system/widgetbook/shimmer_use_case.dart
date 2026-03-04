import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/shimmer_block.dart';
import '../src/shimmer_card_skeleton.dart';
import '../src/shimmer_list_tile.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent shimmerBlockComponent() {
  return WidgetbookComponent(
    name: 'ShimmerBlock',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          final width = context.knobs.double.slider(
            label: 'Width',
            initialValue: 180,
            min: 40,
            max: 360,
          );
          final height = context.knobs.double.slider(
            label: 'Height',
            initialValue: 36,
            min: 12,
            max: 120,
          );
          final circular = context.knobs.boolean(
            label: 'Circular',
            initialValue: false,
          );

          final radii = Theme.of(context).extension<AppRadii>()!;

          return ShimmerHost(
            child: Center(
              child: ShimmerBlock(
                width: width,
                height: height,
                borderRadius: circular ? radii.borderRadiusFull : null,
              ),
            ),
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Card Skeleton',
        builder: (context) {
          final spacing = Theme.of(context).extension<AppSpacing>()!;

          return ShimmerHost(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(spacing.space16),
                child: const ShimmerCardSkeleton(),
              ),
            ),
          );
        },
      ),
    ],
  );
}

WidgetbookComponent shimmerListTileComponent() {
  return WidgetbookComponent(
    name: 'ShimmerListTile',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          final isThreeLine = context.knobs.boolean(
            label: 'Three-line',
            initialValue: true,
          );
          final hasTrailing = context.knobs.boolean(
            label: 'Has trailing',
            initialValue: true,
          );
          final count = context.knobs.int.slider(
            label: 'Count',
            initialValue: 4,
            min: 1,
            max: 8,
          );

          return ShimmerHost(
            child: Column(
              children: List.generate(
                count,
                (_) => ShimmerListTile(
                  isThreeLine: isThreeLine,
                  hasTrailing: hasTrailing,
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
