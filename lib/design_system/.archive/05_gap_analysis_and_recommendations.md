# Gap Analysis & Recommendations

> Archived from Intent workspace note `db5f7570-77a4-4cf3-a053-edc23f7069a0` (Feb 2026).
> Full unabridged research content.

---

Systematic comparison of the First-Principles Design (the ideal) against the Current Implementation Portrait (the reality), with actionable recommendations.

**Sources**: M3 Theme Audit for file:line references, UI Components Audit for component coverage data.

---

## 4A. Alignment Matrix

### 2A/3A — Color Architecture

| Area | Ideal (2A) | Current (3A) | Verdict |
|------|-----------|-------------|---------|
| **Primary role** | Near-black (~T15-20), manually specified, zero chroma | `#252627` near-black, zero chroma | **Aligned** |
| **onPrimary** | White (light) | `#FFFFFF` | **Aligned** |
| **primaryContainer** | Light grey (~T90) | Part of achromatic tonal palette | **Aligned** |
| **Secondary role** | Mid-grey from neutral-variant (~T40), cool-leaning | `#5C5E64` cool-grey from neutral-variant | **Aligned** |
| **secondaryContainer** | Light cool grey (~T90), ΔY ≥10 vs surface | `#E1E2E8` (~ΔL 5 vs `#F5F5F5`) | **Divergent** — marginal contrast (ΔL ~5 vs ideal ΔY ≥10) |
| **Tertiary (ghost)** | Pure neutral ~T47, Lc ~60, container ~ΔY 6 from surface | `#757575` pure neutral, container `#F5F5F5` ~ΔY 6 from surface | **Aligned** |
| **Error** | Signal red, chromatic, standard M3 range | `#BD0F19` — slightly more saturated than M3's `#B3261E` | **Aligned** (minor deviation) |
| **errorContainer** | Light red tint | `#FFBFA9` — warmer/more orange than M3's `#F9DEDC` | **Divergent** — cosmetic difference, APCA-verified |
| **Surface (scaffold)** | Visible grey ~T96 | `#F5F5F5` (T96) | **Aligned** |
| **surfaceContainerLowest** | Pure white (T100) | `#FFFFFF` | **Aligned** |
| **Surface gradient** | 5 levels defined, but 2-tier usage model (scaffold + content) | 5 levels defined, only 2 used in practice | **Aligned** |
| **onSurface / onSurfaceVariant** | Near-black ~T10 / mid-dark grey ~T30 | `#1B1B1B` / `#44474D` | **Aligned** |
| **outline / outlineVariant** | Medium grey ~T46 / light grey ~T77 | `#74777E` / `#C4C6CC` (near M3 defaults) | **Aligned** |
| **inverseSurface / inversePrimary** | Dark grey / achromatic light grey | `#303030` / `#C5C6C8` (achromatic) | **Aligned** |
| **surfaceTint** | Transparent (disabled) | `Colors.transparent` everywhere | **Aligned** |
| **ColorScheme construction** | Manual specification (not `fromSeed()`) | Manually specified in `color_is_expensive_theme.dart` | **Aligned** |
| **Contrast cascade** | 3 levels (standard/medium/high), ghost tertiary restores progressively | 3 levels implemented, APCA-verified | **Aligned** |
| **Dark mode scheme** | Full dark values with inverted lightness, same functions | Complete dark scheme support (`darkScheme()`, `dark()`) | **Aligned** (but see 3C dark mode gap) |
| **Fixed/Dim variants** | Specified as neutral greys consistent with parent role | Present in scheme | **Aligned** |

### 2B/3B — Semantic Color Architecture

| Area | Ideal (2B) | Current (3B) | Verdict |
|------|-----------|-------------|---------|
| **Number of groups** | 4 (technical, flash, community, success) — "as few as possible, as many as necessary" | 4 (technical, flash, community, success) | **Aligned** |
| **Group hue assignments** | Technical=blue, Flash=amber, Community=green, Success=green (different tone) | Technical=`#0055D9` blue, Flash=`#875300` amber, Community=`#146D32` green, Success=`#1A6D23` green | **Aligned** |
| **4-role pattern** | color/onColor/colorContainer/onColorContainer per group | Exactly this pattern in `SemanticColorGroup` | **Aligned** |
| **ThemeExtension delivery** | `ThemeExtension<AppSemanticColors>` registered at root | Registered via `DesignSystemTheme.standardExtensions()` | **Aligned** (but not at app root — see 3C) |
| **Contrast cascade variants** | 3 variants per group (standard/medium/high) | 4 variants (light/dark/mediumContrast/highContrast) | **Aligned** (exceeds ideal — has dark mode variant too) |
| **harmonize() relationship** | No-op with achromatic primary — semantic colors keep pure hues | No harmonization applied | **Aligned** |
| **Flat 4-role vs tonal palette** | Flat 4-role groups sufficient, no full tonal palettes | Flat 4-role groups | **Aligned** |
| **Dark mode derivation** | Manual specification, APCA-verified per pairing | `dark()` variant exists with manual values | **Aligned** |
| **colorBorder sub-role** | Only add if multiple widgets need it | Not present | **Aligned** |
| **Unmigrated screens** | All chromatic color via AppSemanticColors or error | 16 hardcoded `Colors.*` instances across 8 files bypass the gatekeeper | **Divergent** — gatekeeper is bypassed in unmigrated code |
| **Data visualization colors** | Separate `DataVizColors` ThemeExtension for charts | Not implemented — chart colors are hardcoded `Colors.*` | **Missing** |

### 2C/3C — Theme Configuration Architecture

