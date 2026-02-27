# Typography Reference

Self-contained typography guide for the design system.

## The No-copyWith Rule

Use Material 3 `textTheme` styles as-is. Do not override font weight, letter spacing, or
other properties with `copyWith`.

**Why:** A consistent type scale matters more than pixel-matching Figma. When every widget
picks its own weight or size via `copyWith`, the app accumulates dozens of one-off text styles
that drift from the scale. Readers lose the ability to scan — a `titleMedium` should look the
same everywhere.

**When Figma disagrees:** If Figma shows 16px/w600 but the closest M3 style is `titleMedium`
(16px/w500), use `titleMedium` as-is. The 100-unit weight difference is imperceptible to users
but keeping the scale intact is not.

**When the whole scale feels wrong:** Refactor the `TextTheme` at the theme level (one change,
every widget updates) rather than sprinkling `copyWith` overrides across individual widgets.

Access: `Theme.of(context).textTheme`.

## M3 Type Scale Reference

Default Material 3 type scale (2021 tokens, no custom `TextTheme`):

| Style | Size | Weight | Line Height | Typical Use |
|-------|------|--------|-------------|-------------|
| `displayLarge` | 57 | 400 | 64 | Hero numbers, splash headlines |
| `displayMedium` | 45 | 400 | 52 | Large feature numbers |
| `displaySmall` | 36 | 400 | 44 | Score values, large data |
| `headlineLarge` | 32 | 400 | 40 | Screen titles |
| `headlineMedium` | 28 | 400 | 36 | Section headers |
| `headlineSmall` | 24 | 400 | 32 | Card titles (prominent) |
| `titleLarge` | 22 | 400 | 28 | App bar title, dialog title |
| `titleMedium` | 16 | 500 | 24 | Card titles, list headers |
| `titleSmall` | 14 | 500 | 20 | Subtitles, secondary headers |
| `bodyLarge` | 16 | 400 | 24 | Primary body text |
| `bodyMedium` | 14 | 400 | 20 | Default body text |
| `bodySmall` | 12 | 400 | 16 | Captions, helper text |
| `labelLarge` | 14 | 500 | 20 | Button labels, nav labels |
| `labelMedium` | 12 | 500 | 16 | Chip labels, badges |
| `labelSmall` | 11 | 500 | 16 | Overlines, timestamps |

All sizes in logical pixels. Weights are `FontWeight` values (400 = regular, 500 = medium).

**Key observations:**

- The scale has three "families" — display (large data), headline/title (structure), body/label
  (content). Pick the right family first, then choose the size.
- `titleMedium` (16/w500) is the workhorse for card and list headers.
- `labelSmall` (11/w500) is the smallest standard style — avoid going below it.

**Access pattern:**

```dart
final textTheme = Theme.of(context).textTheme;

// Card title
Text('Challenge Name', style: textTheme.titleMedium),

// Body text
Text('Description here...', style: textTheme.bodyMedium),

// Overline label
Text('ENDS IN', style: textTheme.labelSmall),
```

## Permitted Exceptions

`copyWith` is allowed for **functional** needs — cases where the standard scale genuinely
cannot serve the purpose. Each exception must have a clear justification.

| Exception | copyWith | Justification |
|-----------|----------|---------------|
| Monospace for tabular data | `.copyWith(fontFamily: 'monospace')` | Tabular number alignment requires fixed-width glyphs. Variable-width digits cause columns to misalign. This is a functional requirement, not a style preference. |
| Bold for time-critical data | `.copyWith(fontWeight: FontWeight.w700)` | When a data value is actionable and time-sensitive (e.g., countdown timer), weight contrast against its label creates the information hierarchy that the standard scale cannot provide at the same font size. |

**Not permitted:**

- Adjusting weight to match Figma (use the closest M3 style instead)
- Changing letter spacing for aesthetic reasons
- Overriding line height on individual widgets

## Typography Decisions

Decisions captured from widget creation sessions:

| Date | Widget | Decision | Rationale |
|------|--------|----------|-----------|
| 2026-02-23 | ChallengeCard | Keep `titleMedium` (16px/w500) despite Figma showing w600 | No heavier 16px variant exists without `copyWith(fontWeight: w600)`. If a different weight scale is needed, refactor the entire `TextTheme`. |
| 2026-02-23 | ScoreHeader | `displaySmall.copyWith(fontFamily: 'monospace')` for score | Functional `copyWith` for tabular number alignment. Figma uses IBM Plex Mono (not in project); system monospace is acceptable. |
| 2026-02-23 | ScoreHeader | `labelSmall.copyWith(fontWeight: FontWeight.w700)` for countdown | Deliberate deviation — the time value is actionable data needing visual separation from the "ENDS IN" label. Weight contrast serves information hierarchy. |
