source "https://rubygems.org"

gem "fastlane"

# `representable` (pulled in transitively by fastlane's google-apis-* actions,
# which fastlane eager-loads for every lane) does `require "multi_json"` at load
# time but is not always pulled into the bundle on a fresh resolve. Declaring it
# here guarantees it is installed, avoiding a `Gem::LoadError: multi_json is not
# part of the bundle` when fastlane loads its default actions.
gem "multi_json"
