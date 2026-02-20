# Design System — Living Document

This document grows from real widget creation sessions. Rules are added when agents fail without them, not speculatively.

## Core Constraints

- New widgets use Flutter core primitives (no Material/Cupertino widgets)
- Exceptions: `Text`, `Icon`, `InkWell`, `DefaultTextStyle`, composing existing `lib/core/widgets/`
- Tokens via `Theme.of(context).extension<T>()!`
- Colors via `Theme.of(context).colorScheme`
- Typography via `Theme.of(context).textTheme`
- Quality: `dart format` clean, `flutter analyze` passes, tests pass

## Token Vocabulary

| Extension | Access | Values |
|-----------|--------|--------|
| `AppSpacing` | `.space4` .. `.space48` | 4, 8, 12, 16, 24, 32, 48 |
| `AppRadii` | `.small` .. `.full` | 8, 12, 16, 24, 999 |
| `AppElevation` | `.none` .. `.max` | 0, 1, 2, 4, 8 |
| `AppOpacity` | `.subtle` .. `.secondary` | 0.08, 0.12, 0.20, 0.30, 0.40 |
| `AppSizing` | `.iconSmall` .. `.iconXLarge` + `.icon*` | containers: 40-64, icons: 20-32 |
| `AppAnimation` | `.fast` .. `.complex` | 100ms, 150ms, 200ms, 300ms |

## Decisions Log

<!-- Decisions are captured here as they emerge from widget creation sessions -->
<!-- Format: "- **Context**: Decision (date)" -->
