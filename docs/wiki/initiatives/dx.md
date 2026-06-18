# Developer Experience (DX)

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-06-18 ([tracker #387](https://github.com/Usernode-Labs/flutter-mobile-app/issues/387))_

## Phase status

| Phase | Status |
|---|---|
| Idea | ⏳ LATER |
| Demo | — |
| Core Testnet | — |
| Pilot Testnet | — |
| Mainnet | — |

## Active work

### Issues

- [#350](https://github.com/Usernode-Labs/flutter-mobile-app/issues/350) PR Checks & Test Suite CI always fail: poisoned FRB codegen cache
- [#356](https://github.com/Usernode-Labs/flutter-mobile-app/issues/356) Add explicit error state handling for AsyncValue providers in UI screens
- [#369](https://github.com/Usernode-Labs/flutter-mobile-app/issues/369) DS Evolution: DESIGN.md + Widgetbook v4 + Composition Playbooks + ds_lints + Marionette MCP
- [#372](https://github.com/Usernode-Labs/flutter-mobile-app/issues/372) Testing Evolution: Widgetbook Scenarios + Integration Tests + Marionette
- [#409](https://github.com/Usernode-Labs/flutter-mobile-app/issues/409) Wire Sentry: enable telemetry flags + connect Sentry MCP (Opportunity E Step 0)
- [#462](https://github.com/Usernode-Labs/flutter-mobile-app/issues/462) Promote AppCard into the DS as a tokenized, Card-free surface primitive (story + test)

### Pull requests

- [#371](https://github.com/Usernode-Labs/flutter-mobile-app/pull/371) DS Evolution: DESIGN.md + Widgetbook v4 + ds_lints + Marionette MCP

## Recent activity (30d)

- [#390](https://github.com/Usernode-Labs/flutter-mobile-app/pull/390) docs: Mainnet Maturity Matrix wiki — pages + priorities + idea pattern

## Related discussions

- #370 Mainnet Maturity Matrix plan
- #368 DS Evolution Gap Analysis
- #367 Harness Engineering Gap
<!-- auto:end -->

## Overview

The feedback loop, tooling, and conventions that let humans and agents ship correctly without supervision. Scope covers the design system (`lib/design_system/`), lints (`ds_lints`), Widgetbook, integration tests, Marionette MCP, agent skills, pre-commit hooks, `DESIGN.md`, `CLAUDE.md`, and related dev-loop infrastructure.

This is the newest of the 11 matrix initiatives and the broadest — it was renamed from `init:design-system` on 2026-04-13 because "design system" was a means, not an end. The end is "an agent (or a distracted human) can pick up a task and ship it correctly on the first try."

## Known constraints

- **Agents are the demanding consumer, humans benefit.** Work here is justified by agent effectiveness but evaluated on whether it also helps humans. If a change only helps agents, it's probably over-specialized.
- **M3 first.** Never build a custom widget that duplicates a Material 3 component — compose DS slot widgets (IconBadge, StatusBadge, etc.) into M3 containers. Proven gaps only. (See `CLAUDE.md § Design System Boundary`.)
- **Widgetbook use cases must import the real widget with mock data via knobs** — hand-built replicas drift silently.
- **Tokens via `Theme.of(context).extension<T>()`** — no hard-coded spacing or color, no direct `ColorScheme` role access for chromatic color (those are all achromatic grey; use `AppSemanticColors`).

## Open questions

- Widgetbook v4 migration is waiting on a stable release (currently beta.3). What's the trigger to migrate — a specific beta, or when v4 reaches RC?
- Do we want a single `DESIGN.md` source of truth, or keep the current split across `CLAUDE.md § Design System Boundary`, `lib/design_system/DESIGN_SYSTEM.md`, and `lib/design_system/docs/SCREEN_PATTERNS.md`? (Tracked in #369.)
- Where does `/maturity-audit` belong long-term — personal skill (current) or committed slash command for the team? Currently gitignored under `.claude/`.
