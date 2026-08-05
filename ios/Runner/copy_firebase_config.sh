#!/bin/sh

set -eu

if [ -n "${FIREBASE_IOS_CONFIG_FILE:-}" ]; then
  source_plist="${FIREBASE_IOS_CONFIG_FILE}"
  case "${source_plist}" in
    /*) ;;
    *) source_plist="${PROJECT_DIR}/${source_plist}" ;;
  esac
  if [ ! -f "${source_plist}" ]; then
    echo "error: FIREBASE_IOS_CONFIG_FILE does not exist." >&2
    exit 1
  fi
else
  source_plist="${PROJECT_DIR}/Firebase/${CONFIGURATION}/GoogleService-Info.plist"
  if [ ! -f "${source_plist}" ]; then
    source_plist="${PROJECT_DIR}/Runner/GoogleService-Info.plist"
  fi
fi

destination_dir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
destination_plist="${destination_dir}/GoogleService-Info.plist"

if [ ! -f "${source_plist}" ]; then
  /bin/rm -f "${destination_plist}"
  echo "warning: Firebase iOS configuration is absent; Social push is unavailable."
  exit 0
fi

/usr/bin/plutil -lint "${source_plist}" >/dev/null
configured_bundle_id=$(
  /usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "${source_plist}" 2>/dev/null || true
)
if [ -z "${configured_bundle_id}" ] ||
   [ "${configured_bundle_id}" != "${PRODUCT_BUNDLE_IDENTIFIER}" ]; then
  echo "error: Firebase iOS BUNDLE_ID does not match the Runner target." >&2
  exit 1
fi

if [ -n "${FIREBASE_PROJECT_ID:-}" ]; then
  configured_project_id=$(
    /usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "${source_plist}" 2>/dev/null || true
  )
  if [ "${configured_project_id}" != "${FIREBASE_PROJECT_ID}" ]; then
    echo "error: Firebase iOS PROJECT_ID does not match FIREBASE_PROJECT_ID." >&2
    exit 1
  fi
fi

/bin/mkdir -p "${destination_dir}"
/bin/cp "${source_plist}" "${destination_plist}"
