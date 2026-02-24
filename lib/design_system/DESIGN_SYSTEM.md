# Design System — Living Document

This document grows from real widget creation sessions. Rules are added when agents fail without them, not speculatively.

> **Sandboxed POC** — This is an isolated proof-of-concept design system in `lib/design_system/` to experiment with agentic widget building using a living design system. No existing code is modified beyond adding widgetbook to `pubspec.yaml`.
> This boundary is intentional and likely temporary.

## Philosophy

- **Code + tokens = truth.** The widget implementation and its design tokens are authoritative.
- **Figma = inspiration.** A useful reference, not a spec to match. Figma screenshots are kept for context, not compliance.
- **Every deviation is a decision.** When the implementation differs from the inspiration, that's not drift — it's a choice. The genesis file documents the reasoning.

## M3 Components First

Prefer Material 3 components for native behaviour, accessibility, and platform consistency.
When M3 does not cover the need, build from Flutter core primitives with M3 alignment in mind.
The design system names widgets in its own vocabulary and starts with the simplest variant needed.
Additional styles and variants are added as Figma designs demand them — not speculatively.

## Core Constraints

- Prefer M3 Material components; build from core primitives only when M3 doesn't cover the need
- Tokens via `Theme.of(context).extension<T>()!`
- Colors via `Theme.of(context).colorScheme`
- Typography via `Theme.of(context).textTheme`
- Quality: `dart format` clean, `flutter analyze` passes, tests pass
- Every widget in `src/` must have a genesis doc (`.specs/<WidgetName>.genesis.md`) and a row in the Widget Catalog below

<!-- COLOR_PHILOSOPHY_START -->
## Color Philosophy: "Color is Expensive"

Color should be scarce, and therefore valuable. In a world of saturated interfaces, the most powerful move is restraint. Every chromatic pixel earns its place through semantic purpose.

### Core Role Semantics

| Role | Seed | Purpose |
|------|------|---------|
| **Primary** | `#18191B` (near-black) | The attention locker. Maximum contrast CTAs. Same darkness as body text, distinguished by shape (button vs paragraph). |
| **Secondary** | achromatic (neutral-variant) | Structural emphasis without hue. Cool-leaning grey for secondary actions. |
| **Tertiary** | achromatic (pure neutral) | **Ghost role.** Barely-visible grey that passes APCA Lc 60 floor. Container nearly invisible against surface. Forces developers toward `AppSemanticColors` for any real emphasis. |
| **Error** | `#DC362E` (red) | Signal red. Clear error state, functional not emotional. |
| **Neutral** | `#6B6B6B` (gray) | True achromatic. Zero chroma. The paper substrate. |
| **Neutral Variant** | `#696C73` (cool gray) | Faintest cool lean for outlines and structural elements. |

### Ghost Tertiary — Contrast Cascade

Tertiary is deliberately starved of contrast. A developer reaching for `colorScheme.tertiary*` gets nearly nothing — the main color barely clears the APCA Lc 60 floor, and containers are almost indistinguishable from the surface. This makes tertiary a **trap role**: technically accessible, practically invisible. Real emphasis demands `AppSemanticColors`.

The system compensates across contrast levels to maintain accessibility:

| Contrast Level | Tertiary Behavior |
|---------------|-------------------|
| **Standard** | Ghost — barely Lc 60, containers ~ΔY 6 from surface |
| **Medium** | Partial compensation — moderately above Lc 60 |
| **High** | Full compensation — normal M3 contrast, no ghost effect |

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
- Use `AppSemanticColors` for any visible chromatic emphasis (technical, flash, community, success)
- Use neutrals for backgrounds -- let the paper breathe
- Pair `colorContainer` + `onColorContainer` together
- Access colors via `Theme.of(context).colorScheme` and `.extension<AppSemanticColors>()`

**Don't:**
- Use chromatic color decoratively -- every colored pixel must carry meaning
- Hardcode hex values -- always use theme tokens
- Reach for `colorScheme.tertiary*` expecting visible emphasis -- it's a ghost role by design
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
// Secondary (achromatic): colors.secondary, .onSecondary, ...
// Tertiary (ghost): colors.tertiary, .onTertiary, ... — near-invisible, use AppSemanticColors instead
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

