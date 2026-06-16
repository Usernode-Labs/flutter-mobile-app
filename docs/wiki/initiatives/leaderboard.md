# Leaderboard Sunset

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-06-16 ([tracker #388](https://github.com/Usernode-Labs/flutter-mobile-app/issues/388))_

## Phase status

| Phase | Status |
|---|---|
| Idea | ⊘ SKIPPED |
| Demo | ⊘ SKIPPED |
| Core Testnet | — |
| Pilot Testnet | — |
| Mainnet | — |

## Active work

### Issues

- [#408](https://github.com/Usernode-Labs/flutter-mobile-app/issues/408) Challenges screen: 'Leaderboard' button hit area is offset upward
- [#422](https://github.com/Usernode-Labs/flutter-mobile-app/issues/422) Backend prerequisites for ZK Identity end-to-end completion (per-participant enable + bridge config)
- [#434](https://github.com/Usernode-Labs/flutter-mobile-app/issues/434) Challenge CTAs: cta_type dispatcher + dApp deep-link route (tracker)

## Recent activity (30d)

- [#435](https://github.com/Usernode-Labs/flutter-mobile-app/pull/435) feat(leaderboard): cta_type dispatcher + /dapps/:slug route

## Related discussions

- #370 Mainnet Maturity Matrix plan
<!-- auto:end -->

## Overview

Winding down the leaderboard feature. The cache-first leaderboard code (see memory: `leaderboard-cache-handoff.md`) is still live, but the feature is on a path to removal as the reward model shifts.

## Known constraints

- **Leaderboard code still exists** at `lib/core/utils/leaderboard_cache.dart` and across 4 providers using `CachedData<T>`. Sunset needs a deprecation plan and a removal PR, not a code deletion in one shot.

## Open questions

- What replaces the leaderboard UX for users who relied on it?
- When does Fair Rewards have a replacement loop strong enough that we can remove the leaderboard without user confusion?
