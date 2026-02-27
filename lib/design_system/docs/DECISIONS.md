# Design System Decisions

Decisions captured during widget creation sessions, organized by topic.
Each entry preserves the original date and full rationale.

Source: [`DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md) Decisions Log

---

## Architecture Decisions

### M3 Components Preferred (2026-02-24)

Shifted from primitives-only to M3-first approach. Use native Material 3
components for accessibility and consistency; build from primitives only when
M3 doesn't cover the need.

### Selective M3 Adoption (2026-02-24)

After 9 widgets, 5 reimplemented standard M3 interaction patterns (button,
chip, tabs, bottom nav, bottom sheet) — incompletely, lacking ripple, focus,
keyboard, hover, and semantics. Switched to hybrid policy: use M3 components
where interaction maps to standard patterns; keep primitives where visuals are
custom (ChallengeCard, ScoreHeader, ChallengeCategoryIcon, DropdownChain).
Token system, color philosophy, and presentation-only architecture are
orthogonal to widget-layer choice.

---

## Color Decisions

### Achromatic Secondary & Tertiary (2026-02-23)

Moved secondary to neutral-variant palette and tertiary to pure neutral
palette. All chromatic color now lives exclusively in `AppSemanticColors`. M3
structural roles render grey — a developer must consciously reach for a
semantic extension to introduce hue.

### Ghost Tertiary (2026-02-23)

Pushed tertiary further into near-invisibility. Standard contrast: main color
barely clears APCA Lc 60, container ~ΔY 6 from surface. Medium contrast
partially compensates; high contrast fully restores normal M3 levels. This
makes `colorScheme.tertiary*` a trap role that forces use of
`AppSemanticColors` for visible emphasis.

### Surface Shifted to T96 for Grey Scaffold (2026-02-23)

Moved light `surface` from `#FCFCFC` (T99, near-white) to `#F5F5F5` (T96,
visible grey) so M3's default `scaffoldBackgroundColor = surface` produces the
grey page background shown in Figma. Cards and content sheets use
`surfaceContainerLowest` (`#FFFFFF`) for white fills. Dark mode unchanged.

---

## Widget Implementation Decisions

### ChallengeCard Title Weight (2026-02-23)

Figma shows 16px/medium title. Closest Material style is `titleMedium`
(16px/w500). No heavier 16px variant exists without
`copyWith(fontWeight: w600)`. Decided to keep `titleMedium` as-is — no hard
overrides. If we need a different weight scale, we refactor the entire
`TextTheme`.

### ChallengeCard State Demotion (2026-02-23)

Replaced blanket `Opacity` with color-based demotion for completed/missed
variants. `Opacity` on entire card reduces text contrast below accessible
thresholds. Use `onSurfaceVariant` for muted text and `surfaceContainerLow`
for tinted background instead. Never use `Opacity` to communicate semantic
state on readable content.

### ChallengeCard Animation Loop Seam (2026-02-23)

Removed `CurvedAnimation(Curves.easeInOut)` from the ongoing border animation.
`easeInOut` has zero velocity at both endpoints, causing a visible stall when
the repeating controller wraps. Linear rotation is seamless; asymmetric
gradient shape provides organic character. For looping animations, prefer
linear or a custom curve with matching endpoint derivatives (C1 continuity).

### ScoreHeader Score Monospace (2026-02-23)

`displaySmall.copyWith(fontFamily: 'monospace')` — Figma uses IBM Plex Mono
which isn't in the project. This is a functional `copyWith` for tabular number
alignment, not a decorative override. System monospace is acceptable.

### ScoreHeader Countdown Bold (2026-02-23)

`labelSmall.copyWith(fontWeight: FontWeight.w700)` for the countdown time
value. Deliberate deviation from "no copyWith" principle — the time is
actionable data needing visual separation from the "ENDS IN" label. Weight
contrast serves information hierarchy.

---

## Compilation & Platform Decisions

### Widgetbook FFI Compilation Failure (2026-02-20)

Widgetbook failed to compile on web because `AppAppBar` -> `NodeStatusIcon` ->
`nodeStatusProvider` -> Rust FFI. Adopted presentation-only rule: design system
widgets take data as props, never fetch state. Containers live in
`lib/features/`.
