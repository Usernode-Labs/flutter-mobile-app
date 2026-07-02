# AtomicChallengeCard — Genesis Document

> Tracks every design decision from inspiration through implementation.
> New sections are appended as the widget evolves.

## Phase 1: Promotion from Widgetbook prototype (2026-06-16)

### Inspiration / Source
- **Source**: Product board — "Season 1/2 Product Push" (`Season 1_2 Product Push - Frame 1.jpg`),
  CARD + DETAIL + DEFINITIONS frames; plus discussion [#440](https://github.com/Usernode-Labs/flutter-mobile-app/discussions/440)
  and issue [#449](https://github.com/Usernode-Labs/flutter-mobile-app/issues/449) "Active challenges as atomic cards".
- **Figma URL**: N/A (designed on the product board, not Figma).
- This widget was first explored statelessly in Widgetbook at
  `widgetbook/lib/stories/atomic_challenge_card.stories.dart` (`prototypes/challenges`). Phase 1
  promotes the proven prototype verbatim into `lib/design_system/src/atomic_challenge_card.dart`.

### Gap proof (new-pattern justification)
The atomic card is a *new* DS pattern (no existing slot widget composes "title + one progress/reward
rail" with phase-driven state). It is **not** invented from a raw screenshot: it was iterated and
design-approved as a Widgetbook prototype against the product board, reviewed across all card states,
and is the surface the Fair Rewards work in #449 commits to. The existing `ChallengeCard` was rejected
as the base because it is variant/category-colored and carries description + date inside the card —
exactly the noise #440/#449 move out to the band layer and detail page.

## Design Decisions

### Atomic = one mechanic, one verification path
- **What the board showed**: a list of small cards, each a single earning action with a progress/reward rail.
- **What we implemented**: title + a single `AtomicChallengeRail`; the whole card is the tap target; no
  inline CTA. Task copy, requirements, and CTA live on the detail screen (#440 §3).
- **Why**: keeps the Challenges surface scannable and routes attention rather than carrying the whole task.

### Phase, not status theatre
- Four lifecycle phases drive the rail: `open` / `inProgress` / `pendingFinalization` / `completed`
  (#449 "Required Card States"). `pendingFinalization` is reserved for the finalization gap after the
  user's action completes but before points are assigned.

### Nullable `fill`
- `fill` is `double?`. `null` renders a **state-only** rail (e.g. "Submitted · waiting review") with no
  fake progress; when present it is **clamped to 0..1**. This prevents implying progress where only a
  discrete state exists (#449 "Atomic Card Content Model").

### Rail treatments
- `standard` — filled progress rail for bounded metrics (count / percentage / sum).
- `checkbox` — state-only rail with a radio/check icon for binary mechanics.
- `technicalOngoing` — animated `OngoingRailFrame` (comet trail) for continuous background work such as
  block production, where no bounded fill exists.

### Featured treatment
- A premium surface treatment (`AppSemanticColors.premium`) for leaderboard-curated challenges.
- Phase 1 treated "featured" as a client layout treatment of the first active challenge in backend
  order. The current leaderboard contract now owns curation through `featured` and `featured_order`,
  so mobile consumes those fields and keeps the visual treatment presentation-only inside the card.

## Token Mapping
| Element | Design System Token | Notes |
|---------|--------------------|-------|
| Card background (default) | `colorScheme.surfaceContainerLowest` | Card sitting on a surface |
| Card background (featured) | `semantic.premium.colorSurface` | Premium surface |
| Card radius (default / featured) | `radii.largeIncreased` (20) / `radii.xLarge` (24) | Featured reads larger |
| Card border (default) | `colorScheme.outlineVariant` @ `borders.width` | Neutral, felt-not-seen |
| Rail / checkbox radius | `radii.large` (16) | — |
| Rail height | `spacing.space48` | 48px M3 tap-target convergence |
| Progress fill (success) | `semantic.success.*` | Non-featured in/pending/completed |
| Progress fill (featured) | `semantic.premium.*` | Featured phases |
| Ongoing frame color | `semantic.technical.color` | Continuous/technical work |
| Numeric text | `FontFeature.tabularFigures()` | Aligned digits in the rail |

## Accessibility
- Whole card wrapped in `Semantics(button: true, label: '$title, $leftText, $rightText')`.
- Rail height is 48px (meets the ≥48dp tap-target hard ban).
- `OngoingRailFrame` falls back to a solid border when `MediaQuery.disableAnimations` is set.

## Visual Reference
- **Widgetbook story**: `widgetbook/lib/stories/atomic_challenge_card.stories.dart` (imports the real DS widget).
- **In-context preview**: `widgetbook/lib/stories/active_challenge_bands.stories.dart` (cards inside time bands).
