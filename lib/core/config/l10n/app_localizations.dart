import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'Usernode'**
  String get appName;

  /// Application tagline
  ///
  /// In en, this message translates to:
  /// **'Your Gateway to DeFi'**
  String get appTagline;

  /// Loading text on splash screen
  ///
  /// In en, this message translates to:
  /// **'Initializing node...'**
  String get initializingNode;

  /// Title for the clock drift warning dialog
  ///
  /// In en, this message translates to:
  /// **'System time incorrect'**
  String get clockDriftWarningTitle;

  /// Body text for the clock drift warning dialog
  ///
  /// In en, this message translates to:
  /// **'Your device clock differs from the node clock by {drift}. You might see some inconsistencies in the app until your system time is corrected.'**
  String clockDriftWarningBody(String drift);

  /// Instruction for fixing clock drift
  ///
  /// In en, this message translates to:
  /// **'Enable automatic time sync on your device.'**
  String get clockDriftWarningInstruction;

  /// Recommendation heading in the clock drift warning dialog
  ///
  /// In en, this message translates to:
  /// **'Recommendation'**
  String get clockDriftRecommendationTitle;

  /// Recommendation body in the clock drift warning dialog
  ///
  /// In en, this message translates to:
  /// **'To ensure minimum drift, keep \"Automatic date & time\" and \"Automatic time zone\" enabled in settings, which forces the device to query network time.'**
  String get clockDriftRecommendationBody;

  /// Dismiss button label for the clock drift warning dialog
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get clockDriftDismiss;

  /// Describes a positive clock drift
  ///
  /// In en, this message translates to:
  /// **'{seconds}s ahead'**
  String clockDriftAhead(String seconds);

  /// Describes a negative clock drift
  ///
  /// In en, this message translates to:
  /// **'{seconds}s behind'**
  String clockDriftBehind(String seconds);

  /// About section header
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Build info setting label
  ///
  /// In en, this message translates to:
  /// **'Build Info'**
  String get settingsBuildInfo;

  /// Diagnostics section header in settings
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnostics;

  /// Settings tile title for the device benchmark screen
  ///
  /// In en, this message translates to:
  /// **'Device Benchmark'**
  String get settingsDeviceBenchmark;

  /// Settings tile subtitle for the device benchmark screen
  ///
  /// In en, this message translates to:
  /// **'Run on-device performance measurements'**
  String get settingsDeviceBenchmarkSubtitle;

  /// Title for the device benchmark screen
  ///
  /// In en, this message translates to:
  /// **'Device Benchmark'**
  String get perfTitle;

  /// Intro card title for the device benchmark screen
  ///
  /// In en, this message translates to:
  /// **'Run a benchmark on this device'**
  String get perfIntroTitle;

  /// Intro description for the device benchmark screen
  ///
  /// In en, this message translates to:
  /// **'Measure hashing, partial sync, block production, and wallet-send workloads to see how this device performs.'**
  String get perfIntroDescription;

  /// Intro note for the device benchmark screen
  ///
  /// In en, this message translates to:
  /// **'Results stay on this device for now. Performance can vary with battery level, thermals, and background activity.'**
  String get perfIntroNote;

  /// Fallback error shown when the benchmark catalog cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Unable to load the benchmark catalog.'**
  String get perfCatalogLoadError;

  /// Status text shown while the benchmark catalog is being loaded
  ///
  /// In en, this message translates to:
  /// **'Loading benchmark catalog...'**
  String get perfCatalogLoading;

  /// Label for the quick device benchmark profile
  ///
  /// In en, this message translates to:
  /// **'Quick Check'**
  String get perfProfileQuick;

  /// Label for the standard device benchmark profile
  ///
  /// In en, this message translates to:
  /// **'Full Benchmark'**
  String get perfProfileStandard;

  /// Button label for running a benchmark profile
  ///
  /// In en, this message translates to:
  /// **'Run {profile}'**
  String perfRunProfile(String profile);

  /// Label showing how many steps a benchmark profile runs
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String perfStepCount(int count);

  /// Section title for the active benchmark run card
  ///
  /// In en, this message translates to:
  /// **'Current Run'**
  String get perfCurrentRunTitle;

  /// Launcher card title shown when a benchmark is already running
  ///
  /// In en, this message translates to:
  /// **'Benchmark In Progress'**
  String get perfRunInProgressTitle;

  /// Launcher description shown when a benchmark is already running
  ///
  /// In en, this message translates to:
  /// **'A {profile} benchmark is already running on this device.'**
  String perfRunInProgressDescription(String profile);

  /// Launcher description shown when a benchmark is already running but the profile is unknown
  ///
  /// In en, this message translates to:
  /// **'A benchmark is already running on this device.'**
  String get perfRunInProgressDescriptionUnknown;

  /// Button label used to open the dedicated current benchmark run screen
  ///
  /// In en, this message translates to:
  /// **'Open Current Run'**
  String get perfOpenCurrentRun;

  /// Launcher card title shown when a benchmark result is available
  ///
  /// In en, this message translates to:
  /// **'Latest Results'**
  String get perfLatestResultsTitle;

  /// Launcher description shown when benchmark results are available
  ///
  /// In en, this message translates to:
  /// **'{profile} results are ready to review.'**
  String perfLatestResultsDescription(String profile);

  /// Launcher description shown when benchmark results are available but the profile is unknown
  ///
  /// In en, this message translates to:
  /// **'Benchmark results are ready to review.'**
  String get perfLatestResultsDescriptionUnknown;

  /// Button label used to open the latest benchmark results screen
  ///
  /// In en, this message translates to:
  /// **'View Latest Results'**
  String get perfViewLatestResults;

  /// Title shown on the run screen when no benchmark is available
  ///
  /// In en, this message translates to:
  /// **'No Benchmark Run'**
  String get perfNoRunAvailableTitle;

  /// Description shown on the run screen when no benchmark is available
  ///
  /// In en, this message translates to:
  /// **'Start a benchmark from the benchmark screen to see progress or results here.'**
  String get perfNoRunAvailableDescription;

  /// Button label used to return to the benchmark launcher
  ///
  /// In en, this message translates to:
  /// **'Back To Benchmarks'**
  String get perfBackToBenchmarks;

  /// Notice shown on the run screen indicating the background node is paused
  ///
  /// In en, this message translates to:
  /// **'Background node is paused while this benchmark runs.'**
  String get perfRunPausedNodeNotice;

  /// Label for a running benchmark
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get perfStateRunning;

  /// Label for a benchmark that is starting up before the first status update arrives
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get perfStateStarting;

  /// Label for a completed benchmark
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get perfStateCompleted;

  /// Label for a failed benchmark
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get perfStateFailed;

  /// Label for a cancelled benchmark
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get perfStateCancelled;

  /// Progress label for a benchmark run
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} steps'**
  String perfProgressValue(int completed, int total);

  /// Status detail shown while a benchmark profile is starting
  ///
  /// In en, this message translates to:
  /// **'Preparing {profile}'**
  String perfPreparingProfile(String profile);

  /// Label for the current benchmark step
  ///
  /// In en, this message translates to:
  /// **'Current step: {label}'**
  String perfCurrentStep(String label);

  /// Elapsed time label for a benchmark run
  ///
  /// In en, this message translates to:
  /// **'Elapsed: {duration}'**
  String perfElapsed(String duration);

  /// Section title for benchmark results
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get perfResultsTitle;

  /// Summary row label for benchmark profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get perfResultProfile;

  /// Summary row label for device model
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get perfResultDevice;

  /// Summary row label for operating system
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get perfResultOperatingSystem;

  /// Summary row label for CPU architecture
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get perfResultCpu;

  /// Summary row label for CPU core count
  ///
  /// In en, this message translates to:
  /// **'Logical Cores'**
  String get perfResultLogicalCores;

  /// Summary row label for measurement count
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get perfResultMeasurements;

  /// Benchmark suite label for primitive operations
  ///
  /// In en, this message translates to:
  /// **'Primitives'**
  String get perfSuitePrimitives;

  /// Benchmark suite label for partial sync
  ///
  /// In en, this message translates to:
  /// **'Partial Sync'**
  String get perfSuitePartialSync;

  /// Benchmark suite label for partial block production
  ///
  /// In en, this message translates to:
  /// **'Block Production'**
  String get perfSuitePartialBlockProduction;

  /// Benchmark suite label for wallet send
  ///
  /// In en, this message translates to:
  /// **'Wallet Send'**
  String get perfSuiteWalletSend;

  /// Label for a benchmark scenario that has no additional fixture-specific context
  ///
  /// In en, this message translates to:
  /// **'Default case'**
  String get perfScenarioDefault;

  /// Label for a block-sized benchmark scenario transaction count
  ///
  /// In en, this message translates to:
  /// **'{count} tx'**
  String perfContextTxCount(int count);

  /// Label for a benchmark scenario batch layout
  ///
  /// In en, this message translates to:
  /// **'Layout {value}'**
  String perfContextBatchLayout(String value);

  /// Label for a benchmark scenario transaction shape
  ///
  /// In en, this message translates to:
  /// **'Shape {value}'**
  String perfContextTransactionShape(String value);

  /// Summary label for a benchmark result scenario
  ///
  /// In en, this message translates to:
  /// **'Scenario'**
  String get perfDetailScenario;

  /// Summary label for the average runtime of a benchmark result
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get perfDetailAverage;

  /// Summary label for the min and max runtime of a benchmark result
  ///
  /// In en, this message translates to:
  /// **'Min / Max'**
  String get perfDetailMinMax;

  /// Summary label for the number of repeated runs in a benchmark result
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get perfDetailRuns;

  /// Section title for benchmark result scenario metadata
  ///
  /// In en, this message translates to:
  /// **'Scenario Details'**
  String get perfDetailMetadataTitle;

  /// Section title for lower-level benchmark result details
  ///
  /// In en, this message translates to:
  /// **'Implementation Details'**
  String get perfDetailImplementationTitle;

  /// Section title for benchmark result notes
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get perfDetailNotesTitle;

  /// Summary label for benchmark result flow details
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get perfDetailFlow;

  /// Summary label for benchmark result transaction count
  ///
  /// In en, this message translates to:
  /// **'Transaction Count'**
  String get perfDetailTxCount;

  /// Summary label for benchmark result batch layout
  ///
  /// In en, this message translates to:
  /// **'Batch Layout'**
  String get perfDetailBatchLayout;

  /// Summary label for benchmark result transaction shape
  ///
  /// In en, this message translates to:
  /// **'Transaction Shape'**
  String get perfDetailTransactionShape;

  /// Summary label for benchmark result touched leaf count
  ///
  /// In en, this message translates to:
  /// **'Touched Leaves'**
  String get perfDetailTouchedLeaves;

  /// Summary label for benchmark result proof node count
  ///
  /// In en, this message translates to:
  /// **'Proof Nodes'**
  String get perfDetailProofNodes;

  /// Summary label for benchmark result proof size
  ///
  /// In en, this message translates to:
  /// **'Proof Size'**
  String get perfDetailProofSize;

  /// Error shown when cancelling a benchmark run fails
  ///
  /// In en, this message translates to:
  /// **'Unable to cancel the current benchmark run.'**
  String get perfCancelFailed;

  /// Error shown when a benchmark run can no longer be queried
  ///
  /// In en, this message translates to:
  /// **'This benchmark run is no longer available.'**
  String get perfRunUnavailable;

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Version label in build info
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get buildInfoVersion;

  /// Commit label in build info
  ///
  /// In en, this message translates to:
  /// **'Commit'**
  String get buildInfoCommit;

  /// Branch label in build info
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get buildInfoBranch;

  /// Commit time label in build info
  ///
  /// In en, this message translates to:
  /// **'Commit time'**
  String get buildInfoCommitTime;

  /// Rust compiler label in build info
  ///
  /// In en, this message translates to:
  /// **'Rustc'**
  String get buildInfoRustc;

  /// LLVM label in build info
  ///
  /// In en, this message translates to:
  /// **'LLVM'**
  String get buildInfoLlvm;

  /// Cargo target label in build info
  ///
  /// In en, this message translates to:
  /// **'Cargo target'**
  String get buildInfoCargoTarget;

  /// Features label in build info
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get buildInfoFeatures;

  /// Optimization level label in build info
  ///
  /// In en, this message translates to:
  /// **'Opt level'**
  String get buildInfoOptLevel;

  /// Debug label in build info
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get buildInfoDebug;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Detail screen total reward heading
  ///
  /// In en, this message translates to:
  /// **'Total Reward {reward}'**
  String challengeTotalReward(String reward);

  /// Section title for challenge description
  ///
  /// In en, this message translates to:
  /// **'Why it matters'**
  String get challengeSectionTheWhy;

  /// Section title for challenge task
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get challengeSectionTask;

  /// Section title for challenge requirements
  ///
  /// In en, this message translates to:
  /// **'Requirements'**
  String get challengeSectionRequirements;

  /// Detail screen title for the ZK identity challenge
  ///
  /// In en, this message translates to:
  /// **'Prove you\'re a unique human'**
  String get zkIdentityChallengeTitle;

  /// Detail screen CTA shown before the user has begun the flow
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get zkIdentityDetailStartCta;

  /// Detail screen CTA shown when the user resumes an in-progress flow
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get zkIdentityDetailContinueCta;

  /// Title shown when the ZK Passport companion app is not installed
  ///
  /// In en, this message translates to:
  /// **'Install ZK Passport first'**
  String get zkIdentityAppNotFoundTitle;

  /// Detail copy explaining why ZK Passport is needed
  ///
  /// In en, this message translates to:
  /// **'It creates your proof, then sends you back here'**
  String get zkIdentityAppNotFoundDetail;

  /// Button label to open the store listing for ZK Passport
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get zkIdentityInstallCta;

  /// Step label for the check-app step in the stepper
  ///
  /// In en, this message translates to:
  /// **'Open ZK Passport'**
  String get zkIdentityStepLabelOpenApp;

  /// Step description for the check-app step in the stepper
  ///
  /// In en, this message translates to:
  /// **'Make sure ZK Passport is installed'**
  String get zkIdentityStepDescOpenApp;

  /// Button label that triggers the install-check
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get zkIdentityCheckAppCta;

  /// Step label for the confirm-scanned step in the stepper
  ///
  /// In en, this message translates to:
  /// **'Scan your passport'**
  String get zkIdentityStepLabelScan;

  /// Step description for the confirm-scanned step in the stepper
  ///
  /// In en, this message translates to:
  /// **'Scan once in ZK Passport. It\'s saved for next time.'**
  String get zkIdentityStepDescScan;

  /// Body prompt for the confirm-scanned step
  ///
  /// In en, this message translates to:
  /// **'Already scanned?'**
  String get zkIdentityConfirmScannedBody;

  /// Affirmative button on the confirm-scanned step
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get zkIdentityConfirmScannedYesCta;

  /// Decline button on the confirm-scanned step
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get zkIdentityConfirmScannedNoCta;

  /// Step label for the ready-to-verify step in the stepper
  ///
  /// In en, this message translates to:
  /// **'Ready to verify'**
  String get zkIdentityStepLabelReady;

  /// Step description for the ready-to-verify step in the stepper
  ///
  /// In en, this message translates to:
  /// **'Switch to ZK Passport to build your proof'**
  String get zkIdentityStepDescReady;

  /// Body for the ready-to-verify step
  ///
  /// In en, this message translates to:
  /// **'Switch to ZK Passport. It builds your proof in about a minute.'**
  String get zkIdentityReadyBody;

  /// First privacy bullet on the ready-to-verify step
  ///
  /// In en, this message translates to:
  /// **'No name, photo, or ID is shared'**
  String get zkIdentityReadyBullet1;

  /// Second privacy bullet on the ready-to-verify step
  ///
  /// In en, this message translates to:
  /// **'You send only a proof'**
  String get zkIdentityReadyBullet2;

  /// Third privacy bullet on the ready-to-verify step
  ///
  /// In en, this message translates to:
  /// **'Nothing personal is stored on-chain'**
  String get zkIdentityReadyBullet3;

  /// Button label that launches the ZK Passport companion app
  ///
  /// In en, this message translates to:
  /// **'Open ZK Passport'**
  String get zkIdentityReadyCta;

  /// Step label for the verification step in the stepper
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get zkIdentityStepLabelVerifying;

  /// Step description for the verification step in the stepper
  ///
  /// In en, this message translates to:
  /// **'Building and checking your proof'**
  String get zkIdentityStepDescVerifying;

  /// Step label for the result step in the stepper
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get zkIdentityStepLabelResult;

  /// Step description for the result step in the stepper
  ///
  /// In en, this message translates to:
  /// **'View the outcome of your verification'**
  String get zkIdentityStepDescResult;

  /// Verification sub-task label: launching ZK Passport
  ///
  /// In en, this message translates to:
  /// **'Opening ZK Passport'**
  String get zkIdentitySubTaskOpening;

  /// Verification sub-task label: waiting for the user to complete the ZK Passport flow
  ///
  /// In en, this message translates to:
  /// **'Waiting for your proof'**
  String get zkIdentitySubTaskWaiting;

  /// Verification sub-task label: verifying the outer proof
  ///
  /// In en, this message translates to:
  /// **'Checking your proof'**
  String get zkIdentitySubTaskChecking;

  /// Verification sub-task label: wrapping the outer proof
  ///
  /// In en, this message translates to:
  /// **'Wrapping your proof'**
  String get zkIdentitySubTaskWrapping;

  /// Verification sub-task label: final verification of the wrapped proof
  ///
  /// In en, this message translates to:
  /// **'Final check'**
  String get zkIdentitySubTaskFinal;

  /// Success title shown after completing ZK identity verification
  ///
  /// In en, this message translates to:
  /// **'You\'re a unique human!'**
  String get zkIdentityResultSuccessTitle;

  /// Success subtitle shown after completing ZK identity verification
  ///
  /// In en, this message translates to:
  /// **'You proved you\'re unique without sharing your name, photo, or ID'**
  String get zkIdentityResultSuccessSubtitle;

  /// Status card label for the unique-human check
  ///
  /// In en, this message translates to:
  /// **'Unique human'**
  String get zkIdentityStatusUniqueness;

  /// Status card value when the unique-human check is complete
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get zkIdentityStatusUniquenessValue;

  /// Status card label for the face match check
  ///
  /// In en, this message translates to:
  /// **'Face check'**
  String get zkIdentityStatusFaceMatchLabel;

  /// Status card value describing privacy-preserving verification
  ///
  /// In en, this message translates to:
  /// **'Nothing shared'**
  String get zkIdentityStatusPrivacyValue;

  /// Secondary button label for cancelling an in-progress ZK identity verification
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get zkIdentityCancelVerification;

  /// Primary button label that opens the ZK Passport companion app
  ///
  /// In en, this message translates to:
  /// **'Switch to ZK Passport'**
  String get zkIdentityGoToZkPassport;

  /// Button label for retrying a failed ZK identity verification
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get zkIdentityTryAgain;

  /// Button label to dismiss the ZK identity result screen on success
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get zkIdentityDone;

  /// Status card value when face match verification was performed and passed
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get zkIdentityStatusFaceMatchVerified;

  /// Status card value when face match verification was not part of this verification
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get zkIdentityStatusFaceMatchNotRequested;

  /// Status card label for the privacy guarantee row
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get zkIdentityStatusPrivacyLabel;

  /// Status card label for the verification date row
  ///
  /// In en, this message translates to:
  /// **'Verified on'**
  String get zkIdentityStatusVerifiedDateLabel;

  /// Status card label for the proof identifier (truncated nullifier)
  ///
  /// In en, this message translates to:
  /// **'Proof ID'**
  String get zkIdentityStatusProofIdLabel;

  /// Status card label for the outer proof verification timing
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get zkIdentityStatusVerifyDurationLabel;

  /// Status card label for the proof wrapping timing
  ///
  /// In en, this message translates to:
  /// **'Wrap'**
  String get zkIdentityStatusWrapDurationLabel;

  /// Status card label for the final wrapped-proof verification timing
  ///
  /// In en, this message translates to:
  /// **'Final check'**
  String get zkIdentityStatusFinalCheckLabel;

  /// Title for the ZK identity verification failure dialog/screen
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t verify'**
  String get zkIdentityResultFailureTitle;

  /// Reassuring subtitle shown on ZK identity verification failure, naming the specific fields the user kept private
  ///
  /// In en, this message translates to:
  /// **'You didn\'t share your name, photo, or ID'**
  String get zkIdentityResultFailureSubtitle;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// App version label in build info sheet
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get buildInfoAppVersion;

  /// Build number label in build info sheet
  ///
  /// In en, this message translates to:
  /// **'Build Number'**
  String get buildInfoBuildNumber;

  /// Network switcher dialog title
  ///
  /// In en, this message translates to:
  /// **'Network Switcher'**
  String get networkSwitcherTitle;

  /// Network switcher section label
  ///
  /// In en, this message translates to:
  /// **'SELECT NETWORK'**
  String get networkSelectNetwork;

  /// Testnet network option description
  ///
  /// In en, this message translates to:
  /// **'Default network'**
  String get networkTestnetDesc;

  /// Internal network option description
  ///
  /// In en, this message translates to:
  /// **'Development network'**
  String get networkInternalDesc;

  /// Currently active network badge label
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get networkActive;

  /// Network switcher button when same network selected
  ///
  /// In en, this message translates to:
  /// **'No Change'**
  String get networkNoChange;

  /// Network switcher confirm button
  ///
  /// In en, this message translates to:
  /// **'Switch Network'**
  String get networkSwitch;

  /// PIN dialog title for network switcher
  ///
  /// In en, this message translates to:
  /// **'Enter Code'**
  String get networkEnterCode;

  /// PIN dialog input hint
  ///
  /// In en, this message translates to:
  /// **'4-digit code'**
  String get networkCodeHint;

  /// Restart dialog title after network switch
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get networkRestartRequired;

  /// iOS restart dialog message after network switch
  ///
  /// In en, this message translates to:
  /// **'Network switched to {network}. Please manually close and reopen the app to connect to the new network.'**
  String networkSwitchedRestartIos(String network);

  /// Android restart dialog message after network switch
  ///
  /// In en, this message translates to:
  /// **'Network switched to {network}. The app will now close. Please reopen it to connect to the new network.'**
  String networkSwitchedRestartAndroid(String network);

  /// Close app button in restart dialog
  ///
  /// In en, this message translates to:
  /// **'Close App'**
  String get networkCloseApp;

  /// Diagnostics toggle that enables in-memory HTTP request logging
  ///
  /// In en, this message translates to:
  /// **'Debug Mode'**
  String get settingsDebugMode;

  /// Subtitle for the debug mode toggle when enabled
  ///
  /// In en, this message translates to:
  /// **'Capturing HTTP requests to memory'**
  String get settingsDebugModeEnabled;

  /// Subtitle for the debug mode toggle when disabled
  ///
  /// In en, this message translates to:
  /// **'Off · no network logging'**
  String get settingsDebugModeDisabled;

  /// Diagnostics tile that opens the captured HTTP request log viewer
  ///
  /// In en, this message translates to:
  /// **'HTTP Logs'**
  String get settingsHttpLogs;

  /// Subtitle for the HTTP logs tile
  ///
  /// In en, this message translates to:
  /// **'View captured network requests'**
  String get settingsHttpLogsSubtitle;

  /// App bar title of the HTTP debug log viewer
  ///
  /// In en, this message translates to:
  /// **'HTTP Logs'**
  String get httpLogsTitle;

  /// Empty state shown when the HTTP log buffer has no entries
  ///
  /// In en, this message translates to:
  /// **'No requests captured yet. Trigger some network activity to see logs here.'**
  String get httpLogsEmpty;

  /// Tooltip for the action that copies all captured logs
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get httpLogsCopy;

  /// Tooltip for the action that clears the captured logs
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get httpLogsClear;

  /// Snackbar shown after copying logs to the clipboard
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get httpLogsCopied;

  /// Button that starts sending captured logs to the backend
  ///
  /// In en, this message translates to:
  /// **'Share the logs with the team'**
  String get httpLogsShare;

  /// Caption shown while logs are being shared periodically
  ///
  /// In en, this message translates to:
  /// **'Sharing logs with the team every 30s…'**
  String get httpLogsSharing;

  /// Button that stops the periodic log sharing session
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get httpLogsStopSharing;

  /// Snackbar shown when the backend asked the app to stop sharing logs
  ///
  /// In en, this message translates to:
  /// **'The server stopped log sharing. You can share again anytime.'**
  String get httpLogsShareStopped;

  /// Disabled-share hint shown when no participant ID is available
  ///
  /// In en, this message translates to:
  /// **'No participant ID yet — finish onboarding to share logs'**
  String get httpLogsShareNoParticipant;

  /// Placeholder text for the field that filters HTTP logs by URL substring
  ///
  /// In en, this message translates to:
  /// **'Filter by URL'**
  String get httpLogsFilterHint;

  /// Empty state shown when no captured requests match the active URL filter
  ///
  /// In en, this message translates to:
  /// **'No requests match the filter.'**
  String get httpLogsNoMatches;

  /// Caption showing how many captured requests match the active URL filter
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String httpLogsFilterCount(int count, int total);

  /// App bar title of the iOS widget-setup instructions screen
  ///
  /// In en, this message translates to:
  /// **'Add the Usernode widget'**
  String get widgetInstructionsTitle;

  /// Intro of the iOS widget-setup instructions screen
  ///
  /// In en, this message translates to:
  /// **'{name} was added to your Usernode dApps widget. To see it on your home screen, add the widget once:'**
  String widgetInstructionsBody(String name);

  /// First step of the iOS widget-setup instructions
  ///
  /// In en, this message translates to:
  /// **'Touch and hold an empty area of your home screen'**
  String get widgetInstructionsStep1;

  /// Second step of the iOS widget-setup instructions
  ///
  /// In en, this message translates to:
  /// **'Tap Edit in the top corner, then Add Widget'**
  String get widgetInstructionsStep2;

  /// Third step of the iOS widget-setup instructions
  ///
  /// In en, this message translates to:
  /// **'Search for Usernode and add the dApps widget'**
  String get widgetInstructionsStep3;

  /// Dismiss button of the iOS widget-setup instructions screen
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get widgetInstructionsDone;

  /// Title of the inert terminal screen shown after application reset
  ///
  /// In en, this message translates to:
  /// **'Reset complete'**
  String get appResetCompleteTitle;

  /// Instruction on the inert terminal screen shown after application reset
  ///
  /// In en, this message translates to:
  /// **'Close and reopen Usernode to continue.'**
  String get appResetCompleteBody;

  /// Terminal reset screen title after a user-initiated logout
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get appResetLogoutTitle;

  /// Terminal reset screen body after a user-initiated logout
  ///
  /// In en, this message translates to:
  /// **'You signed out, and your local data was cleared. Close and reopen Usernode to continue.'**
  String get appResetLogoutBody;

  /// Terminal reset screen title after the backend rejected the session token
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get appResetSessionExpiredTitle;

  /// Terminal reset screen body after the backend rejected the session token
  ///
  /// In en, this message translates to:
  /// **'Your session is no longer valid, so Usernode signed you out and cleared local data. Close and reopen Usernode to continue.'**
  String get appResetSessionExpiredBody;

  /// Terminal reset screen title after the stored sign-in credential could not be read
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get appResetCredentialMissingTitle;

  /// Terminal reset screen body after the stored sign-in credential could not be read
  ///
  /// In en, this message translates to:
  /// **'Your saved sign-in could not be read, so Usernode signed you out and cleared local data. Close and reopen Usernode to continue.'**
  String get appResetCredentialMissingBody;

  /// Terminal reset screen title after signing in with a different account
  ///
  /// In en, this message translates to:
  /// **'Account changed'**
  String get appResetAccountChangedTitle;

  /// Terminal reset screen body after signing in with a different account
  ///
  /// In en, this message translates to:
  /// **'You signed in with a different account, so the previous account\'s local data was cleared. Close and reopen Usernode to continue.'**
  String get appResetAccountChangedBody;

  /// Terminal reset screen title after switching from an account to guest mode
  ///
  /// In en, this message translates to:
  /// **'Switched to guest'**
  String get appResetGuestTitle;

  /// Terminal reset screen body after switching from an account to guest mode
  ///
  /// In en, this message translates to:
  /// **'You switched to guest mode, and your account\'s local data was cleared. Close and reopen Usernode to continue.'**
  String get appResetGuestBody;

  /// Terminal reset screen title after selecting a different network in diagnostics
  ///
  /// In en, this message translates to:
  /// **'Network changed'**
  String get appResetNetworkChangeTitle;

  /// Terminal reset screen body after selecting a different network in diagnostics
  ///
  /// In en, this message translates to:
  /// **'Usernode will start on the selected network. Close and reopen Usernode to continue.'**
  String get appResetNetworkChangeBody;

  /// First-launch gate of the full-screen SV shell: shown while the Social Vibecoding webapp loads for the first time on this install
  ///
  /// In en, this message translates to:
  /// **'Connecting to Usernode…'**
  String get svShellConnectingTitle;

  /// First-launch gate of the full-screen SV shell: shown when the first-ever load of the Social Vibecoding webapp fails
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach Usernode. Check your connection and try again.'**
  String get svShellOfflineMessage;

  /// Title of the native staking manager opened from Wallet
  ///
  /// In en, this message translates to:
  /// **'Staking mode'**
  String get stakingManagerTitle;

  /// Introductory copy on the delegation review step
  ///
  /// In en, this message translates to:
  /// **'Delegate your stake to the server. Your node keeps running, but the server stakes on your behalf.'**
  String get stakingDelegateIntro;

  /// Friendly name of the single supported delegation target
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get stakingServerName;

  /// Description of delegation's effect on this node
  ///
  /// In en, this message translates to:
  /// **'Your node stops producing blocks. While delegated, you receive half the block-production points you would earn by producing blocks directly on this phone.'**
  String get stakingDelegateEffect;

  /// Reassurance below the delegation review
  ///
  /// In en, this message translates to:
  /// **'You can switch back to staking yourself at any time.'**
  String get stakingDelegateNote;

  /// Action that commits delegation
  ///
  /// In en, this message translates to:
  /// **'Confirm delegation'**
  String get stakingDelegateConfirm;

  /// Loading label while delegation is being committed
  ///
  /// In en, this message translates to:
  /// **'Delegating…'**
  String get stakingDelegating;

  /// Error shown when delegation cannot be committed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit the delegation. Check your connection and try again.'**
  String get stakingDelegateError;

  /// Title shown for active delegation
  ///
  /// In en, this message translates to:
  /// **'Delegation active'**
  String get stakingDelegationActiveTitle;

  /// Body shown for active delegation
  ///
  /// In en, this message translates to:
  /// **'Your stake is delegated to {validator}. You receive half the block-production points you would earn by producing blocks directly on this phone.'**
  String stakingDelegationActiveBody(String validator);

  /// Dismisses the staking manager after delegation
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get stakingDone;

  /// Title of the undelegation confirmation
  ///
  /// In en, this message translates to:
  /// **'Stop delegating?'**
  String get stakingUndelegateTitle;

  /// Body of the undelegation confirmation
  ///
  /// In en, this message translates to:
  /// **'Your stake returns to this phone. Your node will produce blocks directly and earn the full block-production points.'**
  String get stakingUndelegateBody;

  /// Action that commits undelegation
  ///
  /// In en, this message translates to:
  /// **'Stop delegating'**
  String get stakingUndelegateConfirm;

  /// Error shown when undelegation cannot be committed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t stop delegating. Check your connection and try again.'**
  String get stakingUndelegateError;

  /// Button that opens or focuses the desktop dapp window
  ///
  /// In en, this message translates to:
  /// **'Open web app window'**
  String get desktopWebViewOpen;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
