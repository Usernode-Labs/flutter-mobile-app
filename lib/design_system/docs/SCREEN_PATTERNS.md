# Screen Building Playbook

The one doc you need. Read this before building any screen — it has every token value, every rule, every anti-pattern.

---

## 0. Token Quick Reference

All values in one place. No source-file reading needed.

### AppSpacing (8pt grid)

| Token | Value | Typical use |
|-------|-------|-------------|
| `space4` | 4dp | Tiny gaps, fine-grained adjustments |
| `space8` | 8dp | Tight gaps, chip padding |
| `space12` | 12dp | List-item separator, section sub-gap |
| `space16` | 16dp | Screen horizontal margin, card internal padding, card gap |
| `space24` | 24dp | Section gap between major content groups, PSL surface body inset |
| `space32` | 32dp | Bottom breathing room |
| `space48` | 48dp | Hero spacing |

Access: `final spacing = Theme.of(context).extension<AppSpacing>()!;`

### AppRadii

| Token | Value | Getter | Use |
|-------|-------|--------|-----|
| `small` | 8dp | `borderRadiusSmall` | Chips, small badges, inner elements |
| `medium` | 12dp | `borderRadiusMedium` | ListTile shape, snackbar, inner cards |
| `large` | 16dp | `borderRadiusLarge` | Cards (CardTheme default) |
| `largeIncreased` | 20dp | `borderRadiusLargeIncreased` | Prominent cards, split-card segments |
| `xLarge` | 24dp | `borderRadiusXLarge` | Dialogs, bottom sheets |
| `full` | 999dp | `borderRadiusFull` | Pills, fully rounded buttons |

**Partial-side getters** (for split cards, modals):
- `borderRadiusTopSmall`, `borderRadiusTopLarge`, `borderRadiusTopXLarge`
- `borderRadiusTopLargeIncreased`, `borderRadiusBottomLargeIncreased`

Access: `final radii = Theme.of(context).extension<AppRadii>()!;`

### AppSizing

| Token | Value | Use |
|-------|-------|-----|
| `iconSmall` | 20dp | Small icons (trailing chevron) |
| `iconRegular` | 24dp | Default icon size |
| `iconLarge` | 28dp | Emphasized icons |
| `iconXLarge` | 32dp | Large feature icons |
| `iconContainerSmall` | 40dp | Small tap target |
| `iconContainerRegular` | 48dp | Standard tap target (accessibility minimum) |
| `iconContainerLarge` | 56dp | Large tap target |
| `iconContainerXLarge` | 64dp | FAB / primary action |
| `buttonHeightSmall` | 40dp | Small button |
| `buttonHeightRegular` | 48dp | Standard button |
| `buttonHeightLarge` | 56dp | Large / prominent button |

Access: `final sizing = Theme.of(context).extension<AppSizing>()!;`

### AppSemanticColors (5 groups)

| Group | Purpose | Access |
|-------|---------|--------|
| `success` | Positive outcomes, confirmations | `semanticColors.success.color` |
| `warning` | Attention needed, syncing, permissions | `semanticColors.warning.colorContainer` |
| `technical` | Technical / blockchain category | `semanticColors.technical.color` |
| `flash` | Flash / speed category | `semanticColors.flash.color` |
| `community` | Community category | `semanticColors.community.color` |

Each group has: `.color`, `.onColor`, `.colorContainer`, `.onColorContainer`

Access: `final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;`

### Standard Token Preamble

Every `build()` method that uses tokens should start with:

```dart
@override
Widget build(BuildContext context) {
  final spacing = Theme.of(context).extension<AppSpacing>()!;
  final radii = Theme.of(context).extension<AppRadii>()!;
  final sizing = Theme.of(context).extension<AppSizing>()!;
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  // Only if semantic colors needed:
  final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
  ...
}
```

---

## 1. Spacing Ownership — The Matryoshka Model

Every pixel of space on screen is owned by exactly one layer. M3 defines three spacing primitives — **margins**, **spacers/gaps**, and **padding** — each belonging to a different nesting level. Our "Matryoshka" model maps these M3 primitives to Flutter's widget tree so every spacing decision has one unambiguous owner.

### The Mental Model

Think of it like a set of Russian dolls. The app renders a **canvas** (Scaffold surface). On that canvas you place **surfaces** (cards, sheets — visual containers with their own background color). Inside those surfaces you compose **widgets** (ListTile, Text, custom rows — the leaf content). Each doll provides its own internal space and never reaches into its parent's or child's responsibility.

