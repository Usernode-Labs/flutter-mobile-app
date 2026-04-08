# DESIGN.md — Usernode Mobile App Design System

> **One-file reference for building screens.** All token values, color hex codes, and rules inline. No source-file reading needed.

---

## 1. Visual Theme & Atmosphere

**"Color is expensive."** Chromatic color is a scarce resource — every hue earns its place through semantic purpose. Structure is achromatic; only content and status carry hue.

- **Scarcity creates value.** A blue badge on a monochrome list *screams*. Restraint amplifies signal-to-noise ratio.
- **Color becomes vocabulary.** Blue = technical, amber = urgency, green = community/success, red = error. A closed vocabulary — no "decorative purple."
- **Structure is achromatic.** Nav bars, cards, buttons, scaffolds, dividers — the entire structural layer is greyscale.

**The third way:** Neither "colorful M3" (saturated primary tonal palette) nor "monochrome brutalism." Monochrome infrastructure with chromatic semantics.

---

## 2. Color Palette & Roles

### ColorScheme (Light — all structural roles achromatic)

| Role | Hex | Purpose |
|------|-----|---------|
| `primary` | `#252627` | Near-black attention locker. CTAs. |
| `onPrimary` | `#FFFFFF` | Text/icon on primary |
| `primaryContainer` | `#E2E2E4` | Muted primary surface |
| `onPrimaryContainer` | `#1B1B1C` | Text on primaryContainer |
| `secondary` | `#5C5E64` | Cool-grey structural emphasis |
| `onSecondary` | `#FFFFFF` | Text on secondary |
| `secondaryContainer` | `#E1E2E8` | Muted secondary surface |
| `onSecondaryContainer` | `#191A20` | Text on secondaryContainer |
| `tertiary` | `#757575` | **Ghost role** — barely Lc 60. Trap to force semantic colors. |
| `onTertiary` | `#FFFFFF` | Text on tertiary |
| `tertiaryContainer` | `#F5F5F5` | Near-invisible container |
| `onTertiaryContainer` | `#5D5D5D` | Text on tertiaryContainer |
| `error` | `#BD0F19` | Signal red — only chromatic structural role |
| `onError` | `#FFFFFF` | Text on error |
| `errorContainer` | `#FFBFA9` | Error surface |
| `onErrorContainer` | `#9C0003` | Text on errorContainer |
| `surface` | `#EBEBEB` | Grey scaffold substrate |
| `onSurface` | `#1B1B1B` | Primary text/content |
| `onSurfaceVariant` | `#44474D` | Secondary text |
| `outline` | `#74777E` | Borders, dividers |
| `outlineVariant` | `#C4C6CC` | Subtle borders (white-on-white) |
| `surfaceContainerLowest` | `#FFFFFF` | White content tier (cards, sheets, nav) |
| `surfaceContainerLow` | `#F3F3F3` | |
| `surfaceContainer` | `#EEEEEE` | |
| `surfaceContainerHigh` | `#E8E8E8` | Muted bar backgrounds |
| `surfaceContainerHighest` | `#E2E2E2` | Input fills |

Primary vs onSurface: both near-black. Primary = interactive (buttons); onSurface = content (text). Distinguish by shape.

> Full dark, medium-contrast, and high-contrast schemes → `lib/design_system/theme/color_is_expensive_theme.dart`

### ColorScheme (Dark)

| Role | Hex |
|------|-----|
| `primary` | `#D4D4D6` |
| `onPrimary` | `#252627` |
| `surface` | `#212121` |
| `onSurface` | `#EBEBEB` |
| `surfaceContainerLowest` | `#111111` |
| `error` | `#FFA28C` |
| `onError` | `#240D04` |

> Remaining dark roles → `color_is_expensive_theme.dart`

### AppSemanticColors — Chromatic Gatekeeper (Light)

The **only** sanctioned path to hue (besides `error`). Access: `Theme.of(context).extension<AppSemanticColors>()!`

| Group | Purpose | `.color` | `.onColor` | `.colorContainer` | `.onColorContainer` | `.colorSurface` | `.onColorSurface` |
|-------|---------|----------|------------|--------------------|--------------------|-----------------|-------------------|
| `technical` | Precision, code, blockchain | `#0055D9` | `#FFFFFF` | `#D3D9FF` | `#0040BD` | `#E1E8F3` | `#0055D9` |
| `flash` | Urgency, time-limited | `#875300` | `#FFFFFF` | `#FFD87B` | `#774500` | `#ECE8E1` | `#875300` |
| `community` | Participation, social | `#146D32` | `#FFFFFF` | `#B6F0BE` | `#05652B` | `#E3EAE5` | `#146D32` |
| `success` | Completion, achievement | `#1A6D23` | `#FFFFFF` | `#BAF1B4` | `#12681E` | `#E3EAE4` | `#1A6D23` |
| `warning` | Syncing, permissions | `#9C5700` | `#FFFFFF` | `#FFDDB3` | `#874900` | `#EEE8E1` | `#9C5700` |

