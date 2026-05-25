# Background Node Running

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-04-13 (tracker #378)_

## Phase status

| Phase | Status |
|---|---|
| Idea | ✅ DONE |
| Demo | ✅ DONE |
| Core Testnet | 🔄 NOW |
| Pilot Testnet | — |
| Mainnet | — |

## Active work

### Issues

- [#67](https://github.com/Usernode-Labs/flutter-mobile-app/issues/67) Configure Node In Mobile App With Custom Account Keys
- [#300](https://github.com/Usernode-Labs/flutter-mobile-app/issues/300) ANR: WalletProvider parses 6,980+ UTXOs on main thread _(also under init:wallet)_
- [#309](https://github.com/Usernode-Labs/flutter-mobile-app/issues/309) fix(android): prevent ANR by skipping VRF poll in foreground
- [#322](https://github.com/Usernode-Labs/flutter-mobile-app/issues/322) Block datetimes not refreshing — upcoming blocks show times in the past
- [#325](https://github.com/Usernode-Labs/flutter-mobile-app/issues/325) Timezone mismatch: earned/scheduled blocks show wrong timezone vs produced blocks
- [#326](https://github.com/Usernode-Labs/flutter-mobile-app/issues/326) Peers reset to 0 on tab switch / app background — full resync triggered
- [#327](https://github.com/Usernode-Labs/flutter-mobile-app/issues/327) Produced blocks missing metadata (blockHash, canonical, timestamp)
- [#328](https://github.com/Usernode-Labs/flutter-mobile-app/issues/328) Node should detect and warn about system clock skew causing block rejection
- [#329](https://github.com/Usernode-Labs/flutter-mobile-app/issues/329) Blocks missed during background/standby despite battery optimization disabled
- [#330](https://github.com/Usernode-Labs/flutter-mobile-app/issues/330) Excessive data consumption (1-2GB+/day) when app kept in foreground
- [#342](https://github.com/Usernode-Labs/flutter-mobile-app/issues/342) bug(node): connectivity failures — stale identity persistence, post-update regression, missing offline UX
- [#343](https://github.com/Usernode-Labs/flutter-mobile-app/issues/343) Rust FFI crashes on Android 8 (API 26) — minSdkVersion mismatch
- [#344](https://github.com/Usernode-Labs/flutter-mobile-app/issues/344) bug(node): inconsistent block statistics between epoch summary and detail views
- [#361](https://github.com/Usernode-Labs/flutter-mobile-app/issues/361) chore: delete orphaned block production event system and dead files (~3,500 LOC)
- [#365](https://github.com/Usernode-Labs/flutter-mobile-app/issues/365) feat: reassure users that background block production works without keeping app in foreground

### Pull requests

- [#355](https://github.com/Usernode-Labs/flutter-mobile-app/pull/355) Use systemExempted foreground service instead of dataSync when possible

## Related discussions

- [#370](https://github.com/Usernode-Labs/flutter-mobile-app/discussions/370) Mainnet Maturity Matrix plan

<!-- auto:end -->

## Overview

Running a Layer 1 node from a phone in the background — the defining technical bet of the project. Idea and Demo phases are complete; the current focus is hardening for Core Testnet, which means stability (no ANRs, no missed blocks), efficiency (bounded data and battery), and correctness (block metadata, clock skew, timezones).

## Known constraints

- **Android minSdkVersion** must stay compatible with the Rust FFI — see #343 for the Android 8 regression.
- **No ANRs on main thread.** Wallet UTXO parsing (#300) and VRF polling (#309) are both known offenders. Block production work belongs on a background isolate or foreground service.
- **systemExempted foreground service** is the preferred Android mode (see PR #355) — `dataSync` has OEM-specific throttling that silently kills block production.

## Open questions

- Is there a stable path to "block production works with the app fully backgrounded for hours" on both Android and iOS, or is foreground-service-while-charging the realistic target for Pilot Testnet?
- Should the orphaned block-production event system (#361, ~3,500 LOC) be deleted before or after the stability fixes land?
