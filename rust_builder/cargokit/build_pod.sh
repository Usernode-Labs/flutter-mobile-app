#!/bin/sh
set -e

BASEDIR=$(dirname "$0")

# Workaround for https://github.com/dart-lang/pub/issues/4010
BASEDIR=$(cd "$BASEDIR" ; pwd -P)

# Remove XCode SDK from path. Otherwise this breaks tool compilation when building iOS project
NEW_PATH=`echo $PATH | tr ":" "\n" | grep -v "Contents/Developer/" | tr "\n" ":"`

export PATH=${NEW_PATH%?} # remove trailing :

# Some Xcode-provided TMPDIR values occasionally point to cleaned-up paths; force
# a stable temp root so rustc/cargo can create files reliably.
export TMPDIR="${TARGET_TEMP_DIR:-/tmp/cargokit-tmp}"
mkdir -p "$TMPDIR"
echo "cargokit build_pod TMPDIR=$TMPDIR" >&2

# Common paths for dependency patching
CARGO_HOME_PATH=${CARGO_HOME:-$HOME/.cargo}
REGISTRY_SRC="$CARGO_HOME_PATH/registry/src"

env

# Ensure libclang is discoverable for bindgen; prefer existing value if valid
if [ -z "${LIBCLANG_PATH:-}" ] || [ ! -f "${LIBCLANG_PATH}/libclang.dylib" ]; then
  DEV_DIR="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}"
  XCODE_LIB="${DEV_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/lib"
  if [ -n "$DEV_DIR" ] && [ -f "${XCODE_LIB}/libclang.dylib" ]; then
    export LIBCLANG_PATH="$XCODE_LIB"
  fi
fi

# Platform name (macosx, iphoneos, iphonesimulator)
export CARGOKIT_DARWIN_PLATFORM_NAME=$PLATFORM_NAME

# Active architectures (arm64, x86_64), space separated.
export CARGOKIT_DARWIN_ARCHS=$ARCHS

# Current build configuration (Debug, Release)
export CARGOKIT_CONFIGURATION=$CONFIGURATION

# Path to directory containing Cargo.toml. Support both absolute and relative inputs.
case "$1" in
  /*) export CARGOKIT_MANIFEST_DIR="$1" ;;
  *) export CARGOKIT_MANIFEST_DIR="$PODS_TARGET_SRCROOT/$1" ;;
esac

# Temporary directory for build artifacts.
export CARGOKIT_TARGET_TEMP_DIR=$TARGET_TEMP_DIR

# Output directory for final artifacts.
export CARGOKIT_OUTPUT_DIR=$PODS_CONFIGURATION_BUILD_DIR/$PRODUCT_NAME

# Directory to store built tool artifacts.
export CARGOKIT_TOOL_TEMP_DIR=$TARGET_TEMP_DIR/build_tool

# Workaround bindgen/Clang target triple for iOS Simulator on arm64.
# Rust target uses aarch64-apple-ios-sim, but Clang expects arm64-apple-ios-simulator.
# Use per-target env var so it only affects this target.
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim="--target=arm64-apple-ios-simulator"

# Directory inside root project. Not necessarily the top level directory of root project.
export CARGOKIT_ROOT_PROJECT_DIR=$SRCROOT

# Avoid leaking the simulator SDK into host builds run by native build scripts.
unset SDKROOT
MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
export CC_FOR_BUILD="$(xcrun --sdk macosx --find clang) -target arm64-apple-macosx${MACOS_MAJOR}.0 -isysroot $(xcrun --sdk macosx --show-sdk-path)"
export CFLAGS_FOR_BUILD=""
export CPPFLAGS_FOR_BUILD=""
export AR_FOR_BUILD="$(xcrun --sdk macosx --find ar)"

# Configure target-specific toolchains for iOS
if [[ "$PLATFORM_NAME" == "iphonesimulator" ]]; then
  export CC="$(xcrun --sdk iphonesimulator --find clang) -target arm64-apple-ios-simulator -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path) -mios-simulator-version-min=14.0 -fPIC"
  export AR="$(xcrun --sdk iphonesimulator --find ar)"
elif [[ "$PLATFORM_NAME" == "iphoneos" ]]; then
  export CC="$(xcrun --sdk iphoneos --find clang) -target arm64-apple-ios -isysroot $(xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=14.0 -fPIC"
  export AR="$(xcrun --sdk iphoneos --find ar)"
fi

# Ensure nm from the correct SDK is used for cross builds
if [[ "$PLATFORM_NAME" == "iphoneos" ]]; then
  export NM="$(xcrun --sdk iphoneos --find nm)"
elif [[ "$PLATFORM_NAME" == "iphonesimulator" ]]; then
  export NM="$(xcrun --sdk iphonesimulator --find nm)"
fi

FLUTTER_EXPORT_BUILD_ENVIRONMENT=(
  "$PODS_ROOT/../Flutter/ephemeral/flutter_export_environment.sh" # macOS
  "$PODS_ROOT/../Flutter/flutter_export_environment.sh" # iOS
)

for path in "${FLUTTER_EXPORT_BUILD_ENVIRONMENT[@]}"
do
  if [[ -f "$path" ]]; then
    source "$path"
  fi
done

sh "$BASEDIR/run_build_tool.sh" build-pod "$@"

# Make a symlink from built framework to phony file, which will be used as input to
# build script. This should force rebuild (podspec currently doesn't support alwaysOutOfDate
# attribute on custom build phase)
ln -fs "$OBJROOT/XCBuildData/build.db" "${BUILT_PRODUCTS_DIR}/cargokit_phony"
ln -fs "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}" "${BUILT_PRODUCTS_DIR}/cargokit_phony_out"
