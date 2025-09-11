import 'package:bip32_bip44/dart_bip32_bip44.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:web3dart/credentials.dart';
import 'package:web3dart/web3dart.dart';

class KeyManagementService {
  static const String pathForPublicKey = "m/44'/60'/0'/0";
  static const String pathForPrivateKey = "m/44'/60'/0'/0/0";

  String mnemonic = "";
  String privateKey = "";
  String publicKey = "";
  String address = "";
  String message = "";

  Future<List<dynamic>> createWallet() async {
    try {
      mnemonic = bip39.generateMnemonic();

      final String seed = bip39.mnemonicToSeedHex(mnemonic);
      final Chain chain = Chain.seed(seed);

      final ExtendedKey extendedKey = chain.forPath(pathForPrivateKey);
      privateKey = extendedKey.privateKeyHex();

      final EthPrivateKey cryptoPrivateKey = EthPrivateKey.fromHex(privateKey);
      final EthereumAddress cryptoAddress = cryptoPrivateKey.address;

      final ExtendedKey extendedKeyPublic = chain.forPath(pathForPublicKey);
      publicKey = extendedKeyPublic.publicKey().toString();

      address = cryptoAddress.hex;

      return [true, mnemonic, privateKey, publicKey, address];
    } catch (e) {
      return [false, e.toString()];
    }
  }
}
