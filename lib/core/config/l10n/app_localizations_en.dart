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
  String get node => 'Node';

  @override
  String get sendFeedback => 'Send Feedback';

  @override
  String get feedbackTitle => 'Title';

  @override
  String get feedbackTitleHint => 'Brief summary of your feedback';

  @override
  String get feedbackDescription => 'Description';

  @override
  String get feedbackDescriptionHint => 'Describe your feedback in detail';

  @override
  String get feedbackCategory => 'Category';

  @override
  String get feedbackIncludeDeviceInfo => 'Include device information';

  @override
  String get feedbackDeviceInfoHelp => 'Helps us diagnose issues';

  @override
  String get feedbackSubmit => 'Submit Feedback';

  @override
  String get feedbackSuccess => 'Thank you for your feedback!';

  @override
  String get feedbackError => 'Failed to submit feedback';

  @override
  String get feedbackRequired => 'This field is required';

  @override
  String get feedbackScreenshots => 'Screenshots';

  @override
  String get feedbackAddScreenshot => 'Add';

  @override
  String get feedbackNoScreenshots => 'No screenshots added (optional)';

  @override
  String get feedbackHelpImprove => 'Help us improve the app';

  @override
  String feedbackImagePickFailed(String error) {
    return 'Failed to pick image: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsLanguageComingSoon => 'Language support coming soon';

  @override
  String get settingsBackgroundBlockProduction => 'Background Block Production';

  @override
  String get settingsBackgroundBlockProductionSubtitle =>
      'Configure automatic block production';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsBuildInfo => 'Build Info';

  @override
  String get bgProdWhatIs => 'What is Background Block Production?';

  @override
  String get bgProdDescription =>
      'This feature automatically wakes your device to produce blockchain blocks when your node wins a slot. Here\'s how it works:';

  @override
  String get bgProdVrfSelection => 'VRF Selection';

  @override
  String get bgProdVrfSelectionDesc =>
      'Each epoch, the network randomly selects which validators will produce blocks using Verifiable Random Function (VRF)';

  @override
  String get bgProdSlotScheduling => 'Slot Scheduling';

  @override
  String get bgProdSlotSchedulingDesc =>
      'When you win slots, the app schedules alarms to wake your device ~1 minute before each slot';

  @override
  String get bgProdBlockProduction => 'Block Production';

  @override
  String get bgProdBlockProductionDesc =>
      'At slot time, the app monitors your node and ensures the block is produced';

  @override
  String get bgProdSuccessTracking => 'Success Tracking';

  @override
  String get bgProdSuccessTrackingDesc =>
      'Results are recorded to track your reliability over time';

  @override
  String get bgProdAndroidTitle => 'Android Background Production';

  @override
  String get bgProdIosTitle => 'iOS Background Production';

  @override
  String get bgProdAndroidDesc =>
      'Uses Android\'s exact alarm system (AlarmManager) to wake your device precisely when needed for block production.';

  @override
  String get bgProdIosDesc =>
      'Uses a combination of background tasks and keep-alive mode to wake your device for block production.';

  @override
  String get bgProdReliabilityByMode => 'Reliability by Mode';

  @override
  String get bgProdDefaultMode => 'Default (Event-Driven)';

  @override
  String get bgProdDefaultReliability => '90-95%';

  @override
  String get bgProdDefaultDesc =>
      'Battery-efficient, wakes only during slot windows';

  @override
  String get bgProdKeepAliveMode => 'Keep-Alive Mode';

  @override
  String get bgProdKeepAliveReliability => '100%';

  @override
  String get bgProdKeepAliveDesc =>
      'Persistent service, higher battery (~5-10%/hr)';

  @override
  String get bgProdIosKeepAliveReliability => '99%';

  @override
  String get bgProdIosKeepAliveDesc =>
      'App stays awake in foreground, requires charger';

  @override
  String get bgProdBackgroundOnly => 'Background Only';

  @override
  String get bgProdBackgroundOnlyReliability => '40-60%';

  @override
  String get bgProdBackgroundOnlyDesc =>
      'iOS controls execution, not guaranteed';

  @override
  String get bgProdLoading => 'Loading...';

  @override
  String get bgProdVrfComplete => 'VRF Complete';

  @override
  String get bgProdVrfCalculating => 'VRF Calculating...';

  @override
  String get bgProdVrfPending => 'VRF Pending';

  @override
  String get bgProdGrantPermissions => 'Grant Permissions';

  @override
  String get bgProdOpenBatterySettings => 'Open Battery Settings';

  @override
  String get onboardingAccountSetup => 'Account Setup';

  @override
  String get onboardingSetUpYourAccount => 'Set Up Your Account';

  @override
  String get onboardingSelectDemoAccount =>
      'Select a demo account to start using the Usernode blockchain.';

  @override
  String get onboardingUseDemoAccount => 'Use Demo Account';

  @override
  String get onboardingUseDemoAccountDesc =>
      'Quickly set up a pre-configured account for testing purposes.';

  @override
  String get demoNoDemoAccountsAvailable => 'No Demo Accounts Available';

  @override
  String get demoNotConfigured =>
      'Demo accounts are not configured in this build.';

  @override
  String get demoSelectToImport =>
      'Select a demo account to import for testing purposes.';

  @override
  String get demoWarning => 'Demo accounts are for development/testing only';

  @override
  String get demoUseButton => 'Use';

  @override
  String demoKeyValidationFailedPublicKey(String tier) {
    return 'Key validation failed: Public key mismatch for $tier account';
  }

  @override
  String demoKeyValidationFailedAddress(String tier) {
    return 'Key validation failed: Address mismatch for $tier account';
  }

  @override
  String get demoImportFailed => 'Failed to import demo account';

  @override
  String demoImportFailedWithError(String error) {
    return 'Failed to import demo account: $error';
  }

  @override
  String get walletNoActiveAccount =>
      'No active account found. Please create or select an account.';

  @override
  String get walletInvalidAmount =>
      'Invalid amount. Enter a whole-number amount.';

  @override
  String get walletNodeConnectionFailed =>
      'Failed to connect to node. Please ensure the node is running.';

  @override
  String walletTransferFailed(String error) {
    return 'Transfer failed: $error';
  }

  @override
  String get walletTransferNotQueued =>
      'Transfer was not queued. Please try again.';

  @override
  String get walletTransferFailedTitle => 'Transfer Failed';

  @override
  String get walletReviewSend => 'Review Send';

  @override
  String get walletAmount => 'Amount';

  @override
  String get walletNetworkFee => 'Network fee';

  @override
  String get walletBack => 'Back';

  @override
  String get walletSend => 'Send';

  @override
  String get commonOk => 'OK';

  @override
  String get walletDone => 'Done';

  @override
  String get walletPaymentSent => 'Payment Sent';

  @override
  String get walletTransactionSubmitted =>
      'Your transaction has been submitted successfully.';

  @override
  String get nodeStatusTitle => 'Node Status';

  @override
  String get nodePeerIdCopied => 'Peer ID copied to clipboard';

  @override
  String get nodeCopyPeerId => 'Copy full Peer ID';

  @override
  String get nodePeersTitle => 'Node Peers';

  @override
  String nodePeersSummary(String count, String connected, String connecting) {
    return '$count Peers  •  $connected Connected  •  $connecting Connecting';
  }

  @override
  String get wonSlotsTitle => 'Won Slots';

  @override
  String get wonSlotsLoadingEpoch => 'Loading epoch data...';

  @override
  String get wonSlotsEpochUnavailable => 'Epoch data unavailable';

  @override
  String get wonSlotsNoData => 'No won slots data available';

  @override
  String get wonSlotsGroupedByHour => 'Grouped by hour';

  @override
  String get wonSlotsGroupedByDay => 'Grouped by day';

  @override
  String get wonSlotsWon => 'Won';

  @override
  String get wonSlotsProduced => 'Produced';

  @override
  String get wonSlotsMissed => 'Missed';

  @override
  String get wonSlotsPending => 'Pending';

  @override
  String get wonSlotsToday => 'Today';

  @override
  String get producedBlocksTitle => 'Produced Blocks';

  @override
  String get producedBlocksLoading => 'Loading produced blocks...';

  @override
  String get producedBlocksNoData => 'No produced blocks available';

  @override
  String get mempoolTitle => 'Mempool Transactions';

  @override
  String get mempoolLoadFailed => 'Failed to load mempool';

  @override
  String get mempoolRetry => 'Retry';

  @override
  String get mempoolNoTransactions => 'No transactions in mempool';

  @override
  String get mempoolEmpty => 'The mempool is currently empty';

  @override
  String get rewardsBreakdownTitle => 'Rewards Breakdown';

  @override
  String get drawerP2pPeerId => 'P2P Peer ID:';

  @override
  String get drawerClose => 'Close';

  @override
  String get commonError => 'Error';

  @override
  String get buildInfoVersion => 'Version';

  @override
  String get buildInfoCommit => 'Commit';

  @override
  String get buildInfoBranch => 'Branch';

  @override
  String get buildInfoCommitTime => 'Commit time';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Cargo target';

  @override
  String get buildInfoFeatures => 'Features';

  @override
  String get buildInfoOptLevel => 'Opt level';

  @override
  String get buildInfoDebug => 'Debug';

  @override
  String get nodeNotAvailable => 'Not available';
}
