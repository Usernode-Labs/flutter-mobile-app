---
name: usernode-ds-harness-init
description: Bootstrap or repair the Usernode design-system agent harness. Use in this repo when skills, hooks, Claude/Codex discovery adapters, or portable DS agent setup are missing or stale.
---

# Usernode DS Harness Init

Use this skill to set up or repair local agent ergonomics for this repository.

## Workflow

1. From the repo root, run:

   ```bash
   bash tool/agent-setup.sh
   ```

2. If the user explicitly wants Codex skills installed globally, run:

   ```bash
   bash tool/agent-setup.sh --agent codex --codex-global
   ```

3. Confirm:

   ```bash
   git config --get core.hooksPath
   find .claude/skills .agents/skills .codex/skills -maxdepth 1 -type l 2>/dev/null
   ```

4. Report what changed. Do not commit `.claude/`, `.agents/`, or `.codex/`; they are repo-local adapters.

## Rules

- Canonical skill source is `agent-skills/`.
- `.claude/skills/`, `.agents/skills/`, and `.codex/skills/` are local discovery adapters only.
- Do not move personal commands or settings into git.
- If setup fails, inspect `tool/agent-setup.sh` and fix the script rather than hand-building adapters.
