# RankBadge — Genesis Document

**Figma source**: [Testnet App — Leaderboard](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=3446-2393)
**Pattern reference**: ListSystem.genesis.md — Pattern B (Ranking Item)

---

## Purpose

Small slot widget for `ListTile.leading` in leaderboard ranking rows. Shows a rank number inside a bordered circle.

## Structural Analysis

```
┌──────┐
│      │
│  #1  │  40px circle, 1px outlineVariant border
│      │
└──────┘
```

## M3 Mapping

No M3 equivalent — lightweight custom widget using Container with BoxDecoration.

## Constructor

```dart
RankBadge({
  required String rank,  // "#1", "34", "999"
})
```

## Token Mapping

| Element | Token | Value |
|---------|-------|-------|
| Circle size | `AppSizing.iconContainerSmall` | 40px |
| Shape | `BoxShape.circle` | — |
| Background | `colorScheme.surfaceContainerLowest` | White |
| Border | `colorScheme.outlineVariant` | 1px |
| Text style | `textTheme.labelLarge` | 14px |
| Text weight | `FontWeight.w500` | Medium |
| Text color | `colorScheme.onSurface` | — |

## Design Decisions

### 1. Standalone exported widget

Small enough to be its own file and export, since it's reused across leaderboard list rows and potentially other ranking screens (challenge participants, etc.).

### 2. No `#` prefix enforcement

The `rank` param is a raw string — the caller decides whether to include `#` or not. This keeps the widget generic for different formatting needs.

### 3. Snapped from Figma

Figma uses `rgba(0,0,0,0.1)` for the border. Snapped to `outlineVariant` to stay within the token system, consistent with card borders elsewhere.

## File Map

| Purpose | File |
|---------|------|
| Widget | `lib/design_system/src/rank_badge.dart` |
| Test | `test/design_system/rank_badge_test.dart` |
| Widgetbook | `lib/design_system/widgetbook/rank_badge_use_case.dart` |
| Export | `lib/design_system/design_system.dart` |

## Composition

**Use when:** Displaying a numeric rank (1, 2, 3, etc.) as a circular badge in leaderboard rows.
**Parent containers:** `ListTile.leading` (primary use in leaderboard list).
**Pair with:** M3 `ListTile` in leaderboard lists, `LeaderboardStatsCard` (summary above the list).
**Anti-patterns:** Don't use for non-ranking numbers — this is semantically a rank indicator.
**Screen example:** `lib/features/leaderboard/screens/leaderboard_screen.dart`
