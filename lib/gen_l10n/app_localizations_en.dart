// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Usernode';

  @override
  String get appTagline => 'Your Gateway to DeFi';

  @override
  String get initializingNode => 'Initializing node...';

  @override
  String get home => 'Home';

  @override
  String get wallet => 'Wallet';

  @override
  String get node => 'Node';

  @override
  String get nfcReader => 'NFC Reader';

  @override
  String get nfcEmptyTitle => 'Scan your ID';

  @override
  String get nfcEmptySubtitle =>
      'Use your phone to read your ePassport or eID via NFC.';

  @override
  String get nfcScanAnother => 'Scan another';

  @override
  String get nfcManualMrz => 'Enter MRZ manually';

  @override
  String get nfcStartScan => 'Start NFC scan';

  @override
  String get mrzTitle => 'Enter MRZ';

  @override
  String get mrzLine1 => 'MRZ line 1';

  @override
  String get mrzLine2 => 'MRZ line 2';

  @override
  String get mrzLine3 => 'MRZ line 3 (optional)';

  @override
  String get mrzContinue => 'Continue';

  @override
  String get nfcReading => 'Hold document to the phone...';

  @override
  String get nfcSave => 'Save';

  @override
  String get nfcRename => 'Rename';

  @override
  String get nfcDelete => 'Delete';

  @override
  String get nfcConfirmDelete => 'Delete this document?';

  @override
  String get unlockToView => 'Unlock to view private data';

  @override
  String get biometricsNotAvailable => 'Biometrics not available';

  @override
  String get nfcNotSupported => 'This device does not support NFC.';

  @override
  String get nfcTurnOn => 'Please enable NFC in settings.';

  @override
  String get nfcReadFailed =>
      'Failed to read document. Check MRZ and try again.';

  @override
  String get nfcUpdated => 'Document updated';

  @override
  String get nfcSaved => 'Document saved';

  @override
  String nodeStatusSynced(String time) {
    return 'Your Local Node synced in $time';
  }

  @override
  String totalNodes(String count) {
    return '$count Nodes Total';
  }

  @override
  String get bringLiquidity => 'Bring your own liquidity';

  @override
  String get bridgeAssetsDescription =>
      'Bridge assets to the network within your first week';

  @override
  String get bridge => 'Bridge';

  @override
  String get completeVerification => 'Complete verification';

  @override
  String get verificationDescription =>
      'This verifies your identity and increases your rewards';

  @override
  String get verify => 'Verify';

  @override
  String get stakeTokens => 'Stake your tokens';

  @override
  String get stakingDescription =>
      'Lock tokens for a period to earn additional rewards';

  @override
  String get stake => 'Stake';

  @override
  String get multiplier => 'Your Multiplier';

  @override
  String tokensExpected(String count, String days) {
    return '$count Tokens expected in next $days days';
  }

  @override
  String get activity => 'Activity';

  @override
  String upcomingBlock(String time) {
    return 'Upcoming block in $time';
  }

  @override
  String get scheduledBackground => 'Scheduled in the background';

  @override
  String get identityProven => 'Identity Proven';

  @override
  String get depositSuccessful => 'Deposit Successful';

  @override
  String get comingSoon => 'Coming soon...';

  @override
  String get walletManagement => 'Wallet Management';

  @override
  String get crossChainBridge => 'Node status';

  @override
  String get nodeStatus => 'Node Status';

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

  @override
  String get backendStarting => 'Starting backend for your account...';

  @override
  String get nodeStatusLoading => 'Loading node status...';

  @override
  String get nodeStatusError => 'Failed to load node status';

  @override
  String nodePeersCount(String count) {
    return 'Peers: $count';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get currentBlockHeightLabel => 'Current block height';

  @override
  String get nodeStatusLabel => 'Status';

  @override
  String get peersLabel => 'Peers';

  @override
  String get mempoolLabel => 'Mempool';

  @override
  String get evaluatedDiscoveredLabel => 'Evaluated / Discovered Slots';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get pastSlots => 'Past Slots';

  @override
  String get scheduledSlot => 'Scheduled Slot';

  @override
  String discoveredSlot(String id) {
    return 'Discovered Slot $id';
  }

  @override
  String inTime(String time) {
    return 'in $time';
  }

  @override
  String transactionsSuffix(String count) {
    return '$count Transactions';
  }

  @override
  String checkedAgoSeconds(String seconds) {
    return 'Checked $seconds seconds ago';
  }
}