| Area | Ideal (2C) | Current (3C) | Verdict |
|------|-----------|-------------|---------|
| **Theme injection** | Single `ThemeData` at `MaterialApp` root | Dual: legacy `MaterialTheme` at root + local `ColorIsExpensiveTheme` via `Theme()` widget at feature boundaries | **Divergent** — layered injection vs single root |
| **ThemeExtension registration** | All 7+1 extensions at root, globally available | Extensions only inside `Theme()` wrapper; app root has none | **Divergent** — extensions absent at root causes null crashes |
| **Dark mode wiring** | `MaterialApp(theme:, darkTheme:, themeMode:)` with brightness-aware buildTheme() | App root supports dark toggle, but design system boundary hardcodes `.light()` | **Divergent** — dark mode broken at DS boundary |
| **Feature-specific semantics** | Register all extensions globally; unused extensions cost nothing | `AppSemanticColors` only inside `Theme()` wrapper | **Divergent** — follows from layered injection |
| **Token values: spacing** | M3 4dp grid aligned | Exact match (4–48dp) | **Aligned** |
| **Token values: radii** | M3 shape scale (extra-small=4, small=8, medium=12, large=16, extra-large=28) | Close — `xLarge` is 24 vs M3's extra-large 28 | **Divergent** — minor, cosmetic |
| **Token values: elevation** | M3 levels (0/1/3/6/8/12) | 0/1/2/4/8 — missing levels 3 and 6, has non-standard 2 and 4 | **Divergent** — structural |
| **Token values: animation** | M3 motion (50/100/250/300/450ms) | 100/150/200/300ms — partial match, missing 50ms and 450ms | **Divergent** — minor |
| **Token adaptivity** | Fixed values, not adaptive | Fixed values | **Aligned** |
| **Legacy theme coexistence** | Single root is end state; layered injection only as transitional | Legacy `MaterialTheme` still at root with no migration timeline enforcement | **Divergent** — transitional state without clear end date |

### 2D/3D — Component Color Application

| Area | Ideal (2D) | Current (3D) | Verdict |
|------|-----------|-------------|---------|
| **FilledButton** | Achromatic primary, semantic override locally when needed | DS `Button` wraps `FilledButton`/`OutlinedButton`, achromatic via theme | **Aligned** |
| **NavigationBar background** | White (`surfaceContainerLowest`) on grey scaffold | `surfaceContainerLowest` | **Aligned** |
| **NavigationBar indicator** | `secondaryContainer` — achromatic grey pill | No `indicatorColor` override → M3 default `secondaryContainer` = grey `#E1E2E8` | **Aligned** |
| **AppBar** | `surface` background, `scrolledUnderElevation: 0`, border as scroll feedback | `surface`, `scrolledUnderElevation: 0`, but no scroll-state border | **Divergent** — missing scroll feedback alternative |
| **Card** | Outlined variant: `surfaceContainerLowest` + `outlineVariant` border + elevation 0 | Exactly this: `surfaceContainerLowest`, elevation 0, `outlineVariant` border, r16 | **Aligned** (r16 vs M3 r12 is cosmetic) |
| **Dialog** | `surfaceContainerLowest`, elevation 0, r28 | `surfaceContainerLowest`, elevation 0, r24 | **Divergent** — r24 vs ideal/M3 r28 |
| **BottomSheet** | `surfaceContainerLowest`, elevation 0 | Exactly this | **Aligned** |
| **Chip variants** | Achromatic (secondaryContainer selected, outlineVariant border unselected) | No chip theme override — M3 defaults apply with achromatic scheme | **Aligned** (by inheritance) |
| **ProgressIndicator** | Achromatic primary by default, semantic override for domain meaning | No override — M3 default uses primary (achromatic) | **Aligned** (by inheritance) |
| **SnackBar** | `inverseSurface` background, standard M3 | Floating, r12 | **Aligned** (r12 is cosmetic preference) |
| **Switch/Checkbox/Radio** | Achromatic primary for active state | No override — M3 default uses primary (achromatic) | **Aligned** (by inheritance) |
| **Divider** | `outlineVariant`, structural separation | `outlineVariant`, thickness 1, space 1 | **Aligned** (space:1 is intentional) |
| **ListTile** | Not explicitly covered in ideal | Dense + compact double-compaction, bodyMedium title | **Over-engineered** — touch target risk from double-compaction, not justified by ideal |
| **Component theme count** | Not prescribed — as many as needed | 9 component themes overridden | **Aligned** |
| **DS widget catalog** | M3-backed for interaction patterns, primitives for custom visuals | 18 DS widgets: M3-backed (Button, BottomNav, Tabs) + custom (ChallengeCard, ScoreHeader) | **Aligned** |
| **Unmigrated screen components** | All should use theme system | 25/31 screens unmigrated; 12 core widgets with mixed patterns | **Divergent** — large migration surface |

### 2E/3E — Escape Hatches

| Area | Ideal (2E) | Current (3E) | Verdict |
|------|-----------|-------------|---------|
| **Error (M3 built-in)** | Always chromatic, always available via `ColorScheme.error` | `#BD0F19` via colorScheme — used correctly | **Aligned** |
| **Semantic extension** | `AppSemanticColors` as only sanctioned chromatic path; API forces semantic naming | Implemented exactly this way; used by all DS widgets and 6 migrated screens | **Aligned** |
| **Data visualization** | Separate `DataVizColors` ThemeExtension with curated 6-8 color palette | Not implemented — chart screens use hardcoded `Colors.*` | **Missing** |
| **Transient emphasis** | Locally in animation code, using semantic colors or fixed palette; transient by nature | Animated sweep border on ChallengeCard uses semantic colors transiently | **Aligned** (for DS widgets) |
| **Platform conventions** | Accept achromatic "tappable" signal; use semantic colors for link-like elements if needed | No explicit platform convention handling | **Missing** — not yet needed but unaddressed |
| **Leak prevention (sanctioned)** | API forces semantic naming; adding groups is deliberate | 2 sanctioned paths (error + semantic) work as designed | **Aligned** |
| **Leak prevention (unsanctioned)** | No hardcoded hex, no raw Colors.*, all through theme | 16 hardcoded `Colors.*` in 8 files, 10 hardcoded fontSize in 9 files, 5 legacy token imports, 8 hardcoded layout values | **Divergent** — 39 anti-pattern instances |
| **Provider coupling** | Design system widgets are presentation-only | 3 core widgets are ConsumerWidgets with provider dependencies | **Divergent** — structural anti-pattern |

---

## 4B. What the Current Implementation Does Well

### 1. Achromatic ColorScheme — Textbook Execution

The entire M3 `ColorScheme` is achromatic with zero chroma, exactly as the ideal prescribes. Primary (`#252627`), secondary (`#5C5E64`), and tertiary (`#757575`) form a clear contrast hierarchy (darkest → medium → lightest) that matches the ideal's "primary > secondary > tertiary (ghost)" gradient. This directly satisfies:
- **Principle 1** (Achromatic structural layer) — every structural M3 role is greyscale
- **Principle 2** (Chromatic = semantic) — hue is reserved for `AppSemanticColors` and `error`

