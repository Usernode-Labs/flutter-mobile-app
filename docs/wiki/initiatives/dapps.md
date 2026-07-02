# dApps

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-07-02 ([tracker #382](https://github.com/Usernode-Labs/flutter-mobile-app/issues/382))_

## Phase status

| Phase | Status |
|---|---|
| Idea | ✅ DONE |
| Demo | ✅ DONE |
| Core Testnet | 🔄 NOW |
| Pilot Testnet | — |
| Mainnet | — |

## Active work

### Pull requests

- [#463](https://github.com/Usernode-Labs/flutter-mobile-app/pull/463) Make challenges dynamic and keep related screens consistent

## Recent activity (30d)

- [#352](https://github.com/Usernode-Labs/flutter-mobile-app/pull/352) improve dapp transaction logger

## Related discussions

- #370 Mainnet Maturity Matrix plan
- #417 Re-scope init:mini-apps: from dApp host to social agentic app framework
<!-- auto:end -->

## Overview

dApps framework — third-party apps running inside the Usernode mobile app, using the wallet and identity primitives, and increasingly positioned as a substrate for human + agent coordination (see "The idea" below). Idea and Demo phases closed with the merge of #352 ("further dApp improvements"). No active work; the initiative is parked until Core Testnet capacity opens up.

## The idea

_Seed-level — develops as design conversations land. Current framing from the Zura x Lukas conversation (2026-05-13, ~00:24)._

### Objective

Position dApps as a substrate for **human + agent coordination** grounded in the same identity / stake / activity signals that drive consensus elsewhere in the network — not just a host for arbitrary third-party code.

### Problem

Agentic systems (AI deciding what to build, what to fund, what to merge) face a recurring question: **whose input do they listen to, and how much?** Without a verifiable signal, you fall back on either centralised gatekeeping (someone curates the input list) or token-weighted voting (whales win) — both of which the network is explicitly trying to escape.

Web3 doesn't fix this by default. Token voting gives capital the wheel. Off-chain reputation systems become Sybil-able the moment they matter. Anything not grounded in verifiable, costly-to-fake identity + activity drifts toward farming.

### Solution

The triple-signal the network already produces — **ZK identity** (proof of unique human), **stake** (skin in the game), **activity** (earned track record from [fair rewards](fair-rewards.md)) — is the natural alignment layer for human + agent coordination inside a dApp.

A dApp can ask, on any decision:

- Is this input from a real, unique human? *(identity)*
- How much do they have at stake in the outcome? *(stake)*
- Have they made decisions of this kind before? *(activity)*

Once a coordinated decision exists, agents can execute on it. **Social vibe coding** is the early shape of this loop: humans converge on what to build through a verified-input channel, agents do the building, the dApp is the medium where the loop closes.

### Design-space unknowns

- **Domain-specific activity.** Track record is contextual — your reputation in a code-review dApp shouldn't transfer wholesale to a treasury-allocation dApp. How does the platform expose per-dApp activity scoring vs cross-dApp portability?
- **What constrains the agents?** Code agents need a scoped surface ("change this UI", "draft this RFC"). Without it, you're back to centralisation by whoever picked the agent.
- **Sandboxing.** dApps run inside the wallet/identity host. What surface does the host expose to the dApp, and what does the dApp expose to its agents? Wallet primitives must not leak.
- **Sybil at the dApp level.** ZK identity prevents one human from being two humans on-chain. But a single human can still run multiple personas inside one dApp. Worth blocking, or worth allowing?

### Out of the box

- **Agents that build their own track record.** An agent could earn activity multipliers by reliably executing on community decisions — turning agents into accountable participants, not just tools.
- **Cross-dApp reputation portability.** Identity + stake + activity ride with the user. A new dApp could weight inputs by reputation earned in adjacent dApps — opt-in, transparent, sybil-resistant.

## Open questions

- What changes between Demo and Core Testnet for this initiative? Stability, security review, or new API surface?
