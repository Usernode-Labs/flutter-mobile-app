# Background Node Running

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-05-25 (tracker #378)_

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
- [#428](https://github.com/Usernode-Labs/flutter-mobile-app/issues/428) Prolonged foreground use causes hardware degradation (overheating, battery swelling, display damage)
- [#429](https://github.com/Usernode-Labs/flutter-mobile-app/issues/429) 0% block production on secondary/tertiary devices in foreground (E53-E59)
- [#430](https://github.com/Usernode-Labs/flutter-mobile-app/issues/430) Late-epoch startup: VRF evaluation silently skips past slots when node starts mid-epoch
- [#431](https://github.com/Usernode-Labs/flutter-mobile-app/issues/431) Surface OS-induced node restarts to the user (lifecycle churn visibility)

### Pull requests

- [#355](https://github.com/Usernode-Labs/flutter-mobile-app/pull/355) Use systemExempted foreground service instead of dataSync when possible

### Recent activity (30d)

- [#392](https://github.com/Usernode-Labs/flutter-mobile-app/pull/392) Fix background block production breaking when system clock drift is large enough
- [#393](https://github.com/Usernode-Labs/flutter-mobile-app/pull/393) Sleep always-on app setups on inactivity
- [#394](https://github.com/Usernode-Labs/flutter-mobile-app/pull/394) Enable sleep on inactive by default
- [#401](https://github.com/Usernode-Labs/flutter-mobile-app/pull/401) Fix manual wakeup for sleep on inactive feature not working
- [#403](https://github.com/Usernode-Labs/flutter-mobile-app/pull/403) Increase idle timeout for sleep on inactive from 20s to 5m
- [#396](https://github.com/Usernode-Labs/flutter-mobile-app/pull/396) Fix sleep on inactive race condition

## Related discussions

- #370 Mainnet Maturity Matrix plan
- #426 Mobile BG block production: consolidate decision-making into a single state machine

<!-- auto:end -->

## Overview

Running a Layer 1 node from a phone in the background — the defining technical bet of the project. Idea and Demo phases are complete; the current focus is hardening for Core Testnet, which means stability (no ANRs, no missed blocks), efficiency (bounded data and battery), and correctness (block metadata, clock skew, timezones).

## Known constraints

- **Android minSdkVersion** must stay compatible with the Rust FFI — see #343 for the Android 8 regression.
- **No ANRs on main thread.** Wallet UTXO parsing (#300) and VRF polling (#309) are both known offenders. Block production work belongs on a background isolate or foreground service.
- **systemExempted foreground service** is the preferred Android mode (see PR #355) — `dataSync` has OEM-specific throttling that silently kills block production.
- **OEM custom Android skins kill background processes aggressively.** Confirmed offenders from community reports: Poco (MIUI variants), Infinix-OS, Oppo ColorOS, Realme. The user experience is the same across all of them — node missed blocks, no UI explanation. `dontkillmyapp.com`-style per-OEM mitigation guidance is the current workaround until lifecycle hardening lands.
- **Silent failures need surfacing.** Four distinct bg-node bugs (#428 hardware degradation, #429 multi-device 0% production, #430 late-epoch VRF skip, #431 OS-induced restart churn) share the same shape: the team can see the failure in internal logs, the user cannot. Treat user-facing visibility (counter, status indicator, debug view) as part of fixing each one — not a separate UX afterthought. The "set and forget" product position is undermined every time a node silently does less work than the user thinks.

## Open questions

- Is there a stable path to "block production works with the app fully backgrounded for hours" on both Android and iOS, or is foreground-service-while-charging the realistic target for Pilot Testnet?
- Should the orphaned block-production event system (#361, ~3,500 LOC) be deleted before or after the stability fixes land?
- The Build 1164→1182 connecting regression resolved for some users (e.g. @flyingnobita on Poco F2 Pro) but not others (e.g. @hkedia_05 on stock Pixel 7) — two distinct connecting bugs collapsed under #342, or one bug with edge cases? Pending the WebRTC vs QUIC investigation @snaitm mentioned.
