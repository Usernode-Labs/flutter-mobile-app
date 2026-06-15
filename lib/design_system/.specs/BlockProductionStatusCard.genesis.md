# BlockProductionStatusCard Genesis

## Inspiration

Backfilled from `lib/design_system/src/block_production_status_card.dart`, tests, and Widgetbook coverage during DS harness standardization.

## Design Decisions

- Represents block-production progress as a presentation-only status card with caller-provided step data.
- Keeps trailing state display composable through `StepTrailing` variants instead of coupling to node services.
- Uses existing tokens and M3 text styles so feature screens own data flow while the DS widget owns layout.
