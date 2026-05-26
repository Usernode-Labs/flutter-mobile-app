/// Routes that may be opened from backend-provided app CTAs or external
/// `usernode://app/...` links.
bool isAllowedAppDeepLinkPath(String path) {
  if (path == '/challenges/leaderboard' ||
      path == '/challenges/zk-identity' ||
      path == '/challenges/zk-identity/flow' ||
      path == '/dapps') {
    return true;
  }

  final dappMatch = RegExp(r'^/dapps/[a-z0-9-]+$').hasMatch(path);
  return dappMatch;
}

bool isUsernodeAppDeepLink(Uri uri) {
  return uri.scheme == 'usernode' && uri.host == 'app';
}

bool isAllowedUsernodeAppDeepLink(Uri uri) {
  return isUsernodeAppDeepLink(uri) && isAllowedAppDeepLinkPath(uri.path);
}