<!-- SURFACE_ARCHITECTURE_START -->
## Surface Architecture

The light theme uses a grey-scaffold / white-content layering model derived from the Figma Home screen (`#F6F6F6` background with white cards). `surface` is set to T96 (`#F5F5F5`) so that M3's default `scaffoldBackgroundColor = surface` produces the grey substrate naturally.

```
┌─────────────────────────────────┐
│  Scaffold: surface (#F5F5F5)    │  ← grey "paper" substrate
│                                  │
│  ┌───────────────────────────┐  │
│  │ Content sheet:            │  │  ← white surface, rounded top
│  │ surfaceContainerLowest    │  │
│  │                           │  │
│  │  ┌─────────────────────┐  │  │
│  │  │ Card:               │  │  │  ← white card on white sheet
│  │  │ surfaceContainerLow │  │  │     (border = outlineVariant)
│  │  │ est + outlineVariant│  │  │
│  │  └─────────────────────┘  │  │
│  └───────────────────────────┘  │
│                                  │
│  ┌───────────────────────────┐  │
│  │ Nav bar:                  │  │
│  │ surfaceContainerLowest    │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

| Layer | Token | Light Value | Purpose |
|-------|-------|-------------|---------|
| Scaffold | `surface` | `#F5F5F5` (T96) | Grey page background |
| Content sheet | `surfaceContainerLowest` | `#FFFFFF` | White content area |
| Card on sheet | `surfaceContainerLowest` + `outlineVariant` border | `#FFFFFF` + `#C4C6CC` | Distinct card via border, not elevation |
| Nav bar | `surfaceContainerLowest` | `#FFFFFF` | White bottom bar |

### M3 Deviation: Two-Tier vs Tonal Gradient

M3's standard model spreads components across a gradient of surface container levels (`surfaceContainerLowest` → `surfaceContainerHighest`) to create tonal hierarchy through subtle lightness differences. Our model **collapses this to two tiers**: grey scaffold and white content. This is a deliberate simplification — the grey/white contrast is stronger and clearer than M3's subtle tonal shifts.

**What we change from M3 defaults:**

| Component | M3 Default | Our Override | Why |
|-----------|-----------|--------------|-----|
| `surface` itself | near-white (~T99) | grey T96 (`#F5F5F5`) | Foundation: visible grey scaffold enables white-on-grey layering |
| NavigationBar | `surfaceContainer` | `surfaceContainerLowest` + elevation 0 | White nav bar on grey page (2 levels lower than M3) |
| BottomSheet | `surfaceContainerLow` | `surfaceContainerLowest` | White sheet on grey page (1 level lower) |
| Card | `surfaceContainerLow` + elevation 1 | `surfaceContainerLowest` + `outlineVariant` border, elevation 0 | Border replaces tonal elevation |
| Dialog | `surface` + elevation 3 | `surfaceContainerLowest` + elevation 0 | Explicit white, flat (scrim provides separation) |
| Drawer | `surfaceContainerLow` | `surfaceContainerLowest` | White panel (1 level lower) |
| AppBar | `surface` + `scrolledUnderElevation: 3` | `surface` + `scrolledUnderElevation: 0` | Kill scroll-tint that would shift grey on scroll |

**What stays M3 default (no override needed):**

| Component | M3 Default | Why it's already correct |
|-----------|-----------|------------------------|
| Scaffold | `surface` | Grey T96 — exactly what we want |
| Divider | `outlineVariant` | Correct structural separator |
| SnackBar | `inverseSurface` | Dark-on-light for max contrast — correct |
| TabBar | transparent (inherits) | Takes parent surface — correct |
| ListTile / ExpansionTile | transparent | Inherits container — correct |
| FilledTonalButton | `secondaryContainer` | Achromatic tonal — correct |
| Switch / Checkbox / Radio | `primary`-based | Achromatic primary — correct |
| ProgressIndicator | `primary` | Correct |

### Decision Principle for New Components

When adding a new M3 component theme, classify it:

