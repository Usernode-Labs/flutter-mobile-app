# Wallet

<!-- auto:start: regenerated from GitHub state — do not edit by hand -->

_Last synced: 2026-05-25 (tracker #384)_

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

- [#300](https://github.com/Usernode-Labs/flutter-mobile-app/issues/300) ANR: WalletProvider parses 6,980+ UTXOs on main thread _(also under init:bg-node)_
- [#331](https://github.com/Usernode-Labs/flutter-mobile-app/issues/331) bug(wallet): burst transactions not visible in Recent Activity after completion

### Recent activity (30d)

- [#399](https://github.com/Usernode-Labs/flutter-mobile-app/pull/399) add qr code scanning to wallet
- [#400](https://github.com/Usernode-Labs/flutter-mobile-app/pull/400) Add support for signing data from public keys to prove ownership
- [#405](https://github.com/Usernode-Labs/flutter-mobile-app/pull/405) feat: Integrate node storage for wallet cache

## Related discussions

- #370 Mainnet Maturity Matrix plan

<!-- auto:end -->

## Overview

On-device wallet — key management, UTXO tracking, transaction signing and display. The initiative is technically LATER in the matrix, but two critical bugs (#300, #331) exist because wallet state is exercised by the node work.

## Known constraints

- **#300 is cross-cutting with init:bg-node** — parsing 6,980+ UTXOs on the main thread is both a wallet bug and the worst block-production ANR. Whichever initiative fixes it, the other benefits.
- _To fill: wallet storage model (UTXO cache location, signing key location), and how the wallet interacts with the node's view of chain state._

## Open questions

- Should "Recent Activity" (#331) be an eventually-consistent view of confirmed tx, or a live view of pending + confirmed?
- Does the wallet need its own LATER → NOW transition, or does it ride along with bg-node's Core Testnet work?
