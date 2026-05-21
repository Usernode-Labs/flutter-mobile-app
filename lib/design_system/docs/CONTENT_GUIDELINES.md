# Content Guidelines

The Usernode design system's UX writing rules. Every piece of user-facing copy — titles, labels, buttons, body text, errors, status rows — passes through this document.

These guidelines are bottom-up: they were derived from the brand strategy (mission, values, perceptions, positioning) and from concrete UX-audit failures (e.g. issue #418, Bijan's walkthrough of the ZK Identity flow). They are not a remix of Material, Apple, or Microsoft house style — those informed the housekeeping, not the stance.

---

## Stance

Our reader is a curious adult who is new to blockchain and ZK proofs, not stupid. They're showing up because they want **agency over their digital lives** — to access, own, run, and build with their phone. We earn their trust by being clear and accurate at every layer, naming things by their real names, and treating every interaction as a chance for them to act with intention — not be processed.

This stance is downstream of the brand mission: *"to equip everyday people with the tools to create, run and control their own networks and exercise agency over their digital lives."* When copy reduces the user to a passive recipient, we are failing the mission as much as if we shipped a broken feature.

## Voice

| We are | We are not |
|---|---|
| Visionary, principled | Superficial, over-promising |
| Pragmatic, grounded | Abstract, in-the-weeds |
| Empathetic | Reactive, performative |
| Committed, direct | Closed, defensive |
| Positive, empowering | Defensive, gate-keeping |

**Default tone**: calm, concrete, declarative.

**Edge tones**:
- *Celebratory* on agency moments (verified, earned, built) — one exclamation max.
- *Specific and supportive* on errors — what happened, what to do next, no blame, no "oops".

---

## Principle hierarchy

When two principles conflict, resolve in this order:

1. **Truth** — never inaccurate, never misleading.
2. **Specificity** — concrete nouns and named things over abstractions.
3. **Empowerment** — what the user kept, did, owns (active voice when it stays specific).
4. **House style** — sentence case, no period on solos, etc.

An inaccurate-but-empowering line loses to a passive-but-specific one. A passive-but-specific line loses to an active-and-specific one. Default to the highest-ranked principle still achievable for the surface.

---

## The six principles

### 1. The user is the actor

Lead with the user's verb. They prove, send, own, build, earn. Don't say "we verified you" — say "you proved you're unique." Don't say "the proof was sent" — say "you sent the proof." This is the mission rendered as grammar: agency means the user is the grammatical subject doing the action, not the object of the system's action.

### 2. Truth before brevity

Shorter is good. Inaccurate-and-short is fatal — and it dilutes our positioning. If we say "Identity verified" when we mean "uniqueness verified," we're not just wrong; we've quietly weakened "the network for humans, not bots." Test every shortened phrase alone: *does the reader still hold a correct mental model?*

### 3. Empower with specifics

Reassurance is defensive (`Don't worry, we don't see your data`). Empowerment names what the user kept — **specifically**. Prefer active-voice empowerment when it stays concrete (`You didn't share your name, photo, or ID`). But when active voice forces a metaphor or a vague claim (`You kept it all` — kept *what*?), pick the precise negation instead (`Nothing shared`) — especially when the surrounding label or screen has already named the specifics. **Specificity beats voice.**

### 4. Three layers, deliberately separated

| Layer | Surfaces | Length | Vocabulary |
|---|---|---|---|
| **Glance** | titles, labels, step names, buttons | 1–4 words | only words a new user knows |
| **Read** | subtitles, body, bullets, step descriptions | 1–2 plain sentences | concrete nouns; at most one technical term, only if it carries weight |
| **Expert** | status card rows, proof IDs, timings, error details | as long as accuracy demands | precise technical terms without translation |

Each layer is true and complete on its own. A user who only ever reads Glance must still hold a correct mental model. Don't bury required information in Expert. Don't smuggle Expert jargon into Glance or Read.

### 5. Name things by their real names

`Wallet`, `blockchain`, `network`, `proof`, `stake`, `on-chain`: say them. The reader chose to be here; rebranding insults their effort to learn. But save `zero-knowledge proof`, `nullifier`, `wrap`, `outer proof` for Expert. Right level of jargon at the right layer.

### 6. House style

- Sentence case for everything (titles, headings, labels, buttons). Brand names keep their casing (`ZK Passport`, `Usernode`).
- No period on solitary sentences in labels, bullets, dialog body. Periods only when there are 2 or more sentences.
- No em dashes — use commas, periods, or a new sentence.
- No ellipses in buttons. Reserved for in-progress states.
- Serial (Oxford) commas in lists of 3+.
- Contractions when natural (`it's`, `you're`, `can't`). Spell out for emphasis (`do not`).
- Numerals for numbers (`3`, not `three`).
- No `please`, `just`, `simply`, `easy`, `amazing`, `seamless`.

---

## Vocabulary spine

Drawn directly from the brand strategy. The lean-in column is the vocabulary the brand was built on; the avoid column is what dilutes it.

| Lean in | Avoid |
|---|---|
| run, own, build, earn, participate, stake, prove, send | leverage, ecosystem, stakeholder, engagement |
| your network, your wallet, your phone, your proof | decentralized, trustless, web3 (as decoration) |
| network(s), community, humans, everyday people | "for you" + transitive verbs ("we'll X for you") |
| transparent, legible, aligned | amazing, powerful, revolutionary, seamless |
| agency, intention, control | the future of money, game-changing |

Brand names (`ZK Passport`, `Usernode`, `ptk`) keep their canonical casing wherever they appear.

---

## Failure modes

Named so reviewers can flag them by name in PR comments.

| Pattern | Example | Why it fails |
|---|---|---|
| **Mechanism-as-content** | `Bind your wallet to this verification` | tells the user what we do to the system, not what they achieve |
| **Cosmetic brevity** | `Identity verified` for uniqueness | factually wrong; dilutes positioning |
| **Defensive framing** | `We never share your data` | positions us as the actor; misses the agency moment |
| **System-as-actor** | `Your proof was sent` (passive) | drops the user out of their own action |
| **Abstract empowerment** | `Your passport stays on your phone` | feels reassuring but the claim isn't directly verifiable; metaphors invite misreadings |
| **Vague empowerment** | `You kept it all` (as a status row value) | active and brand-shaped, but the reader has to ask "kept what?" — a passive specific (`Nothing shared`) answers their question more directly |
| **Performative apology** | `Oops! Something went wrong` | empty calories; no fix path |
| **Reassurance theatre** | `Don't worry, your data is safe` | claims trust we should be earning |
| **Step restatement** | title `Open ZK Passport` + body `First, make sure you have ZK Passport installed.` | costs the reader time; the screen already says it once |
| **Vague link text** | `Learn more` with no antecedent | screen-reader hostile; gives no preview |
| **Begging** | `Please tap Continue to proceed` | asks for permission we don't need |
| **Anti-rival positioning** | `Unlike other crypto wallets…` | not "anti and not naive" |

---

## Worked example — ZK Identity flow (issue #418)

The three surfaces Bijan flagged, resolved layer by layer.

### Surface 1 — Challenge intro

Bijan saw: *"register this account for the password for the username, ZK passport demo"*

Failure: **mechanism-as-content**. The line described what the system was doing internally, not what the user was achieving.

| Layer | Copy |
|---|---|
| Glance (title) | `Prove you're a unique human` |
| Read (body, fallback when backend is empty) | `Prove you're a unique person in Usernode. No name, photo, or ID is shared.` |
| Expert (Requirements section) | (backend-provided) |

The Glance leads with the user's verb (Principle 1). The Read names the specifics — name, photo, ID — rather than a metaphor (Principle 3). A user who only reads the title still holds an accurate mental model (Principle 2).

### Surface 2 — Verification mid-flow

Bijan saw: a "jump" with no narration of what was happening between phases.

Failure: **system-as-actor**. The pipeline progressed through phases that had no user-facing surface.

| Layer | Copy |
|---|---|
| Glance (step name) | `Verifying` |
| Read (step description) | `Building and checking your proof` |
| Expert (sub-task labels) | `Opening ZK Passport` · `Waiting for your proof` · `Checking your proof` · `Wrapping your proof` · `Final check` |

Sub-task labels keep their technical names — `Wrapping` is the real name for what's happening (Principle 5), and the user is mid-flow, watching progress, so the precise term beats a friendly metaphor.

### Surface 3 — Result screen

Bijan saw: *"Identity Verified!"*

Failure: **cosmetic brevity**. The shortest phrase was wrong: ZK Passport doesn't verify identity — it verifies uniqueness. A user reading only this line walks away believing we saw their ID. That dilutes the brand's strongest positioning moment ("for humans, not bots").

| Layer | Copy |
|---|---|
| Glance (title) | `You're a unique human!` *(congratulatory exception to no-exclamation rule)* |
| Read (subtitle) | `You proved you're unique without sharing your name, photo, or ID` |
| Expert (status card rows) | `Unique human` / `Confirmed` · `Face check` / `Verified` · `Privacy` / `Nothing shared` · `Verified on` / *(date)* · `Proof ID` / *(truncated nullifier)* · `Verify` / `Wrap` / `Final check` *(timings)* |

The Glance is the brand position made operational. The Read makes the user the actor (`You proved`) and names the specifics (`name, photo, or ID`). The Expert status row uses `Nothing shared` because — inside a `Privacy` row, on a screen that has just named the specifics — the passive specific answers the reader's question more directly than the active-but-vague `You kept it all`.

---

## How to use this in PRs

When proposing or reviewing copy:

1. Name the **layer** (Glance / Read / Expert) for each string.
2. Name the **principle(s)** the string satisfies.
3. Check against the **failure modes** — reviewers should be able to flag a violation by name.
4. When two principles conflict, apply the **hierarchy** above.

A copy change without this annotation is incomplete. Reviewers may ask for it before approving.

## Where this fits

- This is part of `lib/design_system/`. Copy is as much a design system surface as spacing tokens or colour roles.
- Cross-reference from [SCREEN_PATTERNS.md](SCREEN_PATTERNS.md) when adding a new screen template.
- Cross-reference from [CONSTRAINTS.md](CONSTRAINTS.md) as a quality gate.

## See also

- Issue #418 — original audit feedback that shaped these rules
- Brand strategy deck — UME × User Nodes, R5 Final (March 2026), source of mission/values/perceptions/positioning
