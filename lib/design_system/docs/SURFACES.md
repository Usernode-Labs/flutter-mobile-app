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

> **Token values and component overrides** — see `color_is_expensive_theme.dart` for the full surface token map, M3 deviation table, and default-aligned components.

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
