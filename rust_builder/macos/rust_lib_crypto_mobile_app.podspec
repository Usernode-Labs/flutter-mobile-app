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
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.frameworks = ['SystemConfiguration', 'Security', 'CFNetwork']

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    # First argument is relative path to the `rust` folder, second is name of rust library
    :script => <<-BASH,
sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../../usernode/crates/usernode usernode
# Xcode links against librust_lib_crypto_mobile_app.a by convention; provide a symlink
ln -sf "${BUILT_PRODUCTS_DIR}/libusernode.a" "${BUILT_PRODUCTS_DIR}/librust_lib_crypto_mobile_app.a"
BASH
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    # Let XCode know that the static library referenced in -force_load below is
    # created by this build step.
    :output_files => ["${BUILT_PRODUCTS_DIR}/libusernode.a"],
  }
    # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '$(inherited) -lc++ -force_load ${BUILT_PRODUCTS_DIR}/libusernode.a',
    'IPHONEOS_DEPLOYMENT_TARGET' => '12.0'
  }
end