*(Current: M3 Theme Audit §A1-A3; Ideal: 2A Primary/Secondary/Tertiary families)*

### 2. Ghost Tertiary — Active Philosophy Enforcement

The ghost tertiary (`#757575`, container `#F5F5F5` ≈ surface) is not merely "unused" — it's a functioning trap role. Container `tertiaryContainer` is ~ΔY 6 from `surface`, making it nearly invisible. The medium/high contrast cascade progressively restores visibility. This is precisely the "design-by-frustration" mechanism the ideal describes:
- **Principle 4** (Ghost roles as guardrails) — tertiary punishes casual color use
- **Principle 7** (Contrast cascade as escape valve) — accessibility override exists

*(Current: M3 Theme Audit §A3; Ideal: 1C Ghost Tertiary)*

### 3. Two-Tier Surface Model — Cleaner Than M3's Gradient

The grey scaffold (`#F5F5F5`) / white content (`#FFFFFF`) model with `outlineVariant` borders is implemented exactly as ideal 2A prescribes. `surfaceTintColor: Colors.transparent` is set on all 6 relevant component themes, ensuring zero M3 tonal elevation bleed. The full 5-level gradient remains available in the `ColorScheme` as an escape hatch. This satisfies:
- **Adjacent Principle: Surface Architecture** — grey scaffold / white content with border separation
- **Design Test 3** (Two-tier surface) — strong grey/white contrast over subtle tonal steps
- **Design Test 4** (Disabled surface tint) — tint is practically invisible with achromatic primary, so disabling it costs nothing

*(Current: M3 Theme Audit §B1-B2; Ideal: 1D Surface Architecture, 2A Surface System)*

### 4. Semantic Color Extension — Exemplary Gatekeeper

`AppSemanticColors` with 4 groups × 4 roles × 4 variants (light/dark/medium/high contrast) is a well-structured chromatic gatekeeper. The `SemanticColorGroup` mirrors M3's role pattern exactly. Access requires explicit `Theme.of(context).extension<AppSemanticColors>()!` — a deliberate import that forces semantic naming. This satisfies:
- **Principle 5** (Chromatic gatekeeper) — only sanctioned path to hue
- **Ideal 2B** (Semantic Color Extension Architecture) — 4 groups, flat 4-role pattern, no tonal palettes

*(Current: M3 Theme Audit §D3; Ideal: 2B Semantic Color Extension Architecture)*

### 5. Manual ColorScheme Specification

The implementation uses manually specified hex values (not `ColorScheme.fromSeed()`) throughout `color_is_expensive_theme.dart`. This gives precise control over every grey value and ensures zero unwanted HCT trace chroma. This satisfies:
- **Design Test 7** (Manual ColorScheme vs fromSeed) — precision over convenience for a system where "every color is a deliberate decision"
- **Ideal 2A** (ColorScheme.fromSeed vs Manual Specification) — manual is recommended for achromatic systems

*(Current: M3 Theme Audit §A1; Ideal: 2A `ColorScheme.fromSeed()` vs Manual Specification)*

### 6. APCA-Verified Contrast Pipeline

All color pairs are verified against APCA perceptual contrast thresholds (body text Lc ≥ 90, accents Lc ≥ 60, borders Lc ≥ 30). This is more perceptually accurate than WCAG 2.x and aligns with the ideal's recommendation. This satisfies:
- **Principle 6** (APCA-verified contrast) — every pairing meets perceptual contrast thresholds
- **Ideal 1D** (APCA-Verified Contrast) — APCA over WCAG 2.x

*(Current: M3 Theme Audit §A8; Ideal: 1D APCA-Verified Contrast)*

### 7. Presentation-Only Widget Architecture

All 18 design system widgets are presentation-only: data in, pixels out. No providers, no `ConsumerWidget`, no services. This matches the ideal's orthogonal requirement and enables Widgetbook compatibility. 15/18 have dedicated Widgetbook use cases. This satisfies:
- **Adjacent Principle: Presentation-Only Widgets** — pure functions, no state management dependencies

*(Current: UI Components Audit §A; Ideal: 1D Presentation-Only Widgets)*

### 8. M3-First Component Strategy

The DS widget catalog appropriately divides between M3-backed components (Button wraps `FilledButton`/`OutlinedButton`, BottomNav wraps `NavigationBar`, Tabs wraps `TabBar`) and custom primitives (ChallengeCard, ScoreHeader, ChallengeCategoryIcon). This matches the ideal's pragmatic rule. This satisfies:
- **Derived Rule 12** (M3 components first) — native M3 for interaction patterns, primitives for custom visuals

*(Current: UI Components Audit §A; Ideal: 1D M3-First Component Strategy)*

### 9. Token ThemeExtension System

7 custom `ThemeExtension` classes cover spacing, radii, elevation, opacity, sizing, animation, and semantic colors. This is the idiomatic Flutter approach; Flutter doesn't expose M3's full token system natively. Spacing values exactly match M3's 4dp grid. This satisfies:
- **Ideal 2C** (Token System Design) — all 7 categories justified, ThemeExtension is correct pattern

*(Current: M3 Theme Audit §D1; Ideal: 2C Token System Design)*

---

## 4C. Divergences

### D1. Dual Theme Architecture (Layered Injection vs Single Root)

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | Single `ThemeData` at `MaterialApp` root. Layered injection creates extension null crashes, brightness inconsistency, and cognitive overhead. *(Ideal 2C: Single Root vs Layered Theme Injection)* |
| **What the code does** | Legacy `MaterialTheme` (chromatic blue `#2633C5`) at app root (`main.dart:236`). `ColorIsExpensiveTheme` injected locally at feature boundaries via `Theme()` widget (`challenges_screen.dart:113-118`). *(Current 3C; M3 Theme Audit §E1-E3)* |
| **Severity** | **Architectural** — affects dev workflow, causes null crashes for widgets outside DS boundary, blocks dark mode |
| **Root cause** | Intentional design choice (progressive migration) — the layered approach was adopted to introduce the design system without disrupting the existing app |
| **Specific risks** | (1) Any widget calling `Theme.of(context).extension<AppSpacing>()!` outside `Theme()` wrapper throws null assertion. (2) Any design system widget used in a non-wrapped screen renders against legacy blue theme. (3) Dark mode toggle switches app root but DS content stays light. |
| **Verdict** | **Change to match ideal** — migrate to single root. A 5-step migration path already exists (M3 Theme Audit §E5). The layered injection was valid as a transitional strategy but should not persist. |

