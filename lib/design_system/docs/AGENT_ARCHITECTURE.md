# Design System Harness — Agent Architecture

Visual map of the orchestration system that guides AI agents through design-to-code work. Six diagrams, read top-to-bottom.

---

## 1. Harness Information Architecture

Everything the agent navigates, layered by distance from code.

```mermaid
graph TD
    subgraph L0["L0 — Entry Points"]
        CLAUDE["CLAUDE.md"]
        AGENTS["AGENTS.md"]
        CMD_WFF["/widget-from-figma"]
        CMD_FI["/figma-inspect"]
        CMD_VW["/verify-widget"]
        AGENT_WB["widget-builder agent"]
    end

    subgraph L1["L1 — Constraint Docs"]
        CONSTRAINTS["CONSTRAINTS.md"]
        COLOR["COLOR.md"]
        SURFACES["SURFACES.md"]
        LAYOUT["LAYOUT.md"]
        TYPOGRAPHY["TYPOGRAPHY.md"]
        SCREEN_PAT["SCREEN_PATTERNS.md"]
        DECISIONS["DECISIONS.md"]
    end

    subgraph L2["L2 — Build References"]
        BUILD_INST["BUILD_INSTRUCTIONS.md"]
        SPEC_YAML[".spec.yaml files"]
        GENESIS[".genesis.md docs"]
        REF_PNG[".reference.png screenshots"]
    end

    subgraph L3["L3 — Tooling"]
        DART_MCP["Dart MCP\nanalyze · resolve · hover\ntest · format · fix"]
        FIGMA_MCP["Figma MCP\nscreenshot · context\nvariables"]
        DS_LINTS["ds_lints\n8 rules"]
        VERIFY_SH["verify-widget.sh\n9 checks"]
        HOOKS["PostToolUse hooks\nauto-format · genesis check\nds_lint on save"]
    end

    subgraph L4_DS["L4a — DS Code Track"]
        TOKENS["tokens/\n9 token classes"]
        THEME["theme/\nColorIsExpensiveTheme"]
        SRC["src/\n35 widgets"]
        WB["widgetbook/\nv4 stories"]
        BARREL["design_system.dart\nbarrel export"]
    end

    subgraph L4_LEGACY["L4b — Legacy Code Track"]
        CORE["lib/core/widgets/\nAppButton · AppCard\nAppActionButton\nAppBottomSheet\nAppProgressBar"]
    end

    subgraph L4_CONSUMER["L4c — Consumer"]
        FEATURES["lib/features/*/screens/\nRiverpod wiring\ncomposes DS + legacy"]
    end

    %% L0 reads L1
    CLAUDE -->|reads| AGENTS
    CLAUDE -->|reads| CONSTRAINTS
    CMD_WFF -->|reads| BUILD_INST
    CMD_WFF -->|reads| CONSTRAINTS
    CMD_FI -->|reads| BUILD_INST
    AGENT_WB -->|reads| BUILD_INST

    %% L0 invokes L3
    CMD_WFF -->|invokes| DART_MCP
    CMD_WFF -->|invokes| FIGMA_MCP
    CMD_FI -->|invokes| FIGMA_MCP
    CMD_VW -->|invokes| VERIFY_SH
    CMD_VW -->|invokes| DS_LINTS

    %% L2 produced by pipeline
    CMD_FI -->|produces| SPEC_YAML
    CMD_FI -->|produces| REF_PNG
    CMD_WFF -->|produces| GENESIS

    %% L3 enforces L4
    DS_LINTS -->|enforces| SRC
    DS_LINTS -->|enforces| FEATURES
    HOOKS -->|enforces| SRC
    DART_MCP -->|validates| SRC
    VERIFY_SH -->|validates| SRC

    %% L4 code flow
    TOKENS --> THEME
    THEME --> SRC
    SRC --> BARREL
    SRC --> WB

    %% Consumer composition
    SRC -->|consumed by| FEATURES
    CORE -->|consumed by| FEATURES
    CORE -->|composed in| SRC
```

---

## 2. Agent Decision Flow

How the agent routes a user request to the right entry point and quality gate.

