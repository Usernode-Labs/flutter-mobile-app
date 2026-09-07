import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A dapp the user pinned to the device homescreen (Android pinned shortcut
/// or iOS widget slot). Persisted locally so `usernode://app/dapps/pinned/:id`
/// deep links can resolve back to a route without embedding raw URLs in the
/// deep link surface.
class PinnedDapp {
  final String id;
  final String name;
  final String url;

  /// The platform hash route this tile opens (`app/<slug>`), without the
  /// leading `#`. Empty means the platform root.
  ///
  /// This — not [url] — is what a launch resolves through, and it is the whole
  /// reason a tile survives an origin change. Pinning is gated on a privileged
  /// bridge lease that already requires the calling page to be on the platform
  /// origin, so the origin is *proven at pin time*. Recording only the
  /// origin-relative half means a launch never has to re-derive that proof by
  /// comparing against a build constant that may since have moved. It used to,
  /// and a tile pinned under one platform base URL then dead-ended in native
  /// browser chrome under the next one.
  final String route;

  final String iconUrl;
  final int pinnedAtMs;

  const PinnedDapp({
    required this.id,
    required this.name,
    required this.url,
    required this.route,
    required this.iconUrl,
    required this.pinnedAtMs,
  });

  /// Stable shortcut id derived from the dapp URL, so re-pinning the same
  /// dapp updates the existing shortcut instead of creating a duplicate.
  ///
  /// Deliberately still keyed on the absolute URL: a homescreen tile carries
  /// this id for as long as it exists, so re-keying on [route] would orphan
  /// every tile already placed.
  static String idForUrl(String url) =>
      sha256.convert(utf8.encode(url)).toString().substring(0, 12);

  /// The platform hash route [url] addresses, without the leading `#`.
  ///
  /// The platform pins its apps as `<origin>/#app/<slug>`, so the fragment is
  /// exactly the origin-independent half. A URL carrying no fragment yields
  /// `''` — the platform root, which is where a tile predating hash-route
  /// pinning should land rather than in a browser.
  static String routeForUrl(String url) =>
      Uri.tryParse(url.trim())?.fragment ?? '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'route': route,
        'iconUrl': iconUrl,
        'pinnedAtMs': pinnedAtMs,
      };

  factory PinnedDapp.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String;
    return PinnedDapp(
      id: json['id'] as String,
      name: json['name'] as String,
      url: url,
      // Entries written before `route` existed carry only the absolute URL.
      // Deriving on read — rather than on the next re-pin — is what heals
      // tiles already sitting on a homescreen: re-pinning mints a *new* id
      // (see [idForUrl]), so a migration that waited for one would leave the
      // placed tile broken forever.
      route: (json['route'] as String?) ?? routeForUrl(url),
      iconUrl: json['iconUrl'] as String? ?? '',
      pinnedAtMs: (json['pinnedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
