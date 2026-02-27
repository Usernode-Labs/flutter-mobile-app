# DropdownSheet — Genesis Document

Tracks design decisions made during widget creation. Each section is appended as the widget evolves.

## Phase 1: Planning & Implementation (2026-02-23)

### Purpose
A custom modal bottom sheet for selecting from a list of string options. Paired with `DropdownChip` — the chip opens the sheet, the sheet returns a selection index.

### Why custom route instead of `showModalBottomSheet`
`showModalBottomSheet` is a Material convenience wrapper around `ModalBottomSheetRoute`, which internally uses Material-specific widgets (`BottomSheet`, `_ModalBottomSheet`). To stay within the design system's "no Material widgets" constraint and maintain full control over animation, drag physics, and visual treatment, we built on `PopupRoute` from `package:flutter/widgets.dart` — a core framework class alongside `Navigator` and `Route`.

### Why `List<String>` not a data class
The simplest API that works. Options are display labels — no icons, no subtitles, no disabled states needed yet. A `SelectionOption` data class would add a file, an import, and a level of indirection for zero current benefit. If subtitles or icons are needed later, we promote to a data class then.

### Why inline option rows instead of a separate `SelectionList`
One file, one responsibility. The option row is 30 lines of code with no reuse case outside this sheet. Extracting it to a separate widget file would be premature abstraction. If another widget needs the same list pattern, we extract then.

### Drag-to-dismiss implementation
The sheet body is a `StatefulWidget` that tracks vertical drag offset via `GestureDetector.onVerticalDragUpdate`. On drag end: if dragged > 100px or velocity > 700px/s, the route pops; otherwise the offset resets to 0. `Transform.translate` moves the sheet during the drag. Only downward drags are allowed (offset clamped at 0 minimum).

The spring-back animation is currently instant (setState to 0) rather than using the route's `AnimationController`. This is adequate for the current use case and avoids complexity. A smooth spring-back can be added later if the snap feels abrupt during Widgetbook review.

### Selected indicator
A simple `Icons.check` (24px, `primary` color) on the right side of the selected row. Unselected rows use `SizedBox(width: 24)` as a spacer for alignment. Not a checkbox — checkboxes imply multi-select; a check mark indicates the current single selection.

### Max height
60% of screen height via `ConstrainedBox`. The `ListView.builder` with `shrinkWrap: true` wraps to content when smaller. Bottom safe area padding is applied to the list to avoid home indicator overlap.

### Animation
Slide-up from bottom using `SlideTransition` with `Curves.easeOutCubic` for a natural deceleration feel. Duration uses `AppAnimation.complex` (300ms). The barrier fades in with the route's default animation.

### Title row
Optional. When provided, renders `bodyLarge` bold text with a close icon (X) on the right. The close icon is wrapped in a `GestureDetector` with padding for a comfortable tap target. When no title is provided, the drag handle alone serves as the visual anchor.

## Phase 2: M3 Migration (2026-02-24)

### Decision
Adopted selective M3 policy. Hand-rolled drag physics on `PopupRoute` were fragile and lacked accessibility. Migrated to `showModalBottomSheet`.

### Migration
Replaced custom `PopupRoute` subclass with `showModalBottomSheet`. Drag-to-dismiss, barrier tap, and slide-up animation now handled by M3. Body simplified to a stateless `Column` with optional title and `ListView.builder`. Option rows use `InkWell` for ripple. Visual appearance controlled by `bottomSheetTheme` in `ColorIsExpensiveTheme` (drag handle, shape, background).

### What changed
- Gained: proper drag physics, barrier accessibility, screen reader semantics, drag handle from theme
- LOC: 279 → 131 (53% reduction — highest value migration)
- Removed: `_DropdownSheetRoute`, `_DropdownSheetBodyState` drag tracking, `Transform.translate` offset management
- API preserved: `showDropdownSheet(context:, labels:, title:, selectedIndex:)` unchanged

### What stayed
- Function signature: identical return type `Future<int?>`
- Option rows: same visual (48dp height, label + check icon)
- Title row: same layout (bold text + close button)
- Presentation-only: no providers

## Phase 3: M3 Whitespace/Density Update (2026-02-26)

### Decision
Gap analysis against M3 specs revealed the sheet was too dense: option rows 8dp too short, missing drag handle, tight title-to-list gap, and insufficient trailing padding. Rather than hand-tuning the custom `_OptionRow`, replaced it with `ListTile` which implements M3 one-line list item spec natively (56dp height, 16dp/24dp start/end padding, built-in ink splash).

### What changed
- Added `showDragHandle: true` — visual affordance + top breathing room (established pattern from `send_screen.dart`)
- Max height: 60% → 65% to compensate for taller drag handle + rows
- Title bottom padding: `space8` → `space16` for better visual separation
- `_OptionRow`: replaced hand-rolled `Container` + `Row` + `InkWell` with `ListTile` — gains correct 56dp height, 16dp/24dp asymmetric padding, and ink splash for free
- ListView bottom padding: added `space8` to prevent last item clipping

### What stayed
- API preserved: `showDropdownSheet(context:, labels:, title:, selectedIndex:)` unchanged
- Typography: `bodyLarge` for labels, `bodyLarge` bold for title
- Selected indicator: `Icons.check` (24dp, `primary` color) with `SizedBox(width: 24)` spacer
- Presentation-only: no providers