```mermaid
flowchart TD
    REQ(["User request"])

    REQ --> D1{"Request type?"}

    D1 -->|"Build widget\nfrom Figma"| P1["/widget-from-figma pipeline"]
    D1 -->|"Build widget\nfrom description"| P2["Manual spec\nthen build pipeline"]
    D1 -->|"Build a screen"| P3["SCREEN_PATTERNS.md\ncompose DS + core widgets"]
    D1 -->|"Fix / iterate\nexisting widget"| P4["Read genesis +\nconstraints, edit"]
    D1 -->|"Change token\nor theme"| P5["color_is_expensive_theme.dart\ncascade to dependents"]
    D1 -->|"Add to\nexisting screen"| P6["AGENTS.md conventions\nRiverpod wiring"]

    P1 --> V1["/verify-widget"]
    P2 --> V1
    P3 --> V2["Screen review\nchecklist"]
    P4 --> V1
    P5 --> V3["flutter analyze\n+ flutter test"]
    P6 --> V3

    V1 --> QG["Quality gate\n10 checks"]
    V2 --> QG
    V3 --> QG

    QG --> PASS{"All pass?"}
    PASS -->|yes| DONE(["Done"])
    PASS -->|no| FIX["Fix issues"] --> QG

    %% Entry-point docs
    P1 -.- DOC1(["Reads: BUILD_INSTRUCTIONS.md\nCONSTRAINTS.md"])
    P2 -.- DOC1
    P3 -.- DOC3(["Reads: SCREEN_PATTERNS.md\nLAYOUT.md, SURFACES.md"])
    P4 -.- DOC4(["Reads: genesis doc\nCONSTRAINTS.md, DECISIONS.md"])
    P5 -.- DOC5(["Reads: COLOR.md\nSURFACES.md, tokens/"])
    P6 -.- DOC6(["Reads: AGENTS.md\nSCREEN_PATTERNS.md"])

    style REQ fill:#f5f5f5,stroke:#333
    style DONE fill:#e8f5e9,stroke:#388e3c
    style QG fill:#fff3e0,stroke:#f57c00
```

---

## 3. Widget Pipeline

Full sequence for building a widget from Figma URL to verified output.

```mermaid
sequenceDiagram
    actor User
    participant Agent
    participant FigmaMCP as Figma MCP
    participant DartMCP as Dart MCP
    participant FS as File System
    participant QG as Quality Gate

    User->>Agent: Figma URL or description

    Note over Agent: Phase 1 — Inspect

    par Parallel Figma calls
        Agent->>FigmaMCP: get_design_context(nodeId)
        Agent->>FigmaMCP: get_screenshot(nodeId)
        Agent->>FigmaMCP: get_variable_defs(fileKey)
    end
    FigmaMCP-->>Agent: design data + image + variables

    Agent->>Agent: Map Figma values to tokens (snap rules)
    Agent->>FS: Write .spec.yaml
    Agent->>FS: Write .reference.png
    Agent->>FS: Write initial .genesis.md

    Note over Agent: Phase 2 — Build

    Agent->>FS: Read BUILD_INSTRUCTIONS.md + CONSTRAINTS.md

    par Parallel Dart MCP lookups
        Agent->>DartMCP: resolve_workspace_symbol (x N tokens)
        Agent->>DartMCP: resolve_workspace_symbol (x N widgets)
        Agent->>DartMCP: hover (token files for API)
    end
    DartMCP-->>Agent: Symbol locations + type info

    Agent->>FS: Write widget src
    Agent->>FS: Write test + golden
    Agent->>FS: Write Widgetbook v4 story + scenarios
    Agent->>FS: Update barrel export
    Agent->>FS: Update genesis doc
    Agent->>FS: Add catalog row to DESIGN_SYSTEM.md

    Note over Agent: Phase 3 — Verify

    par Post-write validation
        Agent->>DartMCP: analyze_files
        Agent->>DartMCP: dart_fix
        Agent->>DartMCP: run_tests
    end
    DartMCP-->>Agent: Results

    Agent->>QG: verify-widget.sh (9 checks)

    alt All checks pass
        QG-->>Agent: PASS
        Agent->>User: Ready for visual review in Widgetbook
    else Failures found
        QG-->>Agent: FAIL (details)
        Agent->>FS: Fix issues
        Agent->>QG: Re-run checks
    end
```

---

## 4. Token Resolution & Composition

### 4a — Token Flow

How a Figma value becomes a pixel on screen.

