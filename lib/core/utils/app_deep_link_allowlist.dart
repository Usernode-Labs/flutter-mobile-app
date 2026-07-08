/// Routes that may be opened from backend-provided app CTAs or external
/// `usernode://app/...` links.
bool isAllowedAppDeepLinkPath(String path) {
  if (path == '/challenges/leaderboard' ||
      path == '/challenges/zk-identity' ||
      path == '/challenges/zk-identity/flow' ||
      path == '/dapps') {
    return true;
  }

  // Homescreen shortcuts / widget tiles deep-link to locally pinned dapps.
  // The id only resolves against the local pinned registry, so external
  // links can't open arbitrary URLs through this path.
  if (RegExp(r'^/dapps/pinned/[a-f0-9]+$').hasMatch(path)) {
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

bool shouldBlockUsernodeDeepLink(Uri uri) {
  return uri.scheme == 'usernode' && !isAllowedUsernodeAppDeepLink(uri);
}
