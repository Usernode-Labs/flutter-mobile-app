# ShimmerListTile Genesis

## Inspiration

Backfilled from `lib/design_system/src/shimmer_list_tile.dart`, tests, and Widgetbook coverage during DS harness standardization.

## Design Decisions

- Provides a loading placeholder that visually aligns with M3 list tile rows.
- Uses shimmer primitives instead of duplicating async logic.
- Keeps list layout tokenized so loading and loaded states share keylines.
