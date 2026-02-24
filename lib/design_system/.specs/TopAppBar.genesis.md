# TopAppBar — Genesis Document

Tracks design decisions made during widget creation. Each section is appended as the widget evolves.

## Phase 1: Figma Inspection & Planning (2026-02-24)

**Figma nodes inspected:**
- `2994:2764` — Small variant: back arrow + "Leaderboard" title + trailing filter chip
- `2943:28629` — Large variant: back arrow + 64px hexagonal icon + "Produce Every Block" title + "Technical · Jan 12 - Jan 30" subtitle

### Naming decision: `TopAppBar`
Named `TopAppBar` to avoid conflict with Flutter's built-in `AppBar` class. Matches M3 naming convention ("Top app bar") and is unambiguous in import context.

### Color hex mismatch — Figma vs project
Figma uses M3 reference palette colors that differ from the project's custom palette:
- **Title**: Figma `#1D1B20` vs project `#17262A` → mapped to `colorScheme.onSurface`
- **Subtitle**: Figma `#49454F` vs project `#4A6572` → mapped to `colorScheme.onSurfaceVariant`
- **Chip border**: Figma `#CAC4D0` vs project `#E2E8F0` → mapped to `colorScheme.outlineVariant`

This is the correct approach per the "Figma = inspiration" philosophy. Semantic color roles ensure the widget adapts across all 6 theme variants (light/dark × 3 contrast levels).

### Image border radius snap
Figma specifies 10.67px border radius on the image container — an odd non-standard value likely resulting from Figma auto-layout fractional math. Snapped to `AppRadii.small` (8px), the closest design system token. The 2.67px difference is imperceptible at 64px container size.

### Trailing content as generic slot
The small variant shows a `DropdownChip` (existing design system widget) as trailing content. The large variant shows icon buttons. Rather than special-casing these, the widget exposes `actions: List<Widget>?` — a generic trailing slot. Feature screens compose specific trailing content. This follows the same pattern as M3's `AppBar.actions`.

### Hidden "TECHNICAL" label excluded
The large variant Figma node (`2943:28629`) contains a transparent text element "TECHNICAL" in the trailing area. This appears to be a Figma component instance artifact (label from a parent component set to transparent). Excluded from the widget spec — not meaningful UI.

### Sliver-based architecture
User chose collapsible large→small behavior on scroll. This dictates:
- **Widget is a Sliver** — wraps `SliverAppBar`, used inside `CustomScrollView` / `NestedScrollView`
- **Does NOT implement `PreferredSizeWidget`** — cannot be used as `Scaffold.appBar`
- **Small variant**: `SliverAppBar` with `pinned: true`, standard 56px height
- **Large variant**: `SliverAppBar` with `pinned: true`, custom `flexibleSpace` with ~232px expanded height

This means screens using `TopAppBar` must use a `CustomScrollView` (or `NestedScrollView`) as their scroll container, not a plain `Scaffold` with `appBar:`.

### Title transition on collapse
Large variant uses two title styles depending on scroll state:
- **Expanded**: `textTheme.displaySmall` (36px) — prominent, immersive
- **Collapsed**: `textTheme.titleLarge` (22px) — same as small variant

Image and subtitle fade out during collapse. The transition uses SliverAppBar's built-in flexibleSpace opacity mechanics — no custom animation controller needed.

### Surface architecture
- `backgroundColor: colorScheme.surface` — matches scaffold background for seamless integration
- `scrolledUnderElevation: 0` — flat, no M3 tonal elevation on scroll. The app uses a flat surface philosophy (grey scaffold, no elevation hierarchy).

### No sub-widgets needed
Unlike ScoreHeader (which has `_ScoreCircle`, `_ScoreArcPainter`, `_CountdownRow`), TopAppBar's layout maps directly to SliverAppBar's existing anatomy (leading, title, actions, flexibleSpace). Private sub-widgets would add abstraction without value.

### Presentation-only contract
- All state via constructor params (data + callbacks)
- No providers, no `ConsumerWidget`, no services
- No FRB-generated types in constructor params
- Feature screens (`lib/features/`) wire navigation, state, and specific trailing widgets

