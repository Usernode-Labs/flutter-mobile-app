# Design System — Living Document

This document grows from real widget creation sessions. Rules are added when agents fail without them, not speculatively.

> **Sandboxed POC** — This is an isolated proof-of-concept design system in `lib/design_system/` to experiment with agentic widget building using a living design system. No existing code is modified beyond adding widgetbook to `pubspec.yaml`.
> This boundary is intentional and likely temporary.

## Philosophy

- **Code + tokens = truth.** The widget implementation and its design tokens are authoritative.
- **Figma = inspiration.** A useful reference, not a spec to match. Figma screenshots are kept for context, not compliance.
- **Every deviation is a decision.** When the implementation differs from the inspiration, that's not drift — it's a choice. The genesis file documents the reasoning.
- **Golden tests = what the widget actually looks like.** A rendered PNG of the real widget, committed to git.

## Core Constraints

- New widgets use Flutter core primitives (no Material/Cupertino widgets)
- Exceptions: `Text`, `Icon`, `InkWell`, `DefaultTextStyle`, composing existing `lib/core/widgets/`
- Tokens via `Theme.of(context).extension<T>()!`
- Colors via `Theme.of(context).colorScheme`
- Typography via `Theme.of(context).textTheme`
- Quality: `dart format` clean, `flutter analyze` passes, tests pass

<!-- COLOR_PHILOSOPHY_START -->
## Color Philosophy: "Color is Expensive"

Color should be scarce, and therefore valuable. In a world of saturated interfaces, the most powerful move is restraint. Every chromatic pixel earns its place through semantic purpose.

### Core Role Semantics

| Role | Seed | Purpose |
|------|------|---------|
| **Primary** | `#18191B` (near-black) | The attention locker. Maximum contrast CTAs. Same darkness as body text, distinguished by shape (button vs paragraph). |
| **Secondary** | `#2563EB` (blue) | Technical precision. Progress indicators, earned states, computation accents. |
| **Tertiary** | `#C49A22` (amber) | Flash/achievement warmth. Ranking, urgency, time-sensitive energy. |
| **Error** | `#DC362E` (red) | Signal red. Clear error state, functional not emotional. |
| **Neutral** | `#6B6B6B` (gray) | True achromatic. Zero chroma. The paper substrate. |
| **Neutral Variant** | `#696C73` (cool gray) | Faintest cool lean for outlines and structural elements. |

### Extended Semantic Colors

| Name | Color | Description |
|------|-------|-------------|
| **Technical** | Blue `#2563EB` | Technical challenges: precision, computation, code. |
| **Flash** | Amber `#E5A100` | Flash/timed challenges: urgency, energy, time-limited. |
| **Community** | Green `#3A8C4E` | Community challenges: growth, participation, social. |
| **Success** | Green `#2E7D32` | Completion states, positive outcomes, earned badges. |

All color pairs are APCA-verified for perceptual contrast (body text Lc >= 90, accents Lc >= 60, borders Lc >= 30).
<!-- COLOR_PHILOSOPHY_END -->

<!-- COLOR_DOS_DONTS_START -->
## Color Do's & Don'ts

**Do:**
- Use `primary` for CTAs and interactive elements demanding attention
- Use semantic colors only for their defined category
- Use neutrals for backgrounds -- let the paper breathe
- Pair `colorContainer` + `onColorContainer` together
- Access colors via `Theme.of(context).colorScheme` and `.extension<AppSemanticColors>()`

**Don't:**
- Use chromatic color decoratively -- every colored pixel must carry meaning
- Hardcode hex values -- always use theme tokens
- Mix semantic purposes (e.g., amber for Technical content, blue for Community)
- Use `primary` and `onSurface` interchangeably (same darkness, different contexts)
- Override APCA-verified contrast pairings
<!-- COLOR_DOS_DONTS_END -->

<!-- COLOR_ACCESS_START -->
## Color Access Patterns

### Core ColorScheme
```dart
final colors = Theme.of(context).colorScheme;
// Primary: colors.primary, .onPrimary, .primaryContainer, .onPrimaryContainer
// Secondary: colors.secondary, .onSecondary, ...
// Tertiary: colors.tertiary, .onTertiary, ...
// Error: colors.error, .onError, ...
// Surface hierarchy: colors.surface, .surfaceDim, .surfaceBright
//   .surfaceContainerLowest -> .surfaceContainerHighest
// Text: colors.onSurface (body), .onSurfaceVariant (secondary)
// Structure: colors.outline (borders), .outlineVariant (dividers)
```

