# First-Principles Design

> Archived from Intent workspace note `first-principles-design` (Feb 2026).
> Full unabridged research content.

---

A complete articulation of the "Color is Expensive" design philosophy, followed by a ground-up ideal M3 implementation designed purely from those principles.

---

# Part 1: Design Foundations

## 1A. The Core Principle

### What "Color is Expensive" Means

"Color is expensive" is an economic metaphor applied to interface design. It treats chromatic color — any pixel that carries hue — as a scarce resource with a cost. Every colored element must justify its existence through semantic purpose. If a pixel doesn't carry meaning, it stays grey.

This is a **budget constraint**, not an aesthetic preference. The metaphor has three implications:

1. **Scarcity creates value.** When chromatic color appears in a sea of achromatic grey, it commands immediate attention. A blue badge on a monochrome list *screams*. The same badge in a colorful interface *whispers*. Restraint amplifies the signal-to-noise ratio of every colored pixel.

2. **Color becomes a vocabulary.** Because chromatic color is rare, users learn to read it. Blue means technical. Amber means time-sensitive. Green means community or success. Red means error. This is a closed vocabulary — you can't add "decorative purple" without diluting every other color's meaning.

3. **Structure is achromatic.** Navigation bars, cards, buttons, outlines, scaffolds, dividers — the entire structural layer of the interface is grey-scale. Structure is infrastructure; it should be invisible. Only content and status carry hue.

### What It Constrains

- **No decorative color.** No branded gradients, no colored section headers, no tinted backgrounds for visual interest. If it's not semantic, it's grey.
- **No chromatic branding at the structural level.** The app's identity comes from typography, spacing, and the restrained palette itself — not from a colored app bar or branded button.
- **No casual color decisions.** A developer cannot reach into the `ColorScheme` and pull out a chromatic accent. The structural roles (`primary`, `secondary`, `tertiary`) are all achromatic. To get hue, you must go through `AppSemanticColors`, which forces you to declare *what the color means*.

### What It Enables

- **Instant status recognition.** Users immediately perceive colored elements as meaningful because color is never used frivolously.
- **Accessibility by design.** An achromatic base layer has inherently high contrast. APCA verification ensures the few chromatic elements also meet perceptual contrast thresholds.
- **Scalability.** The system can add new semantic colors (e.g., "warning", "info") without clashing with existing structural elements, because structure has no hue to clash with.
- **Dark mode simplicity.** An achromatic structural layer inverts cleanly — grey lightens, surfaces darken, and the semantic colors adjust their lightness curves independently.

### A Third Way

This is neither "colorful M3" nor "monochrome brutalism":

