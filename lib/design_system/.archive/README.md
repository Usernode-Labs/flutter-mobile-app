# Design System Research Archive

Local-only archive of research, audits, and gap analysis performed during the
"Color is Expensive" design system development. This directory is git-ignored.

## Contents

| File | Description | ~Lines |
|------|-------------|--------|
| `01_first_principles_design.md` | Complete "Color is Expensive" philosophy + ideal M3 implementation | 720 |
| `02_m3_theme_audit.md` | Detailed audit of every theme decision vs M3 spec | 415 |
| `03_ui_components_audit.md` | Screen-by-screen coverage matrix + anti-pattern catalog | 360 |
| `04_current_implementation_portrait.md` | Synthesized snapshot mapping current code to ideal sections | 300 |
| `05_gap_analysis_and_recommendations.md` | Ideal vs reality alignment matrix + prioritized action plan | 590 |
| `06_harness_engineering_research.md` | Summary of agent/harness research that informed docs restructure | ~100 |

## Origin

These notes were created in the Intent workspace during the design system
documentation restructure on the `unified-theme` branch
(Feb 2026). They informed the final lean documentation in `docs/`.

## How to Use

- **Understanding "why"**: Start with `01_first_principles_design.md` for the
  complete design philosophy and ideal M3 implementation.
- **Finding gaps**: `05_gap_analysis_and_recommendations.md` has the full
  alignment matrix and prioritized action plan.
- **Migration planning**: `03_ui_components_audit.md` §F has the 4-wave
  migration roadmap with per-screen work items.
- **Theme decisions**: `02_m3_theme_audit.md` documents every override with
  M3 compatibility assessment.
