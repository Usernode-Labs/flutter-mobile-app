# ListSystem — Genesis Document

**Figma source**: [Testnet App — List variants](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=3448-15182)
---

## Inspiration

The Figma aggregates three list item patterns used across the app: stats summary rows, leaderboard rankings, and simple two-line detail rows. All three are structurally M3 ListTile with different slot configurations — no custom layout widget is needed.

---

## Structural Analysis: 3 Patterns

### Pattern A — Stats Summary Item

```
┌─────────────────────────────────────────────────────┐
│  ┌──────┐                                           │
│  │ icon │  Title text          Value   >            │
│  │ 48px │  Subtitle text                            │
│  └──────┘                                           │
└─────────────────────────────────────────────────────┘
```

**M3 ListTile mapping:**
- `leading` → 48px rounded container (AppRadii.medium), colored background + 24px icon
- `title` → Primary label (bodyMedium, onSurface)
- `subtitle` → Supporting text (bodySmall, onSurfaceVariant)
- `trailing` → Row: value text (bodyMedium, w500, primary) + chevron icon
- `onTap` → navigates to detail

### Pattern B — Ranking Item

```
┌─────────────────────────────────────────────────────┐
│  ┌────┐                                             │
│  │ #1 │  Username              10,000 pts           │
│  └────┘                                             │
└─────────────────────────────────────────────────────┘
```

**M3 ListTile mapping:**
- `leading` → 40px circle (AppRadii.full), outline border, centered rank number
- `title` → Username (labelLarge, onSurface)
- `subtitle` → null (single-line)
- `trailing` → Points text (labelLarge, w500)
- `onTap` → optional, navigates to participant profile

### Pattern C — Simple 2-Line Item

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  Headline text              Trailing text   >       │
│  Supporting text                                    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**M3 ListTile mapping (direct M3 component in Figma):**
- `leading` → null
- `title` → Headline (bodyMedium, onSurface)
- `subtitle` → Supporting text (bodySmall, onSurfaceVariant)
- `trailing` → Row: status text (bodyMedium, w500) + chevron icon
- `onTap` → navigates to detail

---

## Design Decisions

### 1. M3 ListTile for all 3 patterns — no custom layout widget

ListTile's leading/title/subtitle/trailing slots accommodate all three variants. Building a custom layout widget would duplicate M3 behavior for zero gain. Screens use plain `ListTile` with themed defaults; only the slot contents vary.

### 2. Snap icon container to 48px (AppSizing.iconContainerRegular)

Figma shows 50px for the Pattern A leading container. Snapped to the nearest design system token (48px) for grid alignment. 2px delta is imperceptible and keeps the token system authoritative.

### 3. Figma colors are placeholder — structure is authoritative

The Figma uses default M3 palette (#8c4a60 mauve tones), not our app theme. We map structure to our colorScheme roles: `onSurface` for titles, `onSurfaceVariant` for subtitles, `primary` for emphasized trailing values.

### 4. Ranking item as single-line ListTile

Rank badge as `leading`, username as `title`, points as `trailing`. No subtitle needed — clean single-line fit. The rank badge circle uses outline border (outlineVariant) consistent with our card border convention.

### 5. Chevron as optional affordance

Interactive tiles may or may not show a chevron. `onTap` drives interactivity; the chevron is visual emphasis for navigation-forward actions. Future `TextChevronTrailing` slot widget will take `showChevron: true/false`.

### 6. Just-in-time composable slot widgets

Slot widgets are identified but built only when screens need them:

| Slot Widget | Pattern | Build when? |
|-------------|---------|-------------|
| `IconTileLeading` | A | Stats summary screen |
| `RankBadge` | B | Leaderboard UI |
| `TextChevronTrailing` | A, C | First screen needing value + chevron trailing |

### 7. ListTileTheme eliminates repeated boilerplate

Added `listTileTheme` to `ColorIsExpensiveTheme.theme()` with:
- `contentPadding: 16h / 4v` (AppSpacing.space16, AppSpacing.space4)
- `dense: true`, `visualDensity: compact`
- `shape: RoundedRectangleBorder(borderRadius: 12)` (AppRadii.medium)
- Text styles: bodyMedium/onSurface for title, bodySmall/onSurfaceVariant for subtitle, bodyMedium/w500 for trailing

This eliminates the boilerplate currently repeated across 8+ screens. Category 3 per Surface Architecture: ListTile inherits parent surface — no background override.

### 8. Section header — noted, out of scope

The Figma shows a "Building Blocks / Section header" component above the list items. Addressed separately when needed.

---

## Token Mapping

| Element | Token | Value |
|---------|-------|-------|
| Horizontal padding | AppSpacing.space16 | 16 |
| Vertical padding | AppSpacing.space4 | 4 |
| Tile shape radius | AppRadii.medium | 12 |
| Title style | textTheme.bodyMedium | — |
| Title color | colorScheme.onSurface | — |
| Subtitle style | textTheme.bodySmall | — |
| Subtitle color | colorScheme.onSurfaceVariant | — |
| Trailing text style | textTheme.bodyMedium + w500 | — |
| Trailing text color | colorScheme.onSurface | — |
| Pattern A leading size | AppSizing.iconContainerRegular | 48 |
| Pattern B leading size | AppSizing.iconContainerSmall | 40 |