1. **Scaffold-level** → `surface` (grey): The component IS the page background (Scaffold, canvas, AppBar)
2. **Content-level** → `surfaceContainerLowest` (white): The component sits ON the scaffold as a distinct surface (NavigationBar, BottomSheet, Card, Dialog, Drawer)
3. **Inherit parent** → no background override: The component lives INSIDE a surface (ListTile, ExpansionTile, menus)
4. **Inverse** → M3 default: Transient overlays needing max contrast (SnackBar, Tooltip)
5. **Separation** → `outlineVariant` border, not elevation: Cards on white sheets are distinguished by border. Elevation is zero for content surfaces.

Dark mode keeps `surface` at `#1B1B1B` — no Figma dark reference justifies a shift. The grey-scaffold pattern is light-mode only.
<!-- SURFACE_ARCHITECTURE_END -->

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
- `.specs/<WidgetName>.genesis.md` — initial genesis document capturing non-obvious decisions made during inspection (ambiguous token snaps, Figma scope interpretation, missing tokens flagged, structural choices). Later pipeline steps append to it.

### `/widget-from-figma <Figma URL or screenshot>`
End-to-end builder. If given a Figma URL, runs `/figma-inspect` first, then builds.
Uses Dart MCP tools throughout: `resolve_workspace_symbol` to find tokens and existing widgets,
`hover` for docs, `signature_help` for constructors, `analyze_files` after each file. Produces:
- `src/<widget_name>.dart` — the widget (presentation-only, tokens from theme)
- `test/design_system/<widget_name>_test.dart` — tests
- Widgetbook use case with knobs for each parameter
- `.specs/<WidgetName>.genesis.md` — appends implementation decisions to the genesis doc started by `/figma-inspect`
- Barrel export in `design_system.dart`
- Row in the Widget Catalog below

Also accepts a screenshot or text description instead of a Figma URL.

### `/verify-widget <name or "all">`
Quality gate. Uses Dart MCP tools (`dart_format`, `analyze_files`, `run_tests`) instead of shell commands. Checks:
1. `dart format` clean (via `dart_format` MCP)
2. `flutter analyze` passes (via `analyze_files` MCP)
3. Tests pass (via `run_tests` MCP)
4. No hardcoded values (all from tokens)
5. Exported from barrel file
7. Genesis document exists with Inspiration and Design Decisions sections
8. Widget Catalog entry exists in this file
9. Widgetbook visual review — launches Widgetbook for human sign-off as the final gate

## Token Vocabulary

| Extension | Access | Values |
|-----------|--------|--------|
| `AppSpacing` | `.space4` .. `.space48` | 4, 8, 12, 16, 24, 32, 48 |
| `AppRadii` | `.small` .. `.full` | 8, 12, 16, 20, 24, 999 |
| `AppElevation` | `.none` .. `.max` | 0, 1, 2, 4, 8 |
| `AppOpacity` | `.subtle` .. `.secondary` | 0.08, 0.12, 0.20, 0.30, 0.40 |
| `AppSizing` | `.iconSmall` .. `.iconXLarge` + `.icon*` | containers: 40-64, icons: 20-32 |
| `AppAnimation` | `.fast` .. `.complex` | 100ms, 150ms, 200ms, 300ms |
| `AppSemanticColors` | `.technical`, `.flash`, `.community`, `.success` | Each group: `.color`, `.onColor`, `.colorContainer`, `.onColorContainer` |

## Typography Principle

Use Material 3 `textTheme` styles as-is. Do not override font weight, letter spacing, or other properties with `copyWith` unless a new text style is genuinely missing from the scale. If the standard scale doesn't have the exact weight or size you want, pick the closest match and move on — a consistent type scale matters more than pixel-matching Figma.

When the entire app needs a different typographic feel, refactor the `TextTheme` at the theme level rather than sprinkling `copyWith` overrides across individual widgets. Keep individual widget styling simple.

## Decisions Log

