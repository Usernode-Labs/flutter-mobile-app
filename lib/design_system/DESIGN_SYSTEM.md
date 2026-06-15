---
version: alpha
name: Usernode Mobile Design System
description: "Generated from Dart token classes; do not edit this frontmatter by hand."
generated_by: test/design_system/design_system_md_tokens_test.dart
source_of_truth: lib/design_system/tokens
colors:
  materialLight:
    primary: "#252627"
    onPrimary: "#FFFFFF"
    primaryContainer: "#E2E2E4"
    onPrimaryContainer: "#1B1B1C"
    secondary: "#5C5E64"
    onSecondary: "#FFFFFF"
    tertiary: "#757575"
    onTertiary: "#FFFFFF"
    error: "#BD0F19"
    surface: "#EBEBEB"
    onSurface: "#1B1B1B"
    surfaceContainerLowest: "#FFFFFF"
    surfaceContainerLow: "#F3F3F3"
    surfaceContainer: "#EEEEEE"
    surfaceContainerHigh: "#E8E8E8"
    outline: "#74777E"
    outlineVariant: "#C4C6CC"
  materialDark:
    primary: "#D4D4D6"
    onPrimary: "#252627"
    primaryContainer: "#3A3B3D"
    onPrimaryContainer: "#E2E2E4"
    secondary: "#C8CAD0"
    onSecondary: "#2E3035"
    tertiary: "#B8B8B8"
    onTertiary: "#303030"
    error: "#FFA28C"
    surface: "#212121"
    onSurface: "#EBEBEB"
    surfaceContainerLowest: "#111111"
    surfaceContainerLow: "#262626"
    surfaceContainer: "#262626"
    surfaceContainerHigh: "#303030"
    outline: "#8E9198"
    outlineVariant: "#5B5E65"
  semanticLight:
    technical:
      color: "#0055D9"
      onColor: "#FFFFFF"
      colorContainer: "#D3D9FF"
      onColorContainer: "#0040BD"
      colorSurface: "#E1E8F3"
      onColorSurface: "#0055D9"
    flash:
      color: "#875300"
      onColor: "#FFFFFF"
      colorContainer: "#FFD87B"
      onColorContainer: "#774500"
      colorSurface: "#ECE8E1"
      onColorSurface: "#875300"
    community:
      color: "#146D32"
      onColor: "#FFFFFF"
      colorContainer: "#B6F0BE"
      onColorContainer: "#05652B"
      colorSurface: "#E3EAE5"
      onColorSurface: "#146D32"
    success:
      color: "#2E7D32"
      onColor: "#FFFFFF"
      colorContainer: "#BAF1B4"
      onColorContainer: "#12681E"
      colorSurface: "#E3EAE4"
      onColorSurface: "#2E7D32"
    warning:
      color: "#9C5700"
      onColor: "#FFFFFF"
      colorContainer: "#FFDDB3"
      onColorContainer: "#874900"
      colorSurface: "#EEE8E1"
      onColorSurface: "#9C5700"
  semanticDark:
    technical:
      color: "#AEBCFF"
      onColor: "#002A8F"
      colorContainer: "#003EBA"
      onColorContainer: "#CBD1FF"
      colorSurface: "#27282D"
      onColorSurface: "#AEBCFF"
    flash:
      color: "#FBBB4B"
      onColor: "#502700"
      colorContainer: "#6C3C00"
      onColorContainer: "#FFCA69"
      colorSurface: "#2D281F"
      onColorSurface: "#FBBB4B"
    community:
      color: "#92D69C"
      onColor: "#003B0D"
      colorContainer: "#00541D"
      onColorContainer: "#A2E0AB"
      colorSurface: "#252A25"
      onColorSurface: "#92D69C"
    success:
      color: "#95D690"
      onColor: "#003B00"
      colorContainer: "#00540C"
      onColorContainer: "#A5E0A0"
      colorSurface: "#252A24"
      onColorSurface: "#95D690"
    warning:
      color: "#FFB95D"
      onColor: "#5C2E00"
      colorContainer: "#7A4100"
      onColorContainer: "#FFD5A0"
      colorSurface: "#2D2820"
      onColorSurface: "#FFB95D"
typography:
  mono:
    fontFamily: IBMPlexMono
    usage: "tabular data and display hero text"
spacing:
  space4: 4px
  space8: 8px
  space12: 12px
  space16: 16px
  space24: 24px
  space32: 32px
  space48: 48px
rounded:
  xSmall: 4px
  small: 8px
  medium: 12px
  large: 16px
  largeIncreased: 20px
  xLarge: 24px
  xxLarge: 28px
  full: 999px
sizing:
  iconContainerSmall: 40px
  iconContainerRegular: 48px
  iconContainerLarge: 56px
  iconContainerXLarge: 64px
  iconXSmall: 16px
  iconSmall: 20px
  iconRegular: 24px
  iconLarge: 28px
  iconXLarge: 32px
  iconDisplay: 48px
  iconDisplayLarge: 64px
  buttonHeightSmall: 40px
  buttonHeightRegular: 48px
  buttonHeightLarge: 56px