### D2. Dark Mode Broken at Design System Boundary

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | `MaterialApp(theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: <user preference>)`. Framework handles brightness switching. *(Ideal 2C: Theme Provider Wiring)* |
| **What the code does** | Feature boundaries hardcode `.light()` at `challenges_screen.dart:114`. `ColorIsExpensiveTheme` has complete dark support (`darkScheme()`, `dark()`) but it's never activated. When user toggles dark mode: dark chrome + light DS content area. *(Current 3C; M3 Theme Audit §E4)* |
| **Severity** | **Structural** — dark mode is broken for 6 migrated screens; users see visual inconsistency |
| **Root cause** | Oversight — dark mode was built but the injection point wasn't updated to be brightness-aware |
| **Verdict** | **Change to match ideal** — either (a) make feature boundary brightness-aware as an interim fix, or (b) resolve via D1 (single root theme makes this automatic) |

### D3. ThemeExtensions Absent at App Root

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | All extensions registered at root, globally available. Unused extensions cost nothing at runtime. *(Ideal 2C: ThemeExtension Registration)* |
| **What the code does** | Legacy `MaterialTheme` at app root has no ThemeExtensions. Only the `Theme()` wrapper at feature boundaries registers them. *(Current 3C; M3 Theme Audit §E3)* |
| **Severity** | **Structural** — any widget using `Theme.of(context).extension<T>()!` outside DS boundary crashes |
| **Root cause** | Direct consequence of D1 (dual theme architecture) |
| **Verdict** | **Change to match ideal** — as interim step, add `DesignSystemTheme.standardExtensions()` to app root `MaterialTheme`. Full resolution via D1. |

### D4. 39 Anti-Pattern Instances (Chromatic Leaks, Hardcoded Values)

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | No hardcoded hex values in widgets (Derived Rule 10). All color through theme: `ColorScheme` for structural, `AppSemanticColors` for chromatic. *(Ideal 1B: Level 3 Derived Rules)* |
| **What the code does** | 16 hardcoded `Colors.*` in 8 files, 10 hardcoded fontSize in 9 files, 5 legacy `design_tokens.dart` imports, 8 hardcoded layout values. Total: 39 anti-pattern instances across ~15 files. *(Current 3E; UI Components Audit §E1-E4)* |
| **Severity** | **Structural** — bypasses chromatic budget, creates inconsistency, blocks theme switching |
| **Root cause** | Drift — unmigrated screens predate the design system and were never updated |
| **Specific files** | `won_slot_item.dart` (Colors.green/red/orange), `slot_production_stats_screen.dart` (Colors.amber/blue/green/red), `slot_assignments_screen.dart` (Colors.grey/orange/black87), `transaction_success/failed_screen.dart` (Colors.white), `wallet_screen.dart` (Colors.orange), `exact_alarm_permission1_screen.dart` (Colors.green/orange) |
| **Verdict** | **Change to match ideal** — all 16 hardcoded Colors.* map to existing semantic or colorScheme alternatives. Migration is mechanical (find-and-replace level). See UI Components Audit §E1 for exact mappings. |

### D5. SecondaryContainer Marginal Contrast Against Surface

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | `secondaryContainer` must have visible contrast against `surface` — at least ΔY 10 to avoid the "invisible container" problem. *(Ideal 2A: Secondary Family)* |
| **What the code does** | `secondaryContainer` `#E1E2E8` vs `surface` `#F5F5F5` — approximately ΔL 5, well below the ideal ΔY 10 threshold. Affects `FilledTonalButton`, `NavigationBar` indicator, `FilterChip` selected state. *(M3 Theme Audit §A2)* |
| **Severity** | **Cosmetic** — the container is functional but hard to distinguish from surface at a glance |
| **Root cause** | M3 tonal palette generation produces closely-spaced neutral-variant values; manual adjustment wasn't applied |
| **Verdict** | **Change to match ideal** — darken `secondaryContainer` by ~5 tonal steps (e.g., from `#E1E2E8` to `#D5D7DD` or similar) to achieve ΔY ≥10 against `surface`. Verify with APCA that `onSecondaryContainer` text still passes. |

### D6. Token Values: Elevation Diverges from M3

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | Include M3's standard levels (0, 1, 3, 6, 8, 12) even if the system rarely uses elevation. *(Ideal 2C: Token System Design)* |
| **What the code does** | `AppElevation`: 0, 1, 2, 4, 8. Missing M3 levels 3 and 6; has non-standard levels 2 and 4. *(Current 3C; M3 Theme Audit §D2)* |
| **Severity** | **Structural** — M3 components expecting levels 3 or 6 can't use the token system correctly |
| **Root cause** | Oversight — custom scale was chosen without cross-referencing M3 elevation levels |
| **Verdict** | **Change to match ideal** — add `level3: 3.0` and `level6: 6.0` to `AppElevation`. Keep existing levels 2 and 4 for backwards compatibility. File: `lib/design_system/tokens/app_elevation.dart` |

### D7. Token Values: Radii xLarge (24 vs M3 extra-large 28)

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | Match M3 shape scale where possible, including extra-large = 28. *(Ideal 2C: Token System Design)* |
| **What the code does** | `AppRadii.xLarge = 24`. M3's `extra-large = 28`. Dialog shape uses r24, ideal says r28. *(Current 3C; M3 Theme Audit §D2, §C5)* |
| **Severity** | **Cosmetic** — 4dp difference in corner radius |
| **Root cause** | Intentional design choice, but misaligned with M3 spec |
| **Verdict** | **Change to match ideal** — update `xLarge` from 24 to 28 in `lib/design_system/tokens/app_radii.dart`. Update dialog shape to use `radii.xLarge`. |