<!-- Decisions are captured here as they emerge from widget creation sessions -->
<!-- Format: "- **Context**: Decision (date)" -->
- **Widgetbook failed to compile on web** because `AppAppBar` → `NodeStatusIcon` → `nodeStatusProvider` → Rust FFI. Adopted presentation-only rule: design system widgets take data as props, never fetch state. Containers live in `lib/features/`. (2026-02-20)
- **ChallengeCard title weight**: Figma shows 16px/medium title. Closest Material style is `titleMedium` (16px/w500). No heavier 16px variant exists without `copyWith(fontWeight: w600)`. Decided to keep `titleMedium` as-is — no hard overrides. If we need a different weight scale, we refactor the entire `TextTheme`. (2026-02-23)
- **ChallengeCard state demotion**: Replaced blanket `Opacity` with color-based demotion for completed/missed variants. `Opacity` on entire card reduces text contrast below accessible thresholds. Use `onSurfaceVariant` for muted text and `surfaceContainerLow` for tinted background instead. Never use `Opacity` to communicate semantic state on readable content. (2026-02-23)
- **ChallengeCard animation loop seam**: Removed `CurvedAnimation(Curves.easeInOut)` from the ongoing border animation. `easeInOut` has zero velocity at both endpoints, causing a visible stall when the repeating controller wraps. Linear rotation is seamless; asymmetric gradient shape provides organic character. For looping animations, prefer linear or a custom curve with matching endpoint derivatives (C1 continuity). (2026-02-23)
- **ScoreHeader score monospace**: `displaySmall.copyWith(fontFamily: 'monospace')` — Figma uses IBM Plex Mono which isn't in the project. This is a functional `copyWith` for tabular number alignment, not a decorative override. System monospace is acceptable. (2026-02-23)
- **ScoreHeader countdown bold**: `labelSmall.copyWith(fontWeight: FontWeight.w700)` for the countdown time value. Deliberate deviation from "no copyWith" principle — the time is actionable data needing visual separation from the "ENDS IN" label. Weight contrast serves information hierarchy. (2026-02-23)
- **M3 components preferred**: Shifted from primitives-only to M3-first approach. Use native Material 3 components for accessibility and consistency; build from primitives only when M3 doesn't cover the need. (2026-02-24)
- **Achromatic secondary & tertiary**: Moved secondary to neutral-variant palette and tertiary to pure neutral palette. All chromatic color now lives exclusively in `AppSemanticColors`. M3 structural roles render grey — a developer must consciously reach for a semantic extension to introduce hue. (2026-02-23)
- **Ghost tertiary**: Pushed tertiary further into near-invisibility. Standard contrast: main color barely clears APCA Lc 60, container ~ΔY 6 from surface. Medium contrast partially compensates; high contrast fully restores normal M3 levels. This makes `colorScheme.tertiary*` a trap role that forces use of `AppSemanticColors` for visible emphasis. (2026-02-23)
- **Surface shifted to T96 for grey scaffold**: Moved light `surface` from `#FCFCFC` (T99, near-white) to `#F5F5F5` (T96, visible grey) so M3's default `scaffoldBackgroundColor = surface` produces the grey page background shown in Figma. Cards and content sheets use `surfaceContainerLowest` (`#FFFFFF`) for white fills. Dark mode unchanged. (2026-02-23)

## Widget Catalog

<!-- Updated by the widget builder after each new component -->
| Widget | Source | Genesis |
|--------|--------|---------|
| `ChallengeCard` | [Figma (list)](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=2943:19310), [Figma (ongoing)](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=3012:2402) | [genesis](.specs/ChallengeCard.genesis.md) |
| `ChallengeCategoryIcon` | [Figma](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=3012:2775) | [genesis](.specs/ChallengeCategoryIcon.genesis.md) |
| `Button` | — | [genesis](.specs/ScoreHeader.genesis.md) |
| `DropdownChain` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2860) | [genesis](.specs/DropdownChain.genesis.md) |
| `DropdownChip` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2860) | [genesis](.specs/DropdownChip.genesis.md) |
| `DropdownSheet` | — | [genesis](.specs/DropdownSheet.genesis.md) |
| `ScoreHeader` | [Figma (default)](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2193), [Figma (glow)](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:3259) | [genesis](.specs/ScoreHeader.genesis.md) |
| `Tabs` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=3012:2400) | [genesis](.specs/Tabs.genesis.md) |
| `TopAppBar` | [Figma (small)](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2764), [Figma (large)](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2943:28629) | [genesis](.specs/TopAppBar.genesis.md) |
