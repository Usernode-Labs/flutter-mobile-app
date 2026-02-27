# Design System

Sandboxed POC in `lib/design_system/` for agentic widget building with a living design system.

## Philosophy

- **Code + tokens = truth.** The widget implementation and its design tokens are authoritative.
- **Figma = inspiration.** A useful reference, not a spec to match.
- **Every deviation is a decision.** Document the reasoning in [DECISIONS.md](docs/DECISIONS.md).

## Key Boundaries

- **No chromatic structure.** Primary/secondary/tertiary are achromatic. Only semantic colors carry hue.
- **No hardcoded values.** All visual properties flow from `ThemeExtension` tokens — no hex literals, no magic numbers.
- **No state in design system widgets.** Data in, pixels out. No providers, no services, no async. Screens in `lib/features/` wire state.
- **No `copyWith` on textTheme.** Use M3 styles as-is. Permitted exceptions documented in [CONSTRAINTS.md](docs/CONSTRAINTS.md).
- **No elevation for separation.** Borders replace shadows. Two-tier surface model: grey scaffold + white content. See [SURFACES.md](docs/SURFACES.md).
- **No FRB-generated types in widget constructors.** They transitively import native FFI.

## Quick Start

```dart
final colors   = Theme.of(context).colorScheme;              // M3 colors
final semantic = Theme.of(context).extension<AppSemanticColors>()!; // domain colors
final spacing  = Theme.of(context).extension<AppSpacing>()!;  // spacing tokens
final textTheme = Theme.of(context).textTheme;                // typography
```

## File Map

| Path | Contents |
|------|----------|
| `tokens/` | Spacing, radii, elevation, opacity, sizing, animation, semantic colors |
| `theme/` | ColorScheme construction, ThemeExtension wiring |
| `src/` | Widget implementations |
| `docs/CONSTRAINTS.md` | Rules, quality gate, widget pipeline |
| `docs/COLOR.md` | Color philosophy and semantic color groups |
| `docs/SURFACES.md` | Two-tier surface model |
| `docs/DECISIONS.md` | Design decisions organized by topic |

## Widget Catalog

<!-- Updated by the widget builder after each new component -->
| Widget | Source | Genesis |
|--------|--------|---------|
| `ChallengeCard` | [Figma (list)](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=2943:19310), [Figma (ongoing)](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=3012:2402) | [genesis](.specs/ChallengeCard.genesis.md) |
| `ChallengeCategoryIcon` | [Figma](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=3012:2775) | [genesis](.specs/ChallengeCategoryIcon.genesis.md) |
| `Button` | — | [genesis](.specs/ScoreHeader.genesis.md) |
| `DropdownChain` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2860) | [genesis](.specs/DropdownChain.genesis.md) |
| `DropdownChip` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2860) | [genesis](.specs/DropdownChip.genesis.md) |
| `DropdownSheet` | — | [genesis](.specs/DropdownSheet.genesis.md) |
| `ScoreHeader` | [Figma (default)](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2193), [Figma (glow)](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:3259) | [genesis](.specs/ScoreHeader.genesis.md) |
| `Tabs` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=3012:2400) | [genesis](.specs/Tabs.genesis.md) |
| `TopAppBar` | [Figma (small)](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2994:2764), [Figma (large)](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=2943:28629) | [genesis](.specs/TopAppBar.genesis.md) |
| `ListSystem` | [Figma](https://figma.com/design/Eu4jn5o8finpZ28IAGPyru/?node-id=3448-15182) | [genesis](.specs/ListSystem.genesis.md) |
| `ChallengeRewardCard` | [Figma](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=2943:28627) | [genesis](.specs/ChallengeRewardCard.genesis.md) |
| `ChallengeDetailPage` | [Figma](https://figma.com/design/rsh9wLMKsMnFPOEBkHJUvg/?node-id=2943:28627) | [genesis](.specs/ChallengeDetailPage.genesis.md) |