## Phase 2: Implementation (2026-02-24)

### Small variant — standard SliverAppBar
The small variant delegates fully to `SliverAppBar` with `pinned: true`, using its native `leading`, `title`, and `actions` slots. No custom layout needed — M3's built-in AppBar handles padding, positioning, and accessibility.

### Large variant — custom flexibleSpace with `forceMaterialTransparency`
The large variant uses `SliverAppBar` only for sliver pinning behavior. All visual content is rendered inside a custom `_LargeFlexibleContent` widget placed in `flexibleSpace`.

**Why `forceMaterialTransparency: true`**: SliverAppBar's internal `AppBar` paints an opaque `Material` widget on top of the `flexibleSpace`. Without transparency, the custom toolbar content (leading, collapsed title, actions) in the flexibleSpace would be hidden behind the AppBar's background. Making it transparent lets the flexibleSpace handle all rendering.

**Why `automaticallyImplyLeading: false`**: Since the large variant renders its own leading widget in the flexibleSpace, the SliverAppBar must not auto-generate a back button.

### Collapse animation via FlexibleSpaceBarSettings
`_LargeFlexibleContent` reads `FlexibleSpaceBarSettings` (the inherited widget that SliverAppBar provides to its flexibleSpace) to compute a collapse progress value `t`:
- `t = 0.0` → fully expanded: collapsed title invisible, expanded content visible
- `t = 1.0` → fully collapsed: collapsed title visible, expanded content removed from tree

The expanded content is conditionally rendered (`if (t < 1.0)`) to avoid zero-height layout when fully collapsed. A `ClipRect` prevents overflow during the transition.

### Dynamic expandedHeight
The `expandedHeight` is calculated from the content rather than hardcoded:
- `kToolbarHeight` (56px) + optional image (64px + 16px gap) + title (~46px) + optional subtitle (8px gap + ~24px) + bottom padding (12px)
- Text heights (46px for displaySmall, 24px for titleMedium) are approximations — no design token exists for text line height. These values are close enough for SliverAppBar's layout; minor differences result in slightly more/less whitespace at the bottom.

### One private sub-widget: `_LargeFlexibleContent`
Revised from Phase 1's "no sub-widgets needed" — the large variant's flexibleSpace requires its own build method to read `FlexibleSpaceBarSettings` and compute collapse state. Extracted as a private `StatelessWidget` for clarity. The small variant remains inline.

### Golden test approach
Since `TopAppBar` is a sliver (not a RenderBox), golden tests capture `find.byType(CustomScrollView)` rather than `find.byType(TopAppBar)`. This ensures the sliver's render output is correctly painted into the golden image.

## Token Mapping

| Figma Value | Design System Token | Notes |
|-------------|-------------------|-------|
| 4px leading padding | `AppSpacing.space4` | Exact match |
| 8px top/bottom padding | `AppSpacing.space8` | Exact match |
| 12px bottom padding | `AppSpacing.space12` | Exact match |
| 16px content padding | `AppSpacing.space16` | Exact match |
| 48px icon touch target | `AppSizing.iconContainerRegular` | Exact match |
| 40px icon visible | `AppSizing.iconContainerSmall` | Exact match |
| 24px icon | `AppSizing.iconRegular` | Exact match |
| 64px image | `AppSizing.iconContainerXLarge` | Exact match |
| 10.67px image radius | `AppRadii.small` (8px) | Snapped from 10.67 — Figma auto-layout artifact |
| #1D1B20 title | `colorScheme.onSurface` | Figma M3 reference color, mapped to semantic role |
| #49454F subtitle | `colorScheme.onSurfaceVariant` | Figma M3 reference color, mapped to semantic role |
| 22px/400 title | `textTheme.titleLarge` | Exact match |
| 36px/400 display | `textTheme.displaySmall` | Exact match |
| 16px/500 subtitle | `textTheme.titleMedium` | Exact match |

## Golden Reference

- **Golden files**: `test/design_system/goldens/top_app_bar_small.png`, `test/design_system/goldens/top_app_bar_large.png`
- Rendered with light theme, default viewport
