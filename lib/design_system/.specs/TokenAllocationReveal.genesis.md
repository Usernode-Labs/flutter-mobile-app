# TokenAllocationReveal — Genesis

## Inspiration
- **Source**: Text brief (2026-07-10) — profile page widget between the season
  selector and the tabs showing the season token allocation; amount hidden
  until tap, revealed with a celebratory animation ("feels like a little win").
- **Figma URL**: N/A (text-only override recorded in
  `TokenAllocationReveal.spec.yaml`)
- **Reference screenshot**: N/A

## Design Decisions

### Celebration spends the color budget, not confetti
- **What the brief asked**: a celebratory reveal animation.
- **What we implemented**: the hidden state is fully achromatic
  (white surface, outline border, grey badge). Tapping animates the surface
  to `premium.colorContainer`, the badge to `premium.color`, and emits
  staggered pulse rings — the arrival of chromatic color IS the celebration.
- **Why**: "Color is Expensive" — confetti/particle effects are foreign to
  the quiet technical identity. The premium (yellow) semantic group is
  documented for featured rewards / high-value spotlight, exactly this role.
  The ring language reuses `BurstPulseIllustration`'s expanding-circle
  vocabulary rather than inventing a new visual pattern.

### Reveal is an explicit button, not a gesture or whole-card tap
- **What was considered**: scratch-card drag, long-press, whole-card tap with
  a "Tap to reveal" hint and mono `••••` placeholder.
- **What we implemented**: a DS `Button` (tonal, regular = 48dp) labelled
  "Reveal" as the sole affordance, with a light haptic on press. It crossfades
  out as the amount scales in.
- **Why**: an explicit CTA reads more clearly as "there's a reward here" than a
  dotted placeholder, and a single obvious tap target avoids the redundancy of
  a "Tap to reveal" hint sitting next to a reveal control. Regular size keeps
  it at the 48dp interactive-control minimum (small = 40dp would breach the
  hard ban). Gesture-only controls without a visible affordance are banned.

### Amount is withheld from the tree until reveal
- **What we implemented**: the amount `Text` is only built once the
  celebration starts; hidden state renders mono bullets instead.
- **Why**: an `Opacity(0)` amount would still be exposed to semantics/screen
  readers and to widget tests — hiding means actually absent.

### 900ms local celebration constant
- **What we implemented**: `_celebrationDuration = 900ms` as a widget-local
  const; the surface tint completes within the first third (≈300ms =
  `AppAnimation.complex`), rings and the amount pop use the remainder.
- **Why**: the animation token scale caps at 300ms (micro-transitions). A
  one-shot celebratory sequence needs a longer envelope; precedent is
  `BurstPulseIllustration`'s local 2.5s ring lifetime. Honors
  `MediaQuery.disableAnimations` by jumping straight to the settled state.

### Programmatic reveal skips the celebration
- **What we implemented**: `revealed: true` (initial or via
  `didUpdateWidget`) settles instantly; the animation only plays on user tap.
- **Why**: the celebration is a first-sight moment. Restoring persisted
  "already seen" state on revisit should not replay it. `onReveal` lets the
  feature layer persist the flag.

## Token Mapping
| Design Value | Design System Token | Notes |
|--------------|-------------------|-------|
| Card radius | `radii.borderRadiusLargeIncreased` | Matches profile leaderboard rows |
| Card padding | `space16` / `space12` | Standard card insets |
| Hidden border | `colorScheme.outlineVariant` + `borders.width` | White-on-white inner card rule |
| Reveal tint | `premium.colorContainer` / `onColorContainer` | Featured-reward semantic role |
| Badge | `IconBadge` defaults (48/40/24) | Grey by default, `premium.color` revealed |
| Amount type | `headlineSmall` + `kMonoFontFamily` | Display hero mono exception |
| Ring opacity | `opacity.secondary` (0.4) envelope | Fades with easeIn |
| Tint duration | `animation.complex` (300ms) | First third of the 900ms envelope |

## Optional Visual Reference
- **Widgetbook story**: `widgetbook/lib/stories/token_allocation_reveal.stories.dart`
- **Page integration**: `widgetbook/lib/stories/testnet_profile_page.stories.dart`
  (between the ScoreHeader period chip and the Tabs)
