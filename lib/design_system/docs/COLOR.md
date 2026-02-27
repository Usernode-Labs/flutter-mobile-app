# Color Reference

> **"Color is expensive."** Every chromatic pixel must earn its place through semantic purpose.
> Structure is achromatic; only content and status carry hue.

---

## The "Color is Expensive" Principle

An economic metaphor applied to interface design. Chromatic color is a scarce resource with a cost.

**Three implications:**

1. **Scarcity creates value.** A blue badge on a monochrome list *screams*. The same badge in a colorful interface *whispers*. Restraint amplifies every colored pixel's signal-to-noise ratio.
2. **Color becomes vocabulary.** Because chromatic color is rare, users learn to read it. Blue = technical. Amber = time-sensitive. Green = community or success. Red = error. A closed vocabulary — no "decorative purple" allowed.
3. **Structure is achromatic.** Navigation bars, cards, buttons, scaffolds, dividers — the entire structural layer is greyscale. Structure is infrastructure; it should be invisible.

**What it constrains:** No decorative color. No branded gradients. No chromatic structural roles. To get hue, you must go through `AppSemanticColors`, which forces you to declare *what the color means*.

**What it enables:** Instant status recognition. Accessibility by design (achromatic base = high contrast). Scalability (new semantic colors never clash with structure). Dark mode simplicity (grey inverts cleanly).

**The third way:** Neither "colorful M3" (saturated primary tonal palette) nor "monochrome brutalism" (no color at all). This is monochrome infrastructure with chromatic semantics — the structural layer is greyscale, the content layer carries a controlled color vocabulary.

---

## Core Role Semantics

All M3 `ColorScheme` structural roles are achromatic. Manually specified (not `fromSeed()`).

| Role | Seed | Purpose |
|------|------|---------|
| **Primary** | `#18191B` (near-black) | Attention locker. Maximum contrast CTAs. Same darkness as body text — distinguished by shape (button vs paragraph). |
| **Secondary** | achromatic (neutral-variant) | Structural emphasis without hue. Cool-leaning grey for secondary actions. |
| **Tertiary** | achromatic (pure neutral) | **Ghost role.** Barely-visible grey that just clears APCA Lc 60. Forces developers toward `AppSemanticColors`. |
| **Error** | `#DC362E` (red) | Signal red. The one place chromatic color is *required* in the ColorScheme. |
| **Neutral** | `#6B6B6B` (gray) | True achromatic. Zero chroma. The paper substrate. |
| **Neutral Variant** | `#696C73` (cool gray) | Faintest cool lean for outlines and structural elements. |

**Primary vs onSurface:** Both are near-black. Primary is for interactive elements (buttons); `onSurface` is for content (text). Distinguish by shape, not by color.

---

## Ghost Tertiary & Contrast Cascade

Tertiary is deliberately starved of contrast — a **trap role**. A developer reaching for `colorScheme.tertiary*` gets nearly nothing:

- `tertiary` barely clears the APCA Lc 60 floor
- `tertiaryContainer` is ~DY 6 from `surface` — nearly invisible

This is design-by-frustration: the wrong path is uncomfortable enough that developers self-correct toward `AppSemanticColors`.

The contrast cascade resolves the accessibility tension:

| Contrast Level | Tertiary Behavior | Who Benefits |
|---------------|-------------------|--------------|
| **Standard** | Ghost — barely Lc 60, containers nearly invisible | Default users. Ghost enforces the design philosophy. |
| **Medium** | Partially visible — moderately above Lc 60 | Users who need moderate contrast support. |
| **High** | Fully visible — normal M3 contrast levels | Users who need high contrast. Ghost effect disappears. |

"Color is expensive" is a standard-contrast philosophy with progressive accessibility overrides. The principle yields to user needs, not the other way around.

---

## Semantic Colors (AppSemanticColors)

The chromatic gatekeeper. A `ThemeExtension` — not a `ColorScheme` role — which makes access explicit and opt-in. Exactly 4 groups; adding a 5th is a design decision, not a convenience.

### The 4 Groups

| Group | Hue | Domain Meaning |
|-------|-----|----------------|
| **Technical** | Blue `#0055D9` | Technical challenges: precision, computation, code |
| **Flash** | Amber `#875300` | Flash/timed challenges: urgency, energy, time-limited |
| **Community** | Green `#146D32` | Community challenges: growth, participation, social |
| **Success** | Green `#1A6D23` | Completion states, positive outcomes, earned badges |

### The 4-Role Pattern (per group)

Each group mirrors M3's own color role pattern:

| Sub-role | Purpose | Example Usage |
|----------|---------|---------------|
| `color` | Standalone accent | Badge dot, category icon tint |
| `onColor` | Text/icons on `color` fill | Icon on a filled badge |
| `colorContainer` | Tinted background | Challenge card background tint |
| `onColorContainer` | Text on `colorContainer` | Title text on a tinted card |

