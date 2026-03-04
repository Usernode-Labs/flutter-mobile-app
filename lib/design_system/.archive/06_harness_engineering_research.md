# Harness Engineering Research Summary

> Archived from Intent workspace research session (Feb 2026).
> Research that informed the "Map, Not Manual" restructure of design system docs
> (DESIGN_SYSTEM.md reduced from 1,064 → 390 lines across 8 → 5 files).

---

## Sources Studied

1. **ETH Zurich — "AGENTS.md: Do LLMs Really Need Detailed Instructions?"** (arXiv 2602.11988)
2. **SkillsBench — "Evaluating AI Coding Assistants on Harness Engineering"** (arXiv 2602.12670)
3. **Vercel — "How we built our AI agent tools"** (blog post)
4. **OpenAI — Harness Engineering Guide**
5. **LangChain — Harness Engineering Guide**
6. **Anthropic — Effective Agent Harnesses**

---

## Key Findings

### 1. Context Files Decrease Agent Success (ETH Zurich)
- Adding `AGENTS.md` instructions **decreased** solve rate vs baseline on SWE-bench
- Context files increase cost by 20%+ (more tokens processed)
- Agent models already know frameworks — telling them what they know wastes context
- **Implication**: Remove anything the model already knows (M3 basics, Flutter patterns)

### 2. "A Map, Not a Manual" (OpenAI)
- Show what rarely changes: directory structure, naming conventions, boundaries
- Express invariants as boundaries ("This is NOT...") rather than exhaustive rules
- Use file maps and quick-start blocks, not detailed guides
- **Implication**: DESIGN_SYSTEM.md should be a map with boundary constraints

### 3. Mechanical Enforcement > Prose (OpenAI)
- Rules that can be enforced by tools/linters don't need documentation
- Document the "why" and the boundary; let code enforce the "what"
- **Implication**: Remove rules that `flutter analyze` or `/verify-widget` already check

### 4. "5-Line File > 2,000-Word Overview" (ETH Zurich)
- Smaller, focused context is more effective than comprehensive docs
- Agents perform better with less guidance that's more targeted
- **Implication**: Split monolithic docs, keep each file focused on one concern

### 5. Trust the Model (Vercel)
- Vercel removed 80% of agent tools and got better results
- Less surface area = less confusion = better performance
- **Implication**: Don't over-specify; trust that Claude knows Flutter/M3

### 6. Focused Skills > Comprehensive Docs (SkillsBench)
- Task-specific skills outperform general-purpose documentation
- Agents need to know "what to do now" not "everything about the system"
- **Implication**: Route to specific docs rather than loading everything upfront

---

## How This Shaped the Restructure

| Before | After | Principle Applied |
|--------|-------|-------------------|
| 8 files, 1,064 lines | 5 files, 390 lines | "5-line file > 2000-word overview" |
| Detailed M3 role tables | Source file references | "Trust the model" |
| Comprehensive typography guide | 3-line constraint in CONSTRAINTS.md | "Mechanical enforcement > prose" |
| Component implementation details | Widget catalog with genesis links | "A map, not a manual" |
| Scattered rules across 8 files | Consolidated CONSTRAINTS.md | "Focused skills" |
| Hex value tables | "See color_is_expensive_theme.dart" | "Show what rarely changes" |

---

## The Restructured File Map

```
lib/design_system/
├── DESIGN_SYSTEM.md   (57 lines) — philosophy, boundaries, file map, widget catalog
├── docs/
│   ├── CONSTRAINTS.md (89 lines) — consolidated enforceable rules (WHAT/WHY/WHERE)
│   ├── COLOR.md       (78 lines) — WHY "color is expensive" philosophy
│   ├── SURFACES.md    (66 lines) — WHY two-tier grey/white model
│   └── DECISIONS.md   (101 lines) — all design decisions with rationale
```

Total: 390 lines (63% reduction from 1,064).
