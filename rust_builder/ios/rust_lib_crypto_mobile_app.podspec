#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint rust_lib_crypto_mobile_app.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'rust_lib_crypto_mobile_app'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  # s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.ios.deployment_target = '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # Link C++ stdlib, include the built Rust static lib, and keep the
    # FRB marker symbol so it is linked without all-load.
    'OTHER_LDFLAGS' => '$(inherited) -lc++ ${BUILT_PRODUCTS_DIR}/libusernode.a -Wl,-u,_frb_get_rust_content_hash',
    'IPHONEOS_DEPLOYMENT_TARGET' => '14.0'
  }
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    # Build the Rust static library for the `usernode` crate, then symlink it
    # to the pod's expected product name so Xcode links it normally.
    :script => <<-BASH,
set -euo pipefail 2>/dev/null || set -eu

PROJECT_ROOT="$(cd "$PODS_ROOT/../.." && pwd -P)"

resolve_candidate() {
  if [ -d "$1" ] && [ -f "$1/Cargo.toml" ]; then
    RUST_CRATE_DIR="$1"
  fi
}

if [ -n "${USERNODE_CRATE_DIR:-}" ]; then
  resolve_candidate "$USERNODE_CRATE_DIR"
fi

if [ -z "${RUST_CRATE_DIR:-}" ]; then
  resolve_candidate "$PROJECT_ROOT/../usernode/crates/usernode"
fi

if [ -z "${RUST_CRATE_DIR:-}" ]; then
  resolve_candidate "$PROJECT_ROOT/rust"
fi

if [ -z "${RUST_CRATE_DIR:-}" ]; then
  cat >&2 <<EOF
[rust_lib_crypto_mobile_app] Could not locate the usernode Rust crate.
Checked:
  - USERNODE_CRATE_DIR=${USERNODE_CRATE_DIR:-"(not set)"}
  - $PROJECT_ROOT/../usernode/crates/usernode
  - $PROJECT_ROOT/rust
Ensure the usernode repository exists next to flutter-mobile-app or set USERNODE_CRATE_DIR to the crate path.
EOF
  exit 1
fi

echo "[rust_lib_crypto_mobile_app] Building Rust crate at: $RUST_CRATE_DIR"
sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" "$RUST_CRATE_DIR" usernode
# Ensure the pod product name resolves to the built Rust library
ln -sf "${BUILT_PRODUCTS_DIR}/libusernode.a" "${BUILT_PRODUCTS_DIR}/librust_lib_crypto_mobile_app.a"
BASH
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libusernode.a", "${BUILT_PRODUCTS_DIR}/librust_lib_crypto_mobile_app.a"],
  }
end
