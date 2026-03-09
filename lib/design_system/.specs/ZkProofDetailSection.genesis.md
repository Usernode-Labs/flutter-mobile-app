# ZkProofDetailSection — Genesis

## Inspiration
- **Source**: zkPassport app's "Information Shared" screen
- **Figma URL**: N/A
- **Key insight**: Since this is a zero-knowledge proof that shares NO personal data, the framing is "What You Proved" (empowerment), not "Information Shared" (implies exposure). Addresses user fears ("was my data shared?") and emphasizes wins ("I proved my identity privately and earned points").

## Design Decisions

### Slot widget, not standalone card
- **What the reference showed**: A separate card for verification results
- **What we implemented**: A slot widget that composes into the `ChallengeRewardCard` footer
- **Why**: Merging earned points with proof details into a single high-prominence card creates a unified reward+proof narrative. The separate low-prominence card was visually disconnected.

### Color delegation via constructor params
- **What the reference showed**: Fixed colors for a standalone context
- **What we implemented**: `onColor` / `dimOnColor` passed as params
- **Why**: Same pattern as `_CalculationRow` in ChallengeRewardCard — the slot widget adapts to any category container color without knowing the category itself.

### Generic rows model with leading icons
- **What we implemented**: `List<({IconData icon, String label, String value, bool monospace})>`
- **Why**: Generic enough for reuse across different proof types. Each row has a leading icon for quick visual scanning (e.g. `check_circle` for Status, `shield` for Privacy). The `monospace` flag handles hex identifiers (Proof ID) using `kMonoFontFamily`, which is a permitted `copyWith` exception per CONSTRAINTS.md. Icons render at `sizing.iconSmall` (20px) in `dimOnColor` for secondary emphasis.

## Token Mapping
| Figma Value | Design System Token | Notes |
|-------------|-------------------|-------|
| Heading style | `textTheme.labelLarge` | Matches ChallengeRewardCard section headings |
| Description style | `textTheme.bodySmall` | Standard secondary text |
| Row label style | `textTheme.bodySmall` + dimOnColor | Dimmed for visual hierarchy |
| Row value style | `textTheme.bodySmall` + onColor | Full contrast for readability |
| Heading→desc gap | `spacing.space8` | Standard tight gap |
| Desc→rows gap | `spacing.space12` | Standard medium gap |
| Inter-row gap | `spacing.space8` | Standard tight gap |
| Mono font | `kMonoFontFamily` | For hex identifiers |
| Row icon size | `sizing.iconSmall` (20px) | Compact for card footer context |
| Row icon color | `dimOnColor` | Secondary emphasis, matching label text |
| Icon→label gap | `spacing.space12` | Standard medium gap |

## Golden Reference
- **Golden file**: `test/design_system/goldens/zk_proof_detail_section.png`
- Rendered with light theme, community category container background
