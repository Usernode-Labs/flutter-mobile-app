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
| Monospace for tabular data | `.copyWith(fontFamily: 'IBMPlexMono')` | Fixed-width glyphs for column alignment |
| Monospace for display hero text | `.copyWith(fontFamily: 'IBMPlexMono')` | Unified technical identity for primary KPI / status headlines |
| Bold for time-critical data | `.copyWith(fontWeight: FontWeight.w700)` | Weight contrast for actionable, time-sensitive values |

**Why:** Per-widget overrides accumulate one-off styles that drift from the scale. A `titleMedium` should look the same everywhere. **Where:** [DECISIONS.md](DECISIONS.md) "Widget Implementation Decisions".

## Token Access Rule

**Constraint:** All visual values from theme tokens. No hardcoded hex colors, dp values, or magic numbers.
- Spacing/radii/elevation: `Theme.of(context).extension<T>()!`
- Colors: `Theme.of(context).colorScheme` and `.extension<AppSemanticColors>()!`
- Typography: `Theme.of(context).textTheme`

**Why:** Centralized tokens enable consistent theming, dark mode, and contrast-level switching. **Where:** `theme/color_is_expensive_theme.dart`, `theme/design_system_theme.dart`.

## Color Budget Rule

**Constraint:** Chromatic color only via `AppSemanticColors`. Every `ColorScheme` structural role — primary, secondary, tertiary, and all their containers — is **achromatic grey**. Only `error*` retains hue.

**Critical implication:** Widgets using `ColorScheme` defaults render grey automatically. For example, `IconBadge` defaults to `secondaryContainer` / `onSecondaryContainer` which are grey (`#E1E2E8` / `#44474D`) — no explicit override needed to make them neutral. Do not add color params to "neutralize" something that is already achromatic.

**To introduce hue**, reach for `AppSemanticColors`:
```dart
final semantic = Theme.of(context).extension<AppSemanticColors>()!;
// semantic.technical  — blue (infrastructure, upcoming slots)
// semantic.flash      — amber (challenge category)
// semantic.community  — green (challenge category)
// semantic.success    — green (positive outcomes)
// semantic.warning    — amber (syncing, permissions)
// Each group: .color, .onColor, .colorContainer, .onColorContainer, .colorSurface, .onColorSurface
```

**Why:** An achromatic base ensures color has meaning — every chromatic pixel earns its place through a semantic role. **Where:** [COLOR.md](COLOR.md); `theme/color_is_expensive_theme.dart`.

## Two-Tier Surface Rule

**Constraint:** Scaffold = grey (`surface` T96). Content surfaces (cards, sheets, nav bars) = white (`surfaceContainerLowest`). FG/BG color contrast for separation. Outline borders only for white-on-white inner cards, never on grey scaffold. `surfaceTintColor: Colors.transparent` on all surface-bearing components.

**Why:** M3's tonal elevation with achromatic primary produces imperceptible grey-on-grey shifts. The grey/white contrast IS the primary separation; borders are only warranted when a card sits on a same-tone parent surface. **Where:** [SURFACES.md](SURFACES.md); `theme/color_is_expensive_theme.dart`.

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

## Screen Pipeline

Three slash commands drive screen design-to-code:

| Command | Purpose |
|---------|---------|
| `/screen-from-figma` | End-to-end: detect screen type, select template, compose widgets, wire state, audit |
| `/screen-audit` | Quality gate: 13 automated checks (spacing, colors, SafeArea, scroll, PSL, ds_lints) |
| `/pr-audit` | Pre-push: aggregates `/verify-widget` + `/screen-audit` on changed files + full quality gate |

**Where:** Skills: `/screen-from-figma`, `/screen-audit`, `/pr-audit`.

## M3 Gap-Proof Checklist

Before creating a custom widget, complete these steps:

1. **Identify M3 candidates** — which M3 widgets could handle this? (ListTile, Card, ExpansionTile, etc.)
2. **Prototype with M3** — attempt composition with M3 containers + DS slot widgets
3. **List the gaps** — what specific capability is missing? (custom paint, non-standard layout, animation)
4. **Log a decision** — add an entry to [DECISIONS.md](DECISIONS.md) with the M3 widget tried, what failed, and why a custom widget is needed
5. **Build custom** — only now create the primitive-based widget

