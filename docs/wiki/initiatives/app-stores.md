# App Stores Listing

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-06-16 ([tracker #379](https://github.com/Usernode-Labs/flutter-mobile-app/issues/379))_

## Phase status

| Phase | Status |
|---|---|
| Idea | ⊘ SKIPPED |
| Demo | ⊘ SKIPPED |
| Core Testnet | ⏳ LATER |
| Pilot Testnet | — |
| Mainnet | — |

## Active work

### Issues

- [#358](https://github.com/Usernode-Labs/flutter-mobile-app/issues/358) Continuous app delivery without manual user action

## Related discussions

- #370 Mainnet Maturity Matrix plan
<!-- auto:end -->

## Overview

Getting the app published and continuously delivered through Apple App Store and Google Play. The goal is "users get updates without knowing it happened" — critical for a node operator workflow where stale clients break block production.

## Known constraints

_To fill: store review rules that affect crypto/wallet apps, background-service disclosures, and any existing CI/release tooling._

## Open questions

- Force-update UX (#374): block the app entirely, or degrade gracefully?
- Does "continuous delivery" (#358) mean staged rollouts via the store, or sideload/in-app update mechanisms for advanced users?
