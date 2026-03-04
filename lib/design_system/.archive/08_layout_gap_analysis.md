# Layout Gap Analysis

> Audit performed Mar 2026, `unified-theme` branch.
> Compared all screens in `lib/features/` and widgets in `lib/design_system/src/`
> against the 6 rules codified in `docs/LAYOUT.md`.

---

## 1. Methodology

Audited every screen-level file in `lib/features/` and every widget in
`lib/design_system/src/` against 6 LAYOUT.md rules:

1. **Token-based spacing** — all `EdgeInsets` use `AppSpacing` tokens, not numeric literals
2. **On-grid values** — every spacing value sits on the 4px / 8pt grid (4, 8, 12, 16, 20, 24, 28, 32 …)
3. **SliverPadding** — `CustomScrollView` screen margins via `SliverPadding`, not `Padding` inside `SliverToBoxAdapter`
4. **Column/Row `spacing:`** — uniform gaps via `spacing:` parameter, not interleaved `SizedBox`
5. **SafeArea** — correct per screen type (tab → explicit, detail w/ TopAppBar → automatic, full → explicit)
6. **Screen anatomy** — TopAppBar as first sliver in detail screens, correct scroll pattern choice

Data gathered via `grep` counts and file-level reads of all 17 audited screens.

---

## 2. Per-Screen Compliance Matrix

| Screen | Type | SafeArea | Margins | Scroll Pattern | Compliance |
|--------|------|----------|---------|----------------|------------|
| `challenges_screen.dart` | Tab | Manual `MediaQuery.padding.top` | Tokens (AppSpacing) | NestedScrollView | Partial |
| `wallet_screen.dart` | Tab | Present | Hardcoded | CustomScrollView + SliverFillRemaining | Partial |
| `dapps_screen.dart` | Tab | Handled by AppBar | Hardcoded | WebView | Non-compliant |
| `node_status_screen.dart` | Tab | Present | Hardcoded | ListView | Partial |
| `leaderboard_screen.dart` | Detail | TopAppBar (auto) | Tokens (1 hardcoded exception) | CustomScrollView | Partial |
| `challenge_detail_screen.dart` | Detail | DS widget | DS widget | CustomScrollView (via DS) | Compliant |
| `epoch_performance_screen.dart` | Detail | Missing | Delegated to DS | SingleChildScrollView (anti-pattern) | Non-compliant |
| `send_screen.dart` | Detail | Present | Hardcoded | SingleChildScrollView | Partial |
| `block_details_screen.dart` | Detail | Present | Hardcoded | ListView | Partial |
| `node_peers_screen.dart` | Detail | Present | Hardcoded | Column + ListView.separated | Partial |
| `slot_assignments_screen.dart` | Detail | Present | Hardcoded | Column + ListView.separated | Partial |
| `produced_blocks_screen.dart` | Detail | Present | Hardcoded | CustomScrollView + SliverFillRemaining | Non-compliant |
| `welcome_setup_screen.dart` | Full | Present | Hardcoded | Column (no scroll) | Partial |
| `welcome_claim_screen.dart` | Full | Present | Hardcoded | Column (no scroll) | Partial |
| `transaction_success_screen.dart` | Full | Present | Hardcoded | Column + Spacer | Partial |
| `transaction_failed_screen.dart` | Full | Present | Hardcoded | Column + Spacer | Partial |
| `background_production_settings_screen.dart` | Detail | Present | Hardcoded | ListView | Partial |

**Summary:** 1 compliant, 3 non-compliant, 13 partial.

---

## 3. Gap Inventory by Rule

### 3.1 Hardcoded EdgeInsets

**Scale:** 112 `const EdgeInsets` in `lib/features/` across 25 files; 43 in `lib/design_system/src/` across ~12 files.

#### Off-grid values (visual bugs — snap to nearest token)

