# Fair Rewards

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-04-13 (tracker #381)_

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

- [#349](https://github.com/Usernode-Labs/flutter-mobile-app/issues/349) Challenges: generic challenges missing CTA buttons
- [#354](https://github.com/Usernode-Labs/flutter-mobile-app/issues/354) Simplify challenge categorization — remove enabled/completed theatre

### Pull requests

_None._

## Related discussions

- [#362](https://github.com/Usernode-Labs/flutter-mobile-app/discussions/362) Challenge Properties Reference
- [#370](https://github.com/Usernode-Labs/flutter-mobile-app/discussions/370) Mainnet Maturity Matrix plan

<!-- auto:end -->

## Overview

Fair reward distribution and the challenges system that feeds it. Challenges are the user-visible shape of rewards — completing them is how users earn. Current work is shrinking the categorization surface (#354) and filling UX gaps (#349) before the system is frozen for Demo.

## Known constraints

_To fill: what "fair" means in the reward function, the challenge lifecycle (generation → assignment → completion → settlement), and how this connects to on-chain state._

## Open questions

- #354 calls the current categorization "theatre" — what's the minimal honest model?
- Do generic challenges (#349) need per-challenge CTAs, or a default CTA driven by challenge type?
