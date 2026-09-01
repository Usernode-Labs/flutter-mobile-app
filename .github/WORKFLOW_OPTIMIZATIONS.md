# Mobile build workflow performance

This document describes the current performance strategy for
`build-and-deploy.yml`, `manual-build.yml`, and their shared
`prepare-frb-bindings.yml` workflow.

## Baseline

The September 2026 audit found:

- 74 successful Build and Deploy runs had a median wall time of about 38
  minutes.
- A representative 45-minute run compiled the iOS app twice: roughly 14
  minutes in `flutter build ios --no-codesign`, followed by another roughly 14
  minutes in Fastlane's `build_app` before upload.
- An FRB binding cache hit took seconds to restore, but first waited more than
  five minutes for the scarce 16-core Linux runner.
- The app's native Rust compilation uses Cargokit's build directories, not
  `../usernode/target`, so caching the latter in the platform build jobs did
  not preserve the expensive Android or iOS object files.

## Implemented optimizations

### Build the iOS archive once

The workflows now run `flutter build ipa` with the checked-in
`ios/ExportOptions.plist`. Fastlane's `upload_existing_ipa` lane only uploads
that result to TestFlight. The regular Fastlane `release` lane remains
available for callers that want Fastlane to perform both operations.

This removes an entire Xcode archive from the critical path while preserving
the existing app identifiers, signing profiles, build number, Dart defines,
and TestFlight upload behavior.

### Put cache hits on readily available runners

`prepare-frb-bindings.yml` resolves and restores bindings on `ubuntu-latest`.
Only a cache miss requests the 16-core runner. The generator checks the cache
again after acquiring its concurrency lock, which prevents two simultaneous
misses for the same fingerprint from doing duplicate work.

### Cache the work that is actually reused

- `subosito/flutter-action` caches the pinned Flutter SDK and pub packages.
- `actions/setup-java` caches Gradle dependencies for Android builds.
- `sccache` caches Rust compiler outputs across Cargokit's per-platform target
  directories. Its setup is best-effort, so a cache service problem does not
  prevent a release.
- FRB bindings, codegen binaries, the Cargo registry, and the codegen Cargo
  target remain keyed by their exact source and tool inputs.
- The ineffective `../usernode/target` caches were removed from the Android
  and iOS platform build jobs.

### Avoid obsolete work

Build and Deploy runs for the same non-production branch cancel an older run
when a newer one starts. Main-branch releases are never cancelled. Lightweight
notification jobs use `ubuntu-latest` instead of reserving a 16-core runner.

### Keep publishing optional

Build and Deploy defaults to uploading artifacts, deploying to the stores,
tagging eligible branches, and notifying the team. Clear `publish_release` for
a build-only run that still compiles and verifies the signed AAB and IPA but
does not distribute either one.

## Measured results

Two consecutive build-only runs of the same commit measured the cold-to-warm
effect:

- [Run 239](https://github.com/Usernode-Labs/flutter-mobile-app/actions/runs/33541027074)
  completed in 23 minutes 50 seconds.
- [Run 240](https://github.com/Usernode-Labs/flutter-mobile-app/actions/runs/33543463862)
  completed in 16 minutes 38 seconds, 7 minutes 12 seconds (30%) faster.
- The signed iOS IPA step improved from 19 minutes 41 seconds to 12 minutes 42
  seconds, with a 99.76% compiler-cache hit rate in the warm run.
- The Android AAB step improved from 5 minutes 49 seconds to 5 minutes 31
  seconds. Its Rust-specific cache hit rate reached 97.87%.

The warm result is below the original 38-minute median even before accounting
for normal variance. Publishing-enabled runs also include store upload time, so
multiple real releases are still needed to establish the new production
median.

## Validation

For every workflow change:

1. Run `actionlint` on all modified workflow files.
2. Run `ruby -c fastlane/Fastfile` and lint `ios/ExportOptions.plist`.
3. Let the pull-request checks exercise the shared FRB preparation and normal
   Flutter build paths.
4. Run a controlled Build and Deploy dispatch with `publish_release` cleared to
   verify signing, IPA export, and cache statistics without distributing the
   build.
5. Compare cold and warm step timings in the Actions UI. Validate store uploads
   separately with a deliberate publishing-enabled release.

Pull-request checks and build-only dispatches do not deploy to either store.
