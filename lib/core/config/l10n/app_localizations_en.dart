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
  String get appSleepTitle => 'App asleep';

  @override
  String appSleepUntilSlot(int slotNumber, String dateTime) {
    return 'Sleeping until slot $slotNumber at $dateTime.';
  }

  @override
  String appSleepUntilTime(String dateTime) {
    return 'Sleeping until $dateTime.';
  }

  @override
  String get appSleepUntilUnknown =>
      'Sleeping until the next exact-alarm wake.';

  @override
  String get appSleepTapToWake => 'Tap anywhere to wake now.';

  @override
  String get initializingNode => 'Initializing node...';

  @override
  String get node => 'Node';

  @override
  String get clockDriftWarningTitle => 'System time incorrect';

  @override
  String clockDriftWarningBody(String drift) {
    return 'Your device clock differs from the node clock by $drift. You might see some inconsistencies in the app until your system time is corrected.';
  }

  @override
  String get clockDriftWarningInstruction =>
      'Enable automatic time sync on your device.';

  @override
  String get clockDriftRecommendationTitle => 'Recommendation';

  @override
  String get clockDriftRecommendationBody =>
      'To ensure minimum drift, keep \"Automatic date & time\" and \"Automatic time zone\" enabled in settings, which forces the device to query network time.';

  @override
  String get clockDriftDismiss => 'OK';

  @override
  String clockDriftAhead(String seconds) {
    return '${seconds}s ahead';
  }

  @override
  String clockDriftBehind(String seconds) {
    return '${seconds}s behind';
  }

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
  String get settingsDiagnostics => 'Diagnostics';

  @override
  String get settingsDeviceBenchmark => 'Device Benchmark';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'Run on-device performance measurements';

  @override
  String get perfTitle => 'Device Benchmark';

  @override
  String get perfIntroTitle => 'Run a benchmark on this device';

  @override
  String get perfIntroDescription =>
      'Measure hashing, partial sync, block production, and wallet-send workloads to see how this device performs.';

  @override
  String get perfIntroNote =>
      'Results stay on this device for now. Performance can vary with battery level, thermals, and background activity.';

  @override
  String get perfCatalogLoadError => 'Unable to load the benchmark catalog.';

  @override
  String get perfCatalogLoading => 'Loading benchmark catalog...';

  @override
  String get perfProfileQuick => 'Quick Check';

  @override
  String get perfProfileStandard => 'Full Benchmark';

  @override
  String perfRunProfile(String profile) {
    return 'Run $profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count steps';
  }

  @override
  String get perfRunning => 'Running';

  @override
  String get perfCurrentRunTitle => 'Current Run';

  @override
  String get perfRunInProgressTitle => 'Benchmark In Progress';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'A $profile benchmark is already running on this device.';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'A benchmark is already running on this device.';

  @override
  String get perfOpenCurrentRun => 'Open Current Run';

  @override
  String get perfLatestResultsTitle => 'Latest Results';

  @override
  String perfLatestResultsDescription(String profile) {
    return '$profile results are ready to review.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'Benchmark results are ready to review.';

  @override
  String get perfViewLatestResults => 'View Latest Results';

  @override
  String get perfNoRunAvailableTitle => 'No Benchmark Run';

  @override
  String get perfNoRunAvailableDescription =>
      'Start a benchmark from the benchmark screen to see progress or results here.';

  @override
  String get perfBackToBenchmarks => 'Back To Benchmarks';

  @override
  String get perfRunPausedNodeNotice =>
      'Background node is paused while this benchmark runs.';

  @override
  String get perfStateRunning => 'Running';

  @override
  String get perfStateStarting => 'Starting';

  @override
  String get perfStateCompleted => 'Completed';

  @override
  String get perfStateFailed => 'Failed';

  @override
  String get perfStateCancelled => 'Cancelled';

  @override
  String perfProgressValue(int completed, int total) {
    return '$completed of $total steps';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'Preparing $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'Current step: $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'Elapsed: $duration';
  }

  @override
  String get perfResultsTitle => 'Results';

  @override
  String get perfResultProfile => 'Profile';

  @override
  String get perfResultDevice => 'Device';

  @override
  String get perfResultOperatingSystem => 'OS';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => 'Logical Cores';

  @override
  String get perfResultMeasurements => 'Measurements';

  @override
  String get perfSuitePrimitives => 'Primitives';

  @override
  String get perfSuitePartialSync => 'Partial Sync';

  @override
  String get perfSuitePartialBlockProduction => 'Block Production';

  @override
  String get perfSuiteWalletSend => 'Wallet Send';

  @override
  String perfMinMax(String minValue, String maxValue) {
    return 'Min $minValue · Max $maxValue';
  }

  @override
  String perfRuns(int count) {
    return '$count runs';
  }

  @override
  String perfFlow(String value) {
    return 'Flow: $value';
  }

  @override
  String get perfScenarioDefault => 'Default case';

  @override
  String perfContextTxCount(int count) {
    return '$count tx';
  }

  @override
  String perfContextReplayBlockCount(int count) {
    return '$count replay blocks';
  }

  @override
  String perfContextTxCountPerBlock(int count) {
    return '$count tx/block';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'Layout $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'Shape $value';
  }

  @override
  String perfContextProofNodes(int count) {
    return '$count proof nodes';
  }

  @override
  String perfContextAnchorProofNodes(int count) {
    return '$count anchor proof nodes';
  }

  @override
  String perfContextReplayBlockProofNodes(int count) {
    return '$count replay proof nodes';
  }

  @override
  String perfContextProofSize(String size) {
    return '$size proof';
  }

  @override
  String perfContextTouchedLeaves(String count) {
    return '$count touched leaves';
  }

  @override
  String get perfDetailScenario => 'Scenario';

  @override
  String get perfDetailAverage => 'Average';

  @override
  String get perfDetailMinMax => 'Min / Max';

  @override
  String get perfDetailRuns => 'Runs';

  @override
  String get perfDetailMetadataTitle => 'Scenario Details';

  @override
  String get perfDetailImplementationTitle => 'Implementation Details';

  @override
  String get perfDetailNotesTitle => 'Notes';

  @override
  String get perfDetailFlow => 'Flow';

  @override
  String get perfDetailTxCount => 'Transaction Count';

  @override
  String get perfDetailReplayBlockCount => 'Replay Blocks';

  @override
  String get perfDetailTxCountPerBlock => 'Transactions Per Block';

  @override
  String get perfDetailBatchLayout => 'Batch Layout';

  @override
  String get perfDetailTransactionShape => 'Transaction Shape';

  @override
  String get perfDetailTouchedLeaves => 'Touched Leaves';

  @override
  String get perfDetailProofNodes => 'Proof Nodes';

  @override
  String get perfDetailAnchorProofNodes => 'Anchor Proof Nodes';

  @override
  String get perfDetailReplayBlockProofNodes => 'Replay Proof Nodes';

  @override
  String get perfDetailProofSize => 'Proof Size';

  @override
  String get perfCancelFailed => 'Unable to cancel the current benchmark run.';

  @override
  String get perfRunUnavailable => 'This benchmark run is no longer available.';

  @override
  String get bgProdWhatIs => 'What is Block Production?';

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
  String get walletNoRecentActivity => 'No transactions to display so far';

  @override
  String get walletNoRecentActivitySubtitle =>
      'This page refreshes continuously and will display your transactions here.';

  @override
  String get walletEmptyStateSendAction => 'Send Transaction';

  @override
  String get nodeStatusTitle => 'Node Status';

  @override
  String get nodeSectionNetwork => 'Network';

  @override
  String get nodeSectionChainState => 'Chain state';

  @override
  String get nodePeerIdCopied => 'Peer ID copied to clipboard';

  @override
  String get nodeChainIdCopied => 'Chain ID copied to clipboard';

  @override
  String get nodeBestTipCopied => 'Best tip hash copied to clipboard';

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
  String get navProducedBlocks => 'Blocks';

  @override
  String get navWallet => 'Wallet';

  @override
  String get navDapps => 'dApps';

  @override
  String get navNodeStatus => 'Node Status';

  @override
  String get navChallenges => 'Challenges';

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
      'Android\'s battery optimization can delay or prevent background tasks from running. Disabling it for this app ensures it can wake up on time to produce your scheduled blocks, even when the phone is idle. Settings may vary by device.';

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
  String get onboardingBatteryStepAppUsage =>
      'Look for \"Battery\", \"App Battery Usage\", or \"Battery Optimization\" in the settings page';

  @override
  String get onboardingBatteryStepAllowBackground =>
      'Disable battery optimization or set the app to \"Unrestricted\" / \"No restrictions\" / \"Don\'t optimize\"';

  @override
  String get onboardingBatteryStepTapText =>
      'If available, tap on \"Allow background usage\" to access more options';

  @override
  String get onboardingBatteryStepSelectUnrestricted => 'Select Unrestricted';

  @override
  String get onboardingBatteryStepReturnToApp =>
      'Tap the back button until you return to the app';

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
      'Allow notifications to maximize your block production success rate';

  @override
  String get permNotificationsBlockBackgroundBody =>
      'Notifications are essential for background block production. They alert you when your slots are coming up and ensure the app stays active to produce blocks.';

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

  @override
  String get leaderboardFailedToLoad => 'Failed to load leaderboard';

  @override
  String get retry => 'Retry';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get allParticipants => 'All Participants';

  @override
  String participantFallbackName(String id) {
    return 'Participant $id';
  }

  @override
  String pointsAbbreviated(String points) {
    return '$points pts';
  }

  @override
  String betterThanPercent(int percent) {
    return 'Better than $percent% of participants';
  }

  @override
  String get leaderboardClimbEncouragement =>
      'Keep completing tasks to climb higher on the leaderboard.';

  @override
  String leaderboardTopPercent(int percent) {
    return 'You\'re in the top $percent%! Keep completing challenges to secure your position.';
  }

  @override
  String get totalPointsLabel => 'TOTAL POINTS';

  @override
  String get rankLabel => 'RANK';

  @override
  String pointsRangeBucket(String lo, String hi) {
    return '$lo–$hi pts';
  }

  @override
  String get categoryTechnical => 'Technical';

  @override
  String get categoryCommunity => 'Community';

  @override
  String get categoryFlash => 'Flash';

  @override
  String get allEvents => 'All Events';

  @override
  String get allSeasons => 'All Seasons';

  @override
  String get selectSeason => 'Select Season';

  @override
  String get selectEvent => 'Select Event';

  @override
  String get eventEnded => 'Ended';

  @override
  String get challengeFailedToLoad => 'Failed to load challenges';

  @override
  String get challengeNoActive => 'No active challenges right now.';

  @override
  String get challengeNoCompleted => 'No completed challenges';

  @override
  String get challengeNoMissed => 'No missed challenges';

  @override
  String get challengePoints => 'points';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileCompletedChallengesTab => 'Completed Challenges';

  @override
  String get profileNoCompletedChallengesYet => 'No completed challenges yet.';

  @override
  String get profileLeaderboardUnavailable => 'Leaderboard unavailable.';

  @override
  String get challengeViewInLeaderboard => 'View in Leaderboard';

  @override
  String challengeRank(int rank) {
    return 'Rank $rank';
  }

  @override
  String challengeTotalReward(String reward) {
    return 'Total Reward $reward';
  }

  @override
  String get challengeSectionTheWhy => 'Why it matters';

  @override
  String get challengeSectionTask => 'Task';

  @override
  String get challengeSectionAvailable => 'Available';

  @override
  String get challengeSectionHowPointsWork => 'How points work';

  @override
  String get challengeSectionRules => 'Rules';

  @override
  String get challengeSectionRequirements => 'Requirements';

  @override
  String get challengeAvailableNow => 'Available now';

  @override
  String get challengeDefaultPointsLogic =>
      'Points are awarded once this challenge is completed and verified.';

  @override
  String get challengeDefaultCta => 'Join the challenge';

  @override
  String get challengePhaseNotDone => 'Not done';

  @override
  String get challengePhaseInProgress => 'In progress';

  @override
  String get challengePhaseSubmitted => 'Submitted';

  @override
  String get challengePhaseWaitingReview => 'waiting review';

  @override
  String get challengePhaseDone => 'Done';

  @override
  String get challengeBandFeatured => 'Featured';

  @override
  String get challengeBandToday => 'Today';

  @override
  String get challengeBandThisWeek => 'This week';

  @override
  String get challengeBandSeason => 'Season';

  @override
  String get challengeEpochNoChange => '+0';

  @override
  String get challengeEpochLast24h => 'Last 24h';

  @override
  String get challengeViewEpochDetails => 'View Details';

  @override
  String get zkIdentityChallengeTitle => 'Prove you\'re a unique human';

  @override
  String get zkIdentityDetailStartCta => 'Start';

  @override
  String get zkIdentityDetailContinueCta => 'Continue';

  @override
  String get zkIdentityAppNotFoundTitle => 'Install ZK Passport first';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'It creates your proof, then sends you back here';

  @override
  String get zkIdentityInstallCta => 'Install';

  @override
  String get zkIdentityStepLabelOpenApp => 'Open ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp => 'Make sure ZK Passport is installed';

  @override
  String get zkIdentityCheckAppCta => 'Continue';

  @override
  String get zkIdentityStepLabelScan => 'Scan your passport';

  @override
  String get zkIdentityStepDescScan =>
      'Scan once in ZK Passport. It\'s saved for next time.';

  @override
  String get zkIdentityConfirmScannedBody => 'Already scanned?';

  @override
  String get zkIdentityConfirmScannedYesCta => 'Continue';

  @override
  String get zkIdentityConfirmScannedNoCta => 'Not yet';

  @override
  String get zkIdentityStepLabelReady => 'Ready to verify';

  @override
  String get zkIdentityStepDescReady =>
      'Switch to ZK Passport to build your proof';

  @override
  String get zkIdentityReadyBody =>
      'Switch to ZK Passport. It builds your proof in about a minute.';

  @override
  String get zkIdentityReadyBullet1 => 'No name, photo, or ID is shared';

  @override
  String get zkIdentityReadyBullet2 => 'You send only a proof';

  @override
  String get zkIdentityReadyBullet3 => 'Nothing personal is stored on-chain';

  @override
  String get zkIdentityReadyCta => 'Open ZK Passport';

  @override
  String get zkIdentityStepLabelVerifying => 'Verifying';

  @override
  String get zkIdentityStepDescVerifying => 'Building and checking your proof';

  @override
  String get zkIdentityStepLabelResult => 'Result';

  @override
  String get zkIdentityStepDescResult =>
      'View the outcome of your verification';

  @override
  String get zkIdentitySubTaskOpening => 'Opening ZK Passport';

  @override
  String get zkIdentitySubTaskWaiting => 'Waiting for your proof';

  @override
  String get zkIdentitySubTaskChecking => 'Checking your proof';

  @override
  String get zkIdentitySubTaskWrapping => 'Wrapping your proof';

  @override
  String get zkIdentitySubTaskFinal => 'Final check';

  @override
  String get zkIdentityResultSuccessTitle => 'You\'re a unique human!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'You proved you\'re unique without sharing your name, photo, or ID';

  @override
  String get zkIdentityStatusUniqueness => 'Unique human';

  @override
  String get zkIdentityStatusUniquenessValue => 'Confirmed';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'Face check';

  @override
  String get zkIdentityStatusPrivacyValue => 'Nothing shared';

  @override
  String get zkIdentityCancelVerification => 'Cancel';

  @override
  String get zkIdentityGoToZkPassport => 'Switch to ZK Passport';

  @override
  String get zkIdentityTryAgain => 'Try again';

  @override
  String get zkIdentityDone => 'Done';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'Verified';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'Skipped';

  @override
  String get zkIdentityStatusPrivacyLabel => 'Privacy';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'Verified on';

  @override
  String get zkIdentityStatusProofIdLabel => 'Proof ID';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'Verify';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'Wrap';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'Final check';

  @override
  String get zkIdentityResultFailureTitle => 'Couldn\'t verify';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'You didn\'t share your name, photo, or ID';

  @override
  String get walletSentSuccessfully => 'Sent successfully!';

  @override
  String walletSentDetail(String amount, String tokenSymbol, String address) {
    return '$amount $tokenSymbol sent to\n$address';
  }

  @override
  String get walletTransactionFailed => 'Transaction Failed';

  @override
  String get walletTransactionFailedGeneric =>
      'An error occurred while processing your transaction';

  @override
  String get walletAddressCopied => 'Address copied to clipboard';

  @override
  String get walletRecentActivity => 'Recent Activity';

  @override
  String get walletExplorerUnavailable =>
      'Explorer API unavailable. Showing cached data.';

  @override
  String get walletTransactionsError => 'Error loading transactions';

  @override
  String get walletTokenBalance => '\$TOKEN Balance';

  @override
  String get walletSyncInProgress => 'Sync in progress...';

  @override
  String get walletMyAddress => 'My address';

  @override
  String get walletReceive => 'Receive';

  @override
  String get walletCopyAddress => 'Copy address';

  @override
  String get walletRecipientAddress => 'Recipient address';

  @override
  String get walletRecentRecipients => 'Recent Recipients';

  @override
  String get walletFee => 'Fee';

  @override
  String get walletMemoOptional => 'Memo (optional)';

  @override
  String get walletSending => 'Sending...';

  @override
  String walletFieldRequired(String fieldName) {
    return 'Please enter a $fieldName';
  }

  @override
  String walletFieldTooShort(String fieldName) {
    return '$fieldName appears to be too short';
  }

  @override
  String walletFieldInvalid(String fieldName) {
    return 'Please enter a valid $fieldName';
  }

  @override
  String get walletNoRecentAddresses => 'No recent addresses';

  @override
  String get nodeOffline => 'Offline';

  @override
  String get nodeConnectingEllipsis => 'Connecting...';

  @override
  String get nodeLoadedGenesis => 'Loaded genesis';

  @override
  String get nodeChainSynced => 'Chain Synced';

  @override
  String get nodeSyncingBlocks => 'Syncing blocks';

  @override
  String nodeFetchApplyProgress(int fetchPct, int applyPct) {
    return '$fetchPct % Fetched  ·  $applyPct % Applied';
  }

  @override
  String get nodePeers => 'Peers';

  @override
  String get nodeMempool => 'Mempool';

  @override
  String nodePeersConnected(int connected, int total) {
    return '$connected/$total connected';
  }

  @override
  String nodeEpochN(int epoch) {
    return 'Epoch $epoch';
  }

  @override
  String nodeGlobalSlot(int slot) {
    return 'Global slot $slot';
  }

  @override
  String nodeMempoolSummary(int count, String sizeKB) {
    return '$count txns · $sizeKB KB';
  }

  @override
  String get nodeVrf => 'VRF';

  @override
  String nodeVrfEvaluated(int evaluated, int total) {
    return 'Evaluated $evaluated/$total';
  }

  @override
  String get nodeVrfEvaluatedNA => 'Evaluated ---';

  @override
  String get nodeBestTip => 'Best Tip';

  @override
  String get nodeVrfCompleted => 'Completed';

  @override
  String get nodeVrfEvaluating => 'Evaluating';

  @override
  String get nodeVrfPendingLabel => 'Pending';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonFix => 'Fix';

  @override
  String commonLastCheckedAt(String time) {
    return 'Last checked at $time';
  }

  @override
  String commonLastCheckedOnAt(String date, String time) {
    return 'Last checked on $date at $time';
  }

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAutomaticAppSleep => 'Sleep On Inactivity';

  @override
  String get settingsAutomaticAppSleepEnabled =>
      'Force the app to sleep when it becomes inactive, even if the display stays on. This helps avoid unnecessary battery and bandwidth drain in always-on setups.';

  @override
  String get settingsAutomaticAppSleepDisabled =>
      'When disabled, the app will not force itself to sleep during inactivity. In always-on setups with the display left on, enabling this avoids unnecessary battery and bandwidth drain.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsPermissions => 'Permissions';

  @override
  String get settingsPermAllGood => 'All Good';

  @override
  String get settingsPermActionNeeded => 'Action Needed';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsForegroundKeepAlive => 'Foreground Keep-Alive';

  @override
  String get settingsKeepAliveActive => 'Active — 99% reliability';

  @override
  String get settingsKeepAliveInactive => 'Enable for critical slots';

  @override
  String get settingsBatteryOptimization => 'Battery Optimization';

  @override
  String get settingsBatteryOptDisabled => 'Disabled (recommended)';

  @override
  String get settingsBatteryOptWarning => 'May delay or skip alarms';

  @override
  String settingsManufacturerWarning(String manufacturer) {
    return '$manufacturer devices have aggressive battery management that may kill apps. Check your device\'\'s battery manager.';
  }

  @override
  String get settingsPermGrantedSnackbar => 'Permissions granted successfully';

  @override
  String get settingsPermDeniedSnackbar =>
      'Please grant permissions in settings';

  @override
  String get settingsHelpAndInfo => 'Help & Info';

  @override
  String get permRequiredBlockTiming => 'Required for precise block timing';

  @override
  String get permRequiredSlotAlerts => 'Required for slot alerts';

  @override
  String get themeSystem => 'System';

  @override
  String get themeSystemSubtitle => 'Follow your device setting';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get buildInfoAppVersion => 'App Version';

  @override
  String get buildInfoBuildNumber => 'Build Number';

  @override
  String get networkSwitcherTitle => 'Network Switcher';

  @override
  String get networkSelectNetwork => 'SELECT NETWORK';

  @override
  String get networkTestnetDesc => 'Default network';

  @override
  String get networkInternalDesc => 'Development network';

  @override
  String get networkActive => 'Active';

  @override
  String get networkNoChange => 'No Change';

  @override
  String get networkSwitch => 'Switch Network';

  @override
  String get networkEnterCode => 'Enter Code';

  @override
  String get networkCodeHint => '4-digit code';

  @override
  String get networkRestartRequired => 'Restart Required';

  @override
  String networkSwitchedRestartIos(String network) {
    return 'Network switched to $network. Please manually close and reopen the app to connect to the new network.';
  }

  @override
  String networkSwitchedRestartAndroid(String network) {
    return 'Network switched to $network. The app will now close. Please reopen it to connect to the new network.';
  }

  @override
  String get networkCloseApp => 'Close App';

  @override
  String get faqAboutDescription =>
      'Your device is part of a new network. It verifies, executes, and contributes compute directly to the network, passively in the background - with no central servers, no hidden infra. As long as users keep the app running, the network will continue to operate, peer to peer, with no external dependencies.\n\nWe\'\'re doing this to enable networks that can be hosted end-to-end by their own communities - both for decentralization, and to enable a natural coordination point around participation, where users who help operate and contribute to systems directly realize the benefits from it.\n\nRight now we are in testnet as we validate the core layer: block production, consensus behavior, and network reliability. As these stabilize, we\'\'ll build upon the unique features of the platform - its decentralization, zero knowledge proofs, and sybil-resistant identity - to introduce new activities, coordination mechanisms, and tools for self-hosted, sybil-resistant communities.\n\nThanks for helping test at this early stage. The app right now is simple, but as we prove out the core functionality, we hope to make possible a new kind of community-owned network, where users can directly run and benefit from the networks they use.';

  @override
  String get faqPlatformReliabilityTitle => 'Platform & Reliability';

  @override
  String faqDeviceLabel(String manufacturer) {
    return 'Device: $manufacturer';
  }

  @override
  String get faqVrfSlotsTitle => 'Understanding VRF & Slots';

  @override
  String get faqVrfWhatIsTitle => 'What is VRF?';

  @override
  String get faqVrfWhatIsDescription =>
      'VRF (Verifiable Random Function) is how the network fairly selects block producers. At the start of each epoch, the network runs VRF calculations to determine which validators will produce blocks in upcoming slots.';

  @override
  String get faqVrfStatusMeaningsTitle => 'VRF Status Meanings';

  @override
  String get faqVrfStatusPending => 'Pending';

  @override
  String get faqVrfStatusPendingDesc =>
      'Waiting for epoch transition to start calculations';

  @override
  String get faqVrfStatusCalculating => 'Calculating';

  @override
  String get faqVrfStatusCalculatingDesc =>
      'VRF evaluation in progress (takes a few hours)';

  @override
  String get faqVrfStatusComplete => 'Complete';

  @override
  String get faqVrfStatusCompleteDesc =>
      'Slot assignments are finalized and scheduled';

  @override
  String get faqVrfWonSlotTitle => 'What is a \"Won Slot\"?';

  @override
  String get faqVrfWonSlotDescription =>
      'When VRF selects your node to produce a block at a specific time, you\'\'ve \"won\" that slot. Your responsibility is to have your device awake and connected so the block can be produced.';

  @override
  String get faqVrfTimingTitle => 'Why Timing Matters';

  @override
  String get faqVrfTimingDescription =>
      'Each slot has a ~5-seconds window. If your device doesn\'\'t wake up in time or loses network connectivity, the slot is missed and counted as \"failed.\"';

  @override
  String get blockAppliedLocally => 'Applied Locally';

  @override
  String blockAtSlot(int height, int slot) {
    return 'Block #$height at Slot $slot';
  }

  @override
  String get blockBatches => 'Batches';

  @override
  String get blockCommitted => 'Block Committed';

  @override
  String get blockConfirmed => 'Block Confirmed';

  @override
  String get blockDetailsTitle => 'Block Details';

  @override
  String get blockEpoch => 'Epoch';

  @override
  String blockEpochSlot(int epoch, int slot) {
    return 'Epoch $epoch, Slot $slot';
  }

  @override
  String get blockGlobalSlot => 'Global Slot';

  @override
  String get blockHash => 'Block Hash';

  @override
  String blockHashPrefix(String hash) {
    return 'Hash: $hash...';
  }

  @override
  String get blockHeight => 'Height';

  @override
  String blockIncludedBatchesTx(int batches, int transactions) {
    return 'Included $batches batches / $transactions transactions';
  }

  @override
  String get blockIncludedBatchesTxGeneric => 'Included batches / transactions';

  @override
  String get blockInformation => 'Block Information';

  @override
  String blockNumber(int height) {
    return 'Block #$height';
  }

  @override
  String get blockProducer => 'Producer';

  @override
  String get blockProductionScheduled => 'Block Production Scheduled';

  @override
  String blockSlotWon(int slot) {
    return 'Slot $slot won';
  }

  @override
  String get blockStateTransition => 'State Transition.';

  @override
  String get blockStatesUpdated => 'Protocol and Consensus states updated';

  @override
  String get blockTransactions => 'Transactions';

  @override
  String get blockTxBatchesIncluded => 'Transaction Batches Included';

  @override
  String get blockUtxosUpdated => 'UTXOs updated';

  @override
  String get blockVrfSlotDiscovered => 'VRF Slot Discovered';

  @override
  String get nodeApplyPhase => 'Apply';

  @override
  String get nodeBestTipBadge => 'BEST TIP';

  @override
  String get nodeFetchPhase => 'Fetch';

  @override
  String nodePhaseDone(String count) {
    return 'Done: $count';
  }

  @override
  String nodePhaseIdle(String count) {
    return 'Idle: $count';
  }

  @override
  String nodePhasePending(String count) {
    return 'Pending: $count';
  }

  @override
  String get nodeRecentBlocks => 'Recent Blocks';

  @override
  String get nodeViewAll => 'View All';

  @override
  String get producedBlocksNoData => 'No produced blocks available';

  @override
  String get importApiAccountKeyDerivationFailed =>
      'Account setup failed. Please try again or contact support.';

  @override
  String get importApiAccountStorageFailed =>
      'Could not save account securely. Please check device storage and try again.';

  @override
  String get importApiAccountBackendStartFailed =>
      'Account created, but node startup failed. The app will retry automatically.';

  @override
  String get registrationUsernameEmpty => 'Please enter your username.';

  @override
  String get registrationCodeEmpty => 'Please enter your activation code.';

  @override
  String get registrationTimeoutError =>
      'Connection timed out. Please check your internet and try again.';

  @override
  String get registrationNetworkError =>
      'Could not reach the server. Please check your internet and try again.';

  @override
  String get registrationUnexpectedError =>
      'An unexpected error occurred. Please try again or contact support.';

  @override
  String get registrationStaleTitle => 'Registration Expired';

  @override
  String get registrationStaleBody =>
      'Your registration is from a previous season. Blocks produced with old credentials won\'t earn points. Please contact the team on Discord for assistance.';

  @override
  String get registrationStaleAction => 'Contact us on Discord';

  @override
  String get walletScan => 'Scan';

  @override
  String get walletScanTitle => 'Scan QR Code';

  @override
  String get walletScanInvalidQr => 'Invalid QR code';

  @override
  String get walletScanUnsupportedType => 'Unsupported QR code type';

  @override
  String get walletScanCameraPermissionDenied =>
      'Camera permission denied. Enable it in Settings to scan QR codes.';

  @override
  String get settingsDebugMode => 'Debug Mode';

  @override
  String get settingsDebugModeEnabled => 'Capturing HTTP requests to memory';

  @override
  String get settingsDebugModeDisabled => 'Off · no network logging';

  @override
  String get settingsHttpLogs => 'HTTP Logs';

  @override
  String get settingsHttpLogsSubtitle => 'View captured network requests';

  @override
  String get httpLogsTitle => 'HTTP Logs';

  @override
  String get httpLogsEmpty =>
      'No requests captured yet. Trigger some network activity to see logs here.';

  @override
  String get httpLogsCopy => 'Copy all';

  @override
  String get httpLogsClear => 'Clear';

  @override
  String get httpLogsCopied => 'Logs copied to clipboard';

  @override
  String get httpLogsShare => 'Share the logs with the team';

  @override
  String get httpLogsSharing => 'Sharing logs with the team every 30s…';

  @override
  String get httpLogsStopSharing => 'Stop sharing';

  @override
  String get httpLogsShareStopped =>
      'The server stopped log sharing. You can share again anytime.';

  @override
  String get httpLogsShareNoParticipant =>
      'No participant ID yet — finish onboarding to share logs';

  @override
  String get httpLogsFilterHint => 'Filter by URL';

  @override
  String get httpLogsNoMatches => 'No requests match the filter.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count of $total';
  }

  @override
  String get participantRecoveryTitle => 'Onboarding has evolved';

  @override
  String get participantRecoveryBody =>
      'Set your Discord handle and registration code again to restore your leaderboard participation.';

  @override
  String get participantRecoveryRestore => 'Restore';

  @override
  String get participantRecoveryLater => 'Later';

  @override
  String get participantRecoverySuccess =>
      'Leaderboard participation restored.';
}