```mermaid
graph LR
    FV["Figma value\n(e.g. 16dp)"]
    SNAP["Snap rule\n(e.g. 15-20 → space16)"]
    TOKEN["Token class\n(e.g. AppSpacing)"]
    EXT["ThemeExtension&lt;T&gt;\nregistered in theme"]
    CTX["Theme.of(context)\n.extension&lt;AppSpacing&gt;()!"]
    WIDGET["Widget\nspacing.space16"]

    FV --> SNAP --> TOKEN --> EXT --> CTX --> WIDGET

    subgraph "Token types"
        T1["AppSpacing\n4 · 8 · 12 · 16 · 24 · 32 · 48"]
        T2["AppRadii\nsmall · medium · large\nlargeIncreased · xLarge · full"]
        T3["AppSizing\nicons: 20 · 24 · 28 · 32\ncontainers: 40 · 48 · 56 · 64"]
        T4["AppElevation\nnone · low · medium · high · max"]
        T5["AppOpacity\nsubtle · medium · strong\ndisabled · secondary"]
        T6["AppAnimation\nfast · normal · slow · complex"]
        T7["AppBorders\nborder styles"]
    end

    subgraph "Semantic color groups"
        C1["technical\nblue hue"]
        C2["flash\namber hue"]
        C6["premium\nyellow hue"]
        C3["community\ngreen hue"]
        C4["success\ngreen hue"]
        C5["warning\namber caution"]
    end

    TOKEN --- T1
    TOKEN --- T2
    TOKEN --- T3
    TOKEN --- T4
    TOKEN --- T5
    TOKEN --- T6
    TOKEN --- T7
    TOKEN --- C1
    TOKEN --- C2
    TOKEN --- C3
    TOKEN --- C4
    TOKEN --- C5
```

### 4b — Widget Composition

The M3-first rule in practice: DS slot widgets plug into M3 containers; legacy core widgets can be composed.

```mermaid
graph LR
    subgraph "M3 Components"
        M3_LT["ListTile"]
        M3_CARD["Card"]
        M3_SW["Switch · Checkbox"]
        M3_SC["Scaffold · AppBar"]
    end

    subgraph "DS Slot Widgets (lib/design_system/src/)"
        DS_IB["IconBadge"]
        DS_SB["StatusBadge"]
        DS_RB["RankBadge"]
        DS_IR["InfoRow"]
        DS_SH["ScoreHeader"]
        DS_CC["ChallengeCard"]
        DS_TF["TextField"]
        DS_DD["DropdownChip"]
    end

    subgraph "Legacy Core (lib/core/widgets/)"
        CORE_BTN["AppButton"]
        CORE_CARD["AppCard"]
        CORE_AB["AppActionButton"]
        CORE_BS["AppBottomSheet"]
        CORE_PB["AppProgressBar"]
    end

    subgraph "Consumer (lib/features/*/screens/)"
        SCREEN["Feature Screen\nRiverpod state wiring"]
    end

    DS_IB -->|"slots into"| M3_LT
    DS_SB -->|"slots into"| M3_LT
    DS_RB -->|"slots into"| M3_LT

    M3_LT --> SCREEN
    M3_CARD --> SCREEN
    M3_SC --> SCREEN
    DS_CC --> SCREEN
    DS_SH --> SCREEN
    DS_TF --> SCREEN
    DS_DD --> SCREEN
    DS_IR --> SCREEN
    CORE_BTN --> SCREEN
    CORE_CARD --> SCREEN
    CORE_AB --> SCREEN
    CORE_BS --> SCREEN
    CORE_PB --> SCREEN

    CORE_CARD -->|"composed in"| DS_CC
```

---

## 5. Quality Gate Pipeline

The 10-point check sequence, with PostToolUse hooks as a parallel enforcement lane.

