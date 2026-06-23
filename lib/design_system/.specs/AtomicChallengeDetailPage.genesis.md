# AtomicChallengeDetailPage — Genesis Document

## Phase 1: Promotion from Widgetbook prototype (2026-06-16)

### Inspiration / Source
- **Source**: Product board "Season 1/2 Product Push" — DETAIL frame; discussion
  [#440](https://github.com/Usernode-Labs/flutter-mobile-app/discussions/440) (§3 "cards route attention,
  the detail page carries the task") and issue [#449](https://github.com/Usernode-Labs/flutter-mobile-app/issues/449).
- **Figma URL**: N/A (product board).
- First explored at `widgetbook/lib/stories/atomic_challenge_detail_page.stories.dart`
  (`prototypes/challenges`).

### Gap proof (new-pattern justification)
A new detail page surface for the Fair Rewards challenge model. It reuses the
existing [AtomicChallengeRail] as its hero so the detail reads as an expansion of
the card, not a new record view. The existing `ChallengeDetailPage` was rejected
as the base: it is built around reward cards, a block-production pipeline, and a
points-breakdown list — the dense "instruction manual" surface #440 explicitly
moves away from.

### Design decision — drop the prototype's hardcoded block-production extension
The Widgetbook prototype embedded a fully hardcoded block-production block
(reward formula, live-status steps, "epoch 176"). Promoting that verbatim would
violate the DS presentation-only rule (data baked into the widget). The DS widget
is therefore the **clean, parameterized** page: back, title, rail, "Why it
matters", "Available", "How points work" (expandable), optional "Rules", and a
single pinned CTA. Produce-blocks challenges render with the `technicalOngoing`
rail; any live block-production detail is composed by the feature screen from the
existing `BlockProductionStatusCard` / `ChallengeRewardCard` rather than baked in
here.

## Token Mapping
| Element | Design System Token | Notes |
|---------|--------------------|-------|
| Page background | `colorScheme.surfaceContainerLowest` | — |
| Horizontal inset | `spacing.space32` | Page gutters |
| Title | `textTheme.displaySmall` + `kMonoFontFamily` | Hero goal |
| Section title | `textTheme.labelLarge` w600 | — |
| Section / expansion body | `textTheme.bodyLarge` on `onSurfaceVariant` | — |
| "Available" body | + `FontFeature.tabularFigures()` | Aligned dates |
| CTA | `Button(primary, large)` | Pinned bottom, full width |
| Bottom scroll padding | `buttonHeightLarge + space12 + space32` | Clears the pinned CTA |

## Accessibility
- Back button is a 48dp `IconButton` with a "Back" tooltip.
- CTA is a full-width primary button pinned above the safe area (never keyboard-
  or inset-covered).

## Visual Reference
- **Widgetbook story**: `widgetbook/lib/stories/atomic_challenge_detail_page.stories.dart`.
