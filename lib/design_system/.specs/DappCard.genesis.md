# DappCard Genesis

## Inspiration

Backfilled from `lib/design_system/src/dapp_card.dart`, tests, and Widgetbook coverage during DS harness standardization.

## Design Decisions

- Packages dapp summary content into a reusable card while leaving navigation callbacks to callers.
- Composes DS avatar and stats presentation instead of coupling to dapp repositories.
- Uses the two-tier surface model and tokenized spacing for consistency with app cards.