**Tier usage:** Strong (`.color`/`.onColor`) for small-area emphasis (icons, text, borders). Medium (`.colorContainer`/`.onColorContainer`) for badges, chips. Faint (`.colorSurface`/`.onColorSurface`) for large-area backgrounds (card fills, section highlights).

> Dark and contrast variants → `lib/design_system/tokens/app_semantic_colors.dart`

---

## 3. Typography Rules

Use `Theme.of(context).textTheme` as-is. M3 type scale is the single source of truth.

**Display Mono Rule:** Any screen's primary KPI or status headline uses IBM Plex Mono at `displaySmall` (36px):
```dart
textTheme.displaySmall!.copyWith(fontFamily: 'IBMPlexMono')
```

**Permitted copyWith exceptions (only these 3):**

| Exception | copyWith | When |
|-----------|----------|------|
| Monospace for tabular data | `.copyWith(fontFamily: 'IBMPlexMono')` | Fixed-width column alignment |
| Monospace for display hero | `.copyWith(fontFamily: 'IBMPlexMono')` | Primary KPI / status headline |
| Bold for time-critical data | `.copyWith(fontWeight: FontWeight.w700)` | Actionable, time-sensitive values |

**Don't:** Override font weight, letter spacing, or other properties for aesthetic reasons. When Figma disagrees, use the closest M3 style. When the whole scale feels wrong, refactor the `TextTheme` at the theme level.

---

## 4. Component Stylings

### M3-First Rule (TOP PRIORITY)

Never create a custom widget that duplicates an M3 component (ListTile, Card, Switch, Checkbox, etc.). Use M3 directly and compose DS *slot widgets* (IconBadge, StatusBadge, RankBadge, etc.) into M3 containers. Only create a custom widget when M3 genuinely doesn't cover the pattern — prove the gap first.

### Presentation-Only Rule

All widgets in `lib/design_system/` take state via constructor params (data + callbacks). No providers, no `ConsumerWidget`, no services, no async. No FRB types in props. Screens in `lib/features/` wire state.

### Icon Defaults

Use Material Symbols Sharp: `Symbols.*_sharp` from `material_symbols_icons`. Theme enforces weight 300, outline (fill 0), 24px via `iconTheme`. Sharp variant is per-icon naming.

### Slot Widget Pattern

DS widgets are small, focused components that compose into M3 containers at the screen level. Build from Flutter core primitives (Container, Padding, Row, Column, Stack, CustomPaint, etc.).

---

## 5. Layout Principles

### 8pt Grid

All spacing derives from `AppSpacing` tokens. Values: 4, 8, 12, 16, 24, 32, 48.

### Spacing Roles

| Role | Token | Value | Usage |
|------|-------|-------|-------|
| Screen margin (horizontal) | `space16` | 16dp | `EdgeInsets.symmetric(horizontal: spacing.space16)` |
| Section gap | `space24` | 24dp | Between major content groups |
| Card gap | `space16` | 16dp | Between same-type cards |
| List item gap | `space12` | 12dp | `ListView.separated` or Column `spacing` |
| Bottom scroll padding | `space32` | 32dp | Last sliver breathing room |
| PSL surface body inset | `space24` | 24dp | Horizontal inset for non-ListTile content in PSL |
| Card internal padding | `space16` | 16dp | `EdgeInsets.all(spacing.space16)` |
| Internal element gap | `space8` | 8dp | Between label and value within a card |
| Tight gap | `space4` | 4dp | Between heading and body text |

### Keyline System

```
Screen edge
│
├── K₀ (16dp) ── Card edges, chips, standalone widgets
│
│   Card edge
│   │
│   ├── K₁ (+16dp = 32dp from screen) ── Section titles, subheaders
│   │
│   └── K₂ (+72dp = 88dp from screen) ── Text after leading elements
```

K₂ = contentPadding (16dp) + minLeadingWidth (40dp) + horizontalTitleGap (16dp) = 72dp from card edge.

**Never add manual Padding around ListTile/ExpansionTile** — it shifts K₂.

### Matryoshka Spacing Ownership

Each zone owns its own spacing. No zone reaches into another.

