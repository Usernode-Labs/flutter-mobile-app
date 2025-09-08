#!/bin/bash
set -euo pipefail

echo "==> Step 1: Add Rust target for iOS simulator"
rustup target add aarch64-apple-ios-sim

echo "==> Step 2: Set compilers to Xcode's clang/clang++"
export CC_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator -f clang)"
export CXX_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator -f clang++)"

echo "==> Step 3: Configure SDKROOT and flags"
export SDKROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)"
export CFLAGS_aarch64_apple_ios_sim="--sysroot=$SDKROOT"
export CXXFLAGS_aarch64_apple_ios_sim="--sysroot=$SDKROOT -stdlib=libc++ -std=c++17"
export RUSTFLAGS="-C link-arg=-stdlib=libc++"

echo "==> Step 4: Fix bindgen target triple and libclang path"
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim="-target arm64-apple-ios-simulator -isysroot $SDKROOT -I$SDKROOT/usr/include/c++/v1"
export LIBCLANG_PATH="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib"

echo "==> Step 5: Clean previous builds"
cargo clean
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Intermediates.noindex/Pods.build/Debug-iphonesimulator
cd ios && pod deintegrate && pod install && cd ..

echo "==> Step 6: Rebuild"
# Uncomment one of the following depending on your workflow:
flutter run
# cargo build -p usernode --target aarch64-apple-ios-sim

echo "==> Done."