See [DECISIONS.md](DECISIONS.md) "Selective M3 Adoption" for a worked example.

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

## Card Zero-Margin Rule

**Constraint:** `CardThemeData` sets `margin: EdgeInsets.zero`, overriding Flutter's hidden default `margin: EdgeInsets.all(4.0)`. Cards never own their external spacing — parent widgets (Padding, SizedBox, Column spacing) provide inter-card gaps following the Matryoshka model.

**Why:** Flutter's `Card` has a built-in 4px margin that breaks token-based keyline alignment. When a screen applies `space16` horizontal padding and a Card adds 4px margin, the visual inset becomes 20px instead of 16px — an invisible off-grid drift. Zeroing at the theme level fixes every Card globally.

**Where:** `theme/color_is_expensive_theme.dart` (CardThemeData); enforced by `avoid_card_margin` lint.

## Known Architecture Issues

1. ~~**Dual theme.**~~ **Resolved (2026-03-02).** `ColorIsExpensiveTheme` is now the
   sole theme at the `MaterialApp` root with all extensions registered via
   `standardExtensions()`. No per-screen `Theme()` wrappers remain.
2. ~~**Local Theme() fragility.**~~ **Resolved.** Dark mode is wired at root
   (`theme:` / `darkTheme:` / `themeMode:`). No hardcoded `.light()` in feature screens.
3. **surfaceTint disabled globally.** Intentional with achromatic primary.
   Re-evaluate if chromatic primary is ever adopted.
4. **`LegacyColors` constants.** `lib/core/config/legacy_colors.dart` still holds
   accent hex values (`#F56E98`, `#F1B440`, `#FF9800`). Map to `AppSemanticColors`
   or `colorScheme` roles when those screens are migrated.

**Where:** [DECISIONS.md](DECISIONS.md) "Architecture Decisions"; `theme/color_is_expensive_theme.dart`.

## ListTile Layout Constraint

**Constraint:** Only customize **visual** properties in `ListTileThemeData` (text styles, colors, shape, horizontal `contentPadding`). Never override layout properties (`minVerticalPadding`, `visualDensity`, `minTileHeight`, `titleAlignment`, vertical `contentPadding`) — let M3 defaults handle tile height, density, padding, and alignment.

**Why:** M3's ListTile uses a baseline-anchored layout algorithm where these properties are interdependent (magic numbers 32.0, 52.0, 72.0 in Flutter source). Overriding any one of them breaks the alignment between leading icons and text. We tried overriding all four and each fix solved one symptom but introduced another (misaligned icons, tiles crammed together).

**Where:** `theme/color_is_expensive_theme.dart` (ListTileThemeData); enforced by `avoid_listtile_layout_overrides` lint.

## List Surface Vertical Inset

**Constraint:** When a card contains only ListTile-family widgets, use
`EdgeInsets.symmetric(vertical: spacing.space8)` — not `EdgeInsets.zero`.
ListTile's theme `contentPadding` handles horizontal; the card surface
owns vertical breathing room.

**Why:** `EdgeInsets.zero` eliminates all surface inset, making the first
and last tiles flush against the card boundary. The 8dp vertical inset
matches M3's internal `minVerticalPadding` rhythm, creating balanced
framing.

**Where:** `SCREEN_PATTERNS.md` § "When Zones Collide"; enforced by
`require_tile_card_vertical_inset` lint.

## Automated Lint Rules (`ds_lints`)

The following audits are automated via `packages/ds_lints/`. Run from the project root:

```bash
cd packages/ds_lints && dart run bin/lint.dart /path/to/project/root
```