| Zone | Owner | Controls |
|------|-------|----------|
| **Macro** | Screen body | Screen margins, gaps between surfaces/sections |
| **Meso** | Surface container (AppCard) | Inset padding between surface edge and content |
| **Micro** | Leaf widget (ListTile) | Content padding (theme `contentPadding`) |

### Scroll Container Decision Tree

1. Pinned tabs with independently scrollable tab content? → `NestedScrollView`
2. TopAppBar or multiple distinct sliver types? → `CustomScrollView` + `SliverToBoxAdapter`
3. Simple list of similar items? → `ListView.separated`
4. Default? → `ListView` or `Column` in `SingleChildScrollView`

Use `SliverPadding` for screen margins in `CustomScrollView`, not `Padding` inside `SliverToBoxAdapter`.
Use `Column(spacing: spacing.space16)` instead of interleaving `SizedBox` widgets.

---

## 6. Depth & Elevation

### Two-Tier Surface Model

Grey scaffold + white content. FG/BG color contrast is the primary separation.

```
Scaffold: surface (#EBEBEB) ← grey substrate
  └── Content: surfaceContainerLowest (#FFFFFF) ← white cards, sheets, nav
        └── Inner card on white: outlineVariant border (white-on-white exception)
```

Borders only for white-on-white scenarios. `surfaceTintColor: Colors.transparent` on all surface-bearing components.

Dark mode: `surface` = `#212121`. Content surfaces use standard dark tones.

### Component Surface Classification

| Category | Token | Examples |
|----------|-------|----------|
| Scaffold-level | `surface` | Scaffold, AppBar |
| Content-level | `surfaceContainerLowest` | Card, NavigationBar, BottomSheet, Dialog |
| Input-level | `surfaceContainerHighest` | TextField fill |
| Transparent | `Colors.transparent` | ExpansionTile, surfaceTintColor overrides |
| Inherit | parent surface | Widgets inside a card |

### Elevation Tokens (`AppElevation`)

| Token | Value | Use |
|-------|-------|-----|
| `none` | 0 | Default — borders replace shadows |
| `low` | 1 | Subtle lift |
| `medium` | 2 | Moderate emphasis |
| `high` | 4 | Floating elements |
| `max` | 8 | Maximum emphasis |

---

## 7. Token Tables

### AppSpacing

| Token | Value |
|-------|-------|
| `space4` | 4dp |
| `space8` | 8dp |
| `space12` | 12dp |
| `space16` | 16dp |
| `space24` | 24dp |
| `space32` | 32dp |
| `space48` | 48dp |

Access: `final spacing = Theme.of(context).extension<AppSpacing>()!;`

### AppRadii

| Token | Value | Getter | Use |
|-------|-------|--------|-----|
| `xSmall` | 4dp | `borderRadiusXSmall` | Fine-grained rounding |
| `small` | 8dp | `borderRadiusSmall` | Chips, small badges |
| `medium` | 12dp | `borderRadiusMedium` | ListTile shape, snackbar |
| `large` | 16dp | `borderRadiusLarge` | Cards (CardTheme default) |
| `largeIncreased` | 20dp | `borderRadiusLargeIncreased` | Prominent cards |
| `xLarge` | 24dp | `borderRadiusXLarge` | Dialogs, bottom sheets |
| `xxLarge` | 28dp | `borderRadiusTopXXLarge` | Top-only sheet corners |
| `full` | 999dp | `borderRadiusFull` | Pills, fully rounded |

Partial-side getters: `borderRadiusTopSmall`, `borderRadiusTopLarge`, `borderRadiusTopXLarge`, `borderRadiusTopLargeIncreased`, `borderRadiusBottomLargeIncreased`.

Access: `final radii = Theme.of(context).extension<AppRadii>()!;`

### AppSizing

| Token | Value | Use |
|-------|-------|-----|
| `iconXSmall` | 16dp | Tiny icons |
| `iconSmall` | 20dp | Small icons (trailing chevron) |
| `iconRegular` | 24dp | Default icon size |
| `iconLarge` | 28dp | Emphasized icons |
| `iconXLarge` | 32dp | Large feature icons |
| `iconDisplay` | 48dp | Display icons |
| `iconDisplayLarge` | 64dp | Hero icons |
| `iconContainerSmall` | 40dp | Small tap target |
| `iconContainerRegular` | 48dp | Standard tap target (min accessible) |
| `iconContainerLarge` | 56dp | Large tap target |
| `iconContainerXLarge` | 64dp | FAB / primary action |
| `buttonHeightSmall` | 40dp | Small button |
| `buttonHeightRegular` | 48dp | Standard button |
| `buttonHeightLarge` | 56dp | Large / prominent button |