```
Canvas (Scaffold)
│
├── Margins ← owned by screen body (space16 horizontal)
│
├── Surface (AppCard / explicit container)
│   │
│   ├── Inset padding ← owned by the surface (space16 via AppCard)
│   │
│   ├── Widget (ListTile)
│   │   └── Content padding ← owned by the widget (theme contentPadding)
│   │
│   ├── Gap ← owned by the surface's layout (Column spacing / SizedBox)
│   │
│   └── Widget (Text, custom Row, etc.)
│       └── (no padding — raw content inherits surface inset)
│
├── Gap ← owned by screen body (space16 between cards, space24 between sections)
│
└── Surface (next card / section)
```

### Three Spacing Zones

| Zone | M3 Term | Owner | What it controls | Our token |
|------|---------|-------|------------------|-----------|
| **Macro** | Margins + Spacers | Screen body / layout parent | Screen-edge margins, gaps between sibling surfaces and sections | `space16` (margin), `space16` / `space24` (gaps) |
| **Macro (PSL surface)** | Surface body inset | PSL `surfaceSlivers` content | Horizontal inset from PSL white surface edge for non-ListTile content | `space24` (horizontal) |
| **Meso** | Inset padding | Surface container (AppCard) | Space between a surface's edge and its content | `AppCard.compact` / `.regular` / `.spacious` |
| **Micro** | Component padding | Leaf widget (ListTile, etc.) | Space between a widget's boundary and its rendered content | Theme `contentPadding` (16h); vertical spacing is M3's `minVerticalPadding: 8` |

**The iron rule:** each zone owns its own spacing. No zone reaches into another.

- A **card** never adds horizontal margin — it sits flush within the screen's margins.
- A **ListTile** inside a card uses its theme `contentPadding` — do not wrap it in extra `Padding`.
- A **screen** never sets internal card padding — that's the card's job.

### Matryoshka Diagram — Full Picture

```
┌─ Scaffold ──────────────────────────────────────────────────┐
│  surface (#F5F5F5)                              System      │
│                                                  Insets     │
│  ┌─ Body (scrollable area) ──────────────────────────────┐  │
│  │                                                        │  │
│  │  ← space16 →                            ← space16 →   │  │  MACRO
│  │                                                        │  │  screen-edge
│  │  ┌─ AppCard ────────────────────────────────────────┐  │  │  margins
│  │  │  surfaceContainerLowest + outlineVariant border  │  │  │
│  │  │                                                  │  │  │
│  │  │  ← space16 →                      ← space16 →   │  │  │  MESO
│  │  │                                                  │  │  │  surface inset
│  │  │  ┌─ ListTile ─────────────────────────────────┐  │  │  │
│  │  │  │  ← 16h →  Title / Subtitle       ← 16h →  │  │  │  │  MICRO
│  │  │  │  ↑ 8v ↑                           ↑ 8v ↑   │  │  │  │  widget
│  │  │  └────────────────────────────────────────────┘  │  │  │  M3 minVerticalPad
│  │  │          ↕ space12 (gap between items)           │  │  │
│  │  │  ┌─ ListTile ─────────────────────────────────┐  │  │  │
│  │  │  │  ...                                       │  │  │  │
│  │  │  └────────────────────────────────────────────┘  │  │  │
│  │  │                                                  │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │          ↕ space16 (gap between cards)                 │  │  MACRO
│  │  ┌─ AppCard ────────────────────────────────────────┐  │  │  inter-surface
│  │  │  ← space16 →   Custom content      ← space16 →  │  │  │  gap
│  │  └──────────────────────────────────────────────────┘  │  │
│  │          ↕ space32 (bottom breathing room)             │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌─ NavigationBar ───────────────────────────────────────┐  │
│  │  surfaceContainerLowest (height: 80)                  │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### How It Maps to Containment

M3 distinguishes two containment strategies. Both follow the same Matryoshka spacing rules:

| Strategy | Visual boundary | Spacing behavior | Our implementation |
|----------|----------------|------------------|-------------------|
| **Explicit** | Surface color + border/radius | Surface owns its inset; screen owns the margin around it | `AppCard` (surfaceContainerLowest + outlineVariant) |
| **Implicit** | White space alone | Larger gaps create the visual boundary — no surface needed | `space24` section gaps, `SizedBox(height: spacing.space24)` |

### Composition Rules

1. **Screen body** applies horizontal `space16` margins (via `SliverPadding` or `ListView.padding`) and vertical gaps between surfaces (`space16` between cards, `space24` between sections).
2. **Surfaces** (AppCard, explicit containers) own their internal inset padding — they sit flush within the screen's margins and never add their own horizontal margin.
3. **Widgets** (ListTile, ExpansionTile, etc.) own their content padding via theme. Do not wrap them in extra `Padding`.
4. **Inter-widget gaps** inside a surface are owned by that surface's layout — use `Column(spacing: ...)`. Avoid `Divider` between homogeneous ListTile items.
5. **Keyline consistency** — all text in ListTile/ExpansionTile rows must land on K₂ (see LAYOUT.md § Keylines). Never wrap these widgets in extra horizontal Padding.
6. **PSL surface body inset** — non-ListTile content inside PSL `surfaceSlivers` uses `space24` horizontal inset from the white surface edge. ListTile/ExpansionTile are exempt (they sit edge-to-edge and own their `contentPadding`). Challenges (`nestedBody`/TabBarView) keep `space16` — different layout path.
7. **PSL surface top inset + content slots** — PSL injects `kSurfaceTopInset` (8px) before the first surfaceSliver. The first content widget should deliver a 48px slot — either naturally (rows with M3 action elements like `PopupMenuButton`) or explicitly (`SizedBox(height: sizing.iconContainerRegular)`). Challenges' tab bar is the prior art: `_kTopInset(8) + kTabBarHeight(48)`. See LAYOUT.md § Content Slot System.

### When Zones Collide: The ListTile-in-Card Case

When a surface contains only padding-aware widgets (ListTile, SwitchListTile), the Meso and Micro zones overlap — both want to add horizontal padding. Resolution: **zero horizontal, keep vertical** — let the widget's content padding handle horizontal spacing, but keep `space8` vertical inset so the first and last tiles aren't flush against the card boundary.

```dart
// Card with ONLY ListTiles → zero horizontal, space8 vertical inset
AppCard(
  padding: EdgeInsets.symmetric(vertical: spacing.space8),
  child: Column(
    children: [
      ListTile(title: Text('Item 1'), trailing: Text('Value 1')),
      ListTile(title: Text('Item 2'), trailing: Text('Value 2')),
    ],
  ),
)

