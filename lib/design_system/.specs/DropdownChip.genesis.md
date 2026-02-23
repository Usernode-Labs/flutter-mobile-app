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