```mermaid
flowchart TD
    CODE(["Code written / edited"])

    CODE --> F1["1. dart format"]
    F1 -->|pass| F2["2. flutter analyze"]
    F1 -->|fail| FIX

    F2 -->|pass| F3["3. flutter test"]
    F2 -->|fail| FIX

    F3 -->|pass| F4["4. No hardcoded values\n(spacing, radius, colors)"]
    F3 -->|fail| FIX

    F4 -->|pass| F5["5. No banned M3 wrappers\n(prove gap first)"]
    F4 -->|fail| FIX

    F5 -->|pass| F6["6. Barrel export check\ndesign_system.dart"]
    F5 -->|fail| FIX

    F6 -->|pass| F7["7. Genesis doc check\n.specs/Widget.genesis.md"]
    F6 -->|fail| FIX

    F7 -->|pass| F8["8. Widget catalog check\nDESIGN_SYSTEM.md row"]
    F7 -->|fail| FIX

    F8 -->|pass| F9["9. ds_lints\n8 custom rules"]
    F8 -->|fail| FIX

    F9 -->|pass| ALLPASS{"All 9 pass?"}
    F9 -->|fail| FIX

    ALLPASS -->|yes| VR["10. Visual review\nWidgetbook"]
    ALLPASS -->|no| FIX

    VR --> DONE(["DONE"])

    FIX["Fix issues"] --> CODE

    subgraph HOOKS_LANE["PostToolUse Hooks (parallel enforcement)"]
        H1["On .dart Edit/Write:\nauto dart format"]
        H2["On DS widget save:\ngenesis + catalog reminder"]
        H3["On DS/features save:\nds_lints inline warnings"]
    end

    CODE -.->|"triggers"| HOOKS_LANE

    subgraph DS_LINT_RULES["ds_lints — 8 rules"]
        direction LR
        R1["avoid_hardcoded\n_edge_insets"]
        R2["avoid_hardcoded\n_border_radius"]
        R3["avoid_hardcoded\n_sized_box_spacing"]
        R4["avoid_hardcoded\n_icon_size"]
        R5["matryoshka_zone\n_violation"]
        R6["avoid_frb\n_imports"]
        R7["avoid_padding\n_around_tiles"]
        R8["avoid_listtile\n_layout_overrides"]
    end

    F9 -.-> DS_LINT_RULES

    style CODE fill:#f5f5f5,stroke:#333
    style DONE fill:#e8f5e9,stroke:#388e3c
    style FIX fill:#ffebee,stroke:#c62828
    style ALLPASS fill:#fff3e0,stroke:#f57c00
    style HOOKS_LANE fill:#e3f2fd,stroke:#1565c0
```

---

## 6. Real-World Context-Loading Loop

How the agent actually navigates the harness — not linear, but a lazy-loading loop where docs are pulled in on demand as questions arise mid-build.

```mermaid
stateDiagram-v2
    [*] --> Orient

    state "Orient" as Orient {
        note left of Orient
            Skim DESIGN_SYSTEM.md
            + request analysis
        end note
    }

    state "Pattern-Match" as PatternMatch {
        note left of PatternMatch
            Scan src/ for similar widgets
            Read 1-2 existing impls
        end note
    }

    state "Build" as Build {
        note left of Build
            Write widget, test,
            widgetbook, barrel, genesis
        end note
    }

    state "Hook Fires" as Hook {
        note left of Hook
            PostToolUse: auto-format,
            ds_lint, genesis reminder
        end note
    }

    state "React to Feedback" as React {
        note left of React
            Read hook output,
            interpret lint warning
        end note
    }

    state "Pull Doc on Demand" as PullDoc {
        note left of PullDoc
            Lazy-load the specific
            constraint or reference
        end note
    }

    state "Verify" as Verify {
        note left of Verify
            verify-widget.sh
            9 automated checks
        end note
    }

    state "Fix" as Fix {
        note left of Fix
            Targeted edit based
            on failure message
        end note
    }

    Orient --> PatternMatch
    PatternMatch --> Build

    Build --> Hook : file saved
    Hook --> React : output returned
    React --> Build : understood, continue
    React --> PullDoc : need more context

    PullDoc --> Build : question answered

    Build --> Verify : all files written
    Verify --> [*] : all pass
    Verify --> Fix : failure
    Fix --> PullDoc : re-read constraint
    Fix --> Build : simple fix
```

The key difference from Diagram 3: docs aren't read upfront in a batch — they're pulled in **reactively** when a specific question arises. Common triggers:

| Trigger | Doc pulled |
|---------|-----------|
| "Is this an M3 gap?" | CONSTRAINTS.md (M3 gap-proof checklist) |
| "What token snaps to 14dp?" | BUILD_INSTRUCTIONS.md (snap rules) |
| "How did the last similar widget handle this?" | Existing `.genesis.md` |
| "What's the surface model here?" | SURFACES.md |
| "Matryoshka lint fired — who owns this spacing?" | SCREEN_PATTERNS.md (spacing ownership) |
| "Which color group for this semantic?" | COLOR.md (semantic color groups) |
| Hook warns "missing genesis" | BUILD_INSTRUCTIONS.md (genesis format) |
| Hook warns "missing catalog entry" | DESIGN_SYSTEM.md (catalog table) |
| ds_lint fires `avoid_padding_around_tiles` | LAYOUT.md (ListTile collision rules) |

---

*Source files: [CONSTRAINTS.md](CONSTRAINTS.md) · [BUILD_INSTRUCTIONS.md](../.specs/BUILD_INSTRUCTIONS.md) · [SCREEN_PATTERNS.md](SCREEN_PATTERNS.md) · [DECISIONS.md](DECISIONS.md) · [widget-from-figma](../../../.claude/commands/widget-from-figma.md) · [verify-widget](../../../.claude/commands/verify-widget.md)*
