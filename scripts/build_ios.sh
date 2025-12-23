#!/usr/bin/env bash

set -euo pipefail

# Local helper aligned with the CI "Build and Deploy" iOS steps.
# - Uses the same version/build handling via scripts/version_manager.sh
# - Ensures bindgen sees the iOS SDK (fixes uint16_t/uint32_t errors)
# - Prompts for a target device and runs flutter run -d <device> --verbose

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: build_ios.sh [options]

Options:
  --env-file PATH           Path to .env file (default: .env in repo root if present)
  --help                    Show this help

Environment variables:
  DEBUG_LOGS=true           (kept for compatibility; --verbose is always passed)

Notes:
  - Requires Xcode CLT + full Xcode installed and selected (xcode-select -p).
  - Expects Rust crate at ./rust or symlink to ../usernode/crates/usernode (created automatically if present).
EOF
}

ENV_FILE=".env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[error] Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# Force NONPROD locally (matches CI when not on main).
ENV_TYPE="NONPROD"
echo "[info] Environment type: $ENV_TYPE"

# Ensure expected Rust crate path exists (aligns with CI where ../usernode exists).
if [[ ! -f "$ROOT_DIR/rust/Cargo.toml" && -f "$ROOT_DIR/../usernode/crates/usernode/Cargo.toml" ]]; then
  echo "[info] Creating symlink rust -> ../usernode/crates/usernode"
  ln -snf ../usernode/crates/usernode "$ROOT_DIR/rust"
fi

# .env at repo root by default; fail if missing.
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[error] Env file not found at $ENV_FILE. Create it or pass --env-file." >&2
  exit 1
fi

# Configure bindgen/clang to see the iOS SDK (fixes missing stdint types locally).
SDK_DEVICE=$(xcrun --sdk iphoneos --show-sdk-path)
SDK_SIM=$(xcrun --sdk iphonesimulator --show-sdk-path)
export BINDGEN_EXTRA_CLANG_ARGS="--target=arm64-apple-ios -isysroot $SDK_DEVICE -miphoneos-version-min=14.0"
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim="--target=arm64-apple-ios-simulator -isysroot $SDK_SIM -mios-simulator-version-min=14.0"
unset BINDGEN_EXTRA_CLANG_ARGS_x86_64_apple_ios || true
export PKG_CONFIG_ALLOW_CROSS=1

# CMake compatibility (plog/libjuice/usrsctp expect policy minimum >=3.5).
export CMAKE_POLICY_VERSION_MINIMUM=3.5

# Prefer Xcode clang to avoid Homebrew LLVM picking up the wrong SDK.
export CC="$(xcrun --sdk iphoneos --find clang)"
export CXX="$(xcrun --sdk iphoneos --find clang++)"

# Signing hints pulled from ios/Runner.xcodeproj/project.pbxproj (Debug config).
export DEVELOPMENT_TEAM="785Y2C9VG2"
export CODE_SIGN_IDENTITY="Apple Development"
export CODE_SIGN_STYLE="Manual"
export PROVISIONING_PROFILE_SPECIFIER="mobile-apps Development"

# Version/build handling (same script as CI). Use pubspec.yaml values.
chmod +x scripts/version_manager.sh
BUILD_NUMBER=$(scripts/version_manager.sh get-build production)
BUILD_NAME=$(scripts/version_manager.sh get production)
echo "[info] Build name: $BUILD_NAME | Build number: $BUILD_NUMBER"

echo "[step] flutter pub get"
flutter pub get

echo "[step] pod install"
pushd ios >/dev/null
pod install
popd >/dev/null

echo "[info] Available Flutter devices:"
flutter devices

read -rp "Enter device ID to deploy to: " DEVICE_ID
if [[ -z "$DEVICE_ID" ]]; then
  echo "[error] No device ID provided." >&2
  exit 1
fi

FLUTTER_CMD=(
  flutter run
  -d "$DEVICE_ID"
  --debug
  --verbose
  --dart-define-from-file="$ENV_FILE"
)

echo "[run] ${FLUTTER_CMD[*]}"
"${FLUTTER_CMD[@]}"

echo "[ok] iOS run finished."