// Card with MIXED content → surface owns padding, widgets are raw
AppCard.regular(
  child: Column(
    spacing: spacing.space12,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Section Title', style: textTheme.titleMedium),
      Text('Description text goes here.'),
      Row(children: [/* custom content */]),
    ],
  ),
)
```

### System Insets — The Invisible Outer Doll

Scaffold and SafeArea handle system insets (status bar, notch, keyboard). These are consumed and zeroed out via `MediaQuery.removePadding` so children don't double-apply them.

| Screen type | System inset handling |
|-------------|---------------------|
| Detail screen with `TopAppBar` | Automatic — `SliverAppBar` consumes top inset |
| Full-screen (onboarding) | Explicit `SafeArea` around content |

**Never** nest `SafeArea` inside a screen that already has `TopAppBar` — the AppBar already consumed that inset.

### Anti-Pattern: Raw Container as Surface

```dart
// BAD — rebuilds what AppCard provides, misses theme coordination
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: colorScheme.outlineVariant),
  ),
  child: content,
)

// GOOD — AppCard encapsulates surface color, border, radius, and inset padding
AppCard.regular(child: content)
```

**Exception:** Split-card patterns with per-segment radii use `Container` + `BoxDecoration` + radii tokens, since `AppCard` only supports uniform radius.

---

## 2. Screen Type Decision Table

| Screen Type | Shell | TopAppBar | SafeArea | Scroll Container | Bottom Padding |
|---|---|---|---|---|---|
| Root screen (e.g. Diagnostics) | Pushed root scaffold (native tab shell retired for the SV shell) | No SliverAppBar | Explicit `SafeArea` | `ListView` or `CustomScrollView` | `space32` |
| Detail screen | Pushed via `context.push()` | `SliverAppBar` (pinned) | Automatic via AppBar | `CustomScrollView` | `space32` |
| Full-screen (onboarding) | Standalone | None or minimal | Explicit `SafeArea` | `SingleChildScrollView` or `Column` | `space24` |
| Modal / Bottom sheet | `showModalBottomSheet` | DragHandle or header | Not needed | `ListView` or `Column` | `space16` |

---

## 3. Scroll Container Selection Flowchart

```
Need pinned tabs with independent scroll?
  ├─ YES → NestedScrollView
  └─ NO
      │
      SliverAppBar or multiple sliver types?
        ├─ YES → CustomScrollView
        │         Use SliverPadding for margins (not Padding in child)
        └─ NO
            │
            Simple list of similar items?
              ├─ YES → ListView.separated (with space12 separator)
              └─ NO
                  │
                  Simple vertical stack?
                    → SingleChildScrollView + Column
                      (or just Column if content always fits)
