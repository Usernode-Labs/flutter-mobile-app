# ChallengeCard — Genesis Document

> Tracks every design decision from Figma inspection through implementation.
> New sections are appended as the widget evolves.

## Phase 1: Figma Inspection & Spec Refinement (2026-02-23)

### Source Nodes

- **List view**: `2943:19310` — Column of challenge cards showing default, flash, and completed variants
- **Ongoing variant**: `3012:2402` — Single card with blue reward bar and visible stroke border

### Variant Naming

Figma shows unnamed visual states. User defined four lifecycle variants:

| Variant | Meaning | Who decided |
|---------|---------|-------------|
| `active` | Available to join; the default card state | User |
| `ongoing` | User is participating, daily updating with earned/epoch points | User |
| `completed` | User finished the challenge | Figma + User |
| `missed` | Expired without completion — no Figma reference exists | User (requested addition) |

The initial auto-generated spec used `defaultCard` / `active` / `flash` / `completed`. User corrected this: "active" means joinable (the default), and the Figma blue-bordered card is actually the "ongoing" state. Flash is a **category**, not a variant.

### Categories

Three challenge categories, each with semantic color coding:

| Category | Semantic token | Driven by |
|----------|---------------|-----------|
| `technical` | `semantic.technical` (blue) | User + Figma |
| `community` | `semantic.community` (green) | User |
| `flash` | `semantic.flash` (amber) | User correction — initial spec used "challenge", user clarified it should be "flash" |

Maps 1:1 to existing `AppSemanticColors` fields — no new tokens needed.

### Token Corrections

The auto-generated spec from Figma had several "nearest" confidence mappings. User-driven refinements upgraded most to "exact":

