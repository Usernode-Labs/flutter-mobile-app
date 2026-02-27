# ScoreHeader — Genesis Document

Tracks design decisions made during widget creation. Each section is appended as the widget evolves.

## Phase 1: Figma Inspection & Planning (2026-02-23)

**Figma nodes inspected:**
- `2994:2193` — Default variant: white circle, subtle border, progress arc, countdown, "View in Leaderboard" button
- `2994:3259` — Glow variant: same structure + massive multi-color box shadows
- `2994:2192` — Full screen context: header is sticky, content scrolls below

### Widget decomposition
ScoreHeader is the public widget. Internal sub-widgets are private:
- `_ScoreCircle` — 160px circle with rank/score/label + progress arc
- `_ScoreArcPainter` — CustomPainter for the circular progress arc
- `_CountdownRow` — dot + "ENDS IN" + time text

**Button** is a separate public design system widget (`lib/design_system/src/button.dart`), not a private sub-widget. ScoreHeader composes it for the CTA. This follows the "bottom-up from primitives" philosophy — the design system names widgets in its own vocabulary, starts simple, and adds variants as designs demand them.

### Glow = semantic, not decorative
The three glow colors map to the ecosystem's challenge pillars:
- **Technical** (blue) — `semantic.technical.color`
- **Flash** (amber/gold) — `semantic.flash.color`
- **Community** (green) — `semantic.community.color`

The glow communicates "verified member, belonging to all three pillars." This is meaningful identity, not visual decoration. Colors come from `AppSemanticColors` tokens so the glow adapts across all 6 theme variants.

**Figma uses brighter hex values** (#00dd57, #facc36, #0065f4) than our theme tokens. This is expected — Figma = inspiration, theme tokens = truth. The semantic tokens ensure consistency across light/dark/contrast themes.

### Typography decisions
- **Score number**: `displaySmall` (36px) with `.copyWith(fontFamily: 'monospace')` — Figma uses IBM Plex Mono which isn't in the project. System monospace is acceptable. This is a deliberate `copyWith` for functional reasons (tabular number alignment), not decorative styling.
- **Countdown time (bold)**: `labelSmall.copyWith(fontWeight: FontWeight.w700)` — deliberate deviation from the "no copyWith" principle. The time value is actionable data that needs visual separation from the "ENDS IN" label. Weight contrast serves information hierarchy.
- All other text uses standard textTheme styles with no overrides.

### Glow implementation — v1 scope
- 6 `BoxShadow`s positioned at different offsets with large blur radii
- Inner shadows and backdrop-blur visible in Figma are skipped for v1 — they require `BackdropFilter` and layering complexity that can be added later
- Parent widget must not clip the header area — glow bleeds outward by design

### Circle size
160px is hardcoded, not from AppSizing. This is a deliberate choice — no existing sizing token matches, and adding a one-off token would bloat the system. If more circles appear at this size, we'll extract a token then.

### Progress arc
- Starts at -pi/2 (12 o'clock position), sweeps clockwise
- 3px stroke with `StrokeCap.round` for soft endpoints
- Faint track circle at `AppOpacity.subtle` provides context for how much progress remains
- Color defaults to `colorScheme.primary` but is configurable

## Phase 2: Implementation (2026-02-23)

### Button — separate design system widget
Built bottom-up from Flutter primitives: `GestureDetector` + `Container` + `Text`. No Material Button classes. Starts with secondary/tonal style (what ScoreHeader needs). Additional styles will be added as Figma designs demand them.

The name is simply "Button" — we define our own vocabulary, not Material Design's naming conventions (no "FilledButton", "ElevatedButton", "OutlinedButton" etc.).

### Filter chips are NOT part of ScoreHeader
Filter chips (Season/Category selectors) are separate widgets that will be composed by the screen. The glow effect from ScoreHeader bleeds visually into the surrounding area, creating the ambient background effect seen in Figma — but that's a layout concern for the screen, not the widget.

## Phase 3: Glow v2 — CustomPainter + Additive Blending (2026-02-23)

### Problem
The Phase 1 glow looked muted and flat. Two root causes:
1. **Dark semantic tokens** — e.g. community green `0xFF146D32` is much darker than Figma's neon `#00dd57`
2. **BoxShadow uses srcOver compositing** — overlapping colors muddy rather than brighten

### Solution: `_neonify()` + `_GlowPainter` with `BlendMode.plus`

**`_neonify(Color base)`** — derives a neon variant from any semantic token by preserving hue, maxing saturation to 1.0, and lifting lightness to 0.55. This keeps the semantic connection (hue intact) while producing bright neon colors that adapt across all 6 theme variants.

**`_GlowPainter`** — replaces the `BoxShadow`-based `_buildGlowWrapper` with a `CustomPainter` using `ui.Gradient.radial()` and additive blending:
- `canvas.saveLayer()` isolates the glow onto a transparent layer
- First glow (community green, centered) paints with `srcOver` as the base layer
- Subsequent glows (flash amber, technical blue) use `BlendMode.plus` — additive blending makes overlapping colors brighten like real light instead of muddying
- Two radial gradients per color (near/tight + far/soft) with 3-stop falloff
- `isComplex: true` enables raster caching since the glow is static

### Circle enhancements (glow variant only)
- **White halo**: `BoxShadow(color: Color(0x40FFFFFF), blurRadius: 24, spreadRadius: 2)` makes the circle float above the glow
- **Softened border**: `outlineVariant.withValues(alpha: 0.3)` — full-opacity border competed with the glow

### Performance
Single `saveLayer` call, not animated, raster-cached via `isComplex: true`. No measurable performance impact.

## Phase 4: M3 Migration — Button (2026-02-24)

### Decision
After 9 widgets in the design system, 5 reimplemented standard M3 interaction patterns — incompletely lacking ripple, focus, keyboard, hover, and semantics. Adopted selective M3 policy: use M3 components where interaction maps to standard patterns.

### Migration
`Button` migrated from `GestureDetector` + `Container` + `Text` to `FilledButton.tonal` / `FilledButton.tonalIcon`. Visual appearance controlled by `filledButtonTheme` in `ColorIsExpensiveTheme`.

### What changed
- Gained: ripple feedback, focus management, keyboard navigation, hover states, screen reader semantics
- LOC: 68 → 42 (38% reduction)
- API preserved: `Button(label:, onTap:, leadingIcon:)` unchanged

### What stayed
- Widget name: still `Button`, not `FilledButton`
- Tonal style: `secondaryContainer` / `onSecondaryContainer` — renders identical grey pill
- Presentation-only: no providers, all state via constructor params