```

---

## 4. Error / Loading / Empty State Patterns

Use the DS state widgets instead of ad-hoc spinners or error text.

| State | Widget | Placement |
|-------|--------|-----------|
| Full-page loading | `Center` + `CircularProgressIndicator` | `Scaffold.body` while entire screen loads |
| Full-page error | `FullPageErrorState` | `Scaffold.body` on fatal load failure |
| Empty data set | Centered icon + `Text` (M3) | Inside scroll body when data is empty |
| Inline loading | `SizedBox` + `CircularProgressIndicator(strokeWidth: 2)` | Bottom of list, "load more" |
| Inline error | `Text` with `colorScheme.error` | Inside list or card |

### Typical Riverpod `.when()` Pattern

```dart
ref.watch(myProvider).when(
  data: (data) => _buildContent(data),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => FullPageErrorState(
    message: 'Failed to load data',
    onRetry: () => ref.invalidate(myProvider),
  ),
);
```

Place the `.when()` call where the screen body is built — typically as the `body:` of a `Scaffold` or inside a `SliverToBoxAdapter` if mixed with other slivers.

---

## 5. RefreshIndicator Wiring

`RefreshIndicator` wraps the entire scroll view, not individual slivers or list items.

```dart
RefreshIndicator(
  onRefresh: () => ref.refresh(myProvider.future),
  child: CustomScrollView(
    slivers: [
      const TopAppBar.small(title: 'Title'),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        sliver: SliverList.list(children: [ /* ... */ ]),
      ),
    ],
  ),
)
```

**Notes:**

- For tab screens, each tab has its own `RefreshIndicator`.
- `RefreshIndicator` requires a scrollable child — it does not work with `Column` alone.
- The `onRefresh` callback must return a `Future` (Riverpod's `.future` satisfies this).

---

## 6. Body Padding Rules — Quick Reference

| Role | Token | Value | Notes |
|------|-------|-------|-------|
| Horizontal screen margin | `space16` | 16dp | Applied once at screen level |
| Section gap | `space24` | 24dp | Between major content groups |
| Card gap | `space16` | 16dp | Between cards of the same group |
| List item gap | `space12` | 12dp | `ListView.separated` or Column `spacing` |
| Bottom breathing room | `space32` | 32dp | Last sliver or bottom padding |
| PSL surface body inset | `space24` | 24dp | Horizontal inset for non-ListTile content inside PSL `surfaceSlivers` |

**Implementation tips:**

- In `CustomScrollView`, use `SliverPadding` for margins — not `Padding` inside `SliverToBoxAdapter`.
- Use `Column(spacing: spacing.space16, ...)` / `Row(spacing: ...)` instead of `SizedBox` gaps.
- Apply horizontal margin once at the outermost level. Do not repeat it inside cards.

### Body Padding Anti-Patterns

```dart
// BAD — asymmetric fromLTRB when all sides should be equal
padding: EdgeInsets.fromLTRB(space16, space24, space16, space24)
// GOOD
padding: EdgeInsets.symmetric(horizontal: spacing.space16, vertical: spacing.space24)

// BAD — ListView with zero padding (no screen margins)
ListView(padding: EdgeInsets.zero, children: [...])
// GOOD
ListView(
  padding: EdgeInsets.symmetric(horizontal: spacing.space16),
  children: [...],
)

// BAD — hardcoded off-grid value
padding: const EdgeInsets.only(left: 28)
// GOOD — snap to nearest grid value
padding: EdgeInsets.only(left: spacing.space24)
```

---

## 7. Radius Token System

### Rule: Always Use `radii.*` Getters

Never write `BorderRadius.circular(N)` — always use the token getter.

```dart
// BAD
decoration: BoxDecoration(borderRadius: BorderRadius.circular(12))