| Value | File | Line | Context |
|-------|------|------|---------|
| `1.5` | `produced_blocks_screen.dart` | 779 | `EdgeInsets.all(1.5)` |
| `2` | `node_peers_screen.dart` | 144 | `EdgeInsets.only(top: 2)` |
| `2` | `node_peers_screen.dart` | 152 | `EdgeInsets.all(2)` |
| `2` | `mempool_details_screen.dart` | 269 | `EdgeInsets.only(top: 2)` |
| `2` | `challenge_card.dart` (DS) | 433 | `EdgeInsets.all(2)` |
| `3` | `slot_assignments_screen.dart` | 520 | `EdgeInsets.symmetric(vertical: 3)` |
| `6` | `background_production_settings_screen.dart` | 950 | `EdgeInsets.only(top: 6)` |
| `6` | `node_won_slots_screen.dart` | 434 | `EdgeInsets.symmetric(vertical: 6)` |
| `6` | `slot_assignments_screen.dart` | 510 | `EdgeInsets.symmetric(vertical: 6)` |
| `6` | `wallet_screen.dart` | 501 | `EdgeInsets.symmetric(vertical: 6, horizontal: 6)` |
| `6` | `leaderboard_stats_card.dart` (DS) | 446 | `EdgeInsets.all(6)` |
| `6` | `leaderboard_stats_card.dart` (DS) | 458 | `EdgeInsets.only(bottom: 6)` |
| `10` | `dapps_screen.dart` | 352 | `EdgeInsets.fromLTRB(12, 10, 12, 12)` |
| `10` | `block_details_screen.dart` | 292 | `EdgeInsets.only(left: 10)` |
| `10` | `node_status_screen.dart` | 601 | `EdgeInsets.all(10)` |
| `10` | `node_status_screen.dart` | 606 | `EdgeInsets.fromLTRB(10, 10, 0, 0)` |
| `20` | `wallet_screen.dart` | 244 | `EdgeInsets.all(20)` |
| `20` | `node_status_screen.dart` | 526 | `EdgeInsets.all(20)` |
| `20` | `produced_blocks_screen.dart` | 172 | `EdgeInsets.fromLTRB(20, 20, 20, 32)` |
| `20` | `produced_blocks_screen.dart` | 232 | `EdgeInsets.fromLTRB(20, 20, 20, 32)` |
| `40` | `wallet_screen.dart` | 420 | `EdgeInsets.symmetric(vertical: 40)` |

**Total off-grid violations: 21** (17 in features, 4 in DS)

#### On-grid but hardcoded (systemic — migrate to tokens)

Worst offenders by count of hardcoded `const EdgeInsets`:

| File | Count |
|------|-------|
| `background_production_settings_screen.dart` | 27 |
| `produced_blocks_screen.dart` | 14 |
| `wallet_screen.dart` | 10 |
| `node_status_screen.dart` | 9 |
| `slot_production_stats_screen.dart` | 6 |
| `node_won_slots_screen.dart` | 5 |
| `node_peers_screen.dart` | 4 |
| `slot_assignments_screen.dart` | 4 |
| `import_api_account_screen.dart` | 4 |
| `mempool_details_screen.dart` | 4 |

---

### 3.2 SizedBox gaps instead of `spacing:` parameter

**Scale:** 223 `SizedBox(height:` in `lib/features/` across 26 files; 39 in `lib/design_system/src/` across 11 files. **262 total.**

Column/Row `spacing:` parameter adoption: **13 files** (9 in DS widgets, 1 in features, 3 in widgetbook). Only `challenges_screen.dart` uses it in production feature code.

**Worst offenders (features):**

| File | SizedBox(height:) count |
|------|------------------------|
| `background_production_settings_screen.dart` | 63 |
| `produced_blocks_screen.dart` | 26 |
| `node_status_screen.dart` | 21 |
| `block_details_screen.dart` | 12 |
| `node_status_summary_modal.dart` | 12 |
| `slot_production_stats_screen.dart` | 12 |
| `wallet_screen.dart` | 8 |
| `battery_permission2_screen.dart` | 8 |

**DS widgets with SizedBox gaps:**

| File | Count |
|------|-------|
| `epoch_performance_page.dart` | 6 |
| `challenge_detail_page.dart` | 5 |
| `challenge_reward_card.dart` | 5 |
| `result_page.dart` | 4 |
| `leaderboard_stats_card.dart` | 4 |
| `score_header.dart` | 4 |

