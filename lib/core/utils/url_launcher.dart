import 'package:url_launcher/url_launcher.dart';

/// Launches [url] in an external application if it's a valid URI.
Future<void> launchExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
