# docs/wiki

Compiled, per-initiative knowledge pages for the 11 mainnet initiatives tracked in [Discussion #370](https://github.com/Usernode-Labs/flutter-mobile-app/discussions/370) and the [Mainnet Maturity Matrix project](https://github.com/orgs/Usernode-Labs/projects/2).

Each page is a living summary of one initiative: current phase, active issues and PRs, related discussions, and the decisions and open questions that shape the work. Read them when you want a one-screen view of an initiative without digging through 15 open issues.

## Layout

One page per initiative, filename = the `init:<slug>` label:

```
docs/wiki/initiatives/
├── bg-node.md           Background node running on phones
├── app-stores.md        App Store + Play Store delivery
├── zk-identity.md       Zero-knowledge identity & registration
├── fair-rewards.md      Reward distribution & challenges
├── mini-apps.md         dApp framework
├── block-explorer.md    Block explorer
├── wallet.md            On-device wallet
├── bridge.md            Cross-chain bridge
├── dex.md               DEX
├── dx.md                Developer experience / dev loop
└── leaderboard.md       Leaderboard sunset
```

## Anatomy

Each page has two regions:

### Auto block

Phase status table, active issues and PRs, and related discussions — regenerated from current GitHub state. Marked with `<!-- auto:start -->` / `<!-- auto:end -->` HTML comments. Don't hand-edit the content between the markers; it will be overwritten the next time the page is refreshed.

### Manual sections

Three sections live below the auto block and are free to edit:

- **Overview** — what this initiative is, who owns it, why it matters. Keep it to a short paragraph.
- **Known constraints** — hard constraints, non-obvious trade-offs, and decisions that shape the work. Cite the discussion or PR where each was decided.
- **Open questions** — things we don't know yet. Move to "Known constraints" once answered.

This is where real knowledge compounds. The auto block is just plumbing.

## Editing guidelines

- Don't duplicate tracker content in "Overview" — the auto block already shows phase status and open items.
- Don't write WHAT — the code, tracker, and issues already say that. Write WHY: decisions, trade-offs, non-obvious invariants.
- When a decision lands in a discussion, capture the takeaway in "Known constraints" with a link.
- When you find yourself asking the same question twice, add it to "Open questions" and resolve it into a constraint when you have an answer.