**Note:** Not all SizedBox gaps can convert — conditional children with `if (...) ...[SizedBox(), widget]` patterns need SizedBox since `spacing:` applies uniformly to all children.

---

### 3.3 SliverPadding missing

**Scale:** 0 `SliverPadding` usage in the entire codebase.

**Candidates (SliverToBoxAdapter children wrapped in Padding for screen margins):**

| File | Sliver count | Pattern |
|------|-------------|---------|
| `leaderboard_screen.dart` | 7 SliverToBoxAdapter | 4 wrap children in `Padding(EdgeInsets.symmetric(horizontal: spacing.space16))` |
| `challenge_detail_page.dart` (DS) | 1 SliverToBoxAdapter | Child wrapped in `Padding(EdgeInsets.only(left: spacing.space16, ...))` |
| `challenges_screen.dart` | 1 SliverToBoxAdapter | Spacer sliver in NestedScrollView header |

**Recommended conversion:** Replace per-child `Padding` with a single outer `SliverPadding` wrapping a `SliverList` where possible, or wrap individual slivers in `SliverPadding` for horizontal margins.

---

### 3.4 SafeArea violations

| Screen | Type | Issue |
|--------|------|-------|
| `challenges_screen.dart` | Tab | Uses manual `MediaQuery.of(context).padding.top` arithmetic instead of `SafeArea`. Fragile across device changes. |
| `dapps_screen.dart` | Tab | `AppBar` handles top inset but no bottom SafeArea for notched/gesture-nav devices. WebView content may bleed under system UI. |
| `epoch_performance_screen.dart` | Detail | No `SafeArea` on data path. Loading/error states have `AppBar` but main content path does not. |
| `leaderboard_screen.dart` | Detail | No explicit `SafeArea`. TopAppBar (DS sliver) likely handles top inset per LAYOUT.md rule — **may be correct**. No bottom inset handling for loading/error states. |

**Verdict:** 3 definite violations, 1 borderline (leaderboard relies on TopAppBar — correct per LAYOUT.md if TopAppBar handles `SliverAppBar` insets).

---

### 3.5 Screen anatomy issues

| File | Line | Issue |
|------|------|-------|
| `top_app_bar.dart` (DS) | 220 | `SingleChildScrollView(physics: NeverScrollableScrollPhysics())` — redundant scroll view. The `NeverScrollableScrollPhysics` disables scrolling, making the `SingleChildScrollView` a no-op wrapper. |
| `epoch_performance_screen.dart` | — | `SingleChildScrollView` wrapping `SizedBox(height: MediaQuery.of(context).size.height)` containing the DS widget. Fixed-height box breaks on keyboard appearance and safe area changes. Scroll exists only to enable `RefreshIndicator`. |
| `produced_blocks_screen.dart` | — | `CustomScrollView` with single `SliverFillRemaining` — does not benefit from sliver protocol. Marked `@Deprecated`. |
| `welcome_setup_screen.dart` | — | `Column` with no scroll fallback — content could overflow on small-screen devices. |
| `welcome_claim_screen.dart` | — | Same issue as `welcome_setup_screen.dart`. |
| `transaction_failed_screen.dart` | — | Error message could be long — no scroll fallback. |

---

### 3.6 Bottom scroll padding

| Screen | Bottom padding | Compliant? |
|--------|---------------|------------|
| `leaderboard_screen.dart` | `SizedBox(height: spacing.space32)` via SliverToBoxAdapter | Yes |
| `challenges_screen.dart` | Tab content lists handle their own padding | Partial |
| `wallet_screen.dart` | No explicit bottom padding | No |
| `node_status_screen.dart` | No explicit bottom padding | No |
| `block_details_screen.dart` | No explicit bottom padding | No |
| `send_screen.dart` | No explicit bottom padding | No |
| `node_peers_screen.dart` | No explicit bottom padding | No |
| `slot_assignments_screen.dart` | No explicit bottom padding | No |
| `background_production_settings_screen.dart` | No explicit bottom padding | No |

**Most screens lack the `space32` bottom breathing room** recommended by LAYOUT.md.

---

## 4. Compliant / Reference Screens