### D8. Dialog Elevation 0 + r24

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | Dialog: `surfaceContainerLowest`, elevation 0, r28 (M3 standard). *(Ideal 2D: Dialog)* |
| **What the code does** | `surfaceContainerLowest`, elevation 0, r24. *(M3 Theme Audit §C5, `color_is_expensive_theme.dart:379-386`)* |
| **Severity** | **Cosmetic** — elevation 0 matches ideal; r24 vs r28 is minor |
| **Root cause** | Pre-dates radii alignment decision |
| **Verdict** | **Change to match ideal** — update dialog shape to r28 (resolved by D7 if dialog uses `radii.xLarge`). |

### D9. AppBar Missing Scroll-State Border Feedback

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | `scrolledUnderElevation: 0` is correct. Alternative scroll feedback: an `outlineVariant` bottom border that appears on scroll. *(Ideal 2D: AppBar)* |
| **What the code does** | `scrolledUnderElevation: 0` but no alternative scroll feedback mechanism. AppBar and scrolled content merge visually. *(M3 Theme Audit §B3, `color_is_expensive_theme.dart:352`)* |
| **Severity** | **Cosmetic** — usability concern for scroll-heavy screens |
| **Root cause** | Intentional simplification — scroll feedback was deferred |
| **Verdict** | **Needs discussion** — see 4F Tier 3 for options |

### D10. ListTile Double-Compaction (dense + compact)

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | Not explicitly prescribed. The ideal mentions M3 components first (Rule 12) but doesn't override ListTile density. *(Ideal 2D doesn't cover ListTile)* |
| **What the code does** | `dense: true` + `visualDensity: compact` + bodyMedium title (vs M3 bodyLarge). May push height below 48dp touch target. *(M3 Theme Audit §C9, `color_is_expensive_theme.dart:407-425`)* |
| **Severity** | **Structural** — potential accessibility violation (below 48dp minimum touch target) |
| **Root cause** | Over-engineering — stacking two density reductions without measuring rendered height |
| **Verdict** | **Change to match ideal** — remove one of `dense`/`visualDensity: compact`. Verify rendered height ≥ 48dp. |

### D11. Token Values: Animation Partial M3 Match

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | Include M3 standard motion durations (50, 100, 250, 300, 450ms). *(Ideal 2C: Token System Design)* |
| **What the code does** | `AppAnimation`: 100, 150, 200, 300ms. Missing M3's 50ms (short1) and 450ms (long1). Has non-standard 150ms and 200ms. *(Current 3C; M3 Theme Audit §D2)* |
| **Severity** | **Cosmetic** — doesn't affect correctness, only M3 alignment precision |
| **Root cause** | Custom scale chosen for the app's specific animation needs |
| **Verdict** | **Accept as valid alternative** — the current values serve the app's animation patterns. The 150ms and 200ms values are used by actual widgets. Adding M3-exact values could be done but isn't necessary unless M3 component animations feel inconsistent. |

### D12. Provider Coupling in 3 Core Widgets

| Aspect | Detail |
|--------|--------|
| **What the ideal says** | Design system widgets are pure functions: data in, pixels out. No providers, no services, no `ConsumerWidget`. *(Ideal 1D: Presentation-Only Widgets)* |
| **What the code does** | `AppAppBar`, `AppDrawer`, `NodeStatusIcon` are `ConsumerWidget`/`ConsumerStatefulWidget` with Riverpod dependencies. *(Current 3E; UI Components Audit §E5)* |
| **Severity** | **Structural** — these can't be moved to design system without extracting state; they're in `lib/core/widgets/` |
| **Root cause** | Pre-dates design system architecture; state was embedded in widgets for convenience |
| **Verdict** | **Accept as valid alternative** — these are in `lib/core/widgets/`, not `lib/design_system/`. The ideal's presentation-only rule applies to design system widgets. Core widgets can remain provider-coupled until/unless migrated to DS. |

---

## 4D. Missing Capabilities

### M1. Data Visualization Color Extension

