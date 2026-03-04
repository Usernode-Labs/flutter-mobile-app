# List System Guidance

Reference for building any list-based UI in the design system. Read this before
creating or modifying list components. Everything here is rooted in M3 `ListTile`
and our theme. The slot vocabulary was distilled from design exploration and
codified here as the authoritative source.

---

## 1. The Composition Model

M3 `ListTile` is a three-slot container: **leading + title/subtitle + trailing**.
Our design language defines a vocabulary of what goes in each slot.

### Leading Slot

| Variant | Widget | Size |
|---------|--------|------|
| Icon container | `IconBadge` (DS) | 48 px, rounded 12 px |
| Rank circle | `RankBadge` (DS) | 40 px circle |
| Inline icon | `Icon` | 24 px |
| Thumbnail | `ClipRRect` + `Image` | Varies |
| Empty | omit `leading` | — |

### Content Slot

| Variant | ListTile params |
|---------|----------------|
| Two-line | `title` + `subtitle` |
| Single-line | `title` only |
| Title + progress | `title` + custom `subtitle` with progress bar |

### Trailing Slot

14 patterns, from simplest to most complex:

| Pattern | Flutter Implementation | DS Widget? |
|---------|-----------------------|------------|
| Empty | omit `trailing` | No |
| Value | `Text` | No |
| Chevron | `Icon(Icons.chevron_right)` | No |
| Icon | `Icon` | No |
| Action | `IconButton` | No |
| Avatar | `CircleAvatar` | No |
| Badge | `StatusBadge` | Already built |
| Value + Chevron | `Row(Text, Icon)` | **Yes** — `TextChevronTrailing` (not yet extracted) |
| Icon + Chevron | `Row(Icon, Icon)` | Extract if 2+ screens need it |
| Avatar + Chevron | `Row(CircleAvatar, Icon)` | Extract if 2+ screens need it |
| Value + List Control | `Row(Text, Checkbox)` | Extract if 2+ screens need it |
| List Control | — | Use `CheckboxListTile` / `RadioListTile` instead |
| Switch | — | Use `SwitchListTile` instead |
| Slider | `Slider` | Custom layout, extract if 2+ screens |

### Heights (M3 Defaults + Our Density)

Our `ListTileThemeData` sets `visualDensity: VisualDensity.compact`. Effective
heights:

| Condition | Approx. Height |
|-----------|---------------|
| Two-line (title + subtitle) | ~72 dp |
| Single-line + 48 px leading | ~56 dp |
| Single-line, small/no leading | ~48 dp |

### States

M3 handles all states natively: Normal, Disabled, Pressed, Selected, Focused.
**Never build custom state handling.**

### Composition Diagram

