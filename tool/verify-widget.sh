#!/usr/bin/env bash
set -u

usage() {
  echo "Usage: bash tool/verify-widget.sh <WidgetName|--all>"
}

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$ROOT" ]; then
  echo "Unable to locate git repository root" >&2
  exit 1
fi
cd "$ROOT"

PUBLIC_HELPER_EXEMPTIONS="nav_indicator_shapes paint_helpers"
LEGACY_M3_CONTAINER_ALLOWED="block_production_status_card bottom_nav button challenge_card challenge_detail_page challenge_event_group dapp_card dropdown_sheet epoch_performance_page slot_assignments_page zk_identity_flow_page"

pascal_to_snake() {
  case "$1" in
    DSTextField) echo "text_field" ;;
    *) echo "$1" | perl -pe 's/([A-Z])/_\l$1/g; s/^_//' ;;
  esac
}

snake_to_pascal() {
  case "$1" in
    text_field) echo "DSTextField" ;;
    *) echo "$1" | perl -pe 's/(^|_)(.)/uc($2)/ge' ;;
  esac
}

is_exempt() {
  local snake="$1"
  for item in $PUBLIC_HELPER_EXEMPTIONS; do
    [ "$snake" = "$item" ] && return 0
  done
  return 1
}

is_legacy_m3_allowed() {
  local snake="$1"
  for item in $LEGACY_M3_CONTAINER_ALLOWED; do
    [ "$snake" = "$item" ] && return 0
  done
  return 1
}

widgetbook_use_case_for() {
  local snake="$1"
  case "$snake" in
    shimmer_block|shimmer_card_skeleton|shimmer_list_tile)
      echo "lib/design_system/widgetbook/shimmer_use_case.dart"
      ;;
    *)
      echo "lib/design_system/widgetbook/${snake}_use_case.dart"
      ;;
  esac
}

ensure_ds_lints_deps() {
  if [ ! -f packages/ds_lints/.dart_tool/package_config.json ]; then
    (cd packages/ds_lints && dart pub get >/dev/null)
  fi
}

verify_one() {
  local widget_name="$1"
  local snake
  snake="$(pascal_to_snake "$widget_name")"
  local src="lib/design_system/src/${snake}.dart"
  local test_file="test/design_system/${snake}_test.dart"
  local use_case
  use_case="$(widgetbook_use_case_for "$snake")"
  local barrel="lib/design_system/design_system.dart"
  local genesis="lib/design_system/.specs/${widget_name}.genesis.md"
  local catalog="lib/design_system/DESIGN_SYSTEM.md"

  local pass=0
  local fail=0
  local warn=0
  local report=""

  check() {
    local name="$1"
    local result="$2"
    local detail="${3:-}"
    if [ "$result" -eq 0 ]; then
      report="${report}  PASS  ${name}\n"
      pass=$((pass + 1))
    else
      report="${report}  FAIL  ${name} -- ${detail}\n"
      fail=$((fail + 1))
    fi
  }

  note_warn() {
    local name="$1"
    local detail="$2"
    report="${report}  WARN  ${name} -- ${detail}\n"
    warn=$((warn + 1))
  }

  if is_exempt "$snake"; then
    echo "================================"
    echo "VERIFY: $widget_name"
    echo "================================"
    echo "  SKIP  Public helper exemption ($snake)"
    echo "STATUS: SKIPPED"
    return 0
  fi

  [ -f "$src" ]
  check "Source file" $? "Missing $src"
  if [ ! -f "$src" ]; then
    echo "================================"
    echo "VERIFY: $widget_name"
    echo "================================"
    printf "%b" "$report"
    echo "STATUS: FAILED"
    return "$fail"
  fi

  if [ -f "$test_file" ]; then
    fmt_out="$(dart format --output=none --set-exit-if-changed "$src" "$test_file" 2>&1)"
    check "Format" $? "$fmt_out"

    analyze_out="$(flutter analyze --no-pub "$src" "$test_file" 2>&1)"
    check "Analyze" $? "$(echo "$analyze_out" | tail -20)"

    test_out="$(flutter test --no-pub "$test_file" 2>&1)"
    check "Widget test" $? "$(echo "$test_out" | tail -20)"
  else
    fmt_out="$(dart format --output=none --set-exit-if-changed "$src" 2>&1)"
    check "Format" $? "$fmt_out"
    note_warn "Widget test" "No focused test found: $test_file"
  fi

  hardcoded="$(grep -nE '\b(Color\(0x|Colors\.|EdgeInsets\.(all|symmetric|only)\([0-9]|BorderRadius\.circular\([0-9])' "$src" 2>/dev/null | grep -vE '^[0-9]+:\s*//|Colors\.transparent' | head -5)"
  if [ "$snake" = "dapp_avatar" ]; then
    hardcoded="$(echo "$hardcoded" | grep -vE 'Colors\.(black|white)' || true)"
  fi
  [ -z "$hardcoded" ]
  check "No hardcoded values" $? "$(echo "$hardcoded" | head -3)"

  if is_legacy_m3_allowed "$snake"; then
    banned=""
  else
    banned="$(grep -nE '\b(ElevatedButton|OutlinedButton|TextButton|FloatingActionButton|Card|ListTile|Scaffold|AppBar|NavigationBar|BottomNavigationBar|CupertinoButton|CupertinoNavigationBar)[[:space:]]*\(' "$src" 2>/dev/null | head -5)"
    banned="$(printf "%s\n" "$banned"; grep -nE '\bFilledButton\b' "$src" 2>/dev/null | head -5)"
  fi
  [ -z "$banned" ]
  check "No banned M3 wrappers" $? "$(echo "$banned" | head -3)"

  grep -q "src/${snake}.dart" "$barrel" 2>/dev/null
  check "Barrel export" $? "Not found in $barrel"

  if [ -f "$genesis" ]; then
    grep -qi 'inspiration\|source\|reference\|purpose\|what' "$genesis" && grep -qi 'decision\|decisions\|why\|architecture\|strategy\|migration' "$genesis"
    check "Genesis doc" $? "Missing source/purpose or decision/rationale section"
  else
    check "Genesis doc" 1 "Missing $genesis"
  fi

  grep -q "\`$widget_name\`" "$catalog" 2>/dev/null
  check "Widget catalog" $? "No catalog row for $widget_name"

  [ -f "$use_case" ]
  check "Widgetbook use case" $? "Missing $use_case"

  ensure_ds_lints_deps
  ds_lint_out="$(cd packages/ds_lints && dart run bin/lint.dart --file "$ROOT/$src" 2>&1)"
  check "DS lints" $? "$(echo "$ds_lint_out" | head -10)"

  echo "================================"
  echo "VERIFY: $widget_name"
  echo "================================"
  printf "%b" "$report"
  echo "--------------------------------"
  echo "Result: $pass passed, $fail failed, $warn warnings"
  if [ "$fail" -eq 0 ]; then
    echo "STATUS: ALL BLOCKING CHECKS PASSED"
  else
    echo "STATUS: FAILED"
  fi
  return "$fail"
}

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

if [ "$1" = "--all" ]; then
  total_fail=0
  while IFS= read -r export_path; do
    snake="$(basename "$export_path" .dart)"
    widget="$(snake_to_pascal "$snake")"
    verify_one "$widget"
    total_fail=$((total_fail + $?))
  done < <(grep -E "^export 'src/.+\.dart';" lib/design_system/design_system.dart | sed "s#export 'src/##; s#';##" | sort)
  exit "$total_fail"
fi

verify_one "$1"
exit $?
