# Surface Architecture

The design system uses a **two-tier surface model** — grey scaffold + white content — instead of M3's five-level tonal gradient. Borders replace elevation as the primary separation mechanism.

## Two-Tier Surface Model

The light theme derives from the Figma Home screen (`#F6F6F6` background with white cards). `surface` is set to T96 (`#F5F5F5`) so that M3's default `scaffoldBackgroundColor = surface` produces the grey substrate naturally.

```
┌─────────────────────────────────┐
│  Scaffold: surface (#F5F5F5)    │  ← grey "paper" substrate
│                                  │
│  ┌───────────────────────────┐  │
│  │ Content sheet:            │  │  ← white surface, rounded top
│  │ surfaceContainerLowest    │  │
│  │                           │  │
│  │  ┌─────────────────────┐  │  │
│  │  │ Card:               │  │  │  ← white card on white sheet
│  │  │ surfaceContainerLow │  │  │     (border = outlineVariant)
│  │  │ est + outlineVariant│  │  │
│  │  └─────────────────────┘  │  │
│  └───────────────────────────┘  │
│                                  │
│  ┌───────────────────────────┐  │
│  │ Nav bar:                  │  │
│  │ surfaceContainerLowest    │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

This collapses M3's five-level surface container gradient (`surfaceContainerLowest` through `surfaceContainerHighest`) to two tiers. The grey/white contrast is stronger and clearer than M3's subtle 2-3% lightness differences between container levels. All five levels remain defined in the `ColorScheme` for edge cases — the two-tier model is a usage convention, not a limitation.

Dark mode: `surface` stays at `#1B1B1B` (standard dark). The two-tier visual model is a light-mode expression of the philosophy; in dark mode, content surfaces use their standard darker tones.

## Surface Token Map

| Layer | Token | Light Value | Purpose |
|-------|-------|-------------|---------|
| Scaffold | `surface` | `#F5F5F5` (T96) | Grey page background |
| Content sheet | `surfaceContainerLowest` | `#FFFFFF` | White content area |
| Card on sheet | `surfaceContainerLowest` + `outlineVariant` border | `#FFFFFF` + `#C4C6CC` | Distinct card via border, not elevation |
| Nav bar | `surfaceContainerLowest` | `#FFFFFF` | White bottom bar |

All content-level surfaces use `surfaceContainerLowest` (white). Separation between white-on-white elements (e.g., card on sheet) uses `outlineVariant` borders. Elevation is zero for content surfaces — `surfaceTintColor` is set to `Colors.transparent` on all component themes.

## M3 Deviation Table

What we override from M3 defaults to enforce the two-tier model:

| Component | M3 Default | Our Override | Why |
|-----------|-----------|--------------|-----|
| `surface` itself | near-white (~T99) | grey T96 (`#F5F5F5`) | Foundation: visible grey scaffold enables white-on-grey layering |
| NavigationBar | `surfaceContainer` | `surfaceContainerLowest` + elevation 0 | White nav bar on grey page (2 levels lower than M3) |
| BottomSheet | `surfaceContainerLow` | `surfaceContainerLowest` | White sheet on grey page (1 level lower) |
| Card | `surfaceContainerLow` + elevation 1 | `surfaceContainerLowest` + `outlineVariant` border, elevation 0 | Border replaces tonal elevation |
| Dialog | `surface` + elevation 3 | `surfaceContainerLowest` + elevation 0 | Explicit white, flat (scrim provides separation) |
| Drawer | `surfaceContainerLow` | `surfaceContainerLowest` | White panel (1 level lower) |
| AppBar | `surface` + `scrolledUnderElevation: 3` | `surface` + `scrolledUnderElevation: 0` | Kill scroll-tint that would shift grey on scroll |

Every override moves a component either to the scaffold tier (`surface`) or the content tier (`surfaceContainerLowest`). No intermediate container levels are used.

## What Stays M3 Default

Components that already align with the two-tier model and need no override:

| Component | M3 Default | Why It's Already Correct |
|-----------|-----------|------------------------|
| Scaffold | `surface` | Grey T96 — exactly what we want |
| Divider | `outlineVariant` | Correct structural separator |
| SnackBar | `inverseSurface` | Dark-on-light for max contrast — correct |
| TabBar | transparent (inherits) | Takes parent surface — correct |
| ListTile / ExpansionTile | transparent | Inherits container — correct |
| FilledTonalButton | `secondaryContainer` | Achromatic tonal — correct |
| Switch / Checkbox / Radio | `primary`-based | Achromatic primary — correct |
| ProgressIndicator | `primary` | Correct |

These components work correctly because the achromatic `ColorScheme` makes M3's defaults produce the right result without intervention.

## Decision Principle for New Components

Every surface in the app belongs to exactly one category. When adding a new M3 component theme, classify it into one of five categories:

1. **Scaffold-level** → `surface` (grey)
   The component IS the page background. Examples: Scaffold, canvas, AppBar.

2. **Content-level** → `surfaceContainerLowest` (white)
   The component sits ON the scaffold as a distinct surface. Examples: NavigationBar, BottomSheet, Card, Dialog, Drawer.

3. **Inherit parent** → no background override
   The component lives INSIDE a surface. Examples: ListTile, ExpansionTile, menus, chips.

4. **Inverse** → M3 default
   Transient overlays needing max contrast. Examples: SnackBar, Tooltip.

5. **Separation** → `outlineVariant` border, not elevation
   Cards on white sheets are distinguished by border. Elevation is zero for content surfaces.

If the component doesn't fit cleanly into one category, prefer category 3 (inherit parent) — adding a background override is a stronger commitment than omitting one.

### Quick Reference

| Question | Answer | Category |
|----------|--------|----------|
| Is it the page itself? | Yes → `surface` | 1. Scaffold-level |
| Does it float on the page? | Yes → `surfaceContainerLowest` | 2. Content-level |
| Does it live inside another surface? | Yes → no override | 3. Inherit parent |
| Is it a transient overlay? | Yes → M3 default | 4. Inverse |
| Is it white-on-white? | Yes → `outlineVariant` border | 5. Separation |