- **Colorful M3** (the default) saturates the interface with a primary tonal palette — purple buttons, tinted surfaces, colored chips. It's warm and branded, but every element competes for attention. Status colors (error, success) must be louder than the ambient hue to register.
- **Monochrome brutalism** strips all color, including semantic signals. Everything is black and white. Status must be communicated through icons, text, or layout — never through hue. This is accessible but information-sparse.
- **"Color is expensive"** occupies the middle ground: the structural layer is monochrome (like brutalism), but the content layer carries a controlled chromatic vocabulary (like M3's custom colors). It's monochrome infrastructure with chromatic semantics.

### Design Precedents

- **Apple's restrained approach** (iOS 7+): Large expanses of white/grey with color reserved for interactive elements and status. Apple uses blue as the universal "tappable" signal — a single-color vocabulary at the OS level.
- **Newspaper/editorial design**: Body text in black, headlines in black, structure in grey rules and whitespace. Color appears only in photographs and charts — data-carrying content.
- **Typographic-first Swiss design** (Müller-Brockmann, Vignelli): Grid, hierarchy, and white space do the heavy lifting. Color is a final, deliberate layer — not a starting point.
- **Edward Tufte's data-ink ratio**: Maximize the data-to-ink ratio. Every visual element should carry information. "Color is expensive" applies this principle beyond data visualization to the entire interface.

---

## 1B. The Principle Hierarchy

### Level 0 — Foundational Axiom

> **Color is expensive.** Every chromatic pixel must earn its place through semantic purpose.

### Level 1 — Primary Principles (flow directly from the axiom)

1. **Achromatic structural layer.** All M3 structural roles (`primary`, `secondary`, `tertiary`, surfaces, outlines) are greyscale. The skeleton of the interface has zero hue.

2. **Chromatic = semantic.** Hue enters the system only through sanctioned semantic channels (`AppSemanticColors`, `error`). Color always means something specific.

3. **Scarcity amplifies signal.** The rarity of chromatic color makes each instance more noticeable. This is not a side effect — it's the mechanism.

### Level 2 — Secondary Principles (enforce the primary principles)

4. **Ghost roles as guardrails.** Tertiary is deliberately near-invisible — a "trap role" that returns nearly nothing when accessed. This is an active enforcement mechanism: developers who reach for `colorScheme.tertiary*` expecting accent color get grey, forcing them toward `AppSemanticColors`. The system punishes casual color use.

5. **The chromatic gatekeeper.** `AppSemanticColors` is the *only* sanctioned path to hue (besides `error`). It's a `ThemeExtension`, not a `ColorScheme` role, which makes it explicit and opt-in. You can't accidentally get chromatic color — you must deliberately import and access a semantic group.

6. **APCA-verified contrast.** Every color pairing — chromatic or achromatic — passes perceptual contrast thresholds (APCA Lc >= 90 for body text, >= 60 for accents, >= 30 for borders). This is the accessibility foundation that makes the achromatic base and sparse chromatic accents usable.

7. **Contrast cascade as escape valve.** The ghost tertiary would be an accessibility hazard for users who need high contrast. The three contrast levels (standard → medium → high) progressively restore tertiary visibility. Standard is the design ideal; high contrast is the accessibility guarantee. This demonstrates that "color is expensive" is a *default-contrast* philosophy, not a universal mandate.

### Level 3 — Derived Rules (specific implementations of the principles)

8. **Never use `colorScheme.tertiary*` for visible emphasis.** (From principles 1, 4)
9. **Always pair `container` + `onContainer`.** (From principle 6 — APCA-verified pairs must be used together)
10. **No hardcoded hex values in widgets.** (From principles 1, 5 — all color must flow through the theme)
11. **`primary` and `onSurface` have the same darkness but different contexts.** Primary is for interactive elements (buttons); `onSurface` is for content (text). Distinguish by shape, not by color. (From principle 1)
12. **M3 components first.** Use native Material 3 components for interaction patterns. The color philosophy is orthogonal to the component layer. (Pragmatic rule that emerged from building 9 widgets)
13. **No `Opacity` for semantic state.** Opacity on readable content reduces contrast below accessible thresholds. Use color-based demotion (`onSurfaceVariant`, `surfaceContainerLow`) instead. (From principle 6)

### Level 4 — Operational Guidelines (Do's and Don'ts)

**Do:**
- Use `primary` for CTAs and interactive elements demanding attention
- Use `AppSemanticColors` for any visible chromatic emphasis
- Use neutrals for backgrounds — let the paper breathe
- Access colors via `Theme.of(context).colorScheme` and `.extension<AppSemanticColors>()`

**Don't:**
- Use chromatic color decoratively
- Hardcode hex values
- Reach for `colorScheme.tertiary*` expecting visible emphasis
- Mix semantic purposes (e.g., amber for Technical content, blue for Community)
- Use `primary` and `onSurface` interchangeably
- Override APCA-verified contrast pairings
- Use `Opacity` to communicate semantic state on readable content

---

## 1C. The Chromatic Budget Model

### What Earns Chromatic Color

Chromatic color is a budget. Each expenditure must carry semantic weight:

| Budget Line | Color | Justification |
|-------------|-------|---------------|
| **Technical** challenges | Blue | Domain-specific: computation, code, precision |
| **Flash** challenges | Amber | Domain-specific: urgency, time-limited, energy |
| **Community** challenges | Green | Domain-specific: participation, growth, social |
| **Success** states | Green | Outcome: completion, achievement, earned rewards |
| **Error** states | Red | System: something went wrong, needs attention |

Each budget line gets a 4-role allocation: `color` (standalone accent), `onColor` (text on accent), `colorContainer` (tinted background), `onColorContainer` (text on tinted background). This mirrors M3's own role pattern and ensures every chromatic surface has a verified text-on-surface pairing.

### What Stays Achromatic

Everything structural:

| Element | Why Achromatic |
|---------|---------------|
| Primary buttons (CTAs) | Attention via contrast, not hue. Shape distinguishes button from text. |
| Secondary actions | Utility, not emphasis. Grey signals "available but not urgent." |
| Navigation bars, tabs | Infrastructure. Shouldn't compete with content. |
| Cards, sheets, dialogs | Containment. The paper doesn't need a color. |
| Outlines, dividers | Structure. Invisible when well-placed. |
| Scaffold background | The paper substrate. Grey establishes the two-tier surface model. |
| Progress indicators | Inherits primary → achromatic. Progress is about motion, not color. |
| Switches, checkboxes | Binary state. On/off is structural, not semantic. |

### The Chromatic Gatekeeper

`AppSemanticColors` functions as a gatekeeper:

1. **It's a ThemeExtension, not a ColorScheme role.** You access it via `Theme.of(context).extension<AppSemanticColors>()!`. This is a separate, deliberate import — not something you bump into while browsing `colorScheme`.
2. **It requires a semantic declaration.** You don't get "a color." You get `semantic.technical.color` or `semantic.flash.colorContainer`. The API forces you to name the *meaning* of the color you're using.
3. **It has exactly 4 groups.** Adding a 5th semantic group is a design decision, not a convenience. This keeps the chromatic vocabulary small and learnable.

### The Ghost Tertiary as Enforcement

The ghost tertiary is not merely "unused" — it's actively weaponized:

- A developer who doesn't know the system and reaches for `colorScheme.tertiary` (a natural M3 reflex) gets a nearly invisible grey.
- The container (`tertiaryContainer`) is almost indistinguishable from `surface` (~ΔY 6 in light mode).
- This *immediately* signals that something is wrong, prompting the developer to check the design system docs.
- The docs direct them to `AppSemanticColors`.

This is design-by-frustration: the wrong path is uncomfortable enough that developers self-correct.

### The Contrast Cascade as Accessibility Escape Valve

The ghost tertiary creates a tension with accessibility: some users genuinely need three distinct accent levels. The contrast cascade resolves this:

| Contrast Level | Tertiary Behavior | Who Benefits |
|---------------|-------------------|--------------|
| **Standard** | Ghost — barely Lc 60, containers ~invisible | Default users. Ghost enforces the design philosophy. |
| **Medium** | Partially visible — above Lc 60 | Users who need moderate contrast support. |
| **High** | Fully visible — normal M3 contrast levels | Users who need high contrast. The ghost effect disappears entirely. |

This means "color is expensive" is a standard-contrast design philosophy with progressive accessibility overrides. The principle yields to the user's needs, not the other way around.

---

## 1D. Adjacent Principles

### Surface Architecture: Grey Scaffold / White Content

The two-tier surface model works alongside the achromatic color system:

- **Scaffold layer** (`surface`): Visible grey. This is the "paper substrate" — the background canvas.
- **Content layer** (`surfaceContainerLowest`): Pure white. Cards, sheets, nav bars, dialogs sit as white panels on the grey canvas.
- **Separation**: `outlineVariant` borders, not elevation or tonal tint. Cards on white sheets are distinguished by their border, not by shadow or color difference.

This collapses M3's five-level surface container gradient to two tiers. The design choice: strong grey/white contrast is clearer than M3's subtle tonal steps, and simpler to reason about.

The model classifies every new component into one of five categories:
1. **Scaffold-level** → `surface` (grey)
2. **Content-level** → `surfaceContainerLowest` (white)
3. **Inherit parent** → no background override
4. **Inverse** → M3 default (snackbar, tooltip)
5. **Separation** → `outlineVariant` border, not elevation

Dark mode adaptation: The grey scaffold at light T96 has no direct dark equivalent. In dark mode, `surface` sits at a standard dark value, and the content surfaces use their standard darker tones. The two-tier visual model is specifically a light-mode expression of the philosophy.

### Typography Principle

Use M3's `textTheme` styles as-is. No `copyWith` overrides for weight, spacing, or other properties unless a genuinely missing text style is needed. Exceptions are permitted for:
- **Functional needs** (e.g., monospace for tabular data alignment)
- **Information hierarchy** (e.g., bold for time-critical data)

If the type scale feels wrong, refactor the `TextTheme` at the theme level — don't sprinkle `copyWith` across widgets. A consistent type scale matters more than pixel-matching Figma.

### Presentation-Only Widgets

Design system widgets are pure functions: data in, pixels out.
- No providers, no services, no async loading
- No `ConsumerWidget` / `ConsumerStatefulWidget`
- No FRB-generated types in props (breaks web/Widgetbook compilation)
- Feature screens wire state to widgets

This is orthogonal to color philosophy but synergistic: a presentation-only widget that gets all its colors from the theme is inherently portable, testable, and Widgetbook-compatible.

### M3-First Component Strategy

After building 9 widgets, 5 of which reimplemented standard M3 interaction patterns (incompletely — missing ripple, focus, keyboard, hover, and semantics), the system adopted M3 components as the default:
- **Use M3 components** where interaction maps to standard patterns (buttons, chips, tabs, navigation, sheets)
- **Use primitives** where visuals are truly custom (challenge cards, score headers, category icons)

The token system, color philosophy, and presentation-only architecture are orthogonal to this choice. M3 components receive their achromatic colors from the `ColorScheme` and their semantic colors from `AppSemanticColors` — the philosophy works with or without M3 components.

### APCA-Verified Contrast

The system uses APCA (Accessible Perceptual Contrast Algorithm) rather than WCAG 2.x for contrast verification:
- **Body text**: Lc >= 90 (very high perceptual contrast)
- **Accents/icons**: Lc >= 60 (medium perceptual contrast)
- **Borders/dividers**: Lc >= 30 (minimum perceptual contrast)

APCA is more perceptually accurate than WCAG 2.x's simple luminance ratio, but not yet a finalized standard (still draft in WCAG 3.0). The three contrast levels (standard/medium/high) provide an accessibility progression that addresses this uncertainty.

---

# Part 2: First-Principles Ideal M3 Implementation

*Designed from the principles in Part 1 and M3 specification knowledge. No reference to current implementation details.*

---

## 2A. Color Architecture — The Full Role Map

### Design Approach

M3's `ColorScheme` has ~45 roles organized around a chromatic seed. The "color is expensive" principle subverts this: the seed is achromatic, which means M3's tonal palette generation produces a greyscale gradient. The challenge is making an achromatic `ColorScheme` that remains functionally correct — every role must serve its M3 purpose, even without hue.

### `ColorScheme.fromSeed()` vs Manual Specification

`ColorScheme.fromSeed()` with an achromatic seed (e.g., neutral grey) produces a grey tonal palette, but with trace chroma from M3's HCT color space. The generated values may carry faint warm or cool tints that are unpredictable and hard to control.

**Ideal approach:** Manual specification of all `ColorScheme` values, not `fromSeed()`. This gives precise control over every grey, ensures zero unwanted tint, and allows APCA verification of every pairing. The trade-off is maintenance burden (updating ~45 values manually), but for a "color is expensive" system, precision matters more than convenience.

### Primary Family

| Role | Ideal Approach | Rationale |
|------|---------------|-----------|
| `primary` | Near-black (~T15-20, light) / Near-white (~T85-90, dark) | The "attention locker." Maximum contrast against surface. Achromatic — distinguished from body text by shape (button), not by color. In dark mode, primary lightens to near-white for the same contrast inversion. |
| `onPrimary` | White (light) / Near-black (dark) | Maximum contrast on primary fill. Simple inversion. |
| `primaryContainer` | Light grey (~T90, light) / Dark grey (~T25, dark) | Toned-down version of primary for less prominent uses. Still achromatic but visually distinct from surface. |
| `onPrimaryContainer` | Near-black (light) / Light grey (dark) | Readable text on the container. |

**Dark mode principle:** Primary inverts lightness — near-black becomes near-white. The *function* (attention locker, maximum contrast CTA) is preserved; the *means* changes with the backdrop.

### Secondary Family

| Role | Ideal Approach | Rationale |
|------|---------------|-----------|
| `secondary` | Mid-grey from neutral-variant palette (~T40, light) / (~T80, dark) | Structural emphasis without hue. Cool-leaning (neutral-variant) to subtly differentiate from pure-neutral tertiary. Used for `FilledTonalButton`, filter chips, secondary actions. |
| `onSecondary` | White (light) / Dark grey (dark) | Contrast pairing. |
| `secondaryContainer` | Light cool grey (~T90, light) / Dark cool grey (~T30, dark) | Tonal fill for secondary interactive elements. Must have visible contrast against `surface` — at least ΔY 10 to avoid the "invisible container" problem. |
| `onSecondaryContainer` | Near-black (light) / Light grey (dark) | Text on container. |

**Distinction from primary:** Secondary is lighter and cooler than primary. Primary is the heavy ink; secondary is the medium-weight structure. The contrast hierarchy: primary > secondary > tertiary (ghost).

### Tertiary Family (Ghost Role)

| Role | Ideal Approach | Rationale |
|------|---------------|-----------|
| `tertiary` | Mid-grey from pure neutral palette (~T47, light) — barely clearing APCA Lc 60 against surface | The ghost role. Must be technically accessible (Lc >= 60 for accent use) but practically invisible. Pure neutral (zero cool-lean) to distinguish from secondary's cool bias. |
| `onTertiary` | White (light) / Dark grey (dark) | Functional pairing — rarely seen in practice. |
| `tertiaryContainer` | Nearly identical to `surface` (~T94-95, light) / Nearly identical to dark surface (dark) | The trap: ΔY ~5-6 from surface. A developer using `tertiaryContainer` gets a background nearly indistinguishable from the page. |
| `onTertiaryContainer` | Mid-grey (light) / Light grey (dark) | Functional but low-emphasis. |

**Contrast cascade:** At medium contrast, tertiary values shift toward normal M3 visibility. At high contrast, the ghost effect disappears entirely. This is modeled as three separate `ColorScheme` instances (standard/medium/high), not runtime adjustments.

### Error Family

| Role | Ideal Approach | Rationale |
|------|---------------|-----------|
| `error` | Signal red (standard M3 error red, ~M3's `#B3261E` or nearby) | Error is the one place chromatic color is *required* in the `ColorScheme`. Red is universal, expected, and necessary. No restraint — error must be immediately visible. |
| `onError` | White (light) / Dark (dark) | Maximum contrast on error fill. |
| `errorContainer` | Light red tint (light) / Dark red tint (dark) | Softer error backgrounds for banners, inline messages. |
| `onErrorContainer` | Dark red (light) / Light red (dark) | Readable text on error container. |

**Why error stays chromatic:** "Color is expensive" means color must carry meaning. Error is the most universal chromatic meaning in UI design. Removing red from errors would be restraint for its own sake — not principled restraint.

### Surface System

| Role | Ideal Approach | Rationale |
|------|---------------|-----------|
| `surface` | Visible grey (~T96, light). Standard dark tone (~T10-12, dark). | The grey "paper" substrate. Slightly darker than M3's default near-white (~T99), creating a visible canvas that makes white content surfaces pop. |
| `surfaceDim` | Darker grey (~T87, light) / Deepest dark (~T6, dark) | For areas that need to recede below the standard surface. |
| `surfaceBright` | Near-white (~T98, light) / Brighter dark (~T24, dark) | For areas that need to stand above the standard surface. |

**Five-Level Container Gradient:**

| Container Level | Light (ideal) | Dark (ideal) | Purpose |
|----------------|---------------|-------------|---------|
| `surfaceContainerLowest` | Pure white (T100) | Very dark (~T4-6) | The white content layer — cards, sheets, nav bars. This is the "content paper." |
| `surfaceContainerLow` | Near-white (~T96) | Dark (~T10-12) | Subtle step above lowest. Available for fine differentiation. |
| `surfaceContainer` | Light grey (~T94) | Dark (~T12-14) | M3's default component surface. |
| `surfaceContainerHigh` | Medium grey (~T92) | Medium dark (~T17-20) | Elevated-feel components. |
| `surfaceContainerHighest` | Darker grey (~T89) | Lighter dark (~T22-24) | Highest-emphasis surface. |

**Two-tier usage model:** Despite defining all five levels, the "color is expensive" system primarily uses only two: `surface` (grey scaffold) and `surfaceContainerLowest` (white content). The other three levels are available for edge cases but are not the default.

### Text and Content Colors

| Role | Ideal Approach | Rationale |
|------|---------------|-----------|
| `onSurface` | Near-black (~T10, light) / Near-white (~T93, dark) | Primary text color. High contrast against surface. In light mode, this is the same darkness range as `primary` — distinguished by context (text vs button), not by lightness. |
| `onSurfaceVariant` | Medium-dark grey (~T30, light) / Medium-light grey (~T75, dark) | Secondary text, icons, captions. Visibly lighter than `onSurface` but still comfortably above APCA Lc 60. |

### Structural Colors

| Role | Ideal Approach | Rationale |
|------|---------------|-----------|
| `outline` | Medium grey (~T46, light) / Medium grey (~T56, dark) | Important boundaries — input field borders, focus indicators. Must be visible against both `surface` and `surfaceContainerLowest`. |
| `outlineVariant` | Light grey (~T77, light) / Dark grey (~T36, dark) | Decorative boundaries — card borders, dividers. Lighter touch than `outline`. This is the primary separation mechanism in the two-tier model (borders, not elevation). |

### Inverse and Overlay

| Role | Ideal Approach | Rationale |
|------|---------------|-----------|
| `inverseSurface` | Dark grey (~T20, light) / Light grey (~T90, dark) | Snackbar and tooltip backgrounds. Maximum contrast against the current surface for transient, high-attention overlays. |
| `inversePrimary` | Light grey (~T78, light) / Near-black (dark) | Text/icons on inverse surfaces. Achromatic, consistent with the rest. |
| `shadow` | Black | Standard shadow color. Used sparingly — the system prefers borders over elevation. |
| `scrim` | Black | Dialog/sheet backdrop darkening. Standard M3 usage. |

### surfaceTint

| Role | Ideal Approach | Rationale |
|------|---------------|-----------|
| `surfaceTint` | Transparent (or primary, with all `surfaceTintColor` overrides set to transparent) | M3's surface tint system adds a primary-colored overlay to elevated surfaces. With an achromatic primary, the tint would be grey — functionally a brightness shift, not a color shift. Rather than rely on this subtle and often imperceptible effect, the ideal system disables tint entirely and uses the two-tier model plus borders for hierarchy. |

### Fixed/Dim Variants

M3's `primaryFixed`, `primaryFixedDim`, `secondaryFixed`, `secondaryFixedDim`, `tertiaryFixed`, `tertiaryFixedDim` are designed for elements that should maintain the same tone regardless of light/dark mode (e.g., a colored header that stays the same color in both modes).

**In a restrained system:** These have limited utility because the structural roles are achromatic. However, they should still be specified as neutral greys, consistent with their parent role. They serve as a fallback for any M3 component that reaches for them.

---

## 2B. Semantic Color Extension Architecture

### Number of Semantic Groups

The ideal number is determined by the application's domain vocabulary, not by a universal rule. The principle: **as few as possible, as many as necessary.**

For this application (a blockchain challenge/gamification platform), four semantic groups align with the domain model:

| Group | Represents | Hue Family |
|-------|-----------|------------|
| **Technical** | Computation, code, precision challenges | Blue |
| **Flash** | Time-limited, urgency, energy challenges | Amber/warm |
| **Community** | Social, participation, growth challenges | Green |
| **Success** | Completion, achievement, positive outcome | Green (different tone than community) |

If the application expands, a **fifth** group ("warning" — amber, distinct from flash) might be needed. But the principle says: add it when a real use case demands it, not speculatively.

### The 4-Role Pattern

Each semantic group mirrors M3's own color role pattern:

| Sub-role | Purpose | Usage |
|----------|---------|-------|
| `color` | Standalone accent — icons, small indicators, text highlights | Badge dot, category icon tint |
| `onColor` | Text/icons placed directly on the `color` fill | Icon on a filled badge |
| `colorContainer` | Tinted background — larger areas like cards, chips, banners | Challenge card background tint |
| `onColorContainer` | Text/icons on the `colorContainer` background | Title text on a tinted card |

**Keep this pattern.** It matches M3's role model exactly, which means M3 components can consume semantic colors naturally (e.g., a `Chip` with `backgroundColor: semantic.technical.colorContainer`).

**Potential extension:** A `colorBorder` role (for container outlines in the semantic color) could be useful but should only be added if multiple widgets need it. One widget needing it is not justification — use `color.withValues(alpha: 0.3)` locally.

### Relationship to M3's `harmonize()` and Custom Color API

M3's Material Color Utilities library provides `harmonize()` to shift a custom color's hue slightly toward the primary palette, creating visual cohesion. With an achromatic primary, harmonization is a no-op (there's no primary hue to harmonize toward). This is ideal — semantic colors maintain their pure, unshifted hues, maximizing distinctiveness.

If the system ever adopted a chromatic primary, harmonization would become a question: do you want semantic blue shifted toward the primary hue? In a "color is expensive" system, the answer is no — semantic colors should be maximally distinct from each other and from primary. Distinctiveness > cohesion for a limited chromatic vocabulary.

### Contrast Cascade Strategy

Each semantic group needs three variants: standard, medium contrast, and high contrast. The approach:

| Contrast Level | `color` | `colorContainer` |
|---------------|---------|-------------------|
| **Standard** | Optimized for APCA Lc >= 60 on `surface` | Light tint with APCA Lc >= 90 for `onColorContainer` text |
| **Medium** | Darkened for higher Lc | Slightly more saturated container |
| **High** | Maximum contrast — darkened further, potentially shifted | Strongly tinted container with high onContainer contrast |

In dark mode, the cascade works in reverse — standard dark colors are lighter/pastel, and high contrast variants are even lighter.

### Tonal Palette vs Flat 4-Role Groups

M3 generates full tonal palettes (13 tones from T0 to T100) for each color. Should semantic groups have their own palettes?

**Ideal answer: No.** Flat 4-role groups are sufficient. Tonal palettes are useful when a color needs to appear at many different emphasis levels across many components. Semantic colors in this system appear in limited, controlled contexts. A 4-role group covers: strong accent, text on accent, subtle background, text on background. That's enough.

If a future need arises (e.g., 6+ components using the same semantic color at different emphasis levels), tonal palettes can be generated per-group. But the principle of "color is expensive" argues against making chromatic color *easier* to use at many levels — that encourages proliferation.

### Dark Mode Semantic Color Derivation

**Ideal approach: Manual specification, not algorithmic generation.**

In dark mode, semantic colors should:
- **Lighten the accent** (`color`) to maintain Lc >= 60 against the dark surface
- **Darken the container** (`colorContainer`) while keeping it distinct from the dark surface
- **Ensure `onColorContainer`** has Lc >= 90 against the container

Algorithmic generation (e.g., shifting tonal values by a fixed amount) risks producing colors that fail APCA or look washed out. Manual specification with APCA verification for each dark pairing is more work but ensures quality. Given only 4 groups × 4 roles × 3 contrast levels = 48 values per mode, manual specification is feasible.

---

## 2C. Theme Configuration Architecture

### Single Root vs Layered Theme Injection

**Ideal: Single `ThemeData` at `MaterialApp` root.**

Layered theme injection (wrapping individual screens with `Theme()` widgets) creates these problems:
- **Extension null crashes:** Any widget outside the `Theme()` boundary calling `Theme.of(context).extension<AppSpacing>()!` throws. This is fragile and hard to debug.
- **Brightness inconsistency:** The root theme toggles dark mode, but the local `Theme()` widget might hardcode `.light()`. The user sees dark chrome with light content.
- **Cognitive overhead:** Developers must reason about which theme boundary they're in. "Does this widget see the root theme or the design system theme?"

Single root eliminates all three problems. Every widget in the tree sees the same `ColorScheme` and `ThemeExtension` set.

**Feature-specific semantic colors:** If some features use `technical/flash/community` and others don't, register `AppSemanticColors` globally anyway. Unused semantic groups cost nothing at runtime — they're just theme extension values that no widget accesses. This is simpler than scoping extensions to features.

### ThemeExtension Registration

All extensions registered at the root:

| Extension | Scope | Rationale |
|-----------|-------|-----------|
| `AppSpacing` | Global | Spacing is universal |
| `AppRadii` | Global | Border radii are universal |
| `AppElevation` | Global | Elevation tokens are universal |
| `AppOpacity` | Global | Opacity values are universal |
| `AppSizing` | Global | Icon/container sizing is universal |
| `AppAnimation` | Global | Duration tokens are universal |
| `AppSemanticColors` | Global | Even if not all features use all groups, global registration prevents null crashes |

### Theme Provider Wiring

The ideal wiring for brightness:

```
MaterialApp(
  theme: buildTheme(Brightness.light),     // light ThemeData + all extensions
  darkTheme: buildTheme(Brightness.dark),  // dark ThemeData + all extensions
  themeMode: <user preference or system>,
)
```

Where `buildTheme(brightness)` constructs a `ThemeData` with:
1. The appropriate light/dark `ColorScheme`
2. All component theme overrides (AppBar, Card, NavigationBar, etc.)
3. All `ThemeExtension`s with brightness-appropriate values
4. The correct semantic color set (light or dark)

This leverages Flutter's built-in `themeMode` system — the framework handles brightness switching, and every widget sees the correct theme through `Theme.of(context)`.

### Dark Mode Design Principles

"Color is expensive" has different visual expressions in light vs dark mode:

| Aspect | Light Mode | Dark Mode |
|--------|-----------|-----------|
| **Surface hierarchy** | Grey scaffold / white content (two-tier) | Standard dark surfaces (M3 dark defaults) — the two-tier *visual* model is light-only |
| **Primary** | Near-black on light backgrounds | Near-white on dark backgrounds — same *function* (attention locker), opposite lightness |
| **Ghost tertiary** | Nearly invisible grey | Ghost effect maintained — container nearly matches dark surface |
| **Semantic colors** | Saturated accents on light backgrounds | Lighter/pastel accents on dark backgrounds — APCA-verified for dark surfaces |
| **Borders** | `outlineVariant` visible as light grey on white | `outlineVariant` visible as dark grey on dark surfaces |
| **Overall feel** | Ink-on-paper newspaper aesthetic | Dark mode preserves the restraint but loses the "newspaper" metaphor. It becomes more of a "terminal/dashboard" aesthetic — dark substrate, sparse bright signals. |

**Contrast levels in dark mode:** The standard/medium/high contrast cascade works identically. Ghost tertiary stays ghost at standard; progressively restores at medium/high.

### Token System Design

**Which categories need ThemeExtensions?**

All seven are justified:

| Extension | Why It Exists | Could M3 Replace It? |
|-----------|--------------|---------------------|
| `AppSpacing` | Consistent spacing scale | Flutter has no built-in spacing token API. M3 uses 4dp grid but doesn't expose it as a theme property. |
| `AppRadii` | Consistent border radius scale | M3 has `ShapeBorder` but no radius token API. |
| `AppElevation` | Controlled elevation levels | M3 elevation is per-component, not a global token. |
| `AppOpacity` | Consistent opacity levels | No M3 equivalent. |
| `AppSizing` | Icon and container size scale | M3 has `iconSize` on individual components, not a global scale. |
| `AppAnimation` | Duration tokens | M3 motion spec exists but Flutter doesn't expose it as tokens. |
| `AppSemanticColors` | Chromatic color vocabulary | M3's "custom colors" concept, but no built-in Flutter API. |

**Alignment with M3 values:** Token values should be M3-aligned where possible:
- Spacing: Already matches M3's 4dp grid
- Radii: Should match M3's shape scale (extra-small=4, small=8, medium=12, large=16, extra-large=28, full=∞)
- Elevation: Should include M3's standard levels (0, 1, 3, 6, 8, 12) even if the system rarely uses elevation
- Animation: Should include M3's standard motion durations (50, 100, 250, 300, 450ms)

**Adaptive tokens:** Fixed values, not adaptive. Accessibility is handled through the contrast cascade (which provides alternative `ColorScheme` and `AppSemanticColors` sets), not through token value changes. Spacing, radii, and sizing don't need platform-specific adaptation in a mobile-only app.

---

## 2D. Component Color Application Strategy

### High-Emphasis Interactive Components

**`FilledButton` / `ElevatedButton`:**
Achromatic primary is correct for the highest-emphasis CTA. The button's power comes from its shape and fill-weight against the light background — not from hue. A near-black button on a light surface is maximally attention-grabbing. In dark mode, a near-white button on a dark surface achieves the same.

When a button *needs* to carry semantic meaning (e.g., "Start Technical Challenge"), the screen wraps it with the appropriate semantic color override: `FilledButton(style: FilledButton.styleFrom(backgroundColor: semantic.technical.color))`. This is an explicit, local decision — not a theme-level change.

**`FloatingActionButton`:**
In a restrained system, FAB is problematic. It's a large, prominent, always-visible colored circle — the definition of "expensive color." Ideal approach: either don't use FAB (prefer an in-content action), or render it achromatic (primary fill). If the FAB *must* carry semantic meaning, it gets a semantic color override locally.

**`Switch`, `Checkbox`, `Radio`:**
Achromatic primary for the active/selected state. These are binary state indicators — on/off, checked/unchecked. The state information is structural, not semantic. A dark "on" indicator and a grey "off" indicator are sufficient. M3's default behavior of rendering these in `primary` works perfectly with an achromatic primary.

**`Slider`, `RangeSlider`:**
Achromatic primary for the track and thumb. Value selection is structural. If a slider controls something semantically meaningful (e.g., a "challenge difficulty" slider), the screen applies a semantic color override.

### Navigation Components

**`NavigationBar` (bottom navigation):**
- **Background:** White (`surfaceContainerLowest`) on the grey scaffold — content-level surface.
- **Indicator:** M3 default `secondaryContainer` — achromatic grey pill. The active destination is communicated by the indicator shape and the icon/label emphasis change, not by color.
- **Active icon/label:** `onSecondaryContainer` (or `onSurface` — both dark grey). The distinction is shape (indicator presence), not hue.
- **Inactive icon/label:** `onSurfaceVariant` — lighter grey for de-emphasis.
- **No per-destination semantic colors.** The navigation bar is structural infrastructure. Destination semantics live in the *content* of each page, not the nav.

**`TabBar`:**
- **Indicator:** `primary` — achromatic ink bar under the active tab.
- **Active tab label:** `primary` or `onSurface`.
- **Inactive tab label:** `onSurfaceVariant`.
- Tabs inherit their parent surface — no background override.

**`AppBar`:**
- **Background:** `surface` (grey scaffold level) — the AppBar is scaffold infrastructure.
- **Scroll-under behavior:** No tonal elevation shift (`scrolledUnderElevation: 0`). The grey AppBar stays grey when content scrolls beneath it. Alternative scroll feedback: an `outlineVariant` bottom border that appears on scroll, providing separation without tonal tint.
- **Foreground:** `onSurface` for title and icons.

**`NavigationDrawer`:**
- **Background:** `surfaceContainerLowest` (white) — content-level surface.
- **Selected indicator:** `secondaryContainer` — achromatic grey, same approach as `NavigationBar`.
- **Elevation:** 0 — flat. Scrim provides separation from the underlying content.

### Containment Components

**`Card`:**
- Default variant: **Outlined** (`surfaceContainerLowest` background + `outlineVariant` border + elevation 0).
- This is the standard M3 outlined card variant. In the two-tier surface model, cards on white content sheets are distinguished by their border, not by tonal difference or shadow.
- Cards that carry semantic meaning (e.g., a challenge card) get their semantic color through the *content* layer (a colored badge, a tinted accent strip), not through the card background.

**`Dialog`:**
- **Background:** `surfaceContainerLowest` (white) — content-level surface.
- **Elevation:** 0 — flat. The scrim overlay provides sufficient separation. No shadow needed.
- **Shape:** M3 standard r28 (extra-large radius).
- **Why no elevation:** In a flat, border-based system, dialogs don't need shadow to feel "above" the content. The scrim darkens the background, creating clear figure/ground separation.

**`BottomSheet`:**
- **Background:** `surfaceContainerLowest` (white) — content-level surface.
- **Elevation:** 0 — flat. The drag handle and edge-to-edge position provide structural separation.
- **Shape:** Rounded top corners (r28 or per design).

**`Chip` variants:**
- `FilterChip`: Achromatic — uses `secondaryContainer` when selected, `surfaceContainerLowest` + `outlineVariant` border when unselected. Selection state is structural.
- `InputChip`: Same achromatic treatment.
- `SuggestionChip`: `outlineVariant` border, no fill. Lightest touch.
- `AssistChip`: `outlineVariant` border. If the chip carries semantic meaning (e.g., a "Technical" category chip), apply semantic color locally.

### Feedback Components

**`CircularProgressIndicator` / `LinearProgressIndicator`:**
- Default: `primary` — achromatic. Progress is structural (something is loading), not semantic.
- When progress is semantically meaningful (e.g., "Technical challenge progress"), apply `semantic.technical.color` locally.
- Track: `surfaceContainerHighest` or `outlineVariant` — light grey background track.

**`SnackBar`:**
- **Background:** `inverseSurface` — dark on light, light on dark. Maximum contrast for transient messages.
- **Text:** `inverseOnSurface` / `inversePrimary`.
- **Action button:** `inversePrimary` for the text button.
- Standard M3 treatment. Snackbars are transient and high-urgency — they should stand out. The inverse treatment is already maximally contrasty.

**`Banner` / `MaterialBanner`:**
- **Background:** `surface` or `surfaceContainerLowest`, depending on placement.
- **When carrying error/warning:** Use `errorContainer` + `onErrorContainer` for error banners. For other severities, use semantic colors.

**`ProgressIndicator` (determinate):**
- Same as circular/linear. Achromatic by default, semantic color when the progress *represents* a semantically meaningful domain concept.

### Data Visualization and Status

**Charts and graphs:**
This is where "color is expensive" must relax its constraints. Data visualization *requires* chromatic differentiation — a pie chart with five grey segments is unreadable. The approach:

- Data visualization gets its own color extension (separate from `AppSemanticColors`): a `DataVizColors` extension with a palette of 6-8 perceptually distinct colors, APCA-verified for both light and dark surfaces.
- These colors are used *only* in chart/graph widgets and are *not* available through the standard `ColorScheme` or `AppSemanticColors`. This prevents them from leaking into structural UI.

**Status indicators (badges, dots, status text):**
- Use `AppSemanticColors` where the status maps to a semantic group (technical → blue, flash → amber, etc.).
- Use `error` for error/failed states.
- Use `onSurface` + `onSurfaceVariant` for neutral/informational status (e.g., "pending" — grey is fine for "nothing to report").
- If a new status type emerges that doesn't map to an existing group, evaluate whether it warrants a new semantic group or can be expressed with the existing palette + text labels.

---

## 2E. The Escape Hatch Taxonomy

### 1. Error (M3 Built-in)

| Aspect | Design |
|--------|--------|
| **When allowed** | System errors, validation failures, destructive actions, connection failures |
| **How it enters** | Built into `ColorScheme.error*` — always available, no extension needed |
| **Leak prevention** | Error roles are semantically specific. Using `error` for "warning" or "attention" is a misuse that code review should catch. |

### 2. Semantic Extension (AppSemanticColors)

| Aspect | Design |
|--------|--------|
| **When allowed** | Domain-specific meaning: challenge categories, completion states |
| **How it enters** | `ThemeExtension<AppSemanticColors>` registered at root. Accessed via `Theme.of(context).extension<AppSemanticColors>()!` |
| **Leak prevention** | API forces semantic naming: `semantic.technical.color`, not `Colors.blue`. Adding a new group requires updating the extension class — a deliberate, reviewable decision. |

### 3. Data Visualization

| Aspect | Design |
|--------|--------|
| **When allowed** | Charts, graphs, maps — multi-variable data that requires chromatic differentiation |
| **How it enters** | A separate `ThemeExtension<DataVizColors>` with a curated palette. Registered globally but only accessed by visualization widgets. |
| **Leak prevention** | Separate extension class. Widget-level containment: data viz widgets import `DataVizColors`, non-viz widgets don't. Linting or code review can enforce this boundary. |

### 4. Transient Emphasis

| Aspect | Design |
|--------|--------|
| **When allowed** | Animated glows, progress arcs, celebration states (confetti, achievement), loading shimmer |
| **How it enters** | Locally in the widget's animation code, using either `AppSemanticColors` (if the emphasis is domain-relevant) or a fixed palette for universal effects (e.g., gold confetti for any achievement). |
| **Leak prevention** | Transient by nature — these effects have a start and end. They don't persist in the resting UI. Code review ensures the color doesn't "stick" after the animation completes. |

### 5. Platform Conventions

| Aspect | Design |
|--------|--------|
| **When allowed** | iOS-blue hyperlinks, platform-standard selection colors, system-provided colors |
| **How it enters** | M3 already handles some (e.g., `SelectionControls` use platform colors). For explicit cases (like a URL link styled in platform blue), use `Theme.of(context).colorScheme.primary` on iOS (which is achromatic in this system, potentially wrong) or the platform default. |
| **Leak prevention** | This is the trickiest escape hatch. An achromatic primary means "tappable" is communicated by shape, not by blue-ness. This breaks the iOS convention of "blue = tappable." Resolution: accept that in-app links may need a one-off semantic color (or use `AppSemanticColors.technical.color` for link-like elements if the domain fits). |

---

## 2F. The Design Honor Test

### Test 1: Achromatic Primary

**Claim:** "Achromatic primary honors 'color is expensive' because it removes the largest source of ambient chromatic color in M3. Buttons, switches, progress indicators — the most common interactive elements — all become grey, reserving hue for semantic signals."

**Counter-argument:** "M3's chromatic primary exists for a reason: brand identity and visual wayfinding. Users expect colored buttons to signal 'tappable.' An achromatic primary makes CTAs harder to distinguish from static text elements (both are dark). Research on button affordance shows that color is a primary cue for interactivity. You're sacrificing usability for aesthetic restraint."

**Resolution:** The trade-off is real. Achromatic primary requires that button affordance comes from *shape* (filled rectangle, rounded corners, elevation), *size* (minimum 48dp touch target), and *typography* (label text style) rather than color contrast against body text. This is achievable — iOS has used borderless colored text for buttons and native apps often use monochrome filled buttons successfully. However, the system must ensure that `FilledButton` has sufficient visual weight through fill, padding, and typography to be immediately recognizable as interactive. If usability testing shows users missing CTAs, the principle should yield: add a subtle tint (e.g., very-low-chroma cool primary) rather than abandon the approach entirely. The principle isn't dogma — it's a starting position.

### Test 2: Ghost Tertiary

**Claim:** "The ghost tertiary honors 'color is expensive' by making the M3 tertiary role a trap that forces developers toward AppSemanticColors, preventing casual chromatic color in structural elements."

**Counter-argument:** "M3's tertiary role exists to provide a third accent for visual balance and extended expression. By ghosting it, you're reducing your design vocabulary. You're also making `tertiaryContainer` useless — any widget that needs three distinct background tones (e.g., a settings page with grouped sections) loses its third option. Third-party packages that use `tertiary` will render invisibly, causing confusing visual bugs."

**Resolution:** The ghost tertiary is a strong design stance that has real costs. Third-party package incompatibility is the most practical concern — a date picker package using `tertiary` for accent would render invisibly. Mitigation: the contrast cascade restores tertiary at medium/high contrast, and the system can document known incompatible packages. For the three-background-tone problem: the five surface container levels provide tonal differentiation without hue. The ghost tertiary is defensible as a guardrail for a small team, but should be reconsidered if the codebase grows to include many third-party M3 packages with tertiary dependencies.

### Test 3: Two-Tier Surface Model

**Claim:** "Collapsing M3's five surface container levels to two (grey scaffold, white content) honors 'color is expensive' by simplifying the surface vocabulary to its minimum: background and foreground."

**Counter-argument:** "M3's five-level tonal gradient exists for information hierarchy. A NavigationBar, a Card, and a Dialog at different tonal levels tells the user about their relative importance and depth. By flattening everything to white, you lose this z-axis signaling. The only remaining differentiation is borders — a weaker visual cue than tonal difference. Complex screens with nested surfaces (card-in-sheet-in-scaffold) become ambiguous."

**Resolution:** The two-tier model trades tonal subtlety for clarity. The grey/white contrast is stronger and more legible than M3's subtle 2-3% lightness differences between container levels. For simple layouts (scaffold → sheet → cards), borders provide clear nesting. For complex layouts (deeply nested surfaces), the model may need to *selectively* use intermediate container levels. The five levels remain available in the `ColorScheme` — the two-tier model is a usage convention, not a limitation. This is defensible as a default, with the escape hatch of using more levels when nesting depth demands it.

### Test 4: Disabled Surface Tint

**Claim:** "Disabling surfaceTintColor honors 'color is expensive' by removing M3's subtle primary-tinted elevation overlay, keeping surfaces purely achromatic."

**Counter-argument:** "Surface tint is M3's answer to 'how do elevated surfaces differ from flat ones?' Without tint, elevated and flat surfaces are identical. Even with an achromatic primary, surface tint would create subtle lightness shifts that signal z-position. Disabling it removes a free, built-in visual cue. Combined with elevation 0 on most components, the system has *no* z-axis signaling beyond borders."

**Resolution:** With an achromatic primary, surface tint produces a grey-on-grey lightness shift that is nearly imperceptible — typically 1-2% lightness difference. This is so subtle that it barely registers perceptually, while adding implementation complexity (tint interacts with elevation, container level, and brightness). Borders are a stronger, more intentional separation mechanism. The tint is *theoretically* useful but *practically* invisible with an achromatic seed. Disabling it is defensible. If the system ever adopted a chromatic primary, surface tint should be re-evaluated.

### Test 5: Error Stays Chromatic

**Claim:** "Keeping error as full chromatic red honors 'color is expensive' by demonstrating that the principle is about *purpose*, not about minimizing color for its own sake. Error *earns* its color through universal semantic meaning."

**Counter-argument:** "If you truly commit to 'color is expensive,' why not make error achromatic too? An error state could be communicated through icon (warning triangle), text ('Error: ...'), and layout (red border → grey border) without a red fill. Some monochrome design systems do exactly this. Keeping red for error but denying it for everything else is an inconsistent application of restraint."

**Resolution:** The principle is "every chromatic pixel must earn its place through semantic purpose" — not "no chromatic pixels." Error is the single most universal color-meaning mapping in interface design. Removing it would force users to decode error states from text and icons alone, increasing cognitive load for one of the most important UI signals. This is principled restraint, not dogmatic minimalism. The line is drawn at: "does the color meaning have universal recognition?" Red for error: yes. Blue for brand: no (brand identity can come from typography and layout). This test actually *validates* the principle — it proves the system allows chromatic color where earned.

### Test 6: Single-Root Theme vs Layered Injection

**Claim:** "A single root theme honors the design principles by ensuring every widget in the tree sees the same achromatic ColorScheme and semantic extensions, preventing 'theme boundary' bugs."

**Counter-argument:** "Layered themes are useful for progressive migration. You can introduce the design system in one feature without disrupting the rest of the app. A single root theme is all-or-nothing — you can't partially adopt 'color is expensive.' Also, different features may legitimately need different semantic color sets (wallet vs challenges), and a single root forces all extensions to be global."

**Resolution:** The migration concern is valid. The ideal end-state is a single root theme, but the migration *path* may require temporary layered injection. The recommendation: target single-root as the architecture, use layered injection only as a transitional state, and document the migration plan. For feature-specific semantics: register all extensions globally with their full value set. Unused extensions cost nothing. A wallet feature that doesn't use `technical/flash/community` simply never accesses those properties. This is simpler and more robust than scoped registration.

### Test 7: Manual ColorScheme vs fromSeed()

**Claim:** "Manual ColorScheme specification honors 'color is expensive' by giving precise control over every grey value, ensuring zero unwanted tint and enabling exact APCA verification."

**Counter-argument:** "ColorScheme.fromSeed() exists because manually maintaining 45+ color values is error-prone and doesn't scale. When you need a new contrast level or want to adjust the overall lightness, you're updating dozens of values by hand. fromSeed() with a neutral grey seed would produce a reasonable approximation with one line of code. You're choosing maintenance burden over convenience for marginal quality gains."

**Resolution:** The marginal quality gains are not marginal in this system. "Color is expensive" means every color value is a deliberate decision. `fromSeed()` with a grey seed introduces trace chroma from HCT color space conversion that's invisible but measurable — and the system's APCA pipeline needs exact values. The maintenance burden is real but bounded: ~45 ColorScheme values × 6 variants (light/dark × 3 contrast levels) = ~270 values total. These change rarely (theme redesigns, not feature work). Manual specification is the right choice for a system that treats every color as expensive — including the greys.

### Test 8: Data Visualization Exemption

**Claim:** "Exempting data visualization from 'color is expensive' honors the principle by recognizing that data viz has fundamentally different color requirements — multi-variable differentiation requires chromatic contrast that achromatic palettes cannot provide."

**Counter-argument:** "If you exempt data viz, where do you draw the line? Status badges need differentiation too. So do category indicators, progress rings, and user avatars. Each exemption erodes the principle. A truly committed 'color is expensive' system would find achromatic solutions for data viz — pattern fills, texture, labels, shape variation — like Edward Tufte's early work."

**Resolution:** The line is drawn at "can the information be conveyed without hue?" Status badges: yes (use the existing semantic colors — they're part of the system). Category indicators: yes (same). Data visualization with 5+ categories on a chart: no — shape and pattern are insufficient for rapid comparison at scale. Tufte himself uses color in later work (Beautiful Evidence, Visual Explanations). The exemption is narrow (dedicated data viz widgets with a separate color extension) and contained (the extension is only available in viz contexts). This is principled boundary-setting, not exemption creep.

---

*End of First-Principles Design document.*
