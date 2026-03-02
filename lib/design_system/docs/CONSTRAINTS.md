# Design System Constraints

Rules enforced by convention (and eventually by lint). Each constraint has: WHAT, WHY, WHERE.

## Presentation-Only Rule

**Constraint:** All widgets in `lib/design_system/` take state via constructor params (data + callbacks). No providers, no `ConsumerWidget`, no services, no async loading. No FRB types in props (they transitively import native FFI, breaking Widgetbook's web build).

**Why:** When a widget imported a provider that transitively imported Rust FFI, the entire Widgetbook build broke. Presentation-only widgets are inherently portable and testable. **Where:** `lib/design_system/src/` (all widgets follow this contract).

## No-copyWith Rule

**Constraint:** Use M3 `textTheme` styles as-is. Do not override font weight, letter spacing, or other properties with `copyWith`. When Figma disagrees, use the closest M3 style. When the whole scale feels wrong, refactor the `TextTheme` at the theme level.

**Permitted exceptions** (functional needs only):

| Exception | copyWith | Justification |
|-----------|----------|---------------|
| Monospace for tabular data | `.copyWith(fontFamily: 'monospace')` | Fixed-width glyphs for column alignment |
| Bold for time-critical data | `.copyWith(fontWeight: FontWeight.w700)` | Weight contrast for actionable, time-sensitive values |

**Why:** Per-widget overrides accumulate one-off styles that drift from the scale. A `titleMedium` should look the same everywhere. **Where:** [DECISIONS.md](DECISIONS.md) "Widget Implementation Decisions".

## Token Access Rule

**Constraint:** All visual values from theme tokens. No hardcoded hex colors, dp values, or magic numbers.
- Spacing/radii/elevation: `Theme.of(context).extension<T>()!`
- Colors: `Theme.of(context).colorScheme` and `.extension<AppSemanticColors>()!`
- Typography: `Theme.of(context).textTheme`

**Why:** Centralized tokens enable consistent theming, dark mode, and contrast-level switching. **Where:** `theme/color_is_expensive_theme.dart`, `theme/design_system_theme.dart`.

## Color Budget Rule

**Constraint:** Chromatic color only via `AppSemanticColors`. The `ColorScheme` is achromatic. The tertiary role is a "ghost" that forces semantic color usage.

**Why:** An achromatic base ensures color has meaning — every chromatic pixel earns its place through a semantic role. **Where:** [COLOR.md](COLOR.md).

## Two-Tier Surface Rule

**Constraint:** Scaffold = grey (`surface` T96). Content surfaces (cards, sheets, nav bars) = white (`surfaceContainerLowest`). Borders for separation, not elevation. `surfaceTintColor: Colors.transparent` on all surface-bearing components.

**Why:** M3's tonal elevation with achromatic primary produces imperceptible grey-on-grey shifts. Borders are clearer. **Where:** [SURFACES.md](SURFACES.md); `theme/color_is_expensive_theme.dart`.

## Layout Token Rule

**Constraint:** All layout spacing (margins, gaps, padding) from `AppSpacing` tokens. No hardcoded `EdgeInsets` values.
- Screen margins: `space16` (16dp)
- Section gaps: `space24` (24dp)
- Card gaps: `space16` (16dp)
- Use Column/Row `spacing:` parameter over `SizedBox` gaps
- Use `SliverPadding` over `Padding` inside `SliverToBoxAdapter`

**Why:** Hardcoded layout values drift off the 8pt grid and create visual inconsistency across screens. Tokens keep every screen aligned. **Where:** [LAYOUT.md](LAYOUT.md).

## Widgetbook Rule

**Constraint:** Every widget gets a Widgetbook use case importing the **real widget** with mock data via knobs. Never hand-built replicas.

**Why:** What you see in Widgetbook must be exactly what ships. Replicas drift.
**Where:** Widgetbook use cases in `widgetbook/`.

## Widget Pipeline

Three slash commands drive design-to-code:

| Command | Purpose |
|---------|---------|
| `/figma-inspect` | Extract Figma design data, map to tokens, produce `.spec.yaml` + `.genesis.md` |
| `/widget-from-figma` | End-to-end: inspect + build widget + tests + Widgetbook use case |
| `/verify-widget` | Quality gate: format, analyze, test, token check, barrel, genesis, catalog |

**Where:** Skills: `/figma-inspect`, `/widget-from-figma`, `/verify-widget`.

## Quality Gate Checklist

| # | Constraint | Verification |
|---|-----------|-------------|
| 1 | `dart format` clean | `dart format --set-exit-if-changed .` |
| 2 | `flutter analyze` passes | Zero issues |
| 3 | Tests pass | `flutter test` |
| 4 | No hardcoded values | All visual properties from theme tokens |
| 5 | Tokens via theme | `Theme.of(context).extension<T>()!` |
| 6 | Colors via theme | `colorScheme` and `AppSemanticColors` |
| 7 | Typography via theme | `textTheme` — no `copyWith` unless genuinely needed |
| 8 | Exported from barrel | Listed in `design_system.dart` |
| 9 | Genesis doc exists | `.specs/<WidgetName>.genesis.md` |
| 10 | Catalog entry exists | Row in Widget Catalog |

**Where:** `/verify-widget` checks all 10 items.

## Known Architecture Issues

1. **Dual theme.** Legacy `MaterialTheme` (chromatic blue `#2633C5`) at app root; design system `ColorIsExpensiveTheme` (achromatic) injected locally. Widgets calling `extension<T>()!` outside a wrapper **throw null assertion errors**.
2. **Local Theme() fragility.** Every feature screen must wrap with design system theme + `Builder`. `.light()` is hardcoded, blocking dark mode.
3. **Extension null-crash risk.** Until single-root migration, widgets outside the design system boundary crash on `ThemeExtension` access. Interim fix: register `standardExtensions()` at app root.
4. **surfaceTint disabled globally.** Intentional with achromatic primary. Re-evaluate if chromatic primary is ever adopted.

**Where:** [DECISIONS.md](DECISIONS.md) "Architecture Decisions"; `theme/color_is_expensive_theme.dart`.