elevation:
  none: 0.0
  low: 1.0
  medium: 2.0
  high: 4.0
  max: 8.0
opacity:
  subtle: 0.08
  medium: 0.12
  strong: 0.2
  disabled: 0.38
  secondary: 0.4
borders:
  width: 1px
  opacity: 0.08
animation:
  fast: 100ms
  normal: 150ms
  slow: 200ms
  complex: 300ms
---
# Design System

## Overview

Usernode's design system is a mobile-first Flutter system for a phone-operated Layer 1 blockchain app. It should feel trustworthy, quiet, technical, and fast to scan. The interface is built for one-handed consumer crypto use, where transactions, identity, permissions, and recovery flows carry high trust friction.

- **Code + tokens = truth.** Dart token classes and widget implementations are authoritative.
- **Design input = inspiration.** Figma, screenshots, sketches, and text briefs help match existing patterns; they do not override DS code.
- **Material 3 first.** Use M3 containers and controls directly. Build DS slot widgets and genuine custom gaps only after proving M3 does not cover the need.
- **Every new pattern needs approval.** New visual or interaction patterns require M3/existing-DS gap proof and explicit human approval.
- **Presentation-only DS.** DS widgets receive data and callbacks. Providers, services, async orchestration, and FRB-generated types stay in feature layers.

## Colors

The system is "Color is Expensive": structural UI is achromatic and chromatic color is reserved for semantic meaning.

- Use `Theme.of(context).colorScheme` for M3 structural roles such as surfaces, outlines, text, and error.
- Primary, secondary, tertiary, and containers are deliberately achromatic. Do not assume they carry brand hue.
- Use `Theme.of(context).extension<AppSemanticColors>()!` for chromatic meaning: technical, flash, community, success, and warning.
- Do not use raw `Color(0x...)` or `Colors.*` in widgets except documented transparent/decorative exceptions.

## Typography

Use `Theme.of(context).textTheme` as the source of truth for M3 type styles.

- Do not call `copyWith` on text styles unless the exception is documented in `docs/CONSTRAINTS.md`.
- IBM Plex Mono (`kMonoFontFamily`) is reserved for tabular data and display hero text; see `docs/TYPOGRAPHY.md`.
- Labels and dense metadata should favor scannability over decorative hierarchy.

## Layout

The layout system uses a two-tier surface model: grey scaffold plus white content surfaces. See `docs/SURFACES.md` and `docs/LAYOUT.md`.

- Use spacing tokens from `AppSpacing`; no literal `EdgeInsets` values.
- Use `space16` for normal screen-edge margins and `space24` for PSL surface body insets unless a documented pattern says otherwise.
- Use `SliverPadding` for margins in `CustomScrollView`.
- Use `Column`/`Row` `spacing:` where possible instead of interleaved `SizedBox` gaps.
- Screens follow `docs/SCREEN_PATTERNS.md` for scroll containers, state handling, SafeArea ownership, and templates.

## Elevation & Depth

Depth is expressed with surfaces, borders, and contrast rather than shadows.

- `AppElevation` exists for compatibility and rare cases, but DS surfaces should default to border-based separation.
- `CardThemeData` zeroes Flutter's hidden default card margin; parent layout owns external spacing.
- Borders use `AppBorders` and theme outline roles.

## Shapes

Shape values come from `AppRadii`.

- Use radius getters from `AppRadii`; do not hardcode `BorderRadius.circular(...)`.
- `large` and `largeIncreased` cover most cards/sheets.
- `full` is reserved for pill/circular treatments.
- Decorative painter exceptions must stay local and documented.

## Components

### File Map

| Path | Contents |
|------|----------|
| `tokens/` | Spacing, radii, elevation, opacity, sizing, animation, borders, semantic colors |
| `theme/` | ColorScheme construction and ThemeExtension wiring |
| `src/` | Public DS widgets and supporting primitives |
| `widgetbook/lib/stories/` | Real-widget stories with mock data |
| `.specs/` | Build instructions, specs, and genesis docs |
| `docs/CONSTRAINTS.md` | Rules, lint table, quality gates |
| `docs/LAYOUT.md` | Screen anatomy, spacing roles, scroll patterns |
| `docs/SCREEN_PATTERNS.md` | Screen templates and review checklist |
| `docs/DECISIONS.md` | Design decisions organized by topic |

### Widget Catalog

