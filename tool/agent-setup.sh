#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bash tool/agent-setup.sh [--agent claude|codex|agents|all] [--force] [--codex-global]

Bootstraps the portable DS agent harness for this clone:
  - sets git core.hooksPath to .githooks
  - links repo skills into project-local agent discovery adapters
  - validates Agent Skills frontmatter names

By default this script creates Claude, .agents, and .codex project-local
adapters. .agents/skills is the open Agent Skills discovery path used by the
Flutter skills docs and ui.sh. .codex/skills is kept as a compatibility adapter
for Codex builds that support it. Use --codex-global to also link these project
skills into ~/.codex/skills.
USAGE
}

AGENT="all"
FORCE=0
CODEX_GLOBAL=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agent)
      if [ "$#" -lt 2 ]; then
        echo "--agent requires claude, codex, agents, or all" >&2
        usage >&2
        exit 2
      fi
      shift
      AGENT="$1"
      ;;
    --force)
      FORCE=1
      ;;
    --codex-global)
      CODEX_GLOBAL=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "$AGENT" in
  claude|codex|agents|all) ;;
  *)
    echo "--agent must be claude, codex, agents, or all" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

SKILLS_ROOT="$REPO_ROOT/agent-skills"
if [ ! -d "$SKILLS_ROOT" ]; then
  echo "Missing $SKILLS_ROOT" >&2
  exit 1
fi

validate_skills() {
  local ok=1
  for skill_dir in "$SKILLS_ROOT"/usernode-*; do
    [ -d "$skill_dir" ] || continue
    local skill_file="$skill_dir/SKILL.md"
    local dir_name
    dir_name="$(basename "$skill_dir")"
    if [ ! -f "$skill_file" ]; then
      echo "Missing SKILL.md: $skill_dir" >&2
      ok=0
      continue
    fi
    local name
    name="$(awk -F': *' '/^name:/ {print $2; exit}' "$skill_file" | tr -d '"')"
    if [ "$name" != "$dir_name" ]; then
      echo "Skill name mismatch: $skill_file has '$name', expected '$dir_name'" >&2
      ok=0
    fi
  done
  [ "$ok" -eq 1 ]
}

link_skills() {
  local target_root="$1"
  mkdir -p "$target_root"
  for skill_dir in "$SKILLS_ROOT"/usernode-*; do
    [ -d "$skill_dir" ] || continue
    local target="$target_root/$(basename "$skill_dir")"
    if [ -L "$target" ] || [ -e "$target" ]; then
      if [ "$FORCE" -eq 1 ]; then
        rm -rf "$target"
      else
        echo "Exists, leaving alone: $target"
        continue
      fi
    fi
    ln -s "$skill_dir" "$target"
    echo "Linked: $target -> $skill_dir"
  done
}

validate_skills

git config core.hooksPath .githooks
echo "Configured git core.hooksPath=.githooks"

if [ "$AGENT" = "claude" ] || [ "$AGENT" = "all" ]; then
  link_skills "$REPO_ROOT/.claude/skills"
  echo "Claude project adapter ready: .claude/skills"
fi

if [ "$AGENT" = "agents" ] || [ "$AGENT" = "codex" ] || [ "$AGENT" = "all" ]; then
  link_skills "$REPO_ROOT/.agents/skills"
  echo "Open Agent Skills project adapter ready: .agents/skills"
fi

if [ "$AGENT" = "codex" ] || [ "$AGENT" = "all" ]; then
  link_skills "$REPO_ROOT/.codex/skills"
  echo "Codex compatibility project adapter ready: .codex/skills"
  echo "If your Codex build does not discover repo-local skills from .agents/skills or .codex/skills, rerun with --codex-global."
  if [ "$CODEX_GLOBAL" -eq 1 ]; then
    link_skills "${CODEX_HOME:-$HOME/.codex}/skills"
    echo "Codex global adapter ready: ${CODEX_HOME:-$HOME/.codex}/skills"
  fi
fi
