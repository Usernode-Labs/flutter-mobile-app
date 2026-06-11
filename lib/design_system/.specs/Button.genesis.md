# Button Genesis

## Inspiration

Backfilled from `lib/design_system/src/button.dart`, tests, and Widgetbook coverage during DS harness standardization.

## Design Decisions

- Standardizes app button sizing through `ButtonSize` rather than raw per-call dimensions.
- Wraps M3 button primitives only as the sanctioned DS button abstraction enforced by `require_ds_button`.
- Keeps variants constrained so screens get consistent styling without hand-tuned button themes.