// GOOD
final radii = Theme.of(context).extension<AppRadii>()!;
decoration: BoxDecoration(borderRadius: radii.borderRadiusMedium)
```

### Mapping Table: Hardcoded Value → Token

| Hardcoded | Token getter | When to use |
|-----------|-------------|-------------|
| `BorderRadius.circular(8)` | `radii.borderRadiusSmall` | Chips, badges, small inner elements |
| `BorderRadius.circular(12)` | `radii.borderRadiusMedium` | Inner cards, ListTile shape |
| `BorderRadius.circular(16)` | `radii.borderRadiusLarge` | Cards (theme default) |
| `BorderRadius.circular(20)` | `radii.borderRadiusLargeIncreased` | Prominent cards, split sections |
| `BorderRadius.circular(24)` | `radii.borderRadiusXLarge` | Dialogs, bottom sheets |
| `BorderRadius.circular(999)` | `radii.borderRadiusFull` | Pills, fully rounded buttons |

**Snap rules for off-grid values:** `6 → small(8)`, `18 → large(16)`, `26 → xLarge(24)`, `28/30 → full(999)` for pill shapes.

### Decorative Exception

Values ≤4dp on tiny cosmetic elements (progress bar caps, thin indicators) are acceptable as hardcoded. These are decorative, not structural.

### Split-Card Pattern (Top/Bottom Radii)

Use partial-side getters for visually connected but separate card segments:

```dart
// Top segment
Container(
  decoration: BoxDecoration(
    borderRadius: radii.borderRadiusTopLargeIncreased,
    color: colorScheme.surfaceContainerLowest,
  ),
  child: topContent,
)
// Bottom segment (gap between creates split-card look)
Container(
  decoration: BoxDecoration(
    borderRadius: radii.borderRadiusBottomLargeIncreased,
    color: colorScheme.surfaceContainerLowest,
  ),
  child: bottomContent,
)
```

### Single Radius.circular() Usage

When you need a single `Radius` (not `BorderRadius`), use the raw token value:

```dart
// For BorderRadius.vertical or similar partial constructions
BorderRadius.vertical(top: Radius.circular(radii.largeIncreased))
// Or use the convenience getter directly:
radii.borderRadiusTopLargeIncreased
```

---

## 8. Surface Containers

### AppCard Is the Canonical Meso Container

`AppCard` provides the standard surface: `surfaceContainerLowest` background, `outlineVariant` border, `large` (16dp) radius, and configurable padding. Note: `CardThemeData` zeroes Flutter's hidden default 4px margin — Cards sit flush within screen margins with no invisible offset.

| Constructor | Internal padding | Use for |
|-------------|-----------------|---------|
| `AppCard(padding: EdgeInsets.symmetric(vertical: spacing.space8))` | 8dp vertical only | Cards containing only ListTiles |
| `AppCard.compact(child: ...)` | `space12` all sides | Tight content like badges |
| `AppCard.regular(child: ...)` | `space16` all sides | Standard mixed content |
| `AppCard.spacious(child: ...)` | `space24` all sides | Hero sections |

### Never Raw Container + BoxDecoration for Card Surfaces

```dart
// BAD — rebuilds what AppCard already provides
Container(
  decoration: BoxDecoration(
    color: colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: colorScheme.outlineVariant),
  ),
  child: ...
)

