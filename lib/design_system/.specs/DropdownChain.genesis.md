# DropdownChain — Genesis Document

Tracks design decisions made during widget creation. Each section is appended as the widget evolves.

## Phase 1: Planning & Implementation (2026-02-23)

**Figma reference:**
- `2994:2860` — Challenges screen filter row with chained dropdown chips

### Naming decision
Named `DropdownChain` to describe the pattern: multiple `DropdownChip`s chained with chevron separators indicating hierarchical drill-down (Season > Category). The name complements `DropdownChip` — a chain is a composed sequence of chips.

### Composition pattern
Follows the ScoreHeader > Button composition model. `DropdownChain` composes `DropdownChip` widgets — it does not duplicate chip rendering logic. The `DropdownChainItem` data class mirrors `DropdownChip`'s API (label + onTap) so the chain widget simply delegates to chips.

### Layout strategy
Figma shows 8px gaps between all elements (chips and chevrons). The last chip fills remaining space (`Expanded` + `expanded: true`), all preceding chips shrink-wrap. This matches the Figma structure where "Season 2" is compact and "DApps Integration" stretches.

### Chevron separator
Uses `Icons.chevron_right` (24x24) in `onSurfaceVariant` color. The chevron communicates hierarchical narrowing — each step filters further. N items produce N-1 chevrons.

### Single-item edge case
With one item, the widget renders a single expanded `DropdownChip` with no chevrons. The `Expanded` wrapper ensures it fills the row even without siblings.

### Outer padding excluded
The 16px horizontal / 8px vertical padding visible in Figma is a screen concern, not baked into the widget. Screens apply their own padding. This follows the presentation-only principle — the widget is layout-agnostic.

### Presentation-only
No selection state, no menu logic. The screen passes labels and tap callbacks. Items are an ordered list — the widget doesn't know or care about filter semantics.

## Composition

**Use when:** Presenting a horizontal chain of related filters/selectors (e.g., season → epoch → category).
**Parent containers:** Inside PSL `pinnedHeaderSlivers` as part of a pinned bar, or inside `SliverToBoxAdapter` in scroll content.
**Pair with:** `DropdownSheet` (opens on chip tap), `DropdownChip` (individual items in the chain).
**Anti-patterns:** Don't bake horizontal padding into the chain — screen applies its own margins.
**Screen example:** `lib/features/leaderboard/screens/leaderboard_screen.dart` — filter chain for season/epoch selection
