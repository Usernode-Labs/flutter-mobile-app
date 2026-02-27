# Color Reference

> **"Color is expensive."** Every chromatic pixel must earn its place through semantic purpose.
> Structure is achromatic; only content and status carry hue.

## The "Color is Expensive" Principle

An economic metaphor applied to interface design. Chromatic color is a scarce resource with a cost.

1. **Scarcity creates value.** A blue badge on a monochrome list *screams*. The same badge in a colorful interface *whispers*. Restraint amplifies signal-to-noise ratio.
2. **Color becomes vocabulary.** Users learn to read it: blue = technical, amber = time-sensitive, green = community/success, red = error. A closed vocabulary — no "decorative purple."
3. **Structure is achromatic.** Nav bars, cards, buttons, scaffolds, dividers — the entire structural layer is greyscale. Structure is infrastructure; it should be invisible.

**Constrains:** No decorative color. No branded gradients. No chromatic structural roles. To get hue, go through `AppSemanticColors`, which forces you to declare *what the color means*.

**Enables:** Instant status recognition. Accessibility by design (achromatic base = high contrast). Scalability (semantic colors never clash with structure). Dark mode simplicity (grey inverts cleanly).

**The third way:** Neither "colorful M3" (saturated primary tonal palette) nor "monochrome brutalism." Monochrome infrastructure with chromatic semantics.

## Core Role Semantics

All M3 `ColorScheme` structural roles are achromatic. Manually specified (not `fromSeed()`).

| Role | Purpose |
|------|---------|
| **Primary** | Attention locker. Maximum contrast CTAs. Distinguished from body text by shape, not color. |
| **Secondary** | Structural emphasis without hue. Cool-leaning grey for secondary actions. |
| **Tertiary** | **Ghost role.** Barely-visible grey that just clears APCA Lc 60. Forces developers toward `AppSemanticColors`. |
| **Error** | Signal red. The one place chromatic color is *required* in the ColorScheme. |
| **Neutral** | True achromatic. Zero chroma. The paper substrate. |
| **Neutral Variant** | Faintest cool lean for outlines and structural elements. |

Primary vs onSurface: both near-black. Primary = interactive (buttons); onSurface = content (text). Distinguish by shape.

> Seed values and resolved roles → `color_is_expensive_theme.dart`

## Ghost Tertiary & Contrast Cascade

Tertiary is deliberately starved of contrast — a **trap role**. `tertiary` barely clears APCA Lc 60; `tertiaryContainer` is ~DY 6 from `surface` — nearly invisible. Design-by-frustration: the wrong path is uncomfortable enough that developers self-correct toward `AppSemanticColors`.

| Contrast Level | Tertiary Behavior |
|---------------|-------------------|
| **Standard** | Ghost — barely Lc 60, containers nearly invisible |
| **Medium** | Partially visible — moderately above Lc 60 |
| **High** | Fully visible — normal M3 contrast levels. Ghost disappears. |

The principle yields to user accessibility needs, not the other way around.

## Semantic Colors (AppSemanticColors)

The chromatic gatekeeper. A `ThemeExtension` (not a `ColorScheme` role) — access is explicit and opt-in. Exactly 4 groups; adding a 5th is a design decision, not a convenience.

| Group | Hue | Domain Meaning |
|-------|-----|----------------|
| **Technical** | Blue | Precision, computation, code |
| **Flash** | Amber | Urgency, energy, time-limited |
| **Community** | Green | Participation, growth, social |
| **Success** | Green (distinct tone) | Completion, achievement, earned badges |

Each group provides a 4-role pattern (`color`, `onColor`, `colorContainer`, `onColorContainer`) mirroring M3. All pairs APCA-verified.

> Values, sub-roles, and contrast data → `app_semantic_colors.dart`

## Do's & Don'ts

**Do:** Use `primary` for CTAs. Use `AppSemanticColors` for chromatic emphasis. Pair `colorContainer` + `onColorContainer`. Use neutrals for backgrounds.

**Don't:** Use chromatic color decoratively. Hardcode hex values. Reach for `tertiary*` expecting visible emphasis (ghost role). Mix semantic purposes. Use `Opacity` on readable content (drops contrast) — use color-based demotion instead.

## Chromatic Budget

Color is a budget. Each expenditure must carry semantic weight.

**Earns color:** Technical (blue), Flash (amber), Community (green), Success (green, distinct tone), Error (red).

**Stays achromatic:** Primary buttons, secondary actions, nav bars/tabs, cards/sheets/dialogs, outlines/dividers, scaffold background, progress indicators, switches/checkboxes.

**The gatekeeper:** `AppSemanticColors` is the only sanctioned path to hue (besides `error`). If you can't map to one of 5 budget lines (4 semantic + error), it stays achromatic.