// GOOD
AppCard.regular(child: ...)
```

**Exception:** Split-card patterns where top/bottom segments need different radii — these use `Container` + `BoxDecoration` with radii tokens since `AppCard` only supports uniform radius.

---

## 9. Common Anti-Patterns

| Bad Pattern | Fix |
|-------------|-----|
| `BorderRadius.circular(12)` | `radii.borderRadiusMedium` |
| `BorderRadius.circular(20)` | `radii.borderRadiusLargeIncreased` |
| `Color(0xFF...)` for status colors | `semanticColors.success.color` etc. |
| `EdgeInsets.all(14)` (off-grid) | `EdgeInsets.all(spacing.space12)` or `space16` |
| `Container` + `BoxDecoration` as card | `AppCard.regular(child: ...)` |
| `SafeArea` inside screen with `TopAppBar` | Remove — AppBar handles safe area |
| `SizedBox(height: 16)` between items | `Column(spacing: spacing.space16, ...)` |
| `Padding` inside `SliverToBoxAdapter` | `SliverPadding` wrapping the sliver |
| `Padding(horizontal: 16)` around ExpansionTile | Remove — tilePadding from theme already provides K₂ alignment |
| `const EdgeInsets.only(left: 28)` | `EdgeInsets.only(left: spacing.space24)` |
| `EdgeInsets.fromLTRB(16, 24, 16, 24)` | `EdgeInsets.symmetric(horizontal: .space16, vertical: .space24)` |

---

## 10. Copy-Paste Starter Templates

### Detail Screen Template

```dart
class MyDetailScreen extends StatelessWidget {
  const MyDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const TopAppBar.small(title: 'Title'),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            sliver: SliverList.list(
              children: [
                // content here
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: spacing.space32),
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
        ],
      ),
    );
  }
}
```

### Tab Screen Template

```dart
class MyTabScreen extends StatelessWidget {
  const MyTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.space16,
          vertical: spacing.space16,
        ),
        children: [
          // content here
          SizedBox(height: spacing.space32),
        ],
      ),
    );
  }
}
```

### Onboarding / Full-Screen Template

```dart
class MyOnboardingScreen extends StatelessWidget {
  const MyOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space16),
          child: Column(
            children: [
              const Spacer(),
              // illustration / hero content
              SizedBox(height: spacing.space24),
              Text('Title', style: Theme.of(context).textTheme.headlineMedium),
              SizedBox(height: spacing.space12),
              Text('Body text'),
              const Spacer(),
              // bottom CTA button
              SizedBox(height: spacing.space24),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Modal Bottom Sheet Template

```dart
showModalBottomSheet(
  context: context,
  builder: (context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: radii.borderRadiusTopXLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          SizedBox(height: spacing.space8),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: radii.borderRadiusFull,
            ),
          ),
          SizedBox(height: spacing.space16),
          // Content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            child: Column(children: [/* modal content */]),
          ),
          SizedBox(height: spacing.space16),
        ],
      ),
    );
  },
);
```

---

## 11. Screen Review Checklist

Before submitting a new screen, verify:

1. **Padding ownership** — no double margins (screen + card both adding horizontal padding).
2. **Tokens only** — no hardcoded `EdgeInsets`, no magic dp values. All spacing uses `spacing.*`.
3. **Radii tokens** — no `BorderRadius.circular(N)`. All radii use `radii.*` getters.
4. **AppCard usage** — no raw `Container+BoxDecoration` for card surfaces (split-card exception noted).
5. **Correct scroll container** — matches the decision tree in section 3.
6. **State handling** — loading / error / empty use DS widgets, not ad-hoc.
7. **SafeArea** — present only where needed (not doubled with `TopAppBar`).
8. **Bottom padding** — `space32` breathing room at the end.
9. **RefreshIndicator** — wraps scroll view if pull-to-refresh is needed.
10. **SliverPadding** — used for margins in `CustomScrollView` (not `Padding` in `SliverToBoxAdapter`).
11. **Semantic colors** — status/category colors use `semanticColors.*`, not raw hex.
12. **Grid alignment** — all spacing values snap to the 8pt grid (4, 8, 12, 16, 24, 32, 48).
13. **Keylines** — text offsets from screen edge are consistent across sections (K₀ / K₁ / K₂).
14. **No inter-item dividers** — homogeneous ListTile lists use padding, not `Divider`.
15. **PSL surface inset** — non-ListTile content in `surfaceSlivers` uses `space24` horizontal inset (not `space16`).

### Self-Service Audit Commands

```bash
# Find hardcoded BorderRadius (excluding decorative ≤4dp and backups)
grep -rn 'BorderRadius.circular' lib/features/ lib/core/widgets/ | grep -v '.bak' | grep -v 'circular(2)' | grep -v 'circular(4)'

# Find hardcoded Radius.circular
grep -rn 'Radius.circular' lib/features/ lib/core/widgets/ | grep -v '.bak' | grep -v 'circular(2)' | grep -v 'circular(4)'

# Find raw Container with BoxDecoration (potential AppCard candidates)
grep -rn 'BoxDecoration' lib/features/ | grep -v '.bak'

# Find off-grid EdgeInsets values
grep -rn 'EdgeInsets' lib/features/ | grep -v '.bak' | grep -E '\b(5|7|9|10|11|13|14|15|17|18|19|20|22|25|26|28|30)\b'
```

---

Cross-references: [`LAYOUT.md`](LAYOUT.md), [`SURFACES.md`](SURFACES.md), [`CONSTRAINTS.md`](CONSTRAINTS.md), [`app_spacing.dart`](../tokens/app_spacing.dart), [`app_radii.dart`](../tokens/app_radii.dart), [`app_sizing.dart`](../tokens/app_sizing.dart)
