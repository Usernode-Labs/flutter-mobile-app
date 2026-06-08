# ZK Identity

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-06-08 ([tracker #380](https://github.com/Usernode-Labs/flutter-mobile-app/issues/380))_

## Phase status

| Phase | Status |
|---|---|
| Idea | ✅ DONE |
| Demo | ✅ DONE |
| Core Testnet | ⏳ LATER |
| Pilot Testnet | — |
| Mainnet | — |

## Active work

### Issues

- [#351](https://github.com/Usernode-Labs/flutter-mobile-app/issues/351) Stale local cache/storage causes silent broken states in registration flow
- [#415](https://github.com/Usernode-Labs/flutter-mobile-app/issues/415) ZK Identity: integrate scoped_nullifier as the Leaderboard Unique ID
- [#419](https://github.com/Usernode-Labs/flutter-mobile-app/issues/419) ZK identity flow — companion state blindness + persistence + network resilience
- [#422](https://github.com/Usernode-Labs/flutter-mobile-app/issues/422) Backend prerequisites for ZK Identity end-to-end completion (per-participant enable + bridge config)

## Recent activity (30d)

- [#424](https://github.com/Usernode-Labs/flutter-mobile-app/pull/424) Add Usernode content guidelines + re-pass ZK Identity copy
- [#420](https://github.com/Usernode-Labs/flutter-mobile-app/pull/420) ZK identity: refresh result copy and add in-flow recovery

## Related discussions

- #370 Mainnet Maturity Matrix plan
- #416 ZK Identity: deeplink bridge vs in-app SDK integration
<!-- auto:end -->

## Overview

Registration and zero-knowledge identity for nodes and users. The current focus is making registration reliable — silent cache failures (#351) and key-format mismatches (#333) both cause hard-to-diagnose broken states for new users.

## Known constraints

_To fill: ZK proving system choice, key storage constraints, and how identity maps to on-chain node identity vs off-chain user identity._

## Open questions

- Is bech32m (#333) the canonical on-wire format, or just the FFI boundary format? Downstream callers should know.
- #351's "silent broken states" — is the right fix cache invalidation, or should registration be reset-on-failure?