| Aspect | Detail |
|--------|--------|
| **What it is** | A `ThemeExtension<DataVizColors>` with a curated palette of 6-8 perceptually distinct colors for charts and graphs, APCA-verified for both light and dark surfaces |
| **Why the ideal calls for it** | "Data visualization requires chromatic differentiation — a pie chart with five grey segments is unreadable." The ideal explicitly designs a separate escape hatch for data viz, contained to viz widgets only. *(Ideal 2E: Escape Hatch #3, Design Test 8)* |
| **Current gap** | `slot_production_stats_screen.dart` uses hardcoded `Colors.amber/blue/green/red` for chart segments. No centralized data viz palette exists. |
| **Effort** | **S** — define 6-8 color values × 2 brightness variants in a new ThemeExtension |
| **Priority** | **P3** — Missing but acceptable to defer. Only 1-2 screens currently need data viz colors. The existing semantic colors (technical/flash/community/success) already cover 4 of the needed chart colors. |

### M2. Scroll-State AppBar Feedback

| Aspect | Detail |
|--------|--------|
| **What it is** | An `outlineVariant` bottom border (or similar non-tonal signal) on the AppBar that appears when content scrolls beneath it |
| **Why the ideal calls for it** | With `scrolledUnderElevation: 0`, the AppBar and scrolled content merge visually. The ideal recommends a border as alternative feedback. *(Ideal 2D: AppBar)* |
| **Current gap** | No scroll-state feedback exists. *(M3 Theme Audit §B3)* |
| **Effort** | **S** — implement via `PreferredSize` wrapper or custom `SliverAppBar` decoration that responds to scroll offset |
| **Priority** | **P2** — Missing and needed. Every scroll-heavy screen benefits. |

### M3. Platform Convention Handling

| Aspect | Detail |
|--------|--------|
| **What it is** | A documented strategy for how achromatic primary interacts with platform conventions (iOS blue "tappable" signal, platform selection colors) |
| **Why the ideal calls for it** | The ideal acknowledges this is "the trickiest escape hatch" and suggests using semantic colors for link-like elements. *(Ideal 2E: Escape Hatch #5)* |
| **Current gap** | No explicit handling. Links in the app may not signal "tappable" to iOS users. |
| **Effort** | **S** — documentation + possibly a `linkColor` value in `AppSemanticColors` (or mapped to `semantic.technical.color`) |
| **Priority** | **P3** — Missing but acceptable to defer. Mobile app has fewer traditional hyperlinks than web. |

### M4. Result Page / Status Page Widget

| Aspect | Detail |
|--------|--------|
| **What it is** | Full-page layout widget for success/failure/info states with icon/illustration, headline, body text, and action buttons |
| **Why needed** | 3 screens need it: TransactionSuccessScreen, TransactionFailedScreen, OnboardingBatteryCompleteScreen. Currently use hardcoded colors and layout. *(UI Components Audit §D1)* |
| **Effort** | **S** — 1 widget with variant enum |
| **Priority** | **P2** — Missing and needed now for Wave 2 migration. |

### M5. Form Input / Text Field Widget

| Aspect | Detail |
|--------|--------|
| **What it is** | DS wrapper around text input using ThemeExtension tokens (AppRadii, AppSpacing) with label, helper, error, prefix/suffix |
| **Why needed** | SendScreen, ImportApiAccountScreen need it. `AppTextField` (core) exists but uses legacy `design_tokens.dart`. *(UI Components Audit §D2)* |
| **Effort** | **S** — wrap existing `AppTextField` pattern with ThemeExtension tokens |
| **Priority** | **P2** — Missing and needed now for Wave 2 migration. |

### M6. Status Badge / Indicator Widget

| Aspect | Detail |
|--------|--------|
| **What it is** | Compact colored indicator with icon + label, accepting status enum → semantic color mapping |
| **Why needed** | 4 screens need it: WonSlotItem, NodeStatusScreen, SlotAssignmentsScreen, MempoolDetailsScreen. Currently use hardcoded `Colors.green/red/orange`. *(UI Components Audit §D3)* |
| **Effort** | **S** — 1 widget |
| **Priority** | **P2** — Missing and needed for Wave 3 migration. |

### M7. Settings Toggle / Switch Row Widget

| Aspect | Detail |
|--------|--------|
| **What it is** | M3 SwitchListTile wrapper with consistent padding, label, description |
| **Why needed** | BackgroundProductionSettingsScreen. Already mostly uses M3 components but no DS formalization. *(UI Components Audit §D4)* |
| **Effort** | **S** — 1 widget |
| **Priority** | **P3** — Missing but acceptable to defer. Low impact (1 screen). |

### M8. Data Card / Metric Tile Widget

| Aspect | Detail |
|--------|--------|
| **What it is** | Bordered card with icon container, title, subtitle, trailing value for node/status displays |
| **Why needed** | 4 node screens use this pattern with hardcoded layout: NodeStatusScreen, SlotProductionStatsScreen, BlockDetailsScreen, MempoolDetailsScreen. *(UI Components Audit §D5)* |
| **Effort** | **S** — 1 widget, M3 ListTile-based |
| **Priority** | **P2** — Missing and needed for Wave 3 migration. |

### M9. WCAG 2.x Dual Verification

| Aspect | Detail |
|--------|--------|
| **What it is** | Running all color pairs through both APCA and WCAG 2.x contrast ratios; documenting any where they disagree |
| **Why the ideal calls for it** | APCA is draft in WCAG 3.0. Legal/compliance contexts may require WCAG 2.x. The ideal recommends dual verification. *(Ideal 1D: APCA-Verified Contrast)* |
| **Current gap** | Only APCA-verified. No WCAG 2.x verification documented. *(M3 Theme Audit §A8)* |
| **Effort** | **M** — automated script against all color pairings, documentation of results |
| **Priority** | **P3** — Missing but acceptable to defer unless compliance certification is needed. |

---

## 4E. Unnecessary Complexity

### UC1. Dual Theme Architecture

**Does the ideal call for it?** No. The ideal explicitly recommends single root. *(Ideal 2C)*

**What it costs:**
- Two theme classes to maintain (`MaterialTheme` + `ColorIsExpensiveTheme`)
- `lib/core/config/design_tokens.dart` duplicates values from ThemeExtension tokens
- Every new screen must know to wrap with `Theme()` or risk null crashes
- Dark mode is broken at DS boundary
- Legacy `MaterialTheme` colors (blue `#2633C5`, cyan `#00B6F0`) create visual inconsistency for any DS widget accidentally used outside the boundary

**Removal path:**
1. Add `DesignSystemTheme.standardExtensions()` to `MaterialTheme` in `lib/core/config/theme.dart` (prevents null crashes immediately — **S effort**)
2. Add `AppSemanticColors` to app root (exposes semantic colors globally — **S effort**)
3. Migrate screens one-by-one from legacy to `ColorIsExpensiveTheme` colors (**M-L effort**, per-screen)
4. Once all screens migrated, replace `MaterialTheme` at app root with `ColorIsExpensiveTheme` (**S effort**)
5. Delete `MaterialTheme` class and `design_tokens.dart` (**S effort**)

### UC2. Per-Feature Theme() Injection

**Does the ideal call for it?** No — it's a migration artifact. The ideal says single root makes local `Theme()` wrappers unnecessary. *(Ideal 2C)*

**What it costs:**
- Boilerplate at every feature entry point
- Easy to forget (causing null crashes or wrong colors)
- `.light()` hardcoding blocks dark mode
- `Builder` wrapper needed to ensure children see the new theme

**Removal path:** Resolved by UC1 — once app root uses `ColorIsExpensiveTheme`, the per-feature `Theme()` wrappers become redundant. Remove from `challenges_screen.dart:113-118` and any other feature entry points.

### UC3. Legacy MaterialTheme + design_tokens.dart

**Does the ideal call for it?** No. A single theme system with ThemeExtension tokens is the target. *(Ideal 2C)*

**What it costs:**
- `lib/core/config/theme.dart` (`MaterialTheme`) — ~400 lines of chromatic theme that contradicts the achromatic philosophy
- `lib/core/config/design_tokens.dart` — flat constants duplicating ThemeExtension values. 5 core widgets import it.
- Cognitive overhead: two systems for the same concepts (kSpace8 vs AppSpacing.space8)

**Removal path:**
1. Migrate 5 core widgets from `design_tokens.dart` imports to ThemeExtension tokens: `app_action_button.dart`, `app_button.dart`, `app_card.dart`, `app_bottom_sheet.dart`, `app_text_field.dart` (**S-M effort**)
2. Verify no other imports of `design_tokens.dart` remain
3. Delete `design_tokens.dart` (**S effort**)
4. `MaterialTheme` deletion is part of UC1 step 5

### UC4. ListTile Double-Compaction

**Does the ideal call for it?** No. The ideal doesn't prescribe ListTile density and generally defers to M3 component defaults. *(Ideal 2D, Rule 12)*

**What it costs:**
- Potential 48dp accessibility violation
- Two simultaneous density reductions (`dense: true` + `visualDensity: compact`) that compound unpredictably
- Smaller-than-M3 text styles (bodyMedium/bodySmall vs bodyLarge/bodyMedium)

**Removal path:** Remove either `dense: true` or `visualDensity: compact` (not both) from `lib/design_system/theme/color_is_expensive_theme.dart:407-425`. Verify rendered height ≥ 48dp. (**S effort**)

---

## 4F. Prioritized Action Plan

### Tier 1 — Quick Wins (< 1 hour each, no architectural decisions)

| # | Action | File(s) | Scope | Risk |
|---|--------|---------|-------|------|
| T1.1 | Add `// GHOST: deliberately near-invisible` comment at tertiary role | `lib/design_system/theme/color_is_expensive_theme.dart:33` | **XS** | None |
| T1.2 | Add explanatory block comment for `surfaceTintColor: transparent` rationale | `lib/design_system/theme/color_is_expensive_theme.dart:346` | **XS** | None |
| T1.3 | Add class-level doc-comment on `ColorIsExpensiveTheme` explaining achromatic philosophy and ghost tertiary | `lib/design_system/theme/color_is_expensive_theme.dart` (top of class) | **XS** | None |
| T1.4 | Update `AppRadii.xLarge` from 24 to 28 to match M3 extra-large | `lib/design_system/tokens/app_radii.dart` | **XS** | Low — verify no widget relies on exactly 24 |
| T1.5 | Add `level3: 3.0` and `level6: 6.0` to `AppElevation` | `lib/design_system/tokens/app_elevation.dart` | **XS** | None — additive |
| T1.6 | Update dialog shape to use `radii.xLarge` (now 28, matching M3 r28) | `lib/design_system/theme/color_is_expensive_theme.dart:379-386` | **XS** | Low |
| T1.7 | Remove one of `dense: true` / `visualDensity: compact` from ListTile theme | `lib/design_system/theme/color_is_expensive_theme.dart:407-425` | **S** | Low — visual change to list density; verify 48dp height |
| T1.8 | Register `DesignSystemTheme.standardExtensions()` at app root | `lib/core/config/theme.dart` (in MaterialTheme) | **S** | Low — additive, prevents null crashes. Doesn't change any visual. |
| T1.9 | Register `AppSemanticColors` at app root (light + dark variants) | `lib/core/config/theme.dart` | **S** | Low — additive |

### Tier 2 — Important Improvements (half-day each, clear path)

| # | Action | File(s) | Scope | Risk |
|---|--------|---------|-------|------|
| T2.1 | Fix dark mode at DS boundary: make theme injection brightness-aware | `lib/features/challenges/screens/challenges_screen.dart:113-118` (and any other Theme() injection sites) | **S** | Medium — visual change for dark mode users; needs testing |
| T2.2 | Darken `secondaryContainer` by ~5 tonal steps for ΔY ≥10 against surface | `lib/design_system/theme/color_is_expensive_theme.dart:29` (secondaryContainer value) | **S** | Medium — affects FilledTonalButton, NavigationBar indicator, FilterChip selected; APCA re-verification needed |
| T2.3 | Replace 16 hardcoded `Colors.*` with semantic/colorScheme alternatives | 8 files: `won_slot_item.dart`, `slot_production_stats_screen.dart`, `slot_assignments_screen.dart`, `mempool_details_screen.dart`, `transaction_success_screen.dart`, `transaction_failed_screen.dart`, `wallet_screen.dart`, `exact_alarm_permission1_screen.dart` | **M** | Low — mechanical find-and-replace; mappings already documented in UI Components Audit §E1 |
| T2.4 | Replace 10 hardcoded `fontSize` values with `textTheme` styles | 9 files: `app_bar.dart`, `app_drawer.dart`, `won_slot_item.dart`, `produced_block_card.dart`, `node_status_screen.dart`, `mempool_details_screen.dart`, `transaction_success/failed_screen.dart`, `background_production_settings_screen.dart`, `send_screen.dart` | **M** | Low — mechanical; mappings documented in UI Components Audit §E2 |
| T2.5 | Migrate 5 core widget imports from `design_tokens.dart` to ThemeExtension tokens | `app_action_button.dart`, `app_button.dart`, `app_card.dart`, `app_bottom_sheet.dart`, `app_text_field.dart` | **M** | Low — functionally identical values; prerequisite for deleting design_tokens.dart |
| T2.6 | Replace 8 hardcoded layout values (BorderRadius/EdgeInsets) with AppRadii/AppSpacing | 6 files: `app_progress_bar.dart`, `produced_block_card.dart`, `node_status_screen.dart`, `node_status_summary_modal.dart`, `wallet_screen.dart` | **S** | Low — mechanical |
| T2.7 | WCAG 2.x dual verification: run all color pairs through WCAG 2.x in addition to APCA | Theme color definition files | **M** | None — read-only analysis |
| T2.8 | Create `ResultPage` DS widget for success/failure/info states | New file: `lib/design_system/src/result_page.dart` + Widgetbook use case | **M** | Low |
| T2.9 | Create DS `TextField` wrapper with ThemeExtension tokens | New file: `lib/design_system/src/text_field.dart` + Widgetbook use case | **M** | Low |
| T2.10 | Create `StatusBadge` DS widget for status indicators | New file: `lib/design_system/src/status_badge.dart` + Widgetbook use case | **M** | Low |

### Tier 3 — Architecture Decisions (require discussion, multiple valid paths)

#### T3.1 — Theme Root Migration Strategy

**The question:** How and when to migrate from the current dual-theme (legacy at root + DS at feature boundaries) to a single `ColorIsExpensiveTheme` at app root?

**Option A: Big Bang Migration**
- Replace `MaterialTheme` with `ColorIsExpensiveTheme` at app root in one step
- All 31 screens immediately render against achromatic theme
- **Effort**: S for the swap itself, L for fixing all visual regressions across 25 unmigrated screens
- **Risk**: HIGH — every unmigrated screen changes appearance simultaneously; testing burden is massive
- **What breaks**: Screens relying on legacy blue primary for buttons/links/headers; any screen using colorScheme.tertiary for visible emphasis; all hardcoded Colors.* become more visible as contrast context changes

**Option B: Incremental Migration with Shared Extensions (Recommended path)**
- Step 1: Register all ThemeExtensions at app root (T1.8, T1.9) — tokens available everywhere
- Step 2: Migrate screens wave-by-wave (Waves 1-4 from UI Components Audit §F) — each screen adopts achromatic theme
- Step 3: Once all screens migrated, swap root theme to `ColorIsExpensiveTheme`
- Step 4: Remove local `Theme()` wrappers and delete `MaterialTheme`
- **Effort**: M spread over weeks/months; each wave is independently shippable
- **Risk**: LOW per step — visual changes are scoped to individual screens
- **What breaks**: Nothing incrementally; each screen is visually reviewed before shipping

**Option C: Parallel Root Themes**
- Add `ColorIsExpensiveTheme` as `MaterialApp.theme` and keep `MaterialTheme` as a fallback for unmigrated screens via `ThemeData.fallback` or per-route theme switching
- **Effort**: M — requires route-aware theme selection logic
- **Risk**: MEDIUM — adds complexity during migration; two themes active simultaneously creates reasoning burden
- **What breaks**: Theme selection logic must be maintained until all screens migrate

#### T3.2 — AppBar Scroll Feedback Mechanism

**The question:** With `scrolledUnderElevation: 0`, how should the AppBar signal that content is scrolling beneath it?

**Option A: Animated outlineVariant Border**
- Show a 1px `outlineVariant` bottom border on AppBar when scroll offset > 0
- Implement via `NotificationListener<ScrollNotification>` or `ScrollController` in a custom AppBar wrapper
- **Effort**: S
- **Risk**: LOW — purely additive visual cue
- **Trade-off**: Requires wrapping every screen's AppBar with the scroll-aware version, or building it into the DS TopAppBar widget

**Option B: Subtle Shadow on Scroll**
- Instead of M3's tonal shift, apply a very subtle shadow (`elevation: 0.5`) when scrolled
- The shadow is achromatic (from `ColorScheme.shadow`), consistent with philosophy
- **Effort**: S
- **Risk**: LOW — minor visual change
- **Trade-off**: Reintroduces elevation after deliberately removing it. Contradicts the "borders not shadows" philosophy but is pragmatic.

**Option C: Do Nothing (Accept Current Behavior)**
- The grey scaffold / white content separation already provides visual context
- Users rarely need scroll feedback on mobile (content is clearly scrolling via touch)
- **Effort**: None
- **Risk**: None
- **Trade-off**: Purest adherence to flat philosophy, but some screens may feel "endless" without scroll context

#### T3.3 — Data Visualization Color Strategy

**The question:** How should the system handle chromatic color in data visualization contexts (charts, graphs, pie segments)?

**Option A: Dedicated DataVizColors ThemeExtension**
- Create `ThemeExtension<DataVizColors>` with 6-8 perceptually distinct, APCA-verified colors
- Separate from `AppSemanticColors` — only imported by chart widgets
- Includes light and dark variants
- **Effort**: S for the extension; M for migrating existing chart screens
- **Risk**: LOW — contained, additive
- **Trade-off**: Another ThemeExtension to maintain. Draws a clear boundary but adds a maintenance surface.

**Option B: Reuse Semantic Colors for Charts**
- Map chart segments to existing semantic groups: technical=blue, flash=amber, community=green, success=green, error=red
- Add 2-3 additional muted variants to existing groups if more differentiation needed
- **Effort**: S — no new extension, just usage convention
- **Risk**: MEDIUM — only 4-5 distinct colors; may not be enough for complex charts. Semantic meaning gets overloaded (blue means "technical" in one context, "data series 1" in another).
- **Trade-off**: Simpler architecture but weaker semantic precision. Violates the ideal's recommendation for separation.

**Option C: Hardcoded Chart Palette (Minimal Scope)**
- Keep chart colors as hardcoded constants in a `chart_colors.dart` file (not a ThemeExtension)
- Acknowledge this is a contained exception to the "no hardcoded colors" rule
- Light/dark variants as separate constant sets
- **Effort**: XS
- **Risk**: LOW — no architecture change
- **Trade-off**: Doesn't participate in theme switching automatically. Pragmatic shortcut that may need upgrading later. Not aligned with ideal but honest about current scale (1-2 chart screens).

#### T3.4 — Legacy Core Widget Strategy

**The question:** What should happen to the 12 `lib/core/widgets/` as the design system matures?

**Option A: Migrate Reusable Widgets to DS, Deprecate Rest**
- Migrate `AppBottomSheet`, `AppCard`, `AppTextField`, `AppProgressBar` to `lib/design_system/src/` with ThemeExtension tokens
- Deprecate `AppButton` (superseded by DS `Button`), `AppActionButton` (low reuse)
- Keep provider-coupled widgets (`AppAppBar`, `AppDrawer`, `NodeStatusIcon`) in core as-is
- Keep domain-specific FRB-coupled widgets (`ProducedBlockCard`, `WonSlotItem`) in core as-is
- **Effort**: M — 4 widget migrations + deprecation annotations
- **Risk**: LOW per widget — each migration is independent
- **Trade-off**: Clean separation but some widgets may not justify the migration effort (AppCard is simple enough to inline)

**Option B: Thin Wrapper Approach**
- Create DS wrappers that compose core widgets, adding ThemeExtension tokens
- Core widgets remain unchanged; DS wrappers provide the token-aware interface
- **Effort**: S per wrapper
- **Risk**: LOW — non-breaking, additive
- **Trade-off**: Adds indirection layer. Two files for one concept. But zero risk to existing screens.

**Option C: Inline Replace**
- Don't migrate core widgets. Instead, when migrating each screen (Waves 1-4), replace core widget usage with direct M3 components + DS tokens
- Core widgets die naturally as screens stop using them
- **Effort**: Spread across screen migrations
- **Risk**: LOW — organic deprecation
- **Trade-off**: No upfront effort on widget migration. Core widgets persist until all consumers are migrated. May leave dead code longer.

---

*End of Gap Analysis & Recommendations.*
