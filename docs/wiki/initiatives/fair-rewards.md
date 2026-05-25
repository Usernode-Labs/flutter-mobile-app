# Fair Rewards

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-05-25 (tracker #381)_

## Phase status

| Phase | Status |
|---|---|
| Idea | 🔄 NOW |
| Demo | — |
| Core Testnet | — |
| Pilot Testnet | — |
| Mainnet | — |

## Active work

### Issues

- [#354](https://github.com/Usernode-Labs/flutter-mobile-app/issues/354) Simplify challenge categorization — remove enabled/completed theatre

### Recent activity (30d)

- [#411](https://github.com/Usernode-Labs/flutter-mobile-app/pull/411) fix(challenges): render CTA button on challenge detail page

## Related discussions

- #370 Mainnet Maturity Matrix plan
- #362 Challenge Properties Reference
- #421 Challenge CTAs: option to open the app, not just a webview
- Usernode-Labs/usernode#799 Incentive placement: L1-baked vs Foundation-distributed

<!-- auto:end -->

## Overview

Fair reward distribution and the challenges system that feeds it. Challenges are the user-visible shape of rewards — completing them is how users earn. The design space is articulated in "The idea" below; current operational work is shrinking the categorization surface (#354) before the system is frozen for Demo.

## The idea

### Objective

Align network incentives with human-centric utility so users are rewarded for active contributions, not just capital weight.

### Problem

**The Pareto trap.** Standard Proof-of-Stake rewards capital, not labor. Hold 1% of supply, capture 1% of rewards — regardless of contribution to network health. Compounds into long-term centralization.

**The data center bias.** Networks optimized purely for performance favor server-grade hardware. Mobile nodes can't compete on latency, so the user-owned edge is structurally excluded from consensus.

**The solo staker paradox.** Current L1s can't distinguish a human running their own hardware from an automated script in a data center. Rewards default to capital because that's the only signal — individual users become mathematically irrelevant.

### Solution

**The Schelling point.** You and a friend must meet in NYC but can't talk. Most people go to the clock at Grand Central Terminal — not because it's anyone's favorite spot, but because everyone expects everyone else to go there. The landmark is whatever rational coordinators converge on.

In Usernet, that landmark is a healthy, censorship-resistant network. Users protect it (by being reliable and unique) because their tokens and access only have value if the network itself is alive.

**Dual-track engine.** Rewards split 50/50 between a stake component (capital) and an identity component (human weight). Human weight = base identity score × activity. Active mobile users can out-earn passive whales.

**Deterministic rewards (labor over luck).** Probabilistic consensus makes participation a lottery — a small-stake solo node rarely wins. We reward the actual work of participating instead: local VRF calculation, slot syncing during a won slot, block production when called. Even a tiny stake earns a predictable, steady return for labor. Node operation becomes a job, not a gamble.

**Two-tier placement (L1-baked vs Foundation-distributed).** Reward mechanisms split across two layers. L1-baked incentives — block-production multipliers, on-chain reward formulas — require a fork to change, so the L1 hosts only durable mechanisms expected to last ≥1 year (e.g. liquidity provision, BTC held in a bridge). Foundation-distributed incentives are paid from treasury or accumulated staking rewards and change without a fork — the natural home for short-term, experimental, or campaign-style payouts (e.g. testnet challenges). The placement question ("L1 or foundation?") becomes the first conversation about any new incentive — much shorter than "how should this work?" See [usernode#799](https://github.com/Usernode-Labs/usernode/discussions/799) for the sort table mapping existing proposals to buckets.

### Design-space unknowns

- **Action mapping.** Which on-chain behaviors provide the highest marginal utility for network health, and can they be verified without exposing privacy or burning compute?
- **Multiplier progression.** Static identity floor → labor multiplier (consistency) → alignment multiplier (web-of-trust + onboarding quality). How do these stack and decay?
- **The saturation point.** At what point does an additional node in a given geography stop adding decentralization value? Define the curve where rewards shift from growth to maintenance.
- **The fluid split.** Should the 50/50 stake/identity split be a governance parameter that programmatically shifts toward human-heavy (e.g., 80/20) as the network reaches critical mass?
- **Slashing reputation, not just stake.** Losing accumulated multipliers on malicious behavior — a penalty representing lost history and time, not just capital that can be re-acquired.
- **Diminishing rewards past the Schelling point.** If per-day token reward dilutes toward zero, the floor should shift to a gas-free utility quota: verified humans get a baseline of free network usage (messaging, storage).

### Out of the box

Adjacent design ideas worth keeping in view, not commitments.

- **Mesh resilience premium.** Reward nodes that maintain local connectivity (Bluetooth / WiFi Direct) during global backhaul outages. Local subnets staying alive through user-run mesh earn a premium — the network becomes critical infrastructure for disaster recovery and censorship resistance.
- **Privacy-preserving edge intelligence.** Reward verifiable insight produced at the edge: private AI inference, local data labeling, environmental attestations. Leverages ZK identity + trusted sensor data to monetize computation on sensitive local state without exposing it.

## Known constraints

_To fill: what "fair" means in the reward function, the challenge lifecycle (generation → assignment → completion → settlement), and how this connects to on-chain state._

## Open questions

- #354 calls the current categorization "theatre" — what's the minimal honest model?
- Do generic challenges (#349) need per-challenge CTAs, or a default CTA driven by challenge type?
