# EmptyState Genesis

## Inspiration

Backfilled from `lib/design_system/src/empty_state.dart`, tests, and Widgetbook coverage during DS harness standardization.

## Design Decisions

- Centralizes empty-state layout so screens do not invent one-off blank states.
- Accepts title, body, icon, and action slots from callers.
- Uses M3 text styles and token spacing to stay lightweight and composable.
