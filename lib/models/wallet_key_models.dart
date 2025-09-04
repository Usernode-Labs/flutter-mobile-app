class WalletKeys {
  final String? mnemonic;
  final String? privateKey; // Hex or base58/64 depending on chain
  final String? publicKey; // Hex or base58/64 depending on chain
  final String? address; // Some chains use publicKey as address
  final int? hdIndex; // Derivation index if applicable

  const WalletKeys({
    this.mnemonic,
    this.privateKey,
    this.publicKey,
    this.address,
    this.hdIndex,
  });

  bool get hasMnemonic => mnemonic != null && mnemonic!.isNotEmpty;
  bool get hasKeypair =>
      (privateKey != null && privateKey!.isNotEmpty) &&
      (publicKey != null && publicKey!.isNotEmpty);

  WalletKeys copyWith({
    String? mnemonic,
    String? privateKey,
    String? publicKey,
    String? address,
    int? hdIndex,
  }) {
    return WalletKeys(
      mnemonic: mnemonic ?? this.mnemonic,
      privateKey: privateKey ?? this.privateKey,
      publicKey: publicKey ?? this.publicKey,
      address: address ?? this.address,
      hdIndex: hdIndex ?? this.hdIndex,
    );
  }
}
