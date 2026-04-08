# LeaderboardStatsCard — Genesis Document

**Figma source**: [Testnet App — Leaderboard](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=3446-2393)

---

## Purpose

A stats summary card combining two stat boxes (total points + rank) and a distribution bar chart, used at the top of the leaderboard page.

## Structural Analysis

```
┌──────────────────────────────────────────────┐
│  ┌──────────────────┐  ┌──────────────────┐  │
│  │  TOTAL POINTS    │  │  RANK            │  │
│  │     18,000       │  │     34           │  │
│  └──────────────────┘  └──────────────────┘  │
│                                              │
│  ┌ Better than 45% of participants. ┐  green │
│  ▓▓▓▓▓▓████░░░░░░░░░░░░░░░░░░░░░░░░░        │
│  earned YOU  unconquered (grey)              │
└──────────────────────────────────────────────┘
```

Three-zone "Earned Territory" coloring: bars before user = soft green (earned),
user bar = solid green with BoxShadow, bars after user = grey (unconquered).
Bars animate in with a staggered left-to-right fill on first mount.

## Constructor

```dart
LeaderboardStatsCard({
  required String totalPoints,        // "18,000"
  required String totalPointsLabel,   // "TOTAL POINTS"
  required String rank,               // "34"
  required String rankLabel,          // "RANK"
  required List<double> distribution, // normalized 0..1
  required int userBarIndex,          // highlighted bar
  String? tooltipText,                // "Better than 45%..."
})
```

## Internal Decomposition

| Sub-widget | Purpose |
|------------|---------|
| `_StatBox` | Bordered container with uppercase label + monospace value |
| `_DistributionChart` | Column with tooltip + Row of Expanded > FractionallySizedBox bars |

## Token Mapping

| Element | Token | Value |
|---------|-------|-------|
| Card background | `surfaceContainerLowest` | White |
| Card radius | `AppRadii.largeIncreased` | 20px |
| Card padding | `AppSpacing.space16` | 16px |
| Stat box radius | `AppRadii.large` | 16px |
| Stat box border | `outlineVariant` | — |
| Stat box padding | `AppSpacing.space24` | 24px (snapped from Figma 21px) |
| Stat gap | `AppSpacing.space8` | 8px |
| Stat label | `labelMedium` + `onSurfaceVariant` | 12px, muted |
| Stat value | `headlineSmall` + `IBMPlexMono` | 24px monospace, subordinate to ScoreHeader |
| Stat value color | `onSurface` | Near-black |
| Bar spacing | `AppSpacing.space4` | 4px |
| Earned bars | `semantic.community.colorContainer` | Soft green (#B6F0BE light) |
| User bar | `semantic.community.color` | Solid green (#146D32 light) |
| User bar shadow | `semantic.community.color` @ 35% alpha | BoxShadow, blurRadius 6 |
| Unconquered bars | `outlineVariant` | Neutral grey |
| Tooltip bg | `semantic.community.color` | Green (matches user bar) |
| Tooltip text | `labelSmall` + `semantic.community.onColor` | White on green |
| Tooltip radius | `AppRadii.small` | 8px |
| Animation duration | 800ms | Stagger across all bars |
| Animation curve | `Curves.easeOutCubic` | Natural deceleration per bar |

## Design Decisions

### 1. Monospace font for stat values

Uses `headlineSmall.copyWith(fontFamily: 'IBMPlexMono')`. Smaller than ScoreHeader's `displaySmall` to fit within half-width stat boxes on 360px screens. "9,999" at 24px mono ≈ 75px — fits comfortably in the ~96px available text space.

### 2. Stat box border uses `outlineVariant`

Figma uses `rgba(0,0,0,0.1)`. Snapped to `outlineVariant` to stay in the token system, consistent with card and badge borders.

### 3. Stat box padding snapped to `space24`

Figma shows 21px internal padding. Nearest token is `space24` (24px). 3px delta is imperceptible and keeps the spacing grid authoritative.

### 4. Widget-based bar chart

Bars are built with `Row` of `Expanded` > `FractionallySizedBox` > `Container`. This leverages Flutter's layout system for proper semantics, text scaling, and accessibility — no manual geometry or CustomPainter needed.

### 5. Three-zone "Earned Territory" coloring with community green

Bars before the user = `semantic.community.colorContainer` (soft green = earned territory). User bar = `semantic.community.color` (solid green). Bars after user = `outlineVariant` (grey = unconquered). Community green was chosen over `colorScheme.primary` (#18191B near-black) because primary at any reduced opacity on white is indistinguishable from `outlineVariant` — the territory narrative requires chromatic contrast. Community green provides instant visual distinction, a natural "growth/earned" metaphor, and page coherence with the leaderboard nav's green indicator.

### 6. Centered tooltip with community color

Tooltip bg uses `semantic.community.color` with `semantic.community.onColor` text (white on green). Creates visual unity between the tooltip summary and the user's bar below.

### 7. Minimum bar height

Bars with near-zero value still render at a minimum fraction (4px / 120px chart height) so the chart grid is always visible.

### 8. No x-axis labels

X-axis labels were removed — they added visual noise on mobile and coupled callers to the chart's internal bar geometry.

### 9. BoxShadow on user bar (not glow)

Additive blending (`BlendMode.plus`) requires dark backgrounds to be visible — it can't brighten white. On a `surfaceContainerLowest` (white) card, a `BoxShadow` in `community.color` at 35% alpha adds physical depth with zero architectural cost.

### 10. Staggered fill animation on first appearance

Bars rise sequentially left-to-right when the chart first mounts, making the competitive landscape "build in." Single `AnimationController` (800ms), stagger formula baked into progress math, `Curves.easeOutCubic`. `reduceMotion` check (`MediaQuery.disableAnimations`): skips animation, shows static bars.

## Considered and Rejected

| Idea | Why not |
|------|---------|
| Blob marker above user bar | ±8-15% radial wobble at 20px produces only ±1.6px deviation — indistinguishable from a circle at bar-chart scale |
| Additive glow on user bar | Requires dark background; invisible on white card |
| Percentile arc | Collides with ScoreHeader motif on same page |
| Technical blue (`semantic.technical.color`) | Semantically defensible but breaks the rule that category colors are for challenges, not ranking data |
| Replacing histogram with Split Stat | Loses distribution shape context (clustered vs spread); strong future evolution candidate |

## File Map

| Purpose | File |
|---------|------|
| Widget | `lib/design_system/src/leaderboard_stats_card.dart` |
| Test | `test/design_system/leaderboard_stats_card_test.dart` |
| Widgetbook | `lib/design_system/widgetbook/leaderboard_stats_card_use_case.dart` |
| Export | `lib/design_system/design_system.dart` |

## Composition

**Use when:** Showing leaderboard statistics (rank, score, percentile) as a prominent card with histogram.
**Parent containers:** Inside PSL `surfaceSlivers` or `CustomScrollView` as a standalone card.
**Pair with:** `RankBadge` (displays rank within list rows below), `DropdownChain` for season/epoch filtering.
**Anti-patterns:** Don't use in a list of cards — this is a singleton stats card per screen.
**Screen example:** `lib/features/leaderboard/screens/leaderboard_screen.dart`
