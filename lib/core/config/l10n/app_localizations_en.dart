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
  String get perfScenarioDefault => 'Default case';

  @override
  String perfContextTxCount(int count) {
    return '$count tx';
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
  String get perfDetailBatchLayout => 'Batch Layout';

  @override
  String get perfDetailTransactionShape => 'Transaction Shape';

  @override
  String get perfDetailTouchedLeaves => 'Touched Leaves';

  @override
  String get perfDetailProofNodes => 'Proof Nodes';

  @override
  String get perfDetailProofSize => 'Proof Size';

  @override
  String get perfCancelFailed => 'Unable to cancel the current benchmark run.';

  @override
  String get perfRunUnavailable => 'This benchmark run is no longer available.';

  @override
  String get commonOk => 'OK';

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
  String get retry => 'Retry';

  @override
  String get zkIdentityAppNotFoundTitle => 'Install ZK Passport first';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'It creates your proof, then sends you back here';

  @override
  String get zkIdentityInstallCta => 'Install';

  @override
  String get zkIdentityStepLabelOpenApp => 'Opening ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp =>
      'Preparing a proof request with your saved passport';

  @override
  String get zkIdentityCheckAppCta => 'Continue';

  @override
  String get zkIdentityAccountPreparingTitle => 'Preparing your account';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'Connecting your signed-in Social Vibecoding account';

  @override
  String get zkIdentityAccountUnavailable =>
      'Sign in to Social Vibecoding before starting verification.';

  @override
  String get zkIdentityStepLabelScan => 'Use saved passport';

  @override
  String get zkIdentityStepDescScan =>
      'Uses the passport already stored in ZK Passport';

  @override
  String get zkIdentityConfirmScannedBody =>
      'Your saved passport will be used.';

  @override
  String get zkIdentityConfirmScannedYesCta => 'Continue';

  @override
  String get zkIdentityConfirmScannedNoCta => 'Not yet';

  @override
  String get zkIdentityStepLabelReady => 'Create proof';

  @override
  String get zkIdentityStepDescReady =>
      'ZK Passport will ask you to approve and create the proof';

  @override
  String get zkIdentityReadyBody =>
      'ZK Passport builds the proof from your saved passport in about a minute.';

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
  String get zkIdentityWalletClaimTitle => 'Connect your programme wallet';

  @override
  String get zkIdentityWalletClaimDescription =>
      'This Social account is different from the account that holds your existing wallet. Verify your original programme email once to connect it.';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'Original programme email';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'Use the email from your original Usernode programme registration.';

  @override
  String get zkIdentityWalletClaimSendCode => 'Send verification code';

  @override
  String get zkIdentityWalletClaimSendingCode => 'Sending code…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'Enter the 6-digit code sent to that email.';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'Verification code';

  @override
  String get zkIdentityWalletClaimConnect => 'Connect wallet and continue';

  @override
  String get zkIdentityWalletClaimConnecting => 'Connecting wallet…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'Use a different email';

  @override
  String get zkIdentityWalletClaimEmailRequired =>
      'Enter a valid email address.';

  @override
  String get zkIdentityWalletClaimCodeRequired => 'Enter the 6-digit code.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'Your wallet was connected, but the app could not finish preparing it. Try again.';

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
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCopied => 'Copied';

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
  String get networkSwitchRequiresSignOut =>
      'Sign out before switching networks.';

  @override
  String get networkRestartPreparing =>
      'Preparing the selected network. Do not close the app yet.';

  @override
  String get networkRestartFailed =>
      'The network change could not be saved. Close and reopen Usernode, then try again.';

  @override
  String networkSwitchedRestartIos(String network) {
    return 'Network switched to $network. Please manually close and reopen the app to connect to the new network.';
  }

  @override
  String networkSwitchedRestartAndroid(String network) {
    return 'Network switched to $network. The app will now close. Please reopen it to connect to the new network.';
  }

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
  String get widgetInstructionsTitle => 'Add the Usernode widget';

  @override
  String widgetInstructionsBody(String name) {
    return '$name was added to your Usernode dApps widget. To see it on your home screen, add the widget once:';
  }

  @override
  String get widgetInstructionsStep1 =>
      'Touch and hold an empty area of your home screen';

  @override
  String get widgetInstructionsStep2 =>
      'Tap Edit in the top corner, then Add Widget';

  @override
  String get widgetInstructionsStep3 =>
      'Search for Usernode and add the dApps widget';

  @override
  String get widgetInstructionsDone => 'Done';

  @override
  String get svShellConnectingTitle => 'Connecting to Usernode…';

  @override
  String get svShellOfflineMessage =>
      'Can\'t reach Usernode. Check your connection and try again.';

  @override
  String get stakingManagerTitle => 'Staking mode';

  @override
  String get stakingDelegateIntro =>
      'Delegate your stake to the server. Your node keeps running, but the server stakes on your behalf.';

  @override
  String get stakingServerName => 'Server';

  @override
  String get stakingDelegateEffect =>
      'Your node stops producing blocks. While delegated, you receive half the block-production points you would earn by producing blocks directly on this phone.';

  @override
  String get stakingDelegateNote =>
      'You can switch back to staking yourself at any time.';

  @override
  String get stakingDelegateConfirm => 'Confirm delegation';

  @override
  String get stakingDelegating => 'Delegating…';

  @override
  String get stakingDelegateError =>
      'Couldn\'t submit the delegation. Check your connection and try again.';

  @override
  String get stakingDelegationActiveTitle => 'Delegation active';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'Your stake is delegated to $validator. You receive half the block-production points you would earn by producing blocks directly on this phone.';
  }

  @override
  String get stakingDone => 'Done';

  @override
  String get stakingUndelegateTitle => 'Stop delegating?';

  @override
  String get stakingUndelegateBody =>
      'Your stake returns to this phone. Your node will produce blocks directly and earn the full block-production points.';

  @override
  String get stakingUndelegateConfirm => 'Stop delegating';

  @override
  String get stakingUndelegateError =>
      'Couldn\'t stop delegating. Check your connection and try again.';
}
