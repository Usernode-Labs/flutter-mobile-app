# ZK Identity

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-04-13 (tracker #380)_

## Phase status

| Phase | Status |
|---|---|
| Idea | 🔄 NOW |
| Demo | 🔄 NOW |
| Core Testnet | ⏳ LATER |
| Pilot Testnet | — |
| Mainnet | — |

## Active work

### Issues

- [#351](https://github.com/Usernode-Labs/flutter-mobile-app/issues/351) Stale local cache/storage causes silent broken states in registration flow

### Pull requests

- [#333](https://github.com/Usernode-Labs/flutter-mobile-app/pull/333) fix(registration): convert hex keys to bech32m before Rust FFI import

## Related discussions

- [#370](https://github.com/Usernode-Labs/flutter-mobile-app/discussions/370) Mainnet Maturity Matrix plan

<!-- auto:end -->

## Overview

Registration and zero-knowledge identity for nodes and users. The current focus is making registration reliable — silent cache failures (#351) and key-format mismatches (#333) both cause hard-to-diagnose broken states for new users.

## Known constraints

_To fill: ZK proving system choice, key storage constraints, and how identity maps to on-chain node identity vs off-chain user identity._

## Open questions

- Is bech32m (#333) the canonical on-wire format, or just the FFI boundary format? Downstream callers should know.
- #351's "silent broken states" — is the right fix cache invalidation, or should registration be reset-on-failure?