| Rule | Severity | What it flags |
|------|----------|---------------|
| `avoid_hardcoded_edge_insets` | WARNING | `EdgeInsets.all(16)`, `.only(left: 8)` etc. with numeric literals. `EdgeInsets.zero` and value==0 pass. |
| `avoid_hardcoded_border_radius` | WARNING | `BorderRadius.circular(12)`, `Radius.circular(8)` with literals. Zero values pass. |
| `avoid_hardcoded_sized_box_spacing` | INFO | Childless `SizedBox(height: 16)` matching grid values {4,8,12,16,24,32,48}. SizedBox with `child:` not flagged. |
| `avoid_hardcoded_icon_size` | INFO | `Icon(..., size: 20)` with literal size. Icons without `size:` use theme default. |
| `matryoshka_zone_violation` | WARNING | Macro tokens (space32/space48) as padding. Exception: `EdgeInsets.only(bottom: spacing.space32)` allowed per LAYOUT.md. space24 is dual-purpose (vertical section gap + horizontal PSL body keyline) so horizontal space24 is not flagged. |
| `avoid_frb_imports` | WARNING | `import 'package:flutter_rust_bridge/...'` or `frb_generated` in `lib/design_system/`. FRB types break Widgetbook web. |
| `avoid_padding_around_tiles` | WARNING | `Padding` with horizontal insets wrapping a ListTile-family widget (`ListTile`, `SwitchListTile`, `CheckboxListTile`, `RadioListTile`, `ExpansionTile`). These widgets get `contentPadding` from the theme — outer horizontal Padding causes double-indenting. |
| `avoid_listtile_layout_overrides` | WARNING | Per-widget `visualDensity`, `minVerticalPadding`, `minTileHeight`, `titleAlignment`, or `contentPadding` on `ListTile`/`SwitchListTile`/`CheckboxListTile`/`RadioListTile`. These layout properties should come from the theme — per-widget overrides break M3's baseline alignment. |
| `require_tile_card_vertical_inset` | WARNING | `AppCard(padding: EdgeInsets.zero)` whose child subtree contains tile widgets. Use `EdgeInsets.symmetric(vertical: spacing.space8)` for list surface inset. |
| `avoid_card_margin` | WARNING | `Card(margin: ...)` with an explicit margin argument. CardThemeData zeroes the default 4px margin — use a parent `Padding` or `SizedBox` for spacing instead. |

Excluded paths: `/widgetbook/`, `/test/`.

## Manual Review Rules

Constraints that cannot be fully automated and require periodic manual audits.

### Hardcoded Color Audit

Detect hex color literals and `Colors.*` usage outside the theme:

```bash
grep -rn 'Color(0x' lib/design_system/src/ lib/features/
grep -rn 'Colors\.' lib/design_system/src/ lib/features/
```

Exceptions: `Colors.transparent` is allowed.

### Double Padding Audit

Detect potential padding stacking (screen margin + card margin):

```bash
grep -rn 'padding:' lib/features/ | grep -v 'test'
```

Manually verify no screen applies horizontal margin AND its cards also apply horizontal margin.

### Screen Review Checklist

When reviewing a screen (new or migrated), verify:

| # | Check | How |
|---|-------|-----|
| 1 | Padding ownership | No double margins (screen + card both adding horizontal padding) |
| 2 | Tokens only | No hardcoded EdgeInsets, no magic dp values |
| 3 | Correct scroll container | Matches LAYOUT.md decision tree |
| 4 | State handling | Loading/error/empty use DS widgets (FullPageLoadingState, FullPageErrorState, EmptyState) |
| 5 | SafeArea | Present only where needed (not doubled with TopAppBar) |
| 6 | Bottom padding | `space32` breathing room at end |
| 7 | RefreshIndicator | Wraps scroll view if pull-to-refresh needed |
| 8 | SliverPadding | Used for margins in CustomScrollView |
| 9 | No inter-item dividers | Homogeneous ListTile lists use padding, not Divider |

See also: [SCREEN_PATTERNS.md](SCREEN_PATTERNS.md) for full screen building playbook.

### Widget-Test Constant Sync

When a widget uses an internal numeric constant (not a token) that a test asserts against, mark it:

```dart
height: 128, // @tested — challenge_activity_summary_test.dart:163
```

Before changing a `// @tested` value, update the referenced test first. This prevents the 126→128 class of silent test breakage.