These screens demonstrate correct (or near-correct) LAYOUT.md patterns and can serve as migration references:

- **`challenge_detail_screen.dart`** → delegates to `ChallengeDetailPage` DS widget which uses full token-based spacing, `CustomScrollView` + `TopAppBar` sliver, correct screen anatomy.
- **`leaderboard_screen.dart`** → `AppSpacing` tokens throughout, `CustomScrollView` + `SliverToBoxAdapter` pattern, `TopAppBar` as first sliver, bottom `space32` padding. (Gap: SliverPadding not yet adopted for horizontal margins.)
- **`challenges_screen.dart`** → `AppSpacing` tokens for margins/gaps, `NestedScrollView` for pinned tabs, Column `spacing:` parameter used. (Gap: manual SafeArea via `MediaQuery`, no SliverPadding.)

---

## 5. Priority Fix Order

### Phase 1 — Off-grid values (visual bugs, ~21 sites)

Snap off-grid EdgeInsets to nearest grid token. These are the most visible inconsistencies.

| Value | Nearest grid | Files affected |
|-------|-------------|----------------|
| `1.5` | `space0` or `space4` | 1 |
| `2` | `space4` | 4 |
| `3` | `space4` | 1 |
| `6` | `space4` or `space8` | 6 |
| `10` | `space8` or `space12` | 4 |
| `20` | `space24` (or `space16`) | 4 |
| `40` | `space32` (or `space48`) | 1 |

### Phase 2 — SafeArea fixes (functional, 3 screens)

| Screen | Fix |
|--------|-----|
| `challenges_screen.dart` | Replace `MediaQuery.padding.top` arithmetic with `SafeArea` |
| `dapps_screen.dart` | Add bottom SafeArea for gesture-nav devices |
| `epoch_performance_screen.dart` | Add `SafeArea` on data path; fix `SingleChildScrollView` + fixed-height anti-pattern |

### Phase 3 — SliverPadding adoption (8 candidate slivers)

| Screen | Action |
|--------|--------|
| `leaderboard_screen.dart` | Wrap 4 SliverToBoxAdapter children's Padding → SliverPadding |
| `challenge_detail_page.dart` (DS) | Wrap 1 SliverToBoxAdapter child's Padding → SliverPadding |

### Phase 4 — Token migration (systemic, screen-by-screen)

Convert `const EdgeInsets` → `spacing.spaceN` per screen. Worst-first ordering:

1. `background_production_settings_screen.dart` (27 hardcoded EdgeInsets, 63 SizedBox gaps)
2. `produced_blocks_screen.dart` (14 EdgeInsets, 26 SizedBox gaps) — **deprecated**, may skip
3. `node_status_screen.dart` (9 EdgeInsets, 21 SizedBox gaps)
4. `wallet_screen.dart` (10 EdgeInsets, 8 SizedBox gaps)
5. `slot_production_stats_screen.dart` (6 EdgeInsets, 12 SizedBox gaps)
6. Remaining screens in descending order of violation count

### Phase 5 — Column/Row `spacing:` adoption (opportunistic)

Convert `SizedBox` gaps to `spacing:` parameter where spacing is uniform within a Column/Row.

**Skip:** Conditional `...[SizedBox(), widget]` patterns where children are conditionally included — `spacing:` cannot handle non-uniform gaps.

**Best candidates:** Screens with long Column children lists using consistent `SizedBox(height: 16)` between every child.

### Phase 6 — Bottom scroll padding (9 screens)

Add `SizedBox(height: spacing.space32)` or equivalent sliver at the bottom of scrollable screens for breathing room above BottomNav or screen edge.

---

## 6. What This Does NOT Cover

- **No code changes** — this is a gap analysis document only
- **No migration execution** — separate tasks per phase above
- **No DS widget micro-spacing audit** — internal component spacing (e.g., 2px border insets in `challenge_card.dart`) is intentional design and outside LAYOUT.md scope
- **No hardcoded color audit** — documented in `05_gap_analysis_and_recommendations.md`
- **No `produced_blocks_screen.dart` deep audit** — file is `@Deprecated` and scheduled for removal
