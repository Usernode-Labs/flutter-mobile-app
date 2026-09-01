# Typography

How text styles are applied across the design system.

## Base: M3 Text Scale

All typography starts from `Theme.of(context).textTheme`. The M3 type scale
(display, headline, title, body, label) is the single source of truth for size,
weight, and line height. See [CONSTRAINTS.md](CONSTRAINTS.md) "No-copyWith Rule".

## Display Mono Rule

**Any screen's primary KPI or status headline uses IBM Plex Mono.**

Apply via `.copyWith(fontFamily: 'IBMPlexMono')` on the relevant `textTheme`
style. This gives hero text a technical, engineering identity that is consistent
across the app.

**Canonical hero size: `displaySmall` (36px).** All primary KPI / status headlines
use this style for consistent visual weight across the app.

### Where it applies

| Screen | Style | Text |
|--------|-------|------|
| Wallet | `displaySmall` | Balance number |
| Node Status | `displaySmall` | "Synced" / "Syncing" / "Offline" |
| Quick Settings | `displaySmall` | "All Good" / "Action Needed" |
| Slot Production Stats | `displaySmall` | Success rate % |
| Produced Blocks | `displaySmall` | Success rate % |
| ScoreHeader (DS) | `displaySmall` | Score value |

### When to use

- The text is the single most prominent data point on the screen or card.
- It represents a KPI, score, balance, percentage, or status headline.
- It sits at or above `titleLarge` in the type scale hierarchy.

### When NOT to use

- Body copy, labels, captions, or secondary information.
- Lists of data (use default type scale).
- Situations where the text isn't the hero — don't sprinkle monospace for
  decoration.

## Permitted `copyWith` Exceptions

These are the only functional overrides allowed on `textTheme` styles. See
[CONSTRAINTS.md](CONSTRAINTS.md) for the authoritative table.

| Exception | copyWith | Justification |
|-----------|----------|---------------|
| Monospace for tabular data | `.copyWith(fontFamily: 'IBMPlexMono')` | Fixed-width glyphs for column alignment |
| Monospace for display hero text | `.copyWith(fontFamily: 'IBMPlexMono')` | Unified technical identity for primary KPI / status headlines |
| Bold for time-critical data | `.copyWith(fontWeight: FontWeight.w700)` | Weight contrast for actionable values |

## Font Asset

IBM Plex Mono is bundled in the app (`pubspec.yaml`). It is not a system
fallback — all users see the same typeface.

## Cross-references

- [CONSTRAINTS.md](CONSTRAINTS.md) — No-copyWith Rule and permitted exceptions
- [DECISIONS.md](DECISIONS.md) — "Display Mono Unification" decision entry
