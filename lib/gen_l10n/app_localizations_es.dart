// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Usernode';

  @override
  String get appTagline => 'Tu Puerta de Entrada a DeFi';

  @override
  String get initializingNode => 'Inicializando nodo...';

  @override
  String get home => 'Inicio';

  @override
  String get wallet => 'Billetera';

  @override
  String get node => 'Nodo';

  @override
  String nodeStatusSynced(String time) {
    return 'Tu Nodo Local sincronizado en $time';
  }

  @override
  String totalNodes(String count) {
    return '$count Nodos en Total';
  }

  @override
  String get bringLiquidity => 'Aporta tu propia liquidez';

  @override
  String get bridgeAssetsDescription =>
      'Transfiere activos a la red en tu primera semana';

  @override
  String get bridge => 'Transferir';

  @override
  String get completeVerification => 'Completa la verificación';

  @override
  String get verificationDescription =>
      'Esto verifica tu identidad y aumenta tus recompensas';

  @override
  String get verify => 'Verificar';

  @override
  String get stakeTokens => 'Haz staking de tus tokens';

  @override
  String get stakingDescription =>
      'Bloquea tokens por un período para obtener recompensas adicionales';

  @override
  String get stake => 'Staking';

  @override
  String get multiplier => 'Tu Multiplicador';

  @override
  String tokensExpected(String count, String days) {
    return '$count Tokens esperados en los próximos $days días';
  }

  @override
  String get activity => 'Actividad';

  @override
  String upcomingBlock(String time) {
    return 'Próximo bloque en $time';
  }

  @override
  String get scheduledBackground => 'Programado en segundo plano';

  @override
  String get identityProven => 'Identidad Verificada';

  @override
  String get depositSuccessful => 'Depósito Exitoso';

  @override
  String get comingSoon => 'Próximamente...';

  @override
  String get walletManagement => 'Gestión de Billetera';

  @override
  String get crossChainBridge => 'Puente Entre Cadenas';

  @override
  String get nodeStatus => 'Estado del Nodo';

  @override
  String get swap => 'Swap';

  @override
  String get tokenSwap => 'Token Swap';

  @override
  String get rewards => 'Rewards';

  @override
  String get rewardsAchievements => 'Rewards & Achievements';

  @override
  String get yourMultiplier => 'Your Multiplier';

  @override
  String get createAccountTitle => 'Create Account';

  @override
  String get recoveryPhraseTitle => 'Your recovery phrase';

  @override
  String get recoveryPhraseWarning =>
      'This recovery phrase is the ONLY way to restore your keys and regain access to this account if something goes wrong. Store it securely and never share it.';

  @override
  String get recoveryPhraseInstruction =>
      'Write these words down and store them securely. They will NOT be stored by the app and cannot be recovered.';

  @override
  String get accountNameLabel => 'Account name';

  @override
  String get accountNameHint => 'e.g., Account 1';

  @override
  String get accountNameExplain =>
      'This name is only stored on your device to help you identify the account. It does not affect your blockchain address or keys.';

  @override
  String get seedStoredCheckbox => 'I have securely stored my recovery phrase.';

  @override
  String get continueButton => 'Continue';

  @override
  String get send => 'Send';

  @override
  String get receive => 'Receive';

  @override
  String get balances => 'Balances';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get copyAddress => 'Copy address';

  @override
  String get addressCopied => 'Address copied';

  @override
  String get manageAccounts => 'Manage accounts';

  @override
  String get selectAccount => 'Select account';

  @override
  String get selectAccountHint => 'Tap an account to switch';

  @override
  String get createNewAccount => 'Create new account';

  @override
  String get importFromSeed => 'Import from seed phrase';

  @override
  String get importFromPrivateKey => 'Import from private key';

  @override
  String get deleteAllAccountsDev => 'Delete all accounts (dev)';

  @override
  String get deleteAllConfirmTitle => 'Delete all accounts?';

  @override
  String get deleteAllConfirmBody =>
      'This will remove all stored accounts on this device.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get generateNewAddress => 'Generate new address';
}
