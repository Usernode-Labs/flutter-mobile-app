# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "rust_lib_crypto_mobile_app")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")

set(RUST_CRATE_DIR "../rust")
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${RUST_CRATE_DIR}/Cargo.toml")
  message(FATAL_ERROR
    "[rust_lib_crypto_mobile_app] Could not locate desktop placeholder crate.")
endif()

message(RUST_CRATE_DIR="${RUST_CRATE_DIR}")
apply_cargokit(${PROJECT_NAME} ${RUST_CRATE_DIR} rust_lib_crypto_mobile_app "")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(rust_lib_crypto_mobile_app_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