Access: `final sizing = Theme.of(context).extension<AppSizing>()!;`

### AppOpacity

| Token | Value | Use |
|-------|-------|-----|
| `subtle` | 0.08 | Barely visible overlays, border tints |
| `medium` | 0.12 | Hover/focus states |
| `strong` | 0.20 | Visible but not dominant |
| `disabled` | 0.30 | Disabled elements |
| `secondary` | 0.40 | Secondary/muted content |

Access: `final opacity = Theme.of(context).extension<AppOpacity>()!;`

### AppBorders

| Token | Value |
|-------|-------|
| `width` | 1dp |
| `opacity` | 0.08 |

Usage: `BorderSide(color: colorScheme.onSurface.withValues(alpha: borders.opacity), width: borders.width)`

Access: `final borders = Theme.of(context).extension<AppBorders>()!;`

### AppAnimation

| Token | Duration | Use |
|-------|----------|-----|
| `fast` | 100ms | Micro-interactions |
| `normal` | 150ms | Standard transitions |
| `slow` | 200ms | Complex animations |
| `complex` | 300ms | Page transitions |

Access: `final animation = Theme.of(context).extension<AppAnimation>()!;`

---

## 8. Do's and Don'ts

### Do

- Use `primary` for CTAs, distinguish from body text by shape not color
- Use `AppSemanticColors` for all chromatic emphasis
- Use `colorSurface`/`onColorSurface` for large-area backgrounds, `colorContainer`/`onColorContainer` for compact elements
- Use `surfaceContainerLowest` for content surfaces (cards, sheets, nav)
- Use `SliverPadding` for margins in `CustomScrollView`
- Use `Column(spacing:)` / `Row(spacing:)` instead of `SizedBox` gaps
- Use `Symbols.*_sharp` for all icons
- Use M3 components (ListTile, Card, etc.) directly — compose DS slot widgets into them

### Don't

- Hardcode hex colors — use tokens
- Hardcode `EdgeInsets` or border radius values — use tokens
- Use chromatic color decoratively — must go through `AppSemanticColors`
- Use `Opacity` on readable content (drops contrast) — use color-based demotion
- Reach for `tertiary*` expecting visible emphasis (ghost role)
- Wrap ListTile in Padding with horizontal insets (shifts K₂)
- Use `copyWith` on textTheme except the 3 permitted exceptions
- Add providers or services to design system widgets
- Use FRB-generated types in DS widget constructors
- Use `Card(margin:)` — zeroed by theme, use parent Padding instead
- Override ListTile layout properties per-widget (visualDensity, minVerticalPadding, contentPadding, etc.) — set in theme

---

## 9. Agent Prompt Guide

### Token Preamble

Every `build()` method:
```dart
final spacing = Theme.of(context).extension<AppSpacing>()!;
final radii = Theme.of(context).extension<AppRadii>()!;
final sizing = Theme.of(context).extension<AppSizing>()!;
final colorScheme = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;
// Only if semantic colors needed:
final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
```

### Quality Gate

```bash
dart format .
flutter analyze
cd packages/ds_lints && dart run bin/lint.dart ../..
```

### Key Files

| Purpose | Path |
|---------|------|
| ColorScheme + theme builder | `lib/design_system/theme/color_is_expensive_theme.dart` |
| ThemeExtension wiring | `lib/design_system/theme/design_system_theme.dart` |
| Semantic colors (all variants) | `lib/design_system/tokens/app_semantic_colors.dart` |
| Spacing tokens | `lib/design_system/tokens/app_spacing.dart` |
| Radii tokens | `lib/design_system/tokens/app_radii.dart` |
| Sizing tokens | `lib/design_system/tokens/app_sizing.dart` |
| Elevation tokens | `lib/design_system/tokens/app_elevation.dart` |
| Opacity tokens | `lib/design_system/tokens/app_opacity.dart` |
| Animation tokens | `lib/design_system/tokens/app_animation.dart` |
| Border tokens | `lib/design_system/tokens/app_borders.dart` |
| Widget implementations | `lib/design_system/src/*.dart` |
| Genesis specs | `lib/design_system/.specs/*.genesis.md` |
| Constraints & rules | `lib/design_system/docs/CONSTRAINTS.md` |
| Layout patterns | `lib/design_system/docs/LAYOUT.md` |
| Screen building playbook | `lib/design_system/docs/SCREEN_PATTERNS.md` |
| Surface architecture | `lib/design_system/docs/SURFACES.md` |
| Color philosophy | `lib/design_system/docs/COLOR.md` |
| Typography | `lib/design_system/docs/TYPOGRAPHY.md` |
