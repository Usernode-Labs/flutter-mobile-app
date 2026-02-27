# Design System — Living Document

This document grows from real widget creation sessions. Rules are added when agents fail without them, not speculatively.

> **Sandboxed POC** — This is an isolated proof-of-concept design system in `lib/design_system/` to experiment with agentic widget building using a living design system. No existing code is modified beyond adding widgetbook to `pubspec.yaml`.
> This boundary is intentional and likely temporary.

## Philosophy

- **Code + tokens = truth.** The widget implementation and its design tokens are authoritative.
- **Figma = inspiration.** A useful reference, not a spec to match. Figma screenshots are kept for context, not compliance.
- **Every deviation is a decision.** When the implementation differs from the inspiration, that's not drift — it's a choice. The genesis file documents the reasoning.

## Design Goals

What this design system solves for a blockchain wallet and node operator app:

| Goal | Why It Matters |
|------|----------------|
| **Trustworthy financial UI** | Users manage wallets, run nodes, and earn rewards. Restraint and precision build trust — visual noise undermines confidence in an app handling real assets. |
| **Scannable information density** | Node status, block production stats, wallet balances, challenge progress across 3 categories — dense data needs clear hierarchy without clutter. |
| **Accessible by default** | APCA-verified contrast at 3 levels (standard/medium/high), 48dp touch targets, progressive contrast cascade. Accessibility is structural, not retrofitted. (See "Color Philosophy" below) |
| **Agent-buildable widgets** | Presentation-only widgets with all state via constructor params enable AI agents to reliably build, test, and verify UI components. No hidden state, no implicit providers. (See "Presentation-Only Widgets" below) |
| **Theme-driven consistency** | Every visual property — color, spacing, radii, elevation — flows from `ThemeExtension`s. No hardcoded values, no magic numbers. (See "Token Vocabulary" below) |
| **Progressive migration** | The design system coexists with legacy code in `lib/core/`. New screens adopt it fully; existing screens migrate incrementally. |

Success looks like: a developer (human or AI) can build a new screen using only theme tokens, semantic colors, and M3 components — without referencing any hardcoded value or legacy pattern.

## Design Principles

The core principles that guide every design decision, ordered by precedence:

1. **Color is expensive.** Every chromatic pixel must earn its place through semantic purpose. Structure is achromatic; only content and status carry hue. The interface is grey infrastructure with chromatic semantics — not a colorful canvas with muted structure. (See "Color Philosophy" below)

2. **Presentation-only widgets.** Data in, pixels out. No providers, no services, no async loading inside design system widgets. Feature screens in `lib/features/` wire state; design system widgets in `lib/design_system/` render it. (See "Presentation-Only Widgets" below)

3. **Tokens are the API.** All visual properties accessed via `Theme.of(context).extension<T>()!` — spacing, radii, elevation, semantic colors. No hardcoded hex values, no magic numbers, no flat-constant imports. The theme is the single source of truth. (See "Token Vocabulary" below)

4. **M3 first, primitives when needed.** Use Material 3 components for interaction patterns (buttons, navigation, sheets) — they bring ripple, focus, keyboard, hover, and semantics for free. Build from Flutter primitives only when M3 doesn't cover the need. (See "M3 Components First" below)

5. **Accessibility is structural.** APCA-verified contrast at 3 levels: body text Lc >= 90, accents Lc >= 60, borders Lc >= 30. The ghost tertiary yields to user needs via the contrast cascade — standard is the design ideal, high contrast is the accessibility guarantee. Not a checklist item — baked into the token and theme system.

6. **Semantic color as vocabulary.** Four domain-specific chromatic groups (technical/flash/community/success) via `AppSemanticColors`. Color means something specific; adding a 5th group is a design decision, not a convenience. A closed vocabulary amplifies every color's signal. (See "Color Philosophy" below)

7. **Two-tier surfaces.** Grey scaffold (`surface`) + white content (`surfaceContainerLowest`). Borders for separation, not elevation. Simpler than M3's five-level tonal gradient, clearer than subtle tonal steps. (See "Surface Architecture" below)

8. **Single source of truth.** The theme is the spec. Widget implementation + design tokens = authoritative. Figma is inspiration, not compliance target. (See "Philosophy" above)

## First-Principles Rationale

Why THIS app needs THIS design system:

**The domain.** A Layer 1 blockchain operated from mobile phones. Users run validator nodes, manage wallets, participate in challenges (technical, flash, community), and earn rewards. Every screen carries financial or operational data.

**Why restraint builds trust.** Financial transactions and node operations demand confidence. Users need assurance that the app handles their assets correctly. Visual noise undermines this — every decorative element competes with critical data like balances, transaction status, and node health. An achromatic structural layer lets the signals that matter (errors, challenge categories, success states) stand out unmistakably.

**Why information density matters.** Node operators monitor block production stats, slot assignments, mempool state, and peer connections. Wallet users track balances, transaction history, and UTXOs. Challenge participants track progress across 3 categories simultaneously. This is a data-heavy app where every screen carries multiple information layers — clear hierarchy is not optional.

**Why "color is expensive" fits the domain.** The challenge system has exactly 3 categories (technical, flash, community) plus success/error states — a small, closed color vocabulary. Blue = technical, amber = flash, green = community. Each color is instantly recognizable because it appears on a grey canvas. A colorful UI would force these categories to compete with structural decoration, diluting every signal.

**Why agent-buildability matters.** This design system is built collaboratively by AI agents and humans. Presentation-only widgets, theme-driven tokens, and explicit semantic color access patterns make the system predictable for agents — no hidden state, no implicit providers, no ambient color context to reason about. An agent can build a widget by reading the token vocabulary and following the access patterns.

## Quick Start
```dart
final colors   = Theme.of(context).colorScheme;              // M3 colors
final semantic = Theme.of(context).extension<AppSemanticColors>()!; // domain colors
final spacing  = Theme.of(context).extension<AppSpacing>()!;  // spacing tokens
final textTheme = Theme.of(context).textTheme;                // typography
```

## Reference Guides
| Topic | File | What's Inside |
|-------|------|---------------|
| Color | [COLOR.md](docs/COLOR.md) | "Color is expensive" philosophy, M3 roles, ghost tertiary, semantic colors, access patterns |
| Surfaces | [SURFACES.md](docs/SURFACES.md) | Two-tier surface model, component classification, M3 deviations |
| Tokens | [TOKENS.md](docs/TOKENS.md) | All 7 ThemeExtension tokens — values, access code, M3 alignment |
| Typography | [TYPOGRAPHY.md](docs/TYPOGRAPHY.md) | M3 type scale, no-copyWith rule, permitted exceptions |
| Components | [COMPONENTS.md](docs/COMPONENTS.md) | M3-first strategy, presentation-only rule, widget pipeline, catalog |
| Theme Architecture | [THEME_ARCHITECTURE.md](docs/THEME_ARCHITECTURE.md) | ColorScheme construction, extension wiring, dark mode, contrast levels |
| Decisions | [DECISIONS.md](docs/DECISIONS.md) | Design decisions organized by topic |
