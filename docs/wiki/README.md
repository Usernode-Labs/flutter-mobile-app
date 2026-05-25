# docs/wiki

Compiled knowledge pages for the 11 mainnet initiatives tracked in [Discussion #370](https://github.com/Usernode-Labs/flutter-mobile-app/discussions/370) and the [Mainnet Maturity Matrix project](https://github.com/orgs/Usernode-Labs/projects/2).

Each initiative page is a living summary: current phase, active issues and PRs, related discussions, and the decisions and open questions that shape the work. Read them when you want a one-screen view of an initiative without digging through 15 open issues.

Alongside the initiative pages, [`priorities.md`](priorities.md) holds the team's near-term objective, current milestones, and the committed slice of issues per milestone — the "what we're doing right now and what we've explicitly chosen not to do" layer.

**Where to start:** open [`priorities.md`](priorities.md) for current commitments. Open an [initiative page](initiatives/) for design context and active work.

## Layout

```
docs/wiki/
├── priorities.md         Near-term objective + milestones + committed slice
└── initiatives/          One page per initiative, filename = the init:<slug> label
    ├── bg-node.md           Background node running on phones
    ├── app-stores.md        App Store + Play Store delivery
    ├── zk-identity.md       Zero-knowledge identity & registration
    ├── fair-rewards.md      Reward distribution & challenges
    ├── dapps.md             dApps framework (human + agent coordination substrate)
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

Sections live below the auto block and are free to edit:

- **Overview** — what this initiative is, who owns it, why it matters. Keep it to a short paragraph.
- **The idea** *(optional)* — design rationale. Conventional subsections: `Objective` / `Problem` / `Solution` / `Design-space unknowns` / `Out of the box`. Inner shape of Problem and Solution is free-form — bolded lead-ins per sub-problem (see `fair-rewards.md`) or unified flow (see `dapps.md`), both work. Add when the initiative has a non-obvious design space worth articulating beyond the Overview paragraph. Develops over time.
- **Known constraints** — hard constraints, non-obvious trade-offs, and decisions that shape the work. Cite the discussion or PR where each was decided.
- **Open questions** — operational unknowns about delivery (e.g. *"do we ship X by Y?"*). Move to "Known constraints" once answered. Distinct from "Design-space unknowns" in the optional idea section, which are about what the system should fundamentally do (e.g. *"should rewards decay past saturation?"*).

This is where real knowledge compounds. The auto block is just plumbing.

## Editing guidelines

- Don't duplicate tracker content in "Overview" — the auto block already shows phase status and open items.
- Don't write WHAT — the code, tracker, and issues already say that. Write WHY: decisions, trade-offs, non-obvious invariants.
- When a decision lands in a discussion, capture the takeaway in "Known constraints" with a link.
- When you find yourself asking the same question twice, add it to "Open questions" and resolve it into a constraint when you have an answer.
