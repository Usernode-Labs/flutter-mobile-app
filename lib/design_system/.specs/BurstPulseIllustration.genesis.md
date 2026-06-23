# BurstPulseIllustration Genesis

## Inspiration

Backfilled from `lib/design_system/src/burst_pulse_illustration.dart`, tests,
and Widgetbook coverage during DS harness standardization.

## Design Decisions

- Kept as a custom animated illustration because M3 has no equivalent for burst
  pulse visual language.
- Animation state remains internal and visual-only; business state stays outside
  the widget.
- Uses tokenized colors, sizing, and animation timing so it can be reused
  without feature coupling.
