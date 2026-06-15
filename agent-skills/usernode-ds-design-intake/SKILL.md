---
name: usernode-ds-design-intake
description: Normalize Usernode design input into a DS spec. Use for Figma URLs, screenshots, sketches, wireframes, or text briefs before building design-system widgets or screens.
---

# Usernode DS Design Intake

Turn any design input into a normalized implementation artifact for `usernode-ds-build-widget` or `usernode-ds-build-screen`.

## Inputs

- Figma URL: use Figma tooling if available and capture node context plus screenshot.
- Screenshot/sketch/wireframe: inspect the image and record layout, content, and visual intent.
- Text-only brief: ask the user for a sketch, screenshot, or Figma reference first. Proceed only if the user explicitly says to continue text-only, and record the uncertainty.

## Output

Write or update `lib/design_system/.specs/<Name>.spec.yaml` for design-system widget work. For screen work, produce the same fields in the implementation notes or a screen spec if one is useful.

Required fields for design work:

```yaml
meta:
  name: <Name>
  input_type: figma | screenshot | sketch | wireframe | text-only
  reference: <url-or-path-or-description>
  text_only_override: false
intent:
  summary: <what the user wants>
  scope: widget | screen
  target: new | existing
pattern_decision:
  operating_mode: <user/session/trust/device context>
  chosen_pattern: <M3 or existing DS pattern>
  rejected_alternatives:
    - pattern: <name>
      reason: <why rejected>
  uncertainty:
    - <known ambiguity, especially for text-only override>
```

## Process

1. Read `lib/design_system/DESIGN_SYSTEM.md`, `lib/design_system/docs/CONSTRAINTS.md`, and the relevant screen/widget docs.
2. Run the `usernode-mobile-ux-taste` reasoning before implementation work begins.
3. Map visual values to existing tokens from `lib/design_system/.specs/BUILD_INSTRUCTIONS.md`.
4. Never invent a new pattern silently. If M3 and existing DS patterns do not cover the need, stop with a gap proof and ask for explicit approval.
