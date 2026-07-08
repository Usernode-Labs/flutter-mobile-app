import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A dapp the user pinned to the device homescreen (Android pinned shortcut
/// or iOS widget slot). Persisted locally so `usernode://app/dapps/pinned/:id`
/// deep links can resolve back to a URL without embedding raw URLs in the
/// deep link surface.
class PinnedDapp {
  final String id;
  final String name;
  final String url;
  final String iconUrl;
  final int pinnedAtMs;

  const PinnedDapp({
    required this.id,
    required this.name,
    required this.url,
    required this.iconUrl,
    required this.pinnedAtMs,
  });

  /// Stable shortcut id derived from the dapp URL, so re-pinning the same
  /// dapp updates the existing shortcut instead of creating a duplicate.
  static String idForUrl(String url) =>
      sha256.convert(utf8.encode(url)).toString().substring(0, 12);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'iconUrl': iconUrl,
        'pinnedAtMs': pinnedAtMs,
      };

  factory PinnedDapp.fromJson(Map<String, dynamic> json) {
    return PinnedDapp(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      iconUrl: json['iconUrl'] as String? ?? '',
      pinnedAtMs: (json['pinnedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
