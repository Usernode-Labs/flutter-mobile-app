# ShimmerBlock Genesis

## Inspiration

Backfilled from `lib/design_system/src/shimmer_block.dart`, tests, and Widgetbook coverage during DS harness standardization.

## Design Decisions

- Provides the shared shimmer host/block primitive for loading placeholders.
- Keeps animation visual-only and independent of async state management.
- Uses tokenized colors and animation timing so skeletons match the app theme.
