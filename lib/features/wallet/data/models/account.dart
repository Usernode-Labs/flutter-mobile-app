import 'dart:convert';

class AccountMeta {
  final String id;
  final String name;
  final DateTime createdAt;
  final String derivationPath;
  final int hdIndex;
  final String address;
  final String publicKey;
  final bool backupConfirmed;
  final bool identityVerified;
  final DateTime? identityVerifiedAt;
  final bool isDemo;

  const AccountMeta({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.derivationPath,
    required this.hdIndex,
    required this.address,
    required this.publicKey,
    required this.backupConfirmed,
    this.identityVerified = false,
    this.identityVerifiedAt,
    this.isDemo = false,
  });

  AccountMeta copyWith({
    String? name,
    bool? backupConfirmed,
    bool? identityVerified,
    DateTime? identityVerifiedAt,
    bool? isDemo,
  }) =>
      AccountMeta(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        derivationPath: derivationPath,
        hdIndex: hdIndex,
        address: address,
        publicKey: publicKey,
        backupConfirmed: backupConfirmed ?? this.backupConfirmed,
        identityVerified: identityVerified ?? this.identityVerified,
        identityVerifiedAt: identityVerifiedAt ?? this.identityVerifiedAt,
        isDemo: isDemo ?? this.isDemo,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'derivationPath': derivationPath,
        'hdIndex': hdIndex,
        'address': address,
        'publicKey': publicKey,
        'backupConfirmed': backupConfirmed,
        'identityVerified': identityVerified,
        'identityVerifiedAt': identityVerifiedAt?.toIso8601String(),
        'isDemo': isDemo,
      };

  static AccountMeta fromJson(Map<String, dynamic> json) => AccountMeta(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        derivationPath: json['derivationPath'] as String,
        hdIndex: (json['hdIndex'] as num).toInt(),
        address: json['address'] as String,
        publicKey: json['publicKey'] as String,
        backupConfirmed: (json['backupConfirmed'] as bool? ?? false),
        identityVerified: (json['identityVerified'] as bool? ?? false),
        identityVerifiedAt: json['identityVerifiedAt'] != null
            ? DateTime.parse(json['identityVerifiedAt'] as String)
            : null,
        isDemo: (json['isDemo'] as bool? ?? false),
      );

  @override
  String toString() => jsonEncode(toJson());
}
