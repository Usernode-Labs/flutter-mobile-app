class DappItem {
  final String name;
  final String author;
  final String url;
  final String? pubkey;
  final String? description;

  const DappItem({
    required this.name,
    required this.author,
    required this.url,
    this.pubkey,
    this.description,
  });

  factory DappItem.fromJson(Map<String, dynamic> json) {
    return DappItem(
      name: json['name'] as String,
      author: json['author'] as String,
      url: json['url'] as String,
      pubkey: json['pubkey'] as String?,
      description: json['description'] as String?,
    );
  }

  // Provisional until the backend ships a stable slug with each dApp.
  String get slug => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
