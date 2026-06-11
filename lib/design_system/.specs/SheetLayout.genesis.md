# SheetLayout Genesis

## Inspiration

Backfilled from `lib/design_system/src/sheet_layout.dart`, tests, and Widgetbook coverage during DS harness standardization.

## Design Decisions

- Standardizes modal bottom sheet structure without owning sheet invocation.
- Gives callers slots for title, body, and actions while DS owns padding and shape.
- Keeps escape/CTA review in screen audit because interaction context lives at the caller.
