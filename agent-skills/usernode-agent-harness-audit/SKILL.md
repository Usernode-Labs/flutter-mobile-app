---
name: usernode-agent-harness-audit
description: Audit the Usernode agent harness against curated external Flutter, mobile UX, design-system, and agent-skill harnesses. Use when comparing plugins or skills, refreshing the benchmark list, or evaluating whether to adopt outside ideas without losing Usernode identity.
---

# Usernode Agent Harness Audit

This is the harness immune-system skill. It watches strong external skills and plugins, extracts useful ideas, and rejects anything that would dilute Usernode's DS, mobile UX, or context-discipline rules.

## Identity Contract

External harnesses are references, not authority.

- Usernode project skills in `agent-skills/` stay canonical.
- DS code, token classes, Widgetbook, and `packages/ds_lints` are the source of truth.
- M3 first, existing DS second, new patterns only after gap proof and human approval.
- Mobile crypto UX rules outrank generic visual polish.
- Do not install broad upstream skills as ambient project skills by default.
- Prefer ignored caches and explicit benchmark audits over vendoring outside skill bodies.
- Enforcement belongs in scripts, git hooks, tests, and CI; agent-only guidance is advisory.

## When Auditing

1. Determine scope:
   - `full`: skills, adapters, scripts, hooks, docs, CI, and drift strategy;
   - `skill-hygiene`: naming, triggers, progressive disclosure, overlap;
   - `ds-enforcement`: lints, Widgetbook, genesis/catalog, token drift;
   - `mobile-ux`: safe areas, keyboard CTAs, navigation, sheets, accessibility;
   - `flutter-mechanics`: tests, previews, routing, layout, analyzer workflow;
   - `design-intake`: Figma/screenshot/sketch/text pipeline and visual comparison.
2. Read only the relevant local files first:
   - `AGENTS.md`;
   - `agent-skills/*/SKILL.md`;
   - `tool/agent-setup.sh`, `tool/verify-widget.sh`, `tool/screen-audit.sh`;
   - `.githooks/pre-commit` and CI workflows when enforcement is in scope.
3. Load `references/benchmarks.yaml` and select only the benchmark entries relevant to the scope.
   - Prefer `active` tier sources for recurring audits.
   - Use `narrow` tier sources only for the listed specialty.
   - Treat `private_manual` sources as manually reviewed taste input, never as installable project skills.
4. For full harness audits, load `references/harness_cujs.md` and use the CUJs as the acceptance frame.
5. If the user asks for latest/current status, refresh the selected upstreams with web or shallow clones and record the date/commit/tag used in the audit output.
6. Score each comparison dimension:
   - `progressive_disclosure`: metadata is small; details load just in time;
   - `trigger_hygiene`: descriptions are specific and do not steal unrelated work;
   - `identity_preservation`: external ideas cannot override Usernode constraints;
   - `enforcement_backing`: important rules map to lint, script, test, hook, or CI;
   - `portability`: works across Claude, Codex, other agents, humans, and CI;
   - `drift_strategy`: upstream changes can be followed without silent behavior shifts;
   - `context_cost`: the idea earns the attention it consumes;
   - `verification_loop`: the workflow proves the result with tests, previews, screenshots, or audits.

## Report Shape

Produce a concise audit with these sections:

```markdown
# Harness Benchmark Audit

## Adopt Now
- [small change] -> [local file/script/skill to update] -> [why it preserves identity]

## Consider
- [experiment] -> [risk] -> [validation needed]

## Reject
- [external idea] -> [conflict with Usernode]

## Watchlist
- [upstream] -> [what to monitor]

## Backlog
1. [PR-sized task]
```

## Adoption Rules

- Every `Adopt Now` item must name the exact local owner: skill, doc, lint, script, hook, CI, or test.
- If an idea cannot be enforced or reviewed, keep it in `Consider`.
- If an idea changes visual taste, pattern selection, DS component policy, or token semantics, require explicit human approval.
- If an upstream skill is broad, style-heavy, web/Tailwind-centric, or architecture-opinionated, cite it as a reference only.
- Do not update `AGENT_ARCHITECTURE.md` from this skill; that file has separate ownership.

## Updating The Benchmark Registry

When the user asks to add or refresh sources, edit `references/benchmarks.yaml`.

Each benchmark entry should include:

- `name`
- `source`
- `kind`
- `tier`
- `track`
- `use_for`
- `do_not_use_for`
- `identity_filter`
- `adoption_tests`

Keep the registry curated. Adding a source requires a clear job it performs better than the current Usernode harness. When refreshing an upstream, record the checked commit, tag, or docs date in `latest_snapshots` or the entry `track`.
