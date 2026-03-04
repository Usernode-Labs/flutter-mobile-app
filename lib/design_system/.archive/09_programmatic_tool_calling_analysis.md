# PTC Impact Analysis: How Programmatic Tool Calling Reshapes Our Harness

> **Status**: Research / future reference. PTC is an API-level feature, not available in Claude Code CLI today. MCP tools also can't be called programmatically yet. Revisit when either changes.

## Context

**What is PTC?** Claude writes Python code that calls tools *inside a sandboxed container* — tools execute on the client side, but intermediate results flow back to the code (not Claude's context window). The model reasons once, writes a script, and the script orchestrates N tool calls with filtering/aggregation before returning a summary. Key wins: fewer round-trips, smaller context, better accuracy on multi-step tasks. Opus 4.6 + PTC is #1 on LMArena Search Arena.

**Lance Martin's thesis** ([agent design patterns](https://rlancemartin.github.io/2026/01/09/agent_design/)): "Give Claude a computer." Push actions from the tool-calling layer to the OS/container layer. The fundamental coding agent abstraction is the CLI. PTC is the API-side realization of this — compose tools as code, not as sequential round-trips.

**Our harness today**: 3-phase Figma-to-widget pipeline (`/figma-inspect` → `/widget-from-figma` → `/verify-widget`) using Figma MCP + Dart MCP, producing 14–21 model round-trips per widget.

---

## 1. Current Round-Trip Anatomy

| Phase | What happens | Round-trips |
|-------|-------------|-------------|
| **INSPECT** | 3 parallel Figma MCP calls → read theme files → token-snap → write spec+genesis | ~4 |
| **BUILD** | Dart MCP lookups (resolve_workspace_symbol, hover, signature_help) → write widget → analyze → write test → analyze → write use case → append barrel+catalog | ~8-10 |
| **VERIFY** | format + analyze + test + grep checks + barrel/genesis/catalog checks + Widgetbook launch | ~5-7 |
| **Total** | | **14-21** |

Each round-trip = full model sampling (input tokens + output tokens + latency). The BUILD phase is the worst offender — it's a sequential loop of "write file → validate → fix → write next file."

---

## 2. What PTC Unlocks For Us

### 2a. Batch Dart MCP Validation (BUILD phase, biggest win)

**Today**: Claude calls `resolve_workspace_symbol("AppSpacing")`, waits for result, calls `hover(uri, line, col)`, waits, calls `signature_help(...)`, waits — 3+ sequential round-trips before writing a single line.

**With PTC**: Claude writes a Python script that calls all lookups in a loop:
```python
tokens = ["AppSpacing", "AppRadii", "AppSemanticColors", "StatusBadge", "IconBadge"]
results = {}
for t in tokens:
    results[t] = await resolve_workspace_symbol(t)
# filter to only tokens that exist, extract file paths
valid = {k: v for k, v in results.items() if v.get("found")}
print(json.dumps(valid))
```
One model turn → N tool calls → filtered summary returns to context. **Saves 2-4 round-trips and keeps raw symbol data out of context.**

### 2b. Verify Phase as Single Script

**Today**: 9 checks run as separate tool calls with Claude reasoning between each.

**With PTC**: One script runs all checks, aggregates pass/fail:
```python
fmt = await dart_format(roots=[...])
analysis = await analyze_files()
tests = await run_tests(roots=[...])
# grep for hardcoded values, check exports, etc. done in Python
issues = []
if analysis.get("errors"): issues.append(f"Analysis: {len(analysis['errors'])} errors")
if tests.get("failures"): issues.append(f"Tests: {len(tests['failures'])} failures")
print(f"{'PASS' if not issues else 'FAIL'}: {'; '.join(issues) or 'all 9 checks passed'}")
```
**Saves 4-6 round-trips. Only the summary hits context, not the full analysis/test output.**

### 2c. Multi-Widget Batch Builds

**Today**: Building 3 widgets from a Figma page = 3 sequential pipeline runs = 42-63 round-trips.

**With PTC**: Figma inspection could batch all 3 nodes:
```python
nodes = ["1:23", "1:45", "1:67"]
specs = {}
for nid in nodes:
    ctx = await get_design_context(fileKey="abc", nodeId=nid)
    screenshot = await get_screenshot(fileKey="abc", nodeId=nid)
    vars = await get_variable_defs(fileKey="abc", nodeId=nid)
    specs[nid] = {"context": ctx, "screenshot": screenshot, "vars": vars}
# extract common tokens, deduplicate
print(json.dumps(specs))
```
**3 widgets inspected in 1 model turn instead of 3.**

### 2d. Token Audit / Migration Tooling

A PTC script could crawl every widget file, resolve each token reference via Dart MCP, and produce a migration report — something that would be impractical with sequential tool calls (50+ files × 3 lookups each = 150 round-trips vs. 1 PTC turn).

---

## 3. How Well Our Lindy Architecture Works With PTC

### What aligns perfectly

| Architecture property | Why it helps PTC |
|---|---|
| **Presentation-only rule** | Widgets are pure data-in/pixels-out. A PTC script can generate them without understanding state wiring — the "state gap" is intentional and stays in screens. |
| **Token vocabulary is finite & enumerated** | 50+ tokens across 7 ThemeExtension types. A PTC script can validate every token reference by name — no ambiguity, no runtime lookups needed. |
| **Spec YAML as intermediate artifact** | The inspect→build handoff uses a serialized spec. PTC can produce spec YAML programmatically and pass it forward without round-tripping through Claude's context. |
| **Genesis docs as decision log** | PTC doesn't replace the *reasoning* Claude does — it replaces the *plumbing*. Genesis docs capture the reasoning; PTC handles the mechanical validation. Clean separation. |
| **M3-first composability** | Widgets compose slot widgets into M3 containers. PTC can validate the composition (does this widget use M3 Card directly? does it avoid wrapping ListTile?) via static analysis in the script. |
| **Barrel exports + catalog as append-only** | Mechanical operations (append export line, append catalog row) are ideal for PTC — no reasoning needed, just string operations. |

### What creates friction

| Architecture property | Friction with PTC |
|---|---|
| **Auto-hooks on Edit/Write** | PTC runs in a container — it can't trigger our post-write hooks (dart format, genesis check). Hooks would need to run *after* PTC completes, not per-file. |
| **Dart MCP is stdio-local** | PTC's `allowed_callers: ["code_execution_20260120"]` works with API-defined tools. Our Dart MCP server is local stdio — we'd need to expose Dart MCP tools as API-level tool definitions for PTC to call them. |
| **MCP tools can't be called programmatically yet** | The docs explicitly state: "Tools provided by an MCP connector" are not yet supported for programmatic calling. This is the **key constraint** — our Figma MCP and Dart MCP tools can't be PTC-called today. |
| **Dual-theme fragility** | Not a PTC issue per se, but PTC-generated widgets still need to be tested inside the DesignSystemTheme wrapper. The unified-theme branch work is prerequisite to making PTC-built widgets reliable. |

---

## 4. The MCP Connector Gap — And The Workaround

The biggest limitation: **MCP-provided tools can't be called from PTC containers today.** Both our Figma and Dart MCP tools fall in this category.

**Workaround architecture**: Wrap MCP tool functionality as API-level tool definitions in the orchestrating application. Instead of Claude directly calling `mcp__dart__analyze_files`, define a regular tool `analyze_files` with `allowed_callers: ["code_execution_20260120"]` that your server-side handler routes to the Dart MCP server. This is a thin proxy layer.

**When MCP support ships**: The proxy becomes unnecessary. Our tool definitions already have clean schemas — they'd just get `allowed_callers` added.

---

## 5. Concrete Impact Matrix

| Metric | Today (no PTC) | With PTC (post-MCP support) | Delta |
|--------|----------------|----------------------------|-------|
| Round-trips per widget | 14-21 | ~5-7 | **-60-70%** |
| Context tokens (BUILD phase) | ~30K (raw MCP results in context) | ~5K (filtered summaries only) | **-80%** |
| Multi-widget batch (3 widgets) | 42-63 round-trips | ~12-15 round-trips | **-70%** |
| Verify phase | 5-7 round-trips | 1-2 round-trips | **-75%** |
| Token audit (50 files) | Impractical (~150 trips) | 1-2 round-trips | **New capability** |

---

## 6. What To Do Now vs. Later

### Now (no code changes needed — architectural awareness)

1. **Recognize the pipeline is PTC-shaped already.** The spec YAML intermediary, the presentation-only rule, the finite token vocabulary — these are exactly the properties that make PTC effective. The architecture is lindy because it was built for composability, and PTC rewards composability.

2. **The unified-theme branch work is prerequisite.** PTC-generated widgets need a reliable single-root theme. Finish the theme unification first.

3. **Keep genesis docs as the reasoning layer.** PTC handles plumbing; Claude's reasoning (captured in genesis docs) stays in the model turn. Don't try to move design decisions into scripts.

### When MCP-in-PTC ships

4. **Add `allowed_callers` to Dart MCP tool proxies.** Expose `analyze_files`, `resolve_workspace_symbol`, `run_tests` as PTC-callable.

5. **Refactor `/verify-widget` as a PTC-first flow.** All 9 checks become a single Python script with one summary return.

6. **Refactor BUILD phase token validation.** Batch all `resolve_workspace_symbol` + `hover` calls into a single PTC script that returns a validated token map.

### Longer term

7. **Multi-widget batch pipeline.** `/widget-from-figma` accepts a Figma page URL, PTC inspects all nodes, Claude reasons about the set, PTC builds all widgets, PTC verifies all widgets. Full page → code in ~15 round-trips.

8. **Token migration tooling.** PTC script crawls codebase, validates every token reference, produces migration report for legacy → design system transitions.

---

## 7. Key Takeaway

The lindy architecture — presentation-only widgets, finite token vocabulary, spec YAML as intermediary, genesis docs for reasoning — was built for **composability by humans and agents alike**. PTC doesn't change the architecture; it dramatically reduces the *cost* of the mechanical parts (validation, file operations, batch lookups) while leaving the *valuable* parts (design reasoning, token snapping decisions, M3 composition choices) in Claude's context where they belong.

The main blocker is the MCP connector limitation — once that ships, the pipeline shrinks from 14-21 round-trips to ~5-7 per widget with no architectural changes needed. The architecture was already lindy.

---

Sources:
- [Lance Martin: "Give Claude a computer"](https://x.com/RLanceMartin/status/2027450018513490419)
- [Lance Martin: Agent Design Patterns](https://rlancemartin.github.io/2026/01/09/agent_design/)
- [Claude Docs: Programmatic Tool Calling](https://platform.claude.com/docs/en/agents-and-tools/tool-use/programmatic-tool-calling)
- [Lance Martin: PTC performance results](https://x.com/RLanceMartin/status/2023824176029761931)
- [Anthropic: Advanced Tool Use](https://www.anthropic.com/engineering/advanced-tool-use)