### Light Mode Values

| Group | `color` | `onColor` | `colorContainer` | `onColorContainer` |
|-------|---------|-----------|-------------------|---------------------|
| Technical | `#0055D9` | `#FFFFFF` | `#D3D9FF` | `#0040BD` |
| Flash | `#875300` | `#FFFFFF` | `#FFD87B` | `#774500` |
| Community | `#146D32` | `#FFFFFF` | `#B6F0BE` | `#05652B` |
| Success | `#1A6D23` | `#FFFFFF` | `#BAF1B4` | `#12681E` |

All pairs APCA-verified: body text Lc >= 90, accents Lc >= 60, borders Lc >= 30.

---

## Color Access Patterns

### Core ColorScheme (structural, achromatic)

```dart
final colors = Theme.of(context).colorScheme;

// Interactive: colors.primary, .onPrimary, .primaryContainer, .onPrimaryContainer
// Structural:  colors.secondary, .onSecondary, ...
// Ghost:       colors.tertiary — near-invisible, use AppSemanticColors instead
// Error:       colors.error, .onError, ...
// Surfaces:    colors.surface (grey scaffold), .surfaceContainerLowest (white content)
// Text:        colors.onSurface (body), .onSurfaceVariant (secondary)
// Borders:     colors.outline (important), .outlineVariant (decorative/dividers)
```

### Semantic Colors (chromatic, domain-specific)

```dart
final semantic = Theme.of(context).extension<AppSemanticColors>()!;

// Standalone accent:
semantic.technical.color

// Text on accent fill:
semantic.technical.onColor

// Tinted background:
semantic.technical.colorContainer

// Text on tinted background:
semantic.technical.onColorContainer

// Same pattern for: semantic.flash, semantic.community, semantic.success
```

### Pairing Rule

Always pair `container` + `onContainer` together. These are APCA-verified pairs — mixing them breaks contrast guarantees.

```dart
// Correct:
Container(
  color: semantic.technical.colorContainer,
  child: Text('Technical', style: TextStyle(color: semantic.technical.onColorContainer)),
)

// Wrong — unpaired:
Container(
  color: semantic.technical.colorContainer,
  child: Text('Technical', style: TextStyle(color: colors.onSurface)),  // Not verified
)
```

---

## Do's & Don'ts

**Do:**
- Use `primary` for CTAs and interactive elements demanding attention
- Use `AppSemanticColors` for any visible chromatic emphasis (technical, flash, community, success)
- Use neutrals for backgrounds — let the paper breathe
- Pair `colorContainer` + `onColorContainer` together
- Access colors via `Theme.of(context).colorScheme` and `.extension<AppSemanticColors>()`

**Don't:**
- Use chromatic color decoratively — every colored pixel must carry meaning
- Hardcode hex values — always use theme tokens
- Reach for `colorScheme.tertiary*` expecting visible emphasis — it's a ghost role
- Mix semantic purposes (e.g., amber for Technical, blue for Community)
- Use `primary` and `onSurface` interchangeably (same darkness, different contexts)
- Override APCA-verified contrast pairings
- Use `Opacity` for semantic state on readable content — it drops contrast below accessible thresholds. Use color-based demotion (`onSurfaceVariant`, `surfaceContainerLow`) instead.

---

## Chromatic Budget

Color is a budget. Each expenditure must carry semantic weight.

### What Earns Color

| Budget Line | Color | Justification |
|-------------|-------|---------------|
| Technical challenges | Blue | Domain: computation, code, precision |
| Flash challenges | Amber | Domain: urgency, time-limited, energy |
| Community challenges | Green | Domain: participation, growth, social |
| Success states | Green (distinct tone) | Outcome: completion, achievement |
| Error states | Red | System: something went wrong |

### What Stays Achromatic

| Element | Why |
|---------|-----|
| Primary buttons (CTAs) | Attention via contrast, not hue. Shape distinguishes from text. |
| Secondary actions | Utility, not emphasis. Grey = "available but not urgent." |
| Navigation bars, tabs | Infrastructure. Shouldn't compete with content. |
| Cards, sheets, dialogs | Containment. The paper doesn't need a color. |
| Outlines, dividers | Structure. Invisible when well-placed. |
| Scaffold background | The paper substrate. Grey establishes the two-tier surface model. |
| Progress indicators | Achromatic by default. Semantic color only for domain meaning. |
| Switches, checkboxes | Binary state. On/off is structural, not semantic. |

### The Gatekeeper

`AppSemanticColors` is the only sanctioned path to hue (besides `error`):

1. It's a `ThemeExtension`, not a `ColorScheme` role — a separate, deliberate import
2. The API forces semantic naming: `semantic.technical.color`, not `Colors.blue`
3. Exactly 4 groups — adding a 5th is a reviewable design decision

If you need chromatic color and can't map it to one of these 5 budget lines (4 semantic + error), the answer is probably: it stays achromatic.
