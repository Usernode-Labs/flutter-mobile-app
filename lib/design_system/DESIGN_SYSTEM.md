# Design System — Living Document

This document grows from real widget creation sessions. Rules are added when agents fail without them, not speculatively.

## Core Constraints

- New widgets use Flutter core primitives (no Material/Cupertino widgets)
- Exceptions: `Text`, `Icon`, `InkWell`, `DefaultTextStyle`, composing existing `lib/core/widgets/`
- Tokens via `Theme.of(context).extension<T>()!`
- Colors via `Theme.of(context).colorScheme`
- Typography via `Theme.of(context).textTheme`
- Quality: `dart format` clean, `flutter analyze` passes, tests pass

## Presentation-Only Widgets

Applies to all widgets created in `lib/design_system/`. Existing `lib/core/widgets/` are out of scope until individually migrated.

- **Data in, pixels out.** Widgets receive all state via constructor parameters (data + callbacks). They never fetch state internally — no providers, no services, no async loading.
- **No Riverpod, no native deps.** A design system widget must never `watch`, `read`, or `ref` a provider. No `ConsumerWidget` / `ConsumerStatefulWidget`. This keeps widgets portable, testable, and compilable on all targets (including web/Widgetbook).
- **No FRB types in props.** All FRB-generated files transitively import native FFI via `frb_generated.dart`, which breaks web compilation. Use plain Dart models (String, int, enums, custom data classes) instead.
- **Screens as containers.** Feature screens in `lib/features/` watch providers and pass data down to design system widgets. No separate container widget class is required — the screen itself is the container.
- **Widgetbook imports the real widget.** Every new design system widget gets a use case that imports and renders the actual component with mock data via knobs — never a hand-built visual replica.

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
- **Widgetbook failed to compile on web** because `AppAppBar` → `NodeStatusIcon` → `nodeStatusProvider` → Rust FFI. Adopted presentation-only rule: design system widgets take data as props, never fetch state. Containers live in `lib/features/`. (2026-02-20)
