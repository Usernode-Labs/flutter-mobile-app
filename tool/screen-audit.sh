#!/usr/bin/env bash
set -u

FILE="${1:-}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$ROOT" ]; then
  echo "Unable to locate git repository root" >&2
  exit 1
fi
cd "$ROOT"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Usage: bash tool/screen-audit.sh <path/to/screen_file.dart>"
  echo "File not found: $FILE"
  exit 1
fi

case "$FILE" in
  /*) LINT_FILE="$FILE" ;;
  *) LINT_FILE="$ROOT/$FILE" ;;
esac

PASS=0
FAIL=0
WARN=0
REPORT=""

check() {
  local name="$1"
  local result="$2"
  local detail="${3:-}"
  if [ "$result" -eq 0 ]; then
    REPORT="${REPORT}  PASS  ${name}\n"
    PASS=$((PASS + 1))
  else
    REPORT="${REPORT}  FAIL  ${name} -- ${detail}\n"
    FAIL=$((FAIL + 1))
  fi
}

warn() {
  local name="$1"
  local detail="$2"
  REPORT="${REPORT}  WARN  ${name} -- ${detail} (manual review)\n"
  WARN=$((WARN + 1))
}

ensure_ds_lints_deps() {
  if [ ! -f packages/ds_lints/.dart_tool/package_config.json ]; then
    (cd packages/ds_lints && dart pub get >/dev/null)
  fi
}

HAS_PSL=$(grep -c 'ParallaxSurfaceLayout' "$FILE" 2>/dev/null || true)
HAS_TOP_APP_BAR=$(grep -c 'TopAppBar' "$FILE" 2>/dev/null || true)
HAS_SLIVER_APP_BAR=$(grep -c 'SliverAppBar' "$FILE" 2>/dev/null || true)
HAS_SAFE_AREA=$(grep -c 'SafeArea' "$FILE" 2>/dev/null || true)
HAS_MODAL=$(grep -c 'showModalBottomSheet\|BottomSheet\|SheetLayout' "$FILE" 2>/dev/null || true)
HAS_NESTED_SCROLL=$(grep -c 'NestedScrollView\|nestedBody' "$FILE" 2>/dev/null || true)
HAS_CUSTOM_SCROLL=$(grep -c 'CustomScrollView' "$FILE" 2>/dev/null || true)
HAS_LISTVIEW=$(grep -c 'ListView' "$FILE" 2>/dev/null || true)
HAS_GRIDVIEW=$(grep -c 'GridView' "$FILE" 2>/dev/null || true)
HAS_SINGLE_SCROLL=$(grep -c 'SingleChildScrollView' "$FILE" 2>/dev/null || true)

SCREEN_TYPE="tab"
if [ "$HAS_PSL" -gt 0 ]; then
  SCREEN_TYPE="psl"
elif [ "$HAS_TOP_APP_BAR" -gt 0 ] || [ "$HAS_SLIVER_APP_BAR" -gt 0 ]; then
  SCREEN_TYPE="detail"
elif [ "$HAS_MODAL" -gt 0 ] && [ "$HAS_SAFE_AREA" -eq 0 ] && [ "$HAS_CUSTOM_SCROLL" -eq 0 ]; then
  SCREEN_TYPE="modal"
fi

REPORT="${REPORT}  INFO  Detected screen type: ${SCREEN_TYPE}\n"
check "Screen type detected ($SCREEN_TYPE)" 0 ""

scroll_issue=""
if [ "$HAS_NESTED_SCROLL" -gt 0 ] || [ "$HAS_CUSTOM_SCROLL" -gt 0 ] || [ "$HAS_LISTVIEW" -gt 0 ] || [ "$HAS_SINGLE_SCROLL" -gt 0 ] || [ "$HAS_PSL" -gt 0 ] || [ "$HAS_MODAL" -gt 0 ]; then
  :
else
  scroll_issue="No scroll container found"
fi
[ -z "$scroll_issue" ]
check "Scroll container" $? "$scroll_issue"

double_pad=$(grep -n 'padding:' "$FILE" 2>/dev/null | grep -E 'horizontal.*space16|space16.*horizontal' | head -5)
double_pad_count=$(echo "$double_pad" | grep -c '.' 2>/dev/null || true)
if [ "$double_pad_count" -gt 1 ]; then
  warn "No double padding" "Multiple horizontal space16 paddings found; verify they are not nested: $(echo "$double_pad" | head -2)"
else
  check "No double padding" 0 ""
fi

offgrid=$(grep -nE 'EdgeInsets' "$FILE" 2>/dev/null | grep -E '\b(5|7|9|10|11|13|14|15|17|18|19|20|22|25|26|28|30)\b' | head -5)
[ -z "$offgrid" ]
check "No off-grid EdgeInsets" $? "$(echo "$offgrid" | head -3)"

hardcoded_radius=$(grep -nE 'BorderRadius\.circular\([0-9]' "$FILE" 2>/dev/null | grep -v 'circular(2)' | grep -v 'circular(4)' | head -5)
[ -z "$hardcoded_radius" ]
check "No hardcoded BorderRadius" $? "$(echo "$hardcoded_radius" | head -3)"

hex_colors=$(grep -nE 'Color\(0x' "$FILE" 2>/dev/null | head -5)
raw_colors=$(grep -nE 'Colors\.' "$FILE" 2>/dev/null | grep -v 'Colors\.transparent' | head -5)
color_issues=""
[ -n "$hex_colors" ] && color_issues="${color_issues}Hex: ${hex_colors} "
[ -n "$raw_colors" ] && color_issues="${color_issues}Raw: ${raw_colors}"
[ -z "$color_issues" ]
check "No hardcoded colors" $? "$(echo "$color_issues" | head -3)"

safe_area_issue=""
if [ "$SCREEN_TYPE" = "detail" ] && [ "$HAS_SAFE_AREA" -gt 0 ]; then
  safe_area_issue="SafeArea found in detail screen with TopAppBar"
elif [ "$SCREEN_TYPE" = "psl" ] && [ "$HAS_SAFE_AREA" -gt 0 ]; then
  safe_area_issue="SafeArea found in PSL screen"
elif [ "$SCREEN_TYPE" = "tab" ] && [ "$HAS_SAFE_AREA" -eq 0 ] && [ "$HAS_PSL" -eq 0 ]; then
  safe_area_issue="Tab screen without SafeArea"
fi
[ -z "$safe_area_issue" ]
check "SafeArea correctness" $? "$safe_area_issue"

has_bottom_pad=$(grep -cE 'space32|bottom.*32' "$FILE" 2>/dev/null || true)
if [ "$SCREEN_TYPE" = "modal" ] || [ "$HAS_PSL" -gt 0 ] || [ "$HAS_ATOMIC_CHALLENGE_DETAIL" -gt 0 ] || [ "$has_bottom_pad" -gt 0 ]; then
  check "Bottom padding" 0 ""
else
  check "Bottom padding" 1 "No space32 bottom breathing room found"
fi

hardcoded_strings=$(grep -nE "Text\(\s*'" "$FILE" 2>/dev/null | grep -v 'AppLocalizations' | grep -v '// ignore-l10n' | head -5)
if [ -n "$hardcoded_strings" ]; then
  warn "Localization" "Hardcoded Text string literals: $(echo "$hardcoded_strings" | head -3)"
else
  check "Localization" 0 ""
fi

if [ "$HAS_PSL" -gt 0 ]; then
  has_nested_body=$(grep -c 'nestedBody' "$FILE" 2>/dev/null || true)
  if [ "$has_nested_body" -eq 0 ]; then
    surface_space16=$(grep -nE 'SliverPadding.*space16.*horizontal|horizontal.*space16' "$FILE" 2>/dev/null | head -3)
    if [ -n "$surface_space16" ]; then
      warn "PSL surface inset" "Found horizontal space16 in PSL surfaceSlivers; review against space24 convention"
    else
      check "PSL surface inset" 0 ""
    fi
  else
    check "PSL surface inset (nestedBody exempt)" 0 ""
  fi
else
  check "PSL surface inset (N/A)" 0 ""
fi

has_divider=$(grep -nE '\bDivider\b' "$FILE" 2>/dev/null | head -5)
has_listtile=$(grep -c 'ListTile' "$FILE" 2>/dev/null || true)
if [ -n "$has_divider" ] && [ "$has_listtile" -gt 0 ]; then
  check "No inter-item Dividers" 1 "Divider found alongside ListTiles: $(echo "$has_divider" | head -2)"
else
  check "No inter-item Dividers" 0 ""
fi

if [ "$HAS_CUSTOM_SCROLL" -gt 0 ]; then
  pad_in_sta=$(grep -B1 -A1 'SliverToBoxAdapter' "$FILE" 2>/dev/null | grep -c 'Padding' || true)
  [ "$pad_in_sta" -eq 0 ]
  check "SliverPadding usage" $? "Padding found inside SliverToBoxAdapter"
else
  check "SliverPadding usage (N/A)" 0 ""
fi

has_when=$(grep -c '\.when(' "$FILE" 2>/dev/null || true)
has_state_widgets=$(grep -c 'FullPageLoadingState\|FullPageErrorState\|EmptyState' "$FILE" 2>/dev/null || true)
if [ "$has_when" -gt 0 ] && [ "$has_state_widgets" -eq 0 ]; then
  warn "State handling" "Found .when() but no DS state widgets"
elif [ "$has_when" -eq 0 ]; then
  warn "State handling" "No .when() pattern found; verify loading/error/empty states manually"
else
  check "State handling" 0 ""
fi

small_targets=$(grep -nE 'height:.*(space24|space32|iconSmall|iconRegular|[0-3][0-9]\.0)|width:.*(space24|space32|iconSmall|iconRegular|[0-3][0-9]\.0)' "$FILE" 2>/dev/null | grep -vE 'SizedBox\(height:|SizedBox\(width:|SliverToBoxAdapter\(child: SizedBox' | head -5)
if [ -n "$small_targets" ]; then
  warn "Taste: 48dp tap targets" "Review interactive targets near: $(echo "$small_targets" | head -3)"
else
  check "Taste: 48dp tap targets" 0 ""
fi

if grep -qE 'TextField|TextFormField|Keyboard|MediaQuery\.viewInsets' "$FILE"; then
  if grep -q 'viewInsets' "$FILE"; then
    check "Taste: keyboard-safe CTAs" 0 ""
  else
    warn "Taste: keyboard-safe CTAs" "Inputs found; verify primary CTA is not keyboard-covered"
  fi
else
  check "Taste: keyboard-safe CTAs (N/A)" 0 ""
fi

if [ "$HAS_MODAL" -gt 0 ]; then
  if grep -qE 'Navigator\.pop|context\.pop|showCloseButton|CloseButton|IconButton' "$FILE"; then
    check "Taste: modal escape route" 0 ""
  else
    warn "Taste: modal escape route" "Modal/sheet detected; verify close or back route is visible"
  fi
else
  check "Taste: modal escape route (N/A)" 0 ""
fi

if grep -qE 'NavigationBar|BottomNav|NavigationDestination' "$FILE"; then
  if grep -qE 'label:|tooltip:' "$FILE"; then
    check "Taste: labeled nav icons" 0 ""
  else
    warn "Taste: labeled nav icons" "Navigation detected without obvious labels/tooltips"
  fi
else
  check "Taste: labeled nav icons (N/A)" 0 ""
fi

if grep -qE 'GestureDetector|InkWell|InkResponse' "$FILE"; then
  if grep -qE 'Semantics|tooltip:|label:' "$FILE"; then
    check "Taste: no gesture-only affordances" 0 ""
  else
    warn "Taste: no gesture-only affordances" "Gesture affordance found; verify semantic label and visible cue"
  fi
else
  check "Taste: no gesture-only affordances" 0 ""
fi

orientation_layout=$(grep -nE 'OrientationBuilder|MediaQuery\.orientationOf|MediaQuery\.of\(context\)\.orientation' "$FILE" 2>/dev/null | head -5)
if [ -n "$orientation_layout" ]; then
  warn "Layout: available-width decisions" "Orientation-based layout found; prefer LayoutBuilder/constraints: $(echo "$orientation_layout" | head -3)"
else
  check "Layout: available-width decisions" 0 ""
fi

eager_lists=$(grep -nE '\b(ListView|GridView)[[:space:]]*\(' "$FILE" 2>/dev/null | grep -vE '\.(builder|separated|custom)[[:space:]]*\(' | head -5)
if [ -n "$eager_lists" ]; then
  warn "Layout: lazy list builders" "Eager ListView/GridView found; verify item count is small and bounded: $(echo "$eager_lists" | head -3)"
else
  check "Layout: lazy list builders" 0 ""
fi

if [ "$HAS_LISTVIEW" -gt 0 ] || [ "$HAS_GRIDVIEW" -gt 0 ]; then
  if grep -qE 'Expanded|Flexible|Sliver|SizedBox|ConstrainedBox' "$FILE"; then
    check "Layout: scroll constraints" 0 ""
  else
    warn "Layout: scroll constraints" "Scrollable found without obvious bounding widget; review for unbounded viewport errors"
  fi
else
  check "Layout: scroll constraints (N/A)" 0 ""
fi

if grep -q 'IconButton' "$FILE"; then
  if grep -qE 'tooltip:|Semantics|semanticLabel' "$FILE"; then
    check "A11y: icon labels" 0 ""
  else
    warn "A11y: icon labels" "IconButton found without obvious tooltip or Semantics label"
  fi
else
  check "A11y: icon labels (N/A)" 0 ""
fi

if grep -qE '\bImage\.(asset|network|file|memory)[[:space:]]*\(' "$FILE"; then
  if grep -qE 'semanticLabel:|excludeFromSemantics: true|Semantics' "$FILE"; then
    check "A11y: image semantics" 0 ""
  else
    warn "A11y: image semantics" "Image widget found without obvious semanticLabel or decorative exclusion"
  fi
else
  check "A11y: image semantics (N/A)" 0 ""
fi

if grep -qE 'Dismissible|ReorderableListView|Draggable|LongPressDraggable' "$FILE"; then
  if grep -qE 'delete|Delete|remove|Remove|move|Move|IconButton|TextButton|FilledButton|OutlinedButton' "$FILE"; then
    check "A11y: drag alternatives" 0 ""
  else
    warn "A11y: drag alternatives" "Drag/swipe pattern found; verify same-screen non-drag alternative"
  fi
else
  check "A11y: drag alternatives (N/A)" 0 ""
fi

fixed_text=$(grep -nE 'height:[[:space:]]*([0-9]|[a-zA-Z_][a-zA-Z0-9_]*\.)|SizedBox[[:space:]]*\([^)]*height:' "$FILE" 2>/dev/null | grep -vE 'SizedBox\(height:[^,)]*\)[,;]?$|SliverToBoxAdapter\(child: SizedBox' | head -5)
if [ -n "$fixed_text" ] && grep -q '\bText[[:space:]]*(' "$FILE"; then
  warn "A11y: text scaling" "Fixed-height containers found near text-heavy screen; verify large text does not clip: $(echo "$fixed_text" | head -3)"
else
  check "A11y: text scaling" 0 ""
fi

motion_widgets=$(grep -nE 'AnimationController|AnimatedContainer|Hero[[:space:]]*\(|PageRouteBuilder|AnimatedSwitcher|AnimatedOpacity' "$FILE" 2>/dev/null | head -5)
if [ -n "$motion_widgets" ]; then
  if grep -q 'disableAnimations' "$FILE"; then
    check "A11y: reduced motion" 0 ""
  else
    warn "A11y: reduced motion" "Animation widgets found; verify MediaQuery.disableAnimations is respected: $(echo "$motion_widgets" | head -3)"
  fi
else
  check "A11y: reduced motion (N/A)" 0 ""
fi

ensure_ds_lints_deps
ds_lint_out="$(cd packages/ds_lints && dart run bin/lint.dart --file "$LINT_FILE" 2>&1)"
check "DS lints" $? "$(echo "$ds_lint_out" | head -10)"

echo "================================"
echo "SCREEN AUDIT: $FILE"
echo "================================"
printf "%b" "$REPORT"
echo "--------------------------------"
echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  echo "STATUS: ALL CHECKS PASSED"
elif [ "$FAIL" -eq 0 ]; then
  echo "STATUS: PASSED WITH WARNINGS (manual review needed)"
else
  echo "STATUS: FAILED"
fi
exit "$FAIL"
