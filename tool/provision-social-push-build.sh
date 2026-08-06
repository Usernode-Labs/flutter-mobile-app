#!/usr/bin/env bash

set -euo pipefail
umask 077

readonly android_package='com.usernode_labs.usernode'
readonly ios_bundle_id='org.usernode.app'
readonly env_file="${SOCIAL_PUSH_ENV_FILE:-.env}"

tmp_env=''
tmp_config=''

fail() {
  printf 'Social push provisioning error: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  [[ -z "$tmp_env" ]] || rm -f "$tmp_env"
  [[ -z "$tmp_config" ]] || rm -f "$tmp_config"
}
trap cleanup EXIT

[[ $# -eq 1 ]] || fail 'usage: provision-social-push-build.sh android|ios'
readonly platform="$1"
case "$platform" in
  android) destination='android/app/google-services.json' ;;
  ios) destination='ios/Runner/GoogleService-Info.plist' ;;
  *) fail 'platform must be android or ios.' ;;
esac

readonly environment_type="${SOCIAL_PUSH_ENV_TYPE:-}"
case "$environment_type" in
  PROD|NONPROD) ;;
  *) fail 'SOCIAL_PUSH_ENV_TYPE must be PROD or NONPROD.' ;;
esac
[[ -f "$env_file" ]] || fail "$env_file does not exist."

selected() {
  local name="${environment_type}_$1"
  printf '%s' "${!name:-}"
}

required="$(selected SOCIAL_PUSH_REQUIRED)"
case "$required" in
  true) ;;
  false|'') required='false' ;;
  *) fail "${environment_type}_SOCIAL_PUSH_REQUIRED must be true or false." ;;
esac
mobile_api_base_url="$(selected MOBILE_API_BASE_URL)"

validate_mobile_api_base_url() {
  [[ "$1" =~ ^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~%-]+)*/api/v4/mobile/?$ ]] ||
    fail "${environment_type}_MOBILE_API_BASE_URL must be an HTTPS v4 mobile API base URL."
}

write_deployment_identity() {
  local push_env="$1"
  local project_id="$2"
  local mobile_api_base_url="$3"
  tmp_env="$(mktemp "${TMPDIR:-/tmp}/usernode-push-env.XXXXXX")"
  awk '!/^(PUSH_ENV|FIREBASE_PROJECT_ID|MOBILE_API_BASE_URL)=/' \
    "$env_file" >"$tmp_env"
  {
    printf '\n# Managed by tool/provision-social-push-build.sh\n'
    printf 'PUSH_ENV=%s\n' "$push_env"
    printf 'FIREBASE_PROJECT_ID=%s\n' "$project_id"
    printf 'MOBILE_API_BASE_URL=%s\n' "$mobile_api_base_url"
  } >>"$tmp_env"
  install -m 600 "$tmp_env" "$env_file"
}

if [[ "$required" == 'false' ]]; then
  rm -f "$destination"
  if [[ -n "$mobile_api_base_url" ]]; then
    validate_mobile_api_base_url "$mobile_api_base_url"
  fi
  write_deployment_identity '' '' "$mobile_api_base_url"
  printf 'Social push is disabled for this %s build.\n' "$platform"
  exit 0
fi

push_env="$(selected PUSH_ENV)"
project_id="$(selected FIREBASE_PROJECT_ID)"
client_config="$(selected FIREBASE_CLIENT_CONFIG_BASE64)"

[[ "$push_env" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] ||
  fail "${environment_type}_PUSH_ENV is missing or invalid."
[[ "$project_id" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$ ]] ||
  fail "${environment_type}_FIREBASE_PROJECT_ID is missing or invalid."
if [[ -n "$mobile_api_base_url" ]]; then
  validate_mobile_api_base_url "$mobile_api_base_url"
elif [[ "$environment_type" != 'PROD' ]]; then
  fail 'NONPROD_MOBILE_API_BASE_URL must be an HTTPS v4 mobile API base URL.'
fi
[[ -n "$client_config" ]] ||
  fail "${environment_type}_FIREBASE_CLIENT_CONFIG_BASE64 is required."

tmp_config="$(mktemp "${TMPDIR:-/tmp}/usernode-firebase.XXXXXX")"
if printf '%s' "$client_config" | base64 --decode >"$tmp_config" 2>/dev/null; then
  :
elif printf '%s' "$client_config" | base64 -D >"$tmp_config" 2>/dev/null; then
  :
else
  fail 'Firebase client configuration is not valid base64.'
fi

case "$platform" in
  android)
    command -v jq >/dev/null || fail 'jq is required for Android validation.'
    jq -e \
      --arg project "$project_id" \
      --arg package "$android_package" \
      '(.project_info.project_id == $project) and
       any(.client[]?;
         .client_info.android_client_info.package_name == $package)' \
      "$tmp_config" >/dev/null ||
      fail 'Android Firebase project or package does not match this app.'
    ;;
  ios)
    /usr/bin/plutil -lint "$tmp_config" >/dev/null ||
      fail 'iOS Firebase configuration is not a valid plist.'
    configured_project="$('/usr/libexec/PlistBuddy' -c 'Print :PROJECT_ID' "$tmp_config" 2>/dev/null || true)"
    configured_bundle="$('/usr/libexec/PlistBuddy' -c 'Print :BUNDLE_ID' "$tmp_config" 2>/dev/null || true)"
    [[ "$configured_project" == "$project_id" ]] ||
      fail 'iOS Firebase project does not match this build.'
    [[ "$configured_bundle" == "$ios_bundle_id" ]] ||
      fail 'iOS Firebase bundle id does not match this app.'
    ;;
esac

mkdir -p "$(dirname "$destination")"
install -m 600 "$tmp_config" "$destination"
write_deployment_identity "$push_env" "$project_id" "$mobile_api_base_url"
printf 'Provisioned Social push for %s (%s).\n' "$platform" "$environment_type"
