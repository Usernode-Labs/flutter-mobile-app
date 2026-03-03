# TODO — Deferred Refactors & Known Issues

Backlog of identified issues intentionally deferred from the current task.
Covers the design system, feature screens, and shared code.

## How this file is structured

Entries are grouped by **category**. Within each category, entries are listed
newest-first. When adding a new entry, pick the category that fits (or create
one) and prepend your item at the top of that section.

**Entry format:**

```
### Short title
<!-- area: design-system | feature/settings | feature/wallet | core | theme -->

Where: `path/to/file.dart` (line ~N)
What: one-sentence problem statement.
Fix: one-sentence suggested fix.
```

The `<!-- area: ... -->` comment is a machine-readable tag so entries can be
filtered by area. Use the feature folder name (e.g. `feature/settings`) or
`design-system`, `core`, `theme` for shared code.

**Categories:**

| Category | What goes here |
|---|---|
| Extract widget | Duplicated UI pattern ready to become a shared widget |
| Theme defaults | Values that should move into the theme so widgets can be bare |
| API simplification | Parameter sprawl, data class restructuring |
| Bugs | Confirmed defects not yet fixed |
| Testability | Missing overrides, untestable code paths |
| Toolchain | Analysis errors, lint gaps, build issues |

---

## Extract widget

### Consolidate address shortening into `Utils.shortenID`
<!-- area: core -->

Where: `wallet_screen.dart`, `transaction_success_screen.dart`,
`transaction_model.dart`, `pending_transaction.dart`, `wallet_provider.dart`
What: 6+ inline `substring(0,8)...substring(length-8)` implementations with
minor variations (`...` vs `..`, different length guards).
Fix: replace all with `Utils.shortenID(value, head: 8, tail: 8)` from
`lib/core/utils/utils.dart` which already exists with configurable params.

### Section header
<!-- area: design-system -->

Where: `general_settings_section.dart`, `faq_section.dart`
What: identical `Text` + `SizedBox` section header pattern duplicated twice.
Fix: extract a `ListSectionHeader(title:)` widget — archived guidance
(`07_list_system_guidance.md`) explicitly calls for this.

---

## Theme defaults

### SendScreen `_buildField` — let M3 `InputDecorationTheme` do the work
<!-- area: theme -->

Where: `lib/features/wallet/screens/send_screen.dart` `_buildField` method
What: manually reconstructs M3 filled-text-field style with `ClipRRect` +
`Container` + 5× `InputBorder.none` + `filled: false`. M3's filled variant
already uses `surfaceContainerHighest` with a bottom indicator line.
Fix: add `InputDecorationTheme` to `color_is_expensive_theme.dart` and simplify
`_buildField` to a plain `TextFormField` with default decoration.

### ExpansionTile childrenPadding
<!-- area: theme -->

Where: `faq_section.dart` (4 instances)
What: all 4 `ExpansionTile`s override `childrenPadding` with
`EdgeInsets.fromLTRB(space16, 0, space16, space16)`.
Fix: update `ExpansionTileThemeData.childrenPadding` in the theme if this is
the canonical padding, so tiles can omit it.

---

## API simplification

### WalletScreen shadow state → `ref.watch`
<!-- area: feature/wallet -->

Where: `lib/features/wallet/screens/wallet_screen.dart`
What: maintains `_walletState` / `_nodeStatus` shadow copies of provider state,
synced via manual `setState` in a 5-second timer and `_onRefresh`. Creates a
timing window where provider has updated but widget shows stale data.
Fix: replace shadow fields with `ref.watch(walletProvider)` /
`ref.watch(nodeStatusProvider)` in `build()`. Remove `_loadInitialData`,
simplify timer to just call `silentRefresh()` without `setState`.

### FaqLocalizations (28 fields)
<!-- area: feature/settings -->

Where: `lib/features/settings/widgets/faq_section.dart`
What: 28 required `String` fields with repeating patterns
(`step1Title`/`step1Desc`, `defaultMode`/`defaultReliability`/`defaultDesc`).
Fix: model as lists of small data objects (`FaqStep`, `ReliabilityMode`),
reducing to ~8-10 fields.

### BuildInfo / BuildInfoLocalizations (13 + 11 fields)
<!-- area: feature/settings -->

Where: `lib/features/settings/widgets/build_info_sheet.dart`
What: flat data classes that would read better with sub-objects.
Fix: group into `GitInfo`, `RustInfo`, `CargoInfo`. Lower priority — only
constructed once on user tap.

---

## Bugs

### AppCard drops theme border side
<!-- area: core -->

Where: `lib/core/widgets/app_card.dart`
What: overrides `Card.shape` with a `RoundedRectangleBorder` that omits the
`outlineVariant` border side defined in `CardTheme`. Produces borderless cards,
contradicting `SCREEN_PATTERNS.md`.
Fix: remove the shape override (let theme apply) or explicitly include the
border side.

---

## Testability

### FaqSection platform override
<!-- area: feature/settings -->

Where: `lib/features/settings/widgets/faq_section.dart`
What: `_buildPlatformTile` reads `defaultTargetPlatform` directly; widgetbook
cannot demonstrate iOS vs Android FAQ differences.
Fix: add a `platformOverride` parameter matching `QuickSettingsPanel`'s pattern.

---

## Toolchain

### `defaultTargetPlatform` undefined (7 errors, pre-existing)
<!-- area: feature/settings -->

Where: `settings_screen.dart`, `faq_section.dart`, `quick_settings_panel.dart`
What: all files import `package:flutter/material.dart` which should export
`defaultTargetPlatform`. 7 analysis errors.
Fix: investigate — likely a Flutter 3.35.x regression or stale analysis cache.
