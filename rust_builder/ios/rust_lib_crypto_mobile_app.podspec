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
    'IPHONEOS_DEPLOYMENT_TARGET' => '12.0'
  }
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    # Build the Rust static library for the `usernode` crate, then symlink it
    # to the pod's expected product name so Xcode links it normally.
    :script => <<-BASH,
sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../../usernode/crates/usernode usernode
# Ensure the pod product name resolves to the built Rust library
ln -sf "${BUILT_PRODUCTS_DIR}/libusernode.a" "${BUILT_PRODUCTS_DIR}/librust_lib_crypto_mobile_app.a"
BASH
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libusernode.a", "${BUILT_PRODUCTS_DIR}/librust_lib_crypto_mobile_app.a"],
  }
end