### Semantic Colors (Extended)
```dart
final semantic = Theme.of(context).extension<AppSemanticColors>()!;
// semantic.technical.color         -- standalone accent
// semantic.technical.onColor       -- text on accent
// semantic.technical.colorContainer    -- tinted background
// semantic.technical.onColorContainer  -- text on tinted background
// Same pattern: semantic.flash, semantic.community, semantic.success
```
<!-- COLOR_ACCESS_END -->

## Presentation-Only Widgets

Applies to all widgets created in `lib/design_system/`. Existing `lib/core/widgets/` are out of scope until individually migrated.

- **Data in, pixels out.** Widgets receive all state via constructor parameters (data + callbacks). They never fetch state internally — no providers, no services, no async loading.
- **No Riverpod, no native deps.** A design system widget must never `watch`, `read`, or `ref` a provider. No `ConsumerWidget` / `ConsumerStatefulWidget`. This keeps widgets portable, testable, and compilable on all targets (including web/Widgetbook).
- **No FRB types in props.** All FRB-generated files transitively import native FFI via `frb_generated.dart`, which breaks web compilation. Use plain Dart models (String, int, enums, custom data classes) instead.
- **Screens as containers.** Feature screens in `lib/features/` watch providers and pass data down to design system widgets. No separate container widget class is required — the screen itself is the container.
- **Widgetbook imports the real widget.** Every new design system widget gets a use case that imports and renders the actual component with mock data via knobs — never a hand-built visual replica.

## Widget Pipeline

Three slash commands drive the design system from inspiration to verified widget:

### `/figma-inspect <Figma URL>`
Extracts design data from Figma and maps it to design system tokens. Produces:
- `.specs/<WidgetName>.spec.yaml` — structural spec with token mappings
- `.specs/<WidgetName>.reference.png` — screenshot of the Figma design (inspiration, not spec)

### `/widget-from-figma <Figma URL or screenshot>`
End-to-end builder. If given a Figma URL, runs `/figma-inspect` first, then builds.
Uses Dart MCP tools throughout: `resolve_workspace_symbol` to find tokens and existing widgets,
`hover` for docs, `signature_help` for constructors, `analyze_files` after each file. Produces:
- `src/<widget_name>.dart` — the widget (presentation-only, tokens from theme)
- `test/design_system/<widget_name>_test.dart` — tests + golden screenshot assertion
- `test/design_system/goldens/<widget_name>.png` — rendered widget PNG
- Widgetbook use case with knobs for each parameter
- `.specs/<WidgetName>.genesis.md` — narrative of design decisions and rationale
- Barrel export in `design_system.dart`
- Row in the Widget Catalog below

Also accepts a screenshot or text description instead of a Figma URL.

### `/verify-widget <name or "all">`
Quality gate. Uses Dart MCP tools (`dart_format`, `analyze_files`, `run_tests`) instead of shell commands. Checks:
1. `dart format` clean (via `dart_format` MCP)
2. `flutter analyze` passes (via `analyze_files` MCP)
3. Tests pass (via `run_tests` MCP)
4. No hardcoded values (all from tokens)
5. No banned Material/Cupertino widgets
6. Exported from barrel file
7. Golden screenshot exists and test passes
8. Genesis document exists; visual comparison of Figma reference vs golden confirms documented decisions cover visible differences

## Token Vocabulary

| Extension | Access | Values |
|-----------|--------|--------|
| `AppSpacing` | `.space4` .. `.space48` | 4, 8, 12, 16, 24, 32, 48 |
| `AppRadii` | `.small` .. `.full` | 8, 12, 16, 24, 999 |
| `AppElevation` | `.none` .. `.max` | 0, 1, 2, 4, 8 |
| `AppOpacity` | `.subtle` .. `.secondary` | 0.08, 0.12, 0.20, 0.30, 0.40 |
| `AppSizing` | `.iconSmall` .. `.iconXLarge` + `.icon*` | containers: 40-64, icons: 20-32 |
| `AppAnimation` | `.fast` .. `.complex` | 100ms, 150ms, 200ms, 300ms |
| `AppSemanticColors` | `.technical`, `.flash`, `.community`, `.success` | Each group: `.color`, `.onColor`, `.colorContainer`, `.onColorContainer` |

## Decisions Log

<!-- Decisions are captured here as they emerge from widget creation sessions -->
<!-- Format: "- **Context**: Decision (date)" -->
- **Widgetbook failed to compile on web** because `AppAppBar` → `NodeStatusIcon` → `nodeStatusProvider` → Rust FFI. Adopted presentation-only rule: design system widgets take data as props, never fetch state. Containers live in `lib/features/`. (2026-02-20)

## Widget Catalog

<!-- Updated by the widget builder after each new component -->
| Widget | Source | Genesis |
|--------|--------|---------|
<!-- | `FooBar` | [Figma](<url>) | [genesis](.specs/FooBar.genesis.md) | -->
