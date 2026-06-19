/// Routes that may be opened from backend-provided app CTAs or external
/// `usernode://app/...` links.
bool isAllowedAppDeepLinkPath(String path) {
  if (path == '/challenges' ||
      path == '/challenges/leaderboard' ||
      path == '/challenges/zk-identity' ||
      path == '/challenges/zk-identity/flow' ||
      path == '/activity' ||
      path == '/main/node' ||
      path == '/dapps' ||
      path == '/profile/settings') {
    return true;
  }

  return RegExp(r'^/dapps/[a-z0-9-]+$').hasMatch(path);
}

bool isUsernodeAppDeepLink(Uri uri) {
  return uri.scheme == 'usernode' && uri.host == 'app';
}

bool isAllowedUsernodeAppDeepLink(Uri uri) {
  return isUsernodeAppDeepLink(uri) && isAllowedAppDeepLinkPath(uri.path);
}

bool shouldBlockUsernodeDeepLink(Uri uri) {
  return uri.scheme == 'usernode' && !isAllowedUsernodeAppDeepLink(uri);
}