| Widget | Source | Genesis |
|--------|--------|---------|
| `BlockProductionStatusCard` | Code | [genesis](.specs/BlockProductionStatusCard.genesis.md) |
| `BottomNav` | Code | [genesis](.specs/BottomNav.genesis.md) |
| `BurstPulseIllustration` | Code | [genesis](.specs/BurstPulseIllustration.genesis.md) |
| `Button` | Code | [genesis](.specs/Button.genesis.md) |
| `ChallengeActivitySummary` | Code | [genesis](.specs/ChallengeActivitySummary.genesis.md) |
| `ChallengeCard` | [Figma list](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=2943:19310), [Figma ongoing](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=3012:2402) | [genesis](.specs/ChallengeCard.genesis.md) |
| `ChallengeCategoryIcon` | [Figma](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=3012:2775) | [genesis](.specs/ChallengeCategoryIcon.genesis.md) |
| `ChallengeCategoryTile` | Code | [genesis](.specs/ChallengeCategoryTile.genesis.md) |
| `ChallengeDetailPage` | [Figma](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=2943:28627) | [genesis](.specs/ChallengeDetailPage.genesis.md) |
| `ChallengeEventGroup` | Code | [genesis](.specs/ChallengeEventGroup.genesis.md) |
| `ChallengeRewardCard` | [Figma](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=2943:28627) | [genesis](.specs/ChallengeRewardCard.genesis.md) |
| `DappAvatar` | Code | [genesis](.specs/DappAvatar.genesis.md) |
| `DappCard` | Code | [genesis](.specs/DappCard.genesis.md) |
| `DropdownChain` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2860) | [genesis](.specs/DropdownChain.genesis.md) |
| `DropdownChip` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2860) | [genesis](.specs/DropdownChip.genesis.md) |
| `DropdownSheet` | Code | [genesis](.specs/DropdownSheet.genesis.md) |
| `DSTextField` | Code | [genesis](.specs/DSTextField.genesis.md) |
| `EmptyState` | Code | [genesis](.specs/EmptyState.genesis.md) |
| `EpochPerformancePage` | Code | [genesis](.specs/EpochPerformancePage.genesis.md) |
| `FullPageErrorState` | Code | [genesis](.specs/FullPageErrorState.genesis.md) |
| `FullPageLoadingState` | Code | [genesis](.specs/FullPageLoadingState.genesis.md) |
| `IconBadge` | Code | [genesis](.specs/IconBadge.genesis.md) |
| `InfoRow` | Code | [genesis](.specs/InfoRow.genesis.md) |
| `LeaderboardStatsCard` | Code | [genesis](.specs/LeaderboardStatsCard.genesis.md) |
| `ListSectionHeader` | Code | [genesis](.specs/ListSectionHeader.genesis.md) |
| `ParallaxSurfaceLayout` | Code | [genesis](.specs/ParallaxSurfaceLayout.genesis.md) |
| `RankBadge` | Code | [genesis](.specs/RankBadge.genesis.md) |
| `ResultPage` | Code | [genesis](.specs/ResultPage.genesis.md) |
| `ScoreHeader` | [Figma default](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2193), [Figma glow](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:3259) | [genesis](.specs/ScoreHeader.genesis.md) |
| `SheetLayout` | Code | [genesis](.specs/SheetLayout.genesis.md) |
| `ShimmerBlock` | Code | [genesis](.specs/ShimmerBlock.genesis.md) |
| `ShimmerCardSkeleton` | Code | [genesis](.specs/ShimmerCardSkeleton.genesis.md) |
| `ShimmerListTile` | Code | [genesis](.specs/ShimmerListTile.genesis.md) |
| `SlotAssignmentsPage` | Code | [genesis](.specs/SlotAssignmentsPage.genesis.md) |
| `StatusBadge` | Code | [genesis](.specs/StatusBadge.genesis.md) |
| `StatusTextTrailing` | Code | [genesis](.specs/StatusTextTrailing.genesis.md) |
| `Tabs` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=3012:2400) | [genesis](.specs/Tabs.genesis.md) |
| `TextChevronTrailing` | Code | [genesis](.specs/TextChevronTrailing.genesis.md) |
| `TopAppBar` | [Figma small](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2764), [Figma large](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2943:28629) | [genesis](.specs/TopAppBar.genesis.md) |
| `ZkIdentityFlowPage` | Code | [genesis](.specs/ZkIdentityFlowPage.genesis.md) |
| `ZkIdentityStatusCard` | Code | [genesis](.specs/ZkIdentityStatusCard.genesis.md) |
| `ZkIdentityStepIllustration` | Code | [genesis](.specs/ZkIdentityStepIllustration.genesis.md) |

### Helper Exemptions

`nav_indicator_shapes.dart` exports support primitives for navigation indicator shape painting. It is intentionally excluded from widget genesis/catalog enforcement because it is not a standalone DS component.

## Do's and Don'ts

Do:

- Run `bash tool/agent-setup.sh` in fresh clones.
- Use `usernode-ds-design-intake`, `usernode-ds-build-widget`, `usernode-ds-build-screen`, and `usernode-ds-audit` for DS work.
- Record `pattern_decision` for design work before writing code.
- Verify widgets with `bash tool/verify-widget.sh <WidgetName>`.
- Audit screens with `bash tool/screen-audit.sh <path>`.
- Keep strings localized in feature screens.

Don't:

- Do not commit `.claude/`, `.codex/`, personal commands, local settings, device IDs, or secrets.
- Do not build custom M3 wrappers without gap proof.
- Do not add providers, repositories, services, or FRB-generated types to DS widgets.
- Do not hand-edit generated YAML frontmatter. Regenerate it with:

  ```bash
  UPDATE_DESIGN_SYSTEM_MD=true flutter test test/design_system/design_system_md_tokens_test.dart
  ```
