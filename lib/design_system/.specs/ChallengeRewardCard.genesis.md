# ChallengeRewardCard — Genesis

## Inspiration

Figma node `2943:28627` ("Home>ChallengeDetail") — the blue reward card in the challenge detail view showing total earned points, progress bar, calculation breakdown (success rate × max pts = total), rank reward, and optional epoch section.

## Design Decisions

### Category-colored background
Uses `semantic.<category>.color` for the card background. Text uses `semantic.<category>.onColor` — NOT hardcoded `Colors.white`. This ensures correct contrast in dark mode where `onColor` maps to dark blue on light blue card.

### Optional epoch section
`epochEarned` is nullable. When null, the entire bottom half (divider + epoch earned + button) is hidden. Some challenges may not have epoch data.

### Progress bar
6px height with `borderRadiusFull` for pill shape. Track is `onColor.withValues(alpha: 0.2)`, fill is `onColor`. Component-specific height — not a spacing token.

### Calculation row
Flexible 3-column layout with `×` and `=` operators. Each column has a label (labelSmall) and monospace value (bodyMedium + monospace copyWith). Same monospace precedent as ScoreHeader.

### Button variant
`Button(variant: .surface)` for epoch button — white fill on colored background. `tonal` would use achromatic grey which looks muddy on blue.

### Pre-formatted strings
All point values accepted as `String`, formatted by the feature screen. Presentation-only principle.

### M3 Divider
Standard `Divider` widget with `color: onColor.withValues(alpha: 0.1)` for the separator between top and epoch sections.

---

## Phase 2 — Figma Audit & CTA Fix

### Spacing audit (Figma node `2943:28646`)
All 6 spacing gaps match Figma exactly:
- Label → points: 8px → `space8` ✓
- Points → progress bar: 24px → `space24` ✓
- Progress bar → calc row: 16px → `space16` ✓
- Calc row → rank row: 12px → `space12` ✓
- Card padding: 16px → `space16` ✓
- Operator gaps (×, =): 12px → `space12` ✓

### Typography audit
All 7 text styles match theme mappings:
- "Total Earned": `labelLarge` (14px, w500) ✓
- Points number: `displaySmall` + monospace ✓
- "pts": `titleLarge` ✓
- Labels (SUCCESS RATE, etc.): `labelSmall` + `dimOnColor` ✓
- Values (98%, 5000, etc.): `bodyMedium` + monospace ✓
- Epoch "+50": `headlineSmall` + monospace ✓
- Epoch label: `labelSmall` + `dimOnColor` ✓

### Calculation row layout
`_CalculationRow` uses `MainAxisAlignment.spaceBetween` which correctly spreads SUCCESS RATE × MAX PTS on the left and = TOTAL on the right, matching Figma's `justify-between` layout on node `2943:28657`.

### CTA epoch source fix
Changed from `eb.eventName` (leaderboard event identifier) to `producedBlocksSummaryProvider.maxEpochWithData` (actual latest on-chain epoch). CTA now appears as soon as block data loads, independent of breakdown availability.