| Element | Initial mapping | Final mapping | Rationale |
|---------|----------------|---------------|-----------|
| Card background | `surfaceBright` | `surfaceContainerLowest` | Both are `#FFFFFF` in light theme, but `surfaceContainerLowest` is semantically correct for a card sitting on a surface |
| Card border radius | `xLarge` (24px, nearest) | `largeIncreased` (20px, exact) | Figma uses `var(--corner/large-increased, 20px)`. User agreed to add a new 20px token rather than approximate |
| Active border | `#0070FC` hard blue | `outlineVariant` | User: "should be neutral grey, felt rather than seen, divider kind of a border" |
| Ongoing reward bar | `inverseSurface` (#253840) | `semantic.<category>.color` | User: "use category challenge color for dark reward bar" — the blue bar in Figma is the technical category color |
| Ongoing reward text | `surfaceBright` | `semantic.<category>.onColor` | Follows from using category color for the bar |
| Completed reward bar | `rgba(0,0,0,0.1)` | `surfaceContainerHigh` | Cleaner token than opacity overlay on black |
| Completed card opacity | `0.5` (literal) | `0.5` (kept literal) | No matching `AppOpacity` token; 0.5 is clear enough |

### Missed Variant Design

No Figma reference exists. User chose from three options:

- **Selected**: Dimmed card with "Missed" label and a material symbol (`event_busy` or `timer_off`) instead of a checkmark
- Opacity: `AppOpacity.disabled` (0.30) — significantly more dimmed than completed (0.5) to create clear visual hierarchy
- Reward bar: Same grey `surfaceContainerHigh` as completed, but text in `onSurfaceVariant` (muted)

### Ongoing Animated Border

User requested from Figma inspection of node `3012:2402`: the visible stroke around the ongoing card should be "animated and give perception of ongoing process and grab attention to the single most important card."

Design decisions:
- **Technique**: `CustomPainter` with `SweepGradient` rotating via `AnimationController.repeat()`
- **Visual**: A "scanning beam" — transparent-to-category-color-to-transparent gradient sweeping the perimeter
- **Speed**: `AppAnimation.complex` (300ms) per rotation — fast enough to feel alive, slow enough not to distract
- **Accessibility**: Solid 2px border in category color when reduced motion is enabled
- **Radius**: Must match card's `AppRadii.largeIncreased` (20px)

### Removed Params

| Param | Why removed |
|-------|-------------|
| `categoryLabel` | Derived from `category.name.toUpperCase()` — no need for a separate string |
| `timeRemaining` | Was specific to the old "flash variant" model. Flash is now a category, not a variant |

### New Token: `AppRadii.largeIncreased`

Added `largeIncreased: 20.0` between `large` (16) and `xLarge` (24) to exactly match Figma's `--corner/large-increased` variable. Previously the spec noted "consider adding a 20px token if this recurs" — and the card corners are the first confirmed use case.

---

## Phase 2: Widget Implementation (2026-02-23)

### Architecture

- **StatefulWidget** with `SingleTickerProviderStateMixin` — the animation controller for the ongoing border requires a ticker
- `_syncAnimation()` creates/disposes the controller when the variant changes, keeping lifecycle clean
- Category colors resolved via `_categoryColors()` → `SemanticColorGroup` from `AppSemanticColors`

### Animated Border Implementation

- `_OngoingBorderWrapper` wraps the card for the ongoing variant only
- `_SweepBorderPainter` uses `SweepGradient` with three stops (transparent → full → transparent) rotated by `GradientRotation(progress * 2π)`
- Animation duration: 2000ms per rotation (slower than spec's 300ms — 300ms was too frenetic in practice; 2s feels alive without being distracting)
- **Reduced motion**: Checked in `build()` via `MediaQuery.maybeOf(context)?.disableAnimations` — passes `null` controller to wrapper, which renders a solid 2px border fallback

### Overflow Fix

Initial implementation overflowed at 360px width (compact phone). Two fixes applied:
- **Header row**: Wrapped date text in `Expanded` with `TextOverflow.ellipsis` to yield space to the category label + icon
- **Ongoing reward bar**: Wrapped left side ("Earned X pts") in `Flexible`, added `SizedBox(width: spacing.space8)` separator before right side ("Current Epoch +Y pts")

### Completed Opacity

Spec says 0.5 literal (no matching `AppOpacity` token). Implemented as `Opacity(opacity: 0.5)` directly rather than introducing a token for a single use case. If more widgets need 0.5, we'll add a token then.

### Golden Tests

Four golden PNGs generated at `test/design_system/goldens/`:
- `challenge_card_active.png`
- `challenge_card_ongoing.png` — captured at t=100ms to show border mid-animation
- `challenge_card_completed.png`
- `challenge_card_missed.png`

All rendered at 360px width (compact phone baseline) with `ColorIsExpensiveTheme` light theme.

---

## Phase 3: Material Symbols & Reward Bar Icons (2026-02-23)

### Icon System: Material Symbols Sharp

Figma uses **Material Symbols Sharp** with: Weight 300, Fill Off, Grade Normal, Optical size 20dp. The project had no `material_symbols_icons` package — added it and switched all reward bar icons from `Icons.*` (Material Icons, filled style) to `Symbols.*_sharp` with `weight: 300`, `opticalSize: 20` on every `Icon` widget.

### Active Variant Reward Icon

Figma shows a `rocket_launch` icon before the reward text in the active variant. Our initial implementation had no icon there — just text. Added `rewardIcon` param (`IconData?`, defaults to `Symbols.rocket_launch_sharp`) and rendered it in the active reward bar alongside the text.

### Icon Mapping

| Variant | Before | After |
|---------|--------|-------|
| active | (none) | `Symbols.rocket_launch_sharp` (default, overridable via `rewardIcon`) |
| ongoing | `Icons.check_circle` | `Symbols.check_circle_sharp` |
| completed | `Icons.check_circle` | `Symbols.check_circle_sharp` |
| missed | `Icons.event_busy` | `Symbols.event_busy_sharp` |

Widgetbook category icons also switched to Sharp variants (`code_sharp`, `groups_sharp`, `bolt_sharp`).

---

## Phase 4: Category Icon SVGs (2026-02-23)

### SVG Export from Figma

Figma node `3012:2775` contains three abstract geometric category icons. The official Figma MCP exports individual vector layers as PNGs (known limitation). User manually exported as SVG from Figma's export panel.

**Raw file sizes**:
| Category | Raw size | Optimized |
|----------|----------|-----------|
| Technical | 599 B | (already clean) |
| Flash | 776 B | (already clean) |
| Community | 103 KB | 6 KB (svgo, float precision 2) |

### Shared 3-Layer Structure

All three icons follow the same pattern — only the geometry differs:

1. **Inner shape** — category fill at 20% opacity
2. **Outer shape** — category fill at 10% opacity
3. **Stroke outline** — onSurface color (adapts to light/dark)

| Category | Geometry | Stroke detail |
|----------|----------|---------------|
| Technical | Angular polygons (heptagon variants) | Solid 1px |
| Community | Organic blobs (amorphous shapes) | Solid 1px, round line join |
| Flash | Concentric circles | Dashed (`stroke-dasharray="4 4"`), 80% opacity |

### Theme-Aware Rendering

SVG paths are embedded as Dart string constants in `ChallengeCategoryIcon` — no asset files needed (all under 7KB). At build time:

- **Fill color**: Resolved from `AppSemanticColors` (`semantic.technical.color`, etc.) — adapts to light/dark theme and contrast levels
- **Stroke color**: Resolved from `colorScheme.onSurface` — ensures visibility in all themes
- Colors injected via `String.replaceAll()` on `{{C}}` / `{{S}}` template placeholders
- Rendered with `SvgPicture.string()` from `flutter_svg`

### Figma Color vs Token Color

The SVG raw hex values don't match the semantic tokens (they're Figma's display colors, not Material derived):

| Category | Figma hex | Light token | Dark token |
|----------|-----------|-------------|------------|
| Technical | `#0070FC` | `0xFF0055D9` | `0xFFAEBCFF` |
| Flash | `#FFC900` | `0xFF875300` | `0xFFFBBB4B` |
| Community | `#008C21` | `0xFF146D32` | `0xFF92D69C` |

This is intentional — the widget uses the runtime semantic token, not the Figma hex, so the icons automatically adapt to every theme contrast level.

### Widget Design

`ChallengeCategoryIcon` is a `StatelessWidget` taking `ChallengeCategory` and optional `size`. Exported from `design_system.dart`. Replaces the previous mock `Container + Icon` pattern in the Widgetbook use case and test file.

---

## Phase 5: Animation & Typography Refinement (2026-02-23)

### Animated Border: Comet Trail

The Phase 2 implementation used a wide SweepGradient (50% visible window, 3 stops) that created a "blinking border" feel. User feedback: "feels heavy — the idea was a pulse running around, not a blinking border."

**Before**: `[0.0: transparent, 0.5: category color, 1.0: transparent]` — half the perimeter lit at once, 2s duration, linear timing.

**After** (comet trail):
- **Base track**: Subtle 12% opacity solid border as a "rail" the comet runs on
- **Comet gradient**: Tight ~25% arc with a fading tail and bright head:
  - `stops: [0.0, 0.70, 0.80, 0.90, 0.97, 1.0]`
  - 0%–70% transparent, 70%–80% faint glow (15%), 80%–90% building (50%), 90%–97% bright head (100%), 97%–100% sharp cutoff
- **Duration**: 4000ms (slowed from 2s for a calmer feel)
- **Curve**: Linear (controller used directly) — `CurvedAnimation(Curves.easeInOut)` was removed because zero velocity at both endpoints caused a visible stall each revolution. Linear rotation is seamless; the gradient's asymmetric tail provides organic character without a curve

### Typography Correction

Figma specifies `title/medium` (16px) for the card title and `body/medium` (14px) for the description. Initial implementation used one step too small:

| Element | Before | After | Reason |
|---------|--------|-------|--------|
| Title | `titleSmall` (14px/w500) | `titleMedium` (16px/w500) | Figma uses 16px medium |
| Description | `bodySmall` (12px/w400) | `bodyMedium` (14px/w400) | Figma uses 14px regular |
| Reward bar | `bodySmall` (12px) | `bodySmall` (12px) | Kept at 12px — smaller text for secondary information |

User considered a heavier weight for the title (w600) but decided against it: Material 3 `titleMedium` is w500, and there's no w600 variant at 16px without `copyWith`. The principle was established: **use standard textTheme styles as-is, no hard overrides**. If the entire type scale needs adjusting, do it at the theme level.

### Widgetbook Background Fix

Widgetbook's default background didn't match the selected theme, making it hard to evaluate light-themed widgets (opacity borders invisible against a dark background). Fixed by wrapping the child in `ColoredBox(color: theme.scaffoldBackgroundColor)` in the `themeBuilder` callback.

---

## Phase 6: Accessible State Demotion (2026-02-23)

### Problem

Completed and missed variants wrapped the entire card in `Opacity(opacity: 0.5)` and `Opacity(opacity: 0.30)` respectively. While this reduced visual dominance effectively, it also reduced text/icon contrast below accessible thresholds — problematic for users with low vision. A 0.30 opacity on dark text against a white background drops contrast well below WCAG AA minimums.

### Solution: Color-Based Demotion

Replaced blanket `Opacity` wrapper with per-element color shifts using existing Material 3 surface/text tokens:

| Variant | Card Background | Title & Body Text | Card Opacity |
|---------|----------------|-------------------|-------------|
| **active** | `surfaceContainerLowest` | `onSurface` | 1.0 |
| **ongoing** | `surfaceContainerLowest` | `onSurface` | 1.0 |
| **completed** | `surfaceContainerLowest` | `onSurfaceVariant` | 1.0 (was 0.5) |
| **missed** | `surfaceContainerLow` | `onSurfaceVariant` | 1.0 (was 0.30) |

### Design Decisions

- **Completed**: Same background, but title/body text shifts from `onSurface` → `onSurfaceVariant`. Visually quieter without killing contrast.
- **Missed**: Background elevates from `surfaceContainerLowest` → `surfaceContainerLow` (subtle tint). Text also shifts to `onSurfaceVariant`. Double demotion = most recessive card.
- **Date/category row**: Already used `onSurfaceVariant` for all variants — unchanged.
- **Reward bars**: Already used proper tokens per variant (`surfaceContainerHigh` + `onSurfaceVariant` for missed) — unchanged.
- **`AppOpacity` import removed**: No longer referenced by the card at all.

### Principle

Never use blanket `Opacity` to communicate semantic state on content that includes text. `Opacity` is acceptable for decorative elements (shadows, overlays) but not for entire interactive cards with readable content. Use the Material 3 surface/text color hierarchy instead — it was designed for exactly this purpose.
