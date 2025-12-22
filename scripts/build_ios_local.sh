#!/usr/bin/env bash
# Replicates the GitHub Actions iOS build steps locally.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USERNODE_DIR="${USERNODE_DIR:-"$ROOT_DIR/../usernode"}"
ENV_FILE="${ENV_FILE:-"$ROOT_DIR/.env"}"

BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
FLUTTER_NO_CODESIGN="${FLUTTER_NO_CODESIGN:-true}"
EXTRA_FLUTTER_ARGS=(${EXTRA_FLUTTER_ARGS:-})

cd "$ROOT_DIR"

echo "==> Checking required commands"
for cmd in brew flutter cargo rustup pkg-config; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing command: $cmd" >&2
    exit 1
  fi
done

if ! pkg-config --exists gmp mpfr; then
  echo "pkg-config could not locate gmp/mpfr. Run 'brew install gmp mpfr pkg-config gawk m4 texinfo' first." >&2
  exit 1
fi

if [[ ! -d "$USERNODE_DIR/crates/usernode" ]]; then
  echo "Cannot find ../usernode repository (expected at $USERNODE_DIR)." >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file $ENV_FILE not found. Create it or override ENV_FILE." >&2
  exit 1
fi

echo "==> Ensuring required Rust targets are installed"
for target in aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios; do
  if ! rustup target list --installed | grep -Fxq "$target"; then
    rustup target add "$target"
  fi
done

FRB_REV=$(grep -m1 'flutter_rust_bridge =' "$USERNODE_DIR/crates/usernode/Cargo.toml" | sed -E 's/.*rev = "([^"]+)".*/\1/')
if [[ -z "$FRB_REV" ]]; then
  echo "Unable to determine flutter_rust_bridge rev from usernode Cargo.toml" >&2
  exit 1
fi

if [[ "${FORCE_INSTALL_FRB:-0}" == "1" ]] || ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo "==> Installing flutter_rust_bridge_codegen (rev $FRB_REV)"
  cargo install flutter_rust_bridge_codegen \
    --git https://github.com/Usernode-Labs/flutter_rust_bridge \
    --rev "$FRB_REV" \
    --locked
else
  echo "==> flutter_rust_bridge_codegen already installed"
fi

if [[ -z "$BUILD_NAME" ]]; then
  if [[ -f android/local.properties ]] && grep -q '^flutter.versionName=' android/local.properties; then
    BUILD_NAME=$(grep '^flutter.versionName=' android/local.properties | head -n1 | cut -d'=' -f2)
  else
    BUILD_NAME="0.0.0"
  fi
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  if [[ -f android/local.properties ]] && grep -q '^flutter.versionCode=' android/local.properties; then
    BUILD_NUMBER=$(grep '^flutter.versionCode=' android/local.properties | head -n1 | cut -d'=' -f2)
  else
    BUILD_NUMBER="1"
  fi
fi

echo "==> Running flutter pub get"
flutter pub get

echo "==> Generating flutter_rust_bridge bindings"
export GMP_MPFR_SYS_USE_PKG_CONFIG=1
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export PATH="/opt/homebrew/opt/texinfo/bin:$HOME/.cargo/bin:$PATH"
flutter_rust_bridge_codegen generate

echo "==> Installing CocoaPods dependencies"
(cd ios && pod install)

echo "==> Building iOS app"
BUILD_CMD=(
  flutter build ios
  --release
  --build-name "$BUILD_NAME"
  --build-number "$BUILD_NUMBER"
  --dart-define-from-file "$ENV_FILE"
)

if [[ "$FLUTTER_NO_CODESIGN" == "true" ]]; then
  BUILD_CMD+=(--no-codesign)
fi

BUILD_CMD+=("${EXTRA_FLUTTER_ARGS[@]}")

echo "Running: ${BUILD_CMD[*]}"
"${BUILD_CMD[@]}"

echo "✅ iOS build complete"
