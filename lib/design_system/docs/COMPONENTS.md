# Component Strategy & Catalog

Self-contained reference for building and verifying design system widgets.

---

## M3-First Strategy

Prefer Material 3 components for native behaviour, accessibility, and platform consistency. M3 components bring ripple, focus, keyboard, hover, and semantics for free.

**When to use M3 components:**
- Interaction maps to a standard M3 pattern (buttons, chips, tabs, navigation, sheets)
- The widget needs focus management, keyboard navigation, or platform-standard feedback
- Accessibility semantics are available out of the box

**When to use Flutter primitives:**
- Visuals are truly custom with no M3 equivalent (e.g., ChallengeCard, ScoreHeader, ChallengeCategoryIcon, DropdownChain)
- The M3 component would require so many overrides that the benefit is lost

**Hybrid policy:** The token system, color philosophy, and presentation-only architecture are orthogonal to the component layer. M3 components receive their achromatic colors from the `ColorScheme` and their semantic colors from `AppSemanticColors` — the philosophy works with or without M3 components.

The design system names widgets in its own vocabulary and starts with the simplest variant needed. Additional styles and variants are added as Figma designs demand them — not speculatively.

---

## Presentation-Only Rule

All widgets in `lib/design_system/` follow a strict presentation-only contract: **data in, pixels out.**

### The Rule

- **Constructor params only.** Widgets receive all state via constructor parameters (data + callbacks). They never fetch state internally.
- **No providers, no services.** A design system widget must never `watch`, `read`, or `ref` a provider. No `ConsumerWidget` / `ConsumerStatefulWidget`. No async loading.
- **No FRB types in props.** All FRB-generated files transitively import native FFI via `frb_generated.dart`, which breaks web compilation (including Widgetbook). Use plain Dart models (String, int, enums, custom data classes) instead.
- **Screens as containers.** Feature screens in `lib/features/` watch providers and pass data down to design system widgets. No separate container widget class is required — the screen itself is the container.

### Why This Matters

This separation exists because the Widgetbook web build cannot include native FFI dependencies. When `NodeStatusIcon` imported a Riverpod provider that transitively imported Rust FFI, the entire Widgetbook build broke. Presentation-only widgets are inherently portable, testable, and Widgetbook-compatible.

### Widgetbook Rule

Every new design system widget gets a Widgetbook use case that imports and renders the **real widget** with mock data via knobs — never a hand-built visual replica. This ensures what you see in Widgetbook is exactly what ships.

---

## Core Constraints

Quality gate checklist for every design system widget:

| # | Constraint | How to verify |
|---|-----------|---------------|
| 1 | `dart format` clean | `dart format --set-exit-if-changed .` |
| 2 | `flutter analyze` passes | `flutter analyze` with zero issues |
| 3 | Tests pass | `flutter test` |
| 4 | No hardcoded values | All visual properties from theme tokens |
| 5 | Tokens via theme | `Theme.of(context).extension<T>()!` for spacing, radii, elevation, etc. |
| 6 | Colors via theme | `Theme.of(context).colorScheme` and `.extension<AppSemanticColors>()!` |
| 7 | Typography via theme | `Theme.of(context).textTheme` — no `copyWith` unless genuinely needed |
| 8 | Exported from barrel | Widget listed in `design_system.dart` |
| 9 | Genesis doc exists | `.specs/<WidgetName>.genesis.md` with Inspiration and Design Decisions |
| 10 | Catalog entry exists | Row in the Widget Catalog below |

---

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
6. Genesis document exists with Inspiration and Design Decisions sections
7. Widget Catalog entry exists
8. Widgetbook visual review — launches Widgetbook for human sign-off as the final gate

---

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
| `ListSystem` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=3448-15182) | [genesis](.specs/ListSystem.genesis.md) |
| `ChallengeRewardCard` | [Figma](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=2943:28627) | [genesis](.specs/ChallengeRewardCard.genesis.md) |
| `ChallengeDetailPage` | [Figma](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=2943:28627) | [genesis](.specs/ChallengeDetailPage.genesis.md) |
