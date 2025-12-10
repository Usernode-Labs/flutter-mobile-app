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
  String get importApiAccountTitle => 'Import Pre-configured Account';

  @override
  String get importApiAccountDesc =>
      'Import a pre-configured account from the API';

  @override
  String get importApiAccountContactLabel => 'Discord, Email, or Telegram';

  @override
  String get importApiAccountContactHint => '@username or name@example.com';

  @override
  String get importApiAccountCodeLabel => 'Activation Code';

  @override
  String get importApiAccountCodeHint => 'Enter your code';

  @override
  String get importApiAccountSubmit => 'Verify Code';

  @override
  String get importApiAccountFailed => 'Failed to import account from API';

  @override
  String importApiAccountRegistrationFailed(String error) {
    return 'Registration failed: $error';
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
  String get producedBlocksSuccessRateLast10Epochs =>
      'Block Success Rate · Last 10 Epochs';

  @override
  String producedBlocksTokensEarnedSummary(String earned, String possible) {
    return '+$earned \$TOKENS';
  }

  @override
  String get producedBlocksTokensEarnedLast10Epochs =>
      'Tokens Earned · Last 10 epochs';

  @override
  String producedBlocksEpochSlotProgress(int current, int total) {
    return 'Epoch Slot Progress: $current / $total';
  }

  @override
  String get producedBlocksZeroMinutesLeft => '0m left';

  @override
  String producedBlocksMinutesLeft(int minutes) {
    return '${minutes}m left';
  }

  @override
  String producedBlocksHoursMinutesLeft(int hours, int minutes) {
    return '${hours}h ${minutes}m left';
  }

  @override
  String get producedBlocksEpochPerformance => 'Epoch Performance';

  @override
  String get producedBlocksCheckedSlots => 'Checked Slots';

  @override
  String producedBlocksEvaluatedOfSlots(int evaluated, int total) {
    return 'Evaluated $evaluated of $total';
  }

  @override
  String producedBlocksProducedOfWon(String produced, String won) {
    return '$produced of $won produced this epoch';
  }

  @override
  String get producedBlocksMissedBlocksTitle => 'Missed Blocks';

  @override
  String producedBlocksMissedOfWon(String missed, String won) {
    return '$missed of $won missed this epoch';
  }

  @override
  String get producedBlocksUpcomingBlocksTitle => 'Upcoming Blocks';

  @override
  String producedBlocksUpcomingThisEpoch(String upcoming) {
    return '$upcoming upcoming this epoch';
  }

  @override
  String get producedBlocksSelectEpoch => 'Select Epoch';

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
  String get commonNoValuePlaceholder => '--';

  @override
  String get commonEmDash => '—';

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

  @override
  String get navProducedBlocks => 'Produced Blocks';

  @override
  String get navNodeStatus => 'Node Status';

  @override
  String get navSettings => 'Settings';

  @override
  String get welcomeClaimAccount => 'Claim your account';

  @override
  String get welcomeAlphaTitle => 'Alpha Phase';

  @override
  String get welcomeAlphaSubtitle =>
      'You made the first wave of people running an L1 on their mobile devices';

  @override
  String get welcomeAlphaClaimSpot => 'Claim your spot';

  @override
  String get onboardingVerifyAccessTitle => 'Verify access';

  @override
  String get onboardingVerifyAccessSubtitle =>
      'Use the username/registration code that has been shared with you. Username must be typed exactly as it appears in the registration email.';

  @override
  String onboardingWelcomeSetupTitle(String userId) {
    return 'Welcome, $userId';
  }

  @override
  String get onboardingWelcomeSetupBody =>
      'You are part of the initial test cohort. This app runs a block producing node.\n\nThe next steps will configure your device to produce blocks on demand.';

  @override
  String get onboardingWelcomeSetupStartButton => 'Start Setup';

  @override
  String get permExactAlarmsTitle => 'Exact Alarms';

  @override
  String get permExactAlarmsWhy => 'Why exact alarms are required';

  @override
  String get permExactAlarmsAndroidExplanation =>
      'Android restricts apps from waking the device at precise times unless explicitly allowed. Without this permission, alarms may be delayed by up to 10 minutes, causing missed blocks.\n\nDepending on your device, this permission may already be granted.';

  @override
  String get permExactAlarmsIosExplanation =>
      'This step is primarily for Android devices. You can continue.';

  @override
  String get permGrantExactAlarm => 'Grant exact alarm permission';

  @override
  String get permExactAlarmGranted => 'Exact alarm permission granted';

  @override
  String get permExactAlarmEnableInSettings =>
      'Please enable exact alarms in Settings';

  @override
  String get permGranted => 'Permission granted';

  @override
  String get permRequired => 'Permission required';

  @override
  String get commonNext => 'Next';

  @override
  String get commonFinish => 'Finish';

  @override
  String get permBatteryTitle => 'Allow Background Usage';

  @override
  String get permBatteryWhyMatters => 'Why this matters';

  @override
  String get permBatteryAndroidExplanation =>
      'Android\'s battery saver can delay or skip alarms to save power. Disabling battery optimization for this app ensures your wake-up alarms fire on time when blocks are scheduled to be produced.';

  @override
  String get permBatteryIosExplanation =>
      'This step applies to Android devices.';

  @override
  String get permBatteryImpact => 'Impact of battery optimization:';

  @override
  String get permBatteryWarning =>
      'Alarms may be delayed 1–60 seconds, or skipped entirely.';

  @override
  String get permBatteryOptimized =>
      'With optimization disabled, alarms fire precisely when scheduled.';

  @override
  String get permOpenBatterySettings => 'Open Settings';

  @override
  String permBatteryDeviceWarning(String manufacturer) {
    return '$manufacturer devices require additional settings. Tap Open Battery Settings for guidance.';
  }

  @override
  String get permBatteryOptDisabled => 'Battery optimization disabled';

  @override
  String get permBatteryOptEnabled => 'Battery optimization enabled';

  @override
  String get onboardingBatteryStepAppUsage => 'Tap \"App Battery Usage\"';

  @override
  String get onboardingBatteryStepAllowBackground =>
      'Turn \"Allow background usage\" ON';

  @override
  String get onboardingBatteryStepTapText =>
      'Tap the TEXT itself. Tap the words \"Allow background usage\" to open the detailed menu.';

  @override
  String get onboardingBatteryStepSelectUnrestricted => 'Select Unrestricted';

  @override
  String get onboardingBatteryStepReturnToApp =>
      'Tap the back button until you are back in the app.';

  @override
  String get onboardingBatteryUnrestrictedTitle => 'Background Usage Enabled';

  @override
  String get onboardingBatteryUnrestrictedBody =>
      'Great job! The app is now able to precisely schedule background block production.';

  @override
  String get onboardingBatteryDefaultTitle =>
      'Tap Continue to start the main app';

  @override
  String get onboardingBatteryDefaultBody =>
      'We strongly recommend you enable unrestricted battery optimizations to ensure consistent background block production.';

  @override
  String get permNotificationsTitle => 'Notifications';

  @override
  String get permNotificationsExplanation =>
      'Allow notifications to receive important updates. You can change this later in Settings.';

  @override
  String get permAllowNotifications => 'Allow notifications';

  @override
  String get permNotificationsBlockBackgroundTitle =>
      'Allow notifications to allow the app to make blocks in the background';

  @override
  String get permNotificationsBlockBackgroundBody =>
      'Android requires a visible status to allow the app to work in the background. Without it, the system will be unable to do background block production.';

  @override
  String get permNotificationsSkip => 'Skip';

  @override
  String get permNotificationsDisabledMessage =>
      'Notifications are currently disabled. You can enable them in Settings.';

  @override
  String get permOpenSettings => 'Open Settings';

  @override
  String get permNotificationsEnabled => 'Notifications enabled';

  @override
  String get permNotificationsDisabled => 'Notifications disabled';

  @override
  String get permNotificationsDenied => 'Notifications denied';

  @override
  String get permNotificationsPermanentlyDenied =>
      'Notifications permanently denied. Enable in Settings.';

  @override
  String permNotificationStatus(String status) {
    return 'Notification status: $status';
  }

  @override
  String get statsTitle => 'Production Statistics';

  @override
  String get statsOverall => 'Overall Statistics';

  @override
  String get statsWonSlots => 'Won Slots';

  @override
  String get statsAttempted => 'Attempted';

  @override
  String get statsProduced => 'Produced';

  @override
  String get statsFailed => 'Failed';

  @override
  String get statsLastUpdated => 'Last Updated';

  @override
  String get statsSuccessRate => 'Success Rate';

  @override
  String get statsNoRecords => 'No production records yet';

  @override
  String get statsRecentRecords => 'Recent Production Records';

  @override
  String statsEpoch(int epoch) {
    return 'Epoch $epoch';
  }

  @override
  String statsSlot(int slot) {
    return 'Slot $slot';
  }

  @override
  String statsBlock(int block) {
    return 'Block $block';
  }

  @override
  String statsSuccessfulOf(int produced, int attempted) {
    return '$produced successful out of $attempted attempts';
  }

  @override
  String get statsStatusWon => 'Won (not yet attempted)';

  @override
  String get statsStatusAttempting => 'Currently attempting production';

  @override
  String get statsStatusProduced => 'Successfully produced';

  @override
  String get statsStatusFailed => 'Production failed';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes minutes ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours hours ago';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get blockDetailsTitle => 'Block Details';

  @override
  String get blockVrfSlotDiscovered => 'VRF Slot Discovered';

  @override
  String blockSlotWon(int slot) {
    return 'Slot $slot won';
  }

  @override
  String get blockProductionScheduled => 'Block Production Scheduled';

  @override
  String blockEpochSlot(int epoch, int slot) {
    return 'Epoch $epoch, Slot $slot';
  }

  @override
  String get blockTxBatchesIncluded => 'Transaction Batches Included';

  @override
  String blockIncludedBatchesTx(int batches, int transactions) {
    return 'Included $batches batches / $transactions transactions';
  }

  @override
  String get blockIncludedBatchesTxGeneric => 'Included batches / transactions';

  @override
  String get blockStateTransition => 'State Transition.';

  @override
  String get blockStatesUpdated => 'Protocol and Consensus states updated';

  @override
  String get blockAppliedLocally => 'Applied Locally';

  @override
  String get blockUtxosUpdated => 'UTXOs updated';

  @override
  String get blockCommitted => 'Block Committed';

  @override
  String blockNumber(int height) {
    return 'Block #$height';
  }

  @override
  String get blockConfirmed => 'Block Confirmed';

  @override
  String blockHashPrefix(String hash) {
    return 'Hash: $hash...';
  }

  @override
  String get blockInformation => 'Block Information';

  @override
  String get blockHash => 'Block Hash';

  @override
  String get blockHeight => 'Height';

  @override
  String get blockGlobalSlot => 'Global Slot';

  @override
  String get blockEpoch => 'Epoch';

  @override
  String get blockProducer => 'Producer';

  @override
  String get blockTransactions => 'Transactions';

  @override
  String get blockBatches => 'Batches';

  @override
  String blockAtSlot(int height, int slot) {
    return 'Block #$height at Slot $slot';
  }

  @override
  String get mempoolTotal => 'Total';

  @override
  String get mempoolOrphans => 'Orphans';

  @override
  String get mempoolSize => 'Size';

  @override
  String get mempoolView => 'View';

  @override
  String get mempoolComingSoon => 'Coming Soon';

  @override
  String get mempoolDetailsComingSoon =>
      'Transaction details will be available in a future update.';

  @override
  String get nodeConnecting => 'Connecting';

  @override
  String get nodeSynced => 'Synced';

  @override
  String get nodeSyncing => 'Syncing';

  @override
  String nodeSyncingPercent(String percent) {
    return 'Syncing ($percent%)';
  }

  @override
  String get nodeOverview => 'Overview';

  @override
  String get nodePeerId => 'Peer ID: ';

  @override
  String get peerUnavailable => '(unavailable)';

  @override
  String get peerHiddenAddress => '(Hidden address)';

  @override
  String peerHeight(String height) {
    return 'Height: $height';
  }

  @override
  String peerSlot(String slot) {
    return 'Slot: $slot';
  }

  @override
  String get timeAMinuteAgo => 'a minute ago';

  @override
  String get timeAnHourAgo => 'an hour ago';

  @override
  String get timeYesterday => 'yesterday';

  @override
  String timeWeeksAgo(int weeks, String suffix) {
    return '$weeks week$suffix ago';
  }

  @override
  String timeMonthsAgo(int months, String suffix) {
    return '$months month$suffix ago';
  }

  @override
  String timeYearsAgo(int years, String suffix) {
    return '$years year$suffix ago';
  }
}
