# ChallengeCategoryTile Genesis

## Inspiration

Backfilled from `lib/design_system/src/challenge_category_tile.dart`, tests, and Widgetbook coverage during DS harness standardization.

## Design Decisions

- Builds on M3 `ExpansionTile` instead of recreating expandable list behavior.
- Uses DS category icons and chips as slots inside the M3 container.
- Keeps expansion state local to the presentation widget and avoids provider coupling.
