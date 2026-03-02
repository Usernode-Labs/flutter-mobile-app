# Base Layout System

Mobile-only layout targeting the compact window class (<600dp). All spacing derives from `AppSpacing` tokens on an 8pt grid — no new tokens needed. M3 distinguishes two levels: **micro** spacing (inside components) and **macro** spacing (between sections). Content width is fluid (full-width minus margins); no max-width constraint on mobile.

## Screen Anatomy

The app has two screen shapes. Tab screens live inside `HomeScreen`'s `IndexedStack` and receive BottomNav from the shell. Detail screens are pushed via `context.push()`.

```
Tab Screen (Challenges, Wallet, Node)    Detail Screen (Leaderboard, ChallengeDetail)
┌──────────────────────────┐             ┌──────────────────────────┐
│ StatusBar (system)       │             │ TopAppBar (sliver,pinned)│
├──────────────────────────┤             │  handles SafeArea        │
│                          │             ├──────────────────────────┤
│ ← space16 →  content  ← │             │                          │
│                          │             │ ← space16 → content   ← │
│ ┌────────────────────┐   │             │                          │
│ │ Card / Section     │   │             │ ┌────────────────────┐   │
│ └────────────────────┘   │             │ │ Card / Section     │   │
│     ↕ space16            │             │ └────────────────────┘   │
│ ┌────────────────────┐   │             │     ↕ space24 (section)  │
│ │ Card / Section     │   │             │ ┌────────────────────┐   │
│ └────────────────────┘   │             │ │ Card / Section     │   │
│                          │             │ └────────────────────┘   │
│                          │             │     ↕ space32 (bottom)   │
├──────────────────────────┤             └──────────────────────────┘
│ BottomNav (from shell)   │
└──────────────────────────┘
```

## Spacing Roles

### Macro Spacing (between containers / sections)

| Role | Token | Value | Usage |
|------|-------|-------|-------|
| Screen margin (horizontal) | `space16` | 16dp | `EdgeInsets.symmetric(horizontal: spacing.space16)` |
| Section gap (distinct content groups) | `space24` | 24dp | Major logical breaks between sections |
| Card gap (same-type cards in a list) | `space16` | 16dp | Between cards of the same group |
| List item gap | `space12` | 12dp | `ListView.separated` or Column `spacing` |
| Bottom scroll padding | `space32` | 32dp | Last sliver — breathing room above BottomNav or screen edge |

### Micro Spacing (inside components)

| Role | Token | Value | Usage |
|------|-------|-------|-------|
| Card internal padding | `space16` | 16dp | `EdgeInsets.all(spacing.space16)` |
| Internal element gap | `space8` | 8dp | Between label and value within a card |
| Tight gap | `space4` | 4dp | Between heading and its body text |

## Scroll Pattern Decision Tree

```
1. Pinned tabs with independently scrollable tab content?
   → NestedScrollView

2. TopAppBar (SliverAppBar) or multiple distinct sliver types?
   → CustomScrollView + SliverToBoxAdapter
   → Use SliverPadding for horizontal margins (not Padding inside child)

3. Simple list of similar items?
   → ListView.separated (with space12 separator)

4. Default (simple vertical stack)?
   → ListView or Column in SingleChildScrollView
```

**SliverPadding over Padding.** In `CustomScrollView`, wrap slivers in `SliverPadding` for screen margins instead of putting `Padding` inside each `SliverToBoxAdapter` child. `SliverPadding` is optimized for the sliver protocol and avoids unnecessary layout passes.

**Column/Row `spacing` parameter.** Use `Column(spacing: spacing.space16, ...)` instead of interleaving `SizedBox` widgets. Available since Flutter 3.27; the project targets Flutter 3.35+.

## SafeArea Rules

| Screen type | SafeArea handling |
|-------------|-------------------|
| Detail screen with TopAppBar | Automatic — `SliverAppBar` handles top insets |
| Tab screen in IndexedStack | Wrap body in `SafeArea` — shell provides BottomNav |
| Full-screen (onboarding) | Explicit `SafeArea` around content |

## Rules

**Do:**
- Use `spacing.space16` for screen-edge horizontal margins
- Use `SliverPadding` for margins in `CustomScrollView`
- Use Column/Row `spacing:` parameter instead of `SizedBox` gaps
- Use `space24` between major content sections, `space16` between cards
- Place `TopAppBar` as first sliver in detail screens

**Don't:**
- Hardcode `const EdgeInsets.all(16)` — use token
- Use off-grid values (`20`, `10`, `14`)
- Wrap `SliverToBoxAdapter` children in `Padding` for screen margins (use `SliverPadding`)
- Add `SafeArea` when `TopAppBar` already handles insets
- Use `SingleChildScrollView` wrapping a `Column` when slivers are more appropriate

## Progressive Extensions (deferred)

- Content sheet anatomy (white sheet over grey scaffold as layout pattern)
- Grid layouts (2-column cards)
- Bottom sheet internal layout rules
- Full-bleed sections (edge-to-edge images, dividers)
- Responsive breakpoints (only if tablet support is added)
- Canonical layouts (list-detail, supporting pane — single-pane on mobile for now)

See also: [SCREEN_PATTERNS.md](SCREEN_PATTERNS.md) — full screen building playbook with templates and checklists.

---

Cross-references: [`app_spacing.dart`](../tokens/app_spacing.dart), [`app_sizing.dart`](../tokens/app_sizing.dart) (touch targets), [`SURFACES.md`](SURFACES.md), [`COLOR.md`](COLOR.md), [`CONSTRAINTS.md`](CONSTRAINTS.md)
