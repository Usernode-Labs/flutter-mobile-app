/// Resolve retired Homeroom deployment origins before configuring native HTTP
/// or the WebView trust boundary. Native bearer requests do not follow redirects.
/// Custom deployments and unrelated URLs retain their exact configuration.
String canonicalHomeroomDeploymentUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      !const {
        'my.onhomeroom.com',
        'social-vibecoding.usernodelabs.org',
      }.contains(uri.host)) {
    return value;
  }
  return uri.replace(host: 'app.onhomeroom.com').toString();
}
