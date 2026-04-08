# DropdownChip — Genesis Document

Tracks design decisions made during widget creation. Each section is appended as the widget evolves.

## Phase 1: Planning & Implementation (2026-02-23)

**Figma reference:**
- `2994:2860` — Filter chip row in the Challenges screen header
- `2994:2192` — Full screen context: two filter chips above ScoreHeader

### Naming decision
Named `DropdownChip` instead of `FilterChip` because Material already exports `FilterChip` from `material.dart`. Using that name would cause import conflicts in screens that import both Material and the design system. `DropdownChip` describes the visual behavior (chip with dropdown indicator) and avoids the clash.

### Hardcoded height
Height is 32px, hardcoded like ScoreHeader's 160px circle. No existing `AppSizing` token matches, and adding a one-off token would bloat the system. If more components use 32px height, we'll extract a token then.

### Asymmetric padding
Figma shows 16px left, 8px right. The asymmetry accommodates the trailing dropdown icon — extra left padding gives the label breathing room while the icon sits closer to the edge. Uses `EdgeInsets.only(left: space16, right: space8)` instead of symmetric padding.

### Typography
Uses `labelLarge` (14px, weight 500) with `onSurfaceVariant` color. The `copyWith` for color is unavoidable — text needs the secondary color role, not the default. No weight or size overrides.

### Expanded mode
The `expanded` flag controls whether the chip shrink-wraps or fills available width. In the Figma filter row, the first chip ("Season 2") shrink-wraps and the second ("DApps Integration") expands to fill remaining space. The parent screen wraps the expanded chip in `Expanded` and sets `expanded: true` so the internal `Row` uses `MainAxisSize.max` and the label text gets `Expanded` + `TextOverflow.ellipsis`.

### Border
1px solid `outlineVariant` with `AppRadii.small` (8px) border radius. Matches Figma spec exactly with no token compromises.

### Presentation-only
No selection state, no dropdown menu logic. The screen passes the current label and handles the tap to show a bottom sheet or menu. This follows the design system's presentation-only rule.

## Phase 2: Visual States (2026-02-23)

### `selected` prop
Added `selected: bool` (default `false`). When true, the chip fills with `secondaryContainer` and uses `onSecondaryContainer` for text and icon color. This matches M3 filter chip semantics (tonal fill = active filter) without using any Material Chip classes. The border remains `outlineVariant` in both states to maintain structural consistency in filter rows.

### `enabled` prop
Added `enabled: bool` (default `true`). When false, the entire chip is wrapped in `Opacity(opacity: appOpacity.disabled)` (0.30) and `onTap` is nulled out. Chose whole-chip `Opacity` over per-element color manipulation because:
1. Simpler implementation — one wrapper vs modifying every color individually
2. Consistent dimming across border, text, icon, and any future fill
3. Disabled chips are non-interactive visual hints, not readable content, so the APCA contrast concern from ChallengeCard's state demotion doesn't apply here (users don't need to read disabled filter labels at body-text contrast levels)

### Backward compatibility
Both props are optional with defaults matching the previous behavior (`selected: false`, `enabled: true`). Existing call sites require no changes.

## Phase 3: M3 Migration (2026-02-24)

### Decision
Adopted selective M3 policy. `DropdownChip` reimplemented standard chip interaction patterns — migrated to M3 `FilterChip`.

### Migration
Wrapped `FilterChip` with `showCheckmark: false`. Dropdown arrow placed inside label `Row` rather than using `deleteIcon` (which would create a separate tap target). Disabled state uses `IgnorePointer` + `Opacity` wrapping the entire `FilterChip`.

### What changed
- Gained: ripple feedback, focus management, keyboard navigation, hover states, screen reader semantics
- LOC: 103 → 78 (24% reduction)
- API preserved: `DropdownChip(label:, onTap:, selected:, enabled:, expanded:)` unchanged

### What stayed
- Widget name: still `DropdownChip`, not `FilterChip`
- Selected state: `secondaryContainer` fill via `selectedColor`
- Disabled opacity: still uses `AppOpacity.disabled` (0.30)
- Presentation-only: no providers

## Composition

**Use when:** A single filter/selector chip that opens a dropdown sheet on tap.
**Parent containers:** Inside `DropdownChain` (primary), or standalone in a toolbar row.
**Pair with:** `DropdownChain` (horizontal chain), `DropdownSheet` (selection UI on tap).
**Anti-patterns:** Don't use for actions — chips are selectors, not buttons. Use `Button` for actions.
**Screen example:** `lib/features/dapps/dapps_screen.dart` — standalone sort chip
