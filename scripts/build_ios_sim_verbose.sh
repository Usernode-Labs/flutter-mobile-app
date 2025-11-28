#!/usr/bin/env bash

# Build the Flutter iOS app for Simulator (arm64) without running it,
# with a toolchain configured for Rust bindgen and verbose output.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd -P)"
cd "$ROOT_DIR"

echo "[info] Project root: $ROOT_DIR"

# Prefer Homebrew LLVM for libclang
if command -v brew >/dev/null 2>&1; then
  BREW_LLVM="$(brew --prefix llvm 2>/dev/null || true)"
  if [[ -d "$BREW_LLVM" && -f "$BREW_LLVM/lib/libclang.dylib" ]]; then
    LLVM_PREFIX="$BREW_LLVM"
  fi
fi

if [[ -z "${LLVM_PREFIX:-}" ]]; then
  # Common Homebrew locations if `brew --prefix llvm` fails or llvm is not installed
  for p in /opt/homebrew/opt/llvm /usr/local/opt/llvm; do
    if [[ -d "$p" && -f "$p/lib/libclang.dylib" ]]; then
      LLVM_PREFIX="$p"
      break
    fi
  done
fi

if [[ -n "${LLVM_PREFIX:-}" ]]; then
  export LIBCLANG_PATH="$LLVM_PREFIX/lib"
  export PATH="$LLVM_PREFIX/bin:$PATH"
  echo "[info] Using LLVM at: $LLVM_PREFIX"
else
  XCODE_DEV="$(xcode-select -p 2>/dev/null || true)"
  XCODE_LIB="$XCODE_DEV/Toolchains/XcodeDefault.xctoolchain/usr/lib"
  if [[ -n "$XCODE_DEV" && -f "$XCODE_LIB/libclang.dylib" ]]; then
    export LIBCLANG_PATH="$XCODE_LIB"
    echo "[info] Using Xcode libclang at: $LIBCLANG_PATH"
  else
    echo "[warn] libclang not found; proceeding without overriding clang/libclang."
  fi
fi

# iOS Simulator SDK and compilers
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
export CC="$(xcrun --sdk iphonesimulator --find clang)"
export CXX="$(xcrun --sdk iphonesimulator --find clang++)"
export CFLAGS="-isysroot $SDK -mios-simulator-version-min=13.0"
export CXXFLAGS="$CFLAGS"

# Bindgen: force valid arm64 simulator target and include paths
export BINDGEN_EXTRA_CLANG_ARGS="-target arm64-apple-ios-simulator -isysroot $SDK -mios-simulator-version-min=13.0"
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim="$BINDGEN_EXTRA_CLANG_ARGS"
unset BINDGEN_EXTRA_CLANG_ARGS_x86_64_apple_ios || true

# Helpful for cross builds through pkg-config
export PKG_CONFIG_ALLOW_CROSS=1

# More explicit link diagnostics from Rust
export RUSTFLAGS="-C link-arg=-lc++ -C link-arg=-Wl,-v"

# Verbose logs from the Cargokit build step
export CARGOKIT_VERBOSE=1

echo "[info] CC:   $CC"
echo "[info] CXX:  $CXX"
echo "[info] SDK:  $SDK"

# Ensure expected Rust crate path exists (create symlink if sibling repo is present)
if [[ ! -f "$ROOT_DIR/rust/Cargo.toml" ]]; then
  if [[ -f "$ROOT_DIR/../usernode/crates/usernode/Cargo.toml" ]]; then
    echo "[info] Creating symlink: rust -> ../usernode/crates/usernode"
    ln -snf ../usernode/crates/usernode "$ROOT_DIR/rust"
  else
    echo "[warn] rust/Cargo.toml not found and ../usernode/crates/usernode missing; continuing anyway."
  fi
fi

echo "[step] flutter clean"
flutter clean || true

echo "[step] flutter pub get"
flutter pub get

if [[ -z "${SKIP_POD_INSTALL:-}" ]]; then
  echo "[step] pod install (ios)"
  pushd ios >/dev/null
  pod install --repo-update
  popd >/dev/null
else
  echo "[info] SKIP_POD_INSTALL is set; skipping pod install"
fi

echo "[build] flutter build ios --simulator --debug -v"
# Do not use `set -e`; we want to return the Flutter build exit code without hiding logs
set +e
flutter build ios --simulator --debug -v
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "[error] Build failed with exit code $status"
else
  echo "[ok] Build completed successfully"
fi

exit $status