```
┌─────────────────────────────────────────────────────┐
│ ┌──────────┐ ┌───────────────────┐ ┌─────────────┐ │
│ │ leading  │ │  title            │ │  trailing   │ │
│ │          │ │  subtitle         │ │             │ │
│ │ IconBadge│ │  (from textTheme) │ │ Value  ›    │ │
│ │ RankBadge│ │                   │ │ Badge       │ │
│ │ Icon     │ │                   │ │ Switch      │ │
│ │ (none)   │ │                   │ │ (14 types)  │ │
│ └──────────┘ └───────────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## 2. Section Grouping

List tiles are grouped into sections using `Card` + `Column`.

### Section Headers

No M3 equivalent exists. Four header styles are recognized:

| Style | Description |
|-------|-------------|
| Normal | Left-aligned label above card |
| Indented | Label indented to match item leading width |
| Large | Bolder/larger label |
| Large + Sub | Large label with descriptive subtitle |

No `ListSectionHeader` widget exists yet. Build it just-in-time when the first
screen needs it, then reuse.

### Specialized List Items

These don't fit the standard `ListTile` shape:

| Item | M3 Widget |
|------|-----------|
| Master switch (section toggle) | `SwitchListTile` with section-level callback |
| Expandable sub-list | `ExpansionTile` |
| Contextual actions | Swipe via `Dismissible` or long-press menu |

---

## 3. What's Already Built

### Widget Inventory

| Need | Widget | Path | Notes |
|------|--------|------|-------|
| Icon container leading | `IconBadge` | `src/icon_badge.dart` | 48 px, `secondaryContainer` bg, 12 px radius |
| Rank circle leading | `RankBadge` | `src/rank_badge.dart` | 40 px circle, `surfaceContainerLowest` bg, `outlineVariant` border |
| Status badge trailing | `StatusBadge` | `src/status_badge.dart` | Colored pill, 5 variants (success/error/warning/info/neutral) |
| Key-value row | `InfoRow` | `src/info_row.dart` | Standalone pattern — not a ListTile slot widget |
| ListTile theming | `ListTileThemeData` | `theme/color_is_expensive_theme.dart:407` | Global defaults |

All paths relative to `lib/design_system/`.

### ListTileThemeData Defaults (lines 407-425)

```
contentPadding:  horizontal 16, vertical 4
dense:           true  ← see Known Issues
visualDensity:   compact
shape:           RoundedRectangleBorder, radius 12
titleTextStyle:  bodyMedium, onSurface
subtitleTextStyle: bodySmall, onSurfaceVariant
leadingAndTrailingTextStyle: bodyMedium, onSurface, w500
```

### Known Issues

1. **TextChevron duplication** — Value + Chevron trailing is implemented twice:
   - `_TextChevron` class in `widgetbook/list_tile_use_case.dart:270`
   - `_buildTextAndChevron()` in `src/epoch_performance_page.dart:378`
   Both produce: `Row(Text, SizedBox(4), Icon(chevron_right, 20, onSurfaceVariant))`.
   Extract to a public `TextChevronTrailing` DS widget.

2. **Double compaction** — `ListTileThemeData` sets both `dense: true` and
   `visualDensity: VisualDensity.compact`. Remove `dense`; `VisualDensity.compact`
   alone is sufficient.

3. **Ad-hoc section grouping** — Every screen manually writes
   `Card(child: Column(children: tiles))`. No shared helper.

---

## 4. Rules for Building New List Variants

### Step 1: Is it a ListTile?

If the item has leading/title/subtitle/trailing slots → use M3 `ListTile`.
**Never create `AppListTile` or any custom list item container.**

### Step 2: Does M3 have a specialized variant?

| Need | Use |
|------|-----|
| Switch/toggle | `SwitchListTile` |
| Checkbox | `CheckboxListTile` |
| Radio | `RadioListTile` |
| Expandable | `ExpansionTile` |

Use the M3 variant directly. Do not wrap it.

### Step 3: Is the slot content a reusable composition?

1. Check the inventory in **§3**.
2. If a DS widget exists → use it.
3. If not → does 2+ screens need the same composition?
   - **Yes** → extract a DS slot widget into `src/`.
   - **No** → keep it inline in the screen file.

### Step 4: Need section grouping?

`Card(child: Column(children: tiles))`. If a shared helper exists by then, use
it. If not and 2+ screens need it, build it.

### Step 5: Need a section header?

Build `ListSectionHeader` just-in-time when the first screen requires it.

### Step 6: Styling

Everything from the theme — no exceptions:
- `ListTileThemeData` for tile defaults
- `colorScheme` for colors
- `textTheme` for typography
- Token extensions (`AppSpacing`, `AppRadii`, `AppElevation`) for layout

**Never hardcode colors, font sizes, or padding in individual tiles.**

### Step 7: State

M3 handles it. Never build custom state handling for list items.

---

## 5. Cross-References

| Topic | Location | What's There |
|-------|----------|-------------|
| Genesis spec | `.specs/ListSystem.genesis.md` | Original 3 patterns + 8 design decisions |
| Anti-pattern catalog | `.archive/03_ui_components_audit.md` §E | Hardcoded colors, font sizes, layout values across screens |
| Component gaps | `.archive/05_gap_analysis_and_recommendations.md` §4D | Missing capabilities incl. StatusBadge (now built), MetricTile |
| Theme rules | `DESIGN_SYSTEM.md` | M3-first rule, no-wrapper boundary, presentation-only constraint |
| Surface model | `docs/SURFACES.md` | Two-tier surface model (grey scaffold + white content) |
| ListTile theme source | `theme/color_is_expensive_theme.dart:407-425` | Global ListTileThemeData defaults |

All paths relative to `lib/design_system/`.
