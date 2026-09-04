#!/usr/bin/env bash

set -euo pipefail

readonly ANDROID_APPLICATION_ID="com.usernode_labs.usernode"
readonly IOS_BUNDLE_ID="org.usernode.app"
readonly ANDROID_MAPPING="build/app/outputs/mapping/release/mapping.txt"
readonly ANDROID_NATIVE_SYMBOLS="build/app/outputs/native-debug-symbols/release/native-debug-symbols.zip"
readonly IOS_DSYMS="build/ios/archive/Runner.xcarchive/dSYMs"

fail() {
  echo "Sentry symbol upload: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  local description="$2"
  [[ -s "$path" ]] || fail "$description is missing or empty at $path"
}

require_dsym() {
  local name="$1"
  local bundle="$IOS_DSYMS/$name"
  local dwarf_dir="$bundle/Contents/Resources/DWARF"
  local dwarf
  local found=false

  [[ -d "$bundle" ]] || fail "$name is missing at $bundle"
  [[ -d "$dwarf_dir" ]] || fail "$name has no DWARF directory at $dwarf_dir"

  shopt -s nullglob
  for dwarf in "$dwarf_dir"/*; do
    if [[ -f "$dwarf" && -s "$dwarf" ]]; then
      found=true
      break
    fi
  done
  shopt -u nullglob

  [[ "$found" == true ]] || fail "$name contains no non-empty DWARF debug file"
}

require_sentry_environment() {
  local name
  local missing=()
  for name in SENTRY_AUTH_TOKEN SENTRY_ORG SENTRY_PROJECT; do
    if [[ -z "${!name:-}" ]]; then
      missing+=("$name")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    fail "missing required environment: ${missing[*]}"
  fi
}

validate_android_symbols() {
  local symbols_dir="$1"
  local symbol
  local dart_symbol_found=false
  local rust_symbol_found=false
  local native_entries

  [[ -d "$symbols_dir" ]] || fail "Flutter split-debug-info directory is missing at $symbols_dir"

  shopt -s nullglob
  for symbol in "$symbols_dir"/app.*.symbols; do
    if [[ -f "$symbol" && -s "$symbol" ]]; then
      dart_symbol_found=true
      break
    fi
  done
  shopt -u nullglob
  [[ "$dart_symbol_found" == true ]] ||
    fail "no non-empty app.*.symbols file found in $symbols_dir"

  require_file "$ANDROID_MAPPING" "Android R8 mapping"
  require_file "$ANDROID_NATIVE_SYMBOLS" "Android native debug-symbol archive"

  native_entries="$(unzip -Z1 "$ANDROID_NATIVE_SYMBOLS")"
  [[ "$native_entries" == *"arm64-v8a/libusernode.so.dbg"* ]] ||
    fail "$ANDROID_NATIVE_SYMBOLS does not contain the arm64 Rust debug companion"

  while IFS= read -r symbol; do
    if [[ -s "$symbol" ]]; then
      rust_symbol_found=true
      break
    fi
  done < <(find build/app/intermediates -type f -name 'libusernode.so.dbg' -path '*/release/*' -print)
  [[ "$rust_symbol_found" == true ]] ||
    fail "no non-empty release libusernode.so.dbg found under build/app/intermediates"
}

validate_ios_symbols() {
  [[ -d "$IOS_DSYMS" ]] || fail "iOS archive dSYMs are missing at $IOS_DSYMS"
  require_dsym "Runner.app.dSYM"
  require_dsym "App.framework.dSYM"
  require_dsym "Flutter.framework.dSYM"
  require_dsym "rust_lib_crypto_mobile_app.framework.dSYM"
}

if (( $# < 3 || $# > 4 )); then
  fail "usage: $0 <android|ios> <version> <build-number> [android-symbols-directory]"
fi

readonly platform="$1"
readonly version="$2"
readonly build_number="$3"

[[ -n "$version" ]] || fail "version must not be empty"
[[ "$version" != *"+"* ]] || fail "version must not include a build number: $version"
[[ "$build_number" =~ ^[0-9]+$ ]] || fail "build number must be numeric: $build_number"

require_sentry_environment

case "$platform" in
  android)
    (( $# == 4 )) || fail "Android upload requires the split-debug-info directory"
    readonly symbols_path="$4"
    readonly package_id="$ANDROID_APPLICATION_ID"
    validate_android_symbols "$symbols_path"
    ;;
  ios)
    (( $# == 3 )) || fail "iOS upload does not accept an Android symbols directory"
    readonly symbols_path="$IOS_DSYMS"
    readonly package_id="$IOS_BUNDLE_ID"
    validate_ios_symbols
    ;;
  *)
    fail "unsupported platform: $platform"
    ;;
esac

export SENTRY_RELEASE="${package_id}@${version}+${build_number}"
export SENTRY_DIST="$build_number"

echo "Uploading $platform debug files for release $SENTRY_RELEASE (dist $SENTRY_DIST)"
dart run sentry_dart_plugin \
  "--sentry-define=symbols_path=$symbols_path"
