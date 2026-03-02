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

  /// Node tab label
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get node;

  /// Send feedback button text
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// Feedback title field label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get feedbackTitle;

  /// Feedback title field hint
  ///
  /// In en, this message translates to:
  /// **'Brief summary of your feedback'**
  String get feedbackTitleHint;

  /// Feedback description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get feedbackDescription;

  /// Feedback description field hint
  ///
  /// In en, this message translates to:
  /// **'Describe your feedback in detail'**
  String get feedbackDescriptionHint;

  /// Feedback category field label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get feedbackCategory;

  /// Include device info checkbox label
  ///
  /// In en, this message translates to:
  /// **'Include device information'**
  String get feedbackIncludeDeviceInfo;

  /// Device info checkbox subtitle
  ///
  /// In en, this message translates to:
  /// **'Helps us diagnose issues'**
  String get feedbackDeviceInfoHelp;

  /// Submit feedback button text
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get feedbackSubmit;

  /// Feedback submission success message
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get feedbackSuccess;

  /// Feedback submission error message
  ///
  /// In en, this message translates to:
  /// **'Failed to submit feedback'**
  String get feedbackError;

  /// Required field validation message
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get feedbackRequired;

  /// Screenshots section label
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get feedbackScreenshots;

  /// Add screenshot button text
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get feedbackAddScreenshot;

  /// Empty screenshots message
  ///
  /// In en, this message translates to:
  /// **'No screenshots added (optional)'**
  String get feedbackNoScreenshots;

  /// Feedback FAB subtitle
  ///
  /// In en, this message translates to:
  /// **'Help us improve the app'**
  String get feedbackHelpImprove;

  /// Image pick error message
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String feedbackImagePickFailed(String error);

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// French language option
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get settingsLanguageFrench;

  /// Spanish language option
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get settingsLanguageSpanish;

  /// Language not yet supported message
  ///
  /// In en, this message translates to:
  /// **'Language support coming soon'**
  String get settingsLanguageComingSoon;

  /// Background block production setting label
  ///
  /// In en, this message translates to:
  /// **'Background Block Production'**
  String get settingsBackgroundBlockProduction;

  /// Background block production setting subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure automatic block production'**
  String get settingsBackgroundBlockProductionSubtitle;

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

  /// Background production explanation title
  ///
  /// In en, this message translates to:
  /// **'What is Background Block Production?'**
  String get bgProdWhatIs;

  /// Background production explanation
  ///
  /// In en, this message translates to:
  /// **'This feature automatically wakes your device to produce blockchain blocks when your node wins a slot. Here\'s how it works:'**
  String get bgProdDescription;

  /// VRF selection step title
  ///
  /// In en, this message translates to:
  /// **'VRF Selection'**
  String get bgProdVrfSelection;

  /// VRF selection step description
  ///
  /// In en, this message translates to:
  /// **'Each epoch, the network randomly selects which validators will produce blocks using Verifiable Random Function (VRF)'**
  String get bgProdVrfSelectionDesc;

  /// Slot scheduling step title
  ///
  /// In en, this message translates to:
  /// **'Slot Scheduling'**
  String get bgProdSlotScheduling;

  /// Slot scheduling step description
  ///
  /// In en, this message translates to:
  /// **'When you win slots, the app schedules alarms to wake your device ~1 minute before each slot'**
  String get bgProdSlotSchedulingDesc;

  /// Block production step title
  ///
  /// In en, this message translates to:
  /// **'Block Production'**
  String get bgProdBlockProduction;

  /// Block production step description
  ///
  /// In en, this message translates to:
  /// **'At slot time, the app monitors your node and ensures the block is produced'**
  String get bgProdBlockProductionDesc;

  /// Success tracking step title
  ///
  /// In en, this message translates to:
  /// **'Success Tracking'**
  String get bgProdSuccessTracking;

  /// Success tracking step description
  ///
  /// In en, this message translates to:
  /// **'Results are recorded to track your reliability over time'**
  String get bgProdSuccessTrackingDesc;

  /// Android background production section title
  ///
  /// In en, this message translates to:
  /// **'Android Background Production'**
  String get bgProdAndroidTitle;

  /// iOS background production section title
  ///
  /// In en, this message translates to:
  /// **'iOS Background Production'**
  String get bgProdIosTitle;

  /// Android background production description
  ///
  /// In en, this message translates to:
  /// **'Uses Android\'s exact alarm system (AlarmManager) to wake your device precisely when needed for block production.'**
  String get bgProdAndroidDesc;

  /// iOS background production description
  ///
  /// In en, this message translates to:
  /// **'Uses a combination of background tasks and keep-alive mode to wake your device for block production.'**
  String get bgProdIosDesc;

  /// Reliability by mode section title
  ///
  /// In en, this message translates to:
  /// **'Reliability by Mode'**
  String get bgProdReliabilityByMode;

  /// Default mode label
  ///
  /// In en, this message translates to:
  /// **'Default (Event-Driven)'**
  String get bgProdDefaultMode;

  /// Default mode reliability
  ///
  /// In en, this message translates to:
  /// **'90-95%'**
  String get bgProdDefaultReliability;

  /// Default mode description
  ///
  /// In en, this message translates to:
  /// **'Battery-efficient, wakes only during slot windows'**
  String get bgProdDefaultDesc;

  /// Keep-alive mode label
  ///
  /// In en, this message translates to:
  /// **'Keep-Alive Mode'**
  String get bgProdKeepAliveMode;

  /// Keep-alive mode reliability
  ///
  /// In en, this message translates to:
  /// **'100%'**
  String get bgProdKeepAliveReliability;

  /// Keep-alive mode description
  ///
  /// In en, this message translates to:
  /// **'Persistent service, higher battery (~5-10%/hr)'**
  String get bgProdKeepAliveDesc;

  /// iOS keep-alive mode reliability
  ///
  /// In en, this message translates to:
  /// **'99%'**
  String get bgProdIosKeepAliveReliability;

  /// iOS keep-alive mode description
  ///
  /// In en, this message translates to:
  /// **'App stays awake in foreground, requires charger'**
  String get bgProdIosKeepAliveDesc;

  /// Background only mode label
  ///
  /// In en, this message translates to:
  /// **'Background Only'**
  String get bgProdBackgroundOnly;

  /// Background only mode reliability
  ///
  /// In en, this message translates to:
  /// **'40-60%'**
  String get bgProdBackgroundOnlyReliability;

  /// Background only mode description
  ///
  /// In en, this message translates to:
  /// **'iOS controls execution, not guaranteed'**
  String get bgProdBackgroundOnlyDesc;

  /// Loading button state
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get bgProdLoading;

  /// VRF complete button state
  ///
  /// In en, this message translates to:
  /// **'VRF Complete'**
  String get bgProdVrfComplete;

  /// VRF calculating button state
  ///
  /// In en, this message translates to:
  /// **'VRF Calculating...'**
  String get bgProdVrfCalculating;

  /// VRF pending button state
  ///
  /// In en, this message translates to:
  /// **'VRF Pending'**
  String get bgProdVrfPending;

  /// Grant permissions button
  ///
  /// In en, this message translates to:
  /// **'Grant Permissions'**
  String get bgProdGrantPermissions;

  /// Open battery settings button
  ///
  /// In en, this message translates to:
  /// **'Open Battery Settings'**
  String get bgProdOpenBatterySettings;

  /// Account setup screen title
  ///
  /// In en, this message translates to:
  /// **'Account Setup'**
  String get onboardingAccountSetup;

  /// Account setup heading
  ///
  /// In en, this message translates to:
  /// **'Set Up Your Account'**
  String get onboardingSetUpYourAccount;

  /// Demo account selection instruction
  ///
  /// In en, this message translates to:
  /// **'Select a demo account to start using the Usernode blockchain.'**
  String get onboardingSelectDemoAccount;

  /// Use demo account card title
  ///
  /// In en, this message translates to:
  /// **'Use Demo Account'**
  String get onboardingUseDemoAccount;

  /// Use demo account card description
  ///
  /// In en, this message translates to:
  /// **'Quickly set up a pre-configured account for testing purposes.'**
  String get onboardingUseDemoAccountDesc;

  /// No demo accounts heading
  ///
  /// In en, this message translates to:
  /// **'No Demo Accounts Available'**
  String get demoNoDemoAccountsAvailable;

  /// Demo accounts not configured message
  ///
  /// In en, this message translates to:
  /// **'Demo accounts are not configured in this build.'**
  String get demoNotConfigured;

  /// Demo account selection instruction
  ///
  /// In en, this message translates to:
  /// **'Select a demo account to import for testing purposes.'**
  String get demoSelectToImport;

  /// Demo account warning
  ///
  /// In en, this message translates to:
  /// **'Demo accounts are for development/testing only'**
  String get demoWarning;

  /// Use demo account button
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get demoUseButton;

  /// Public key validation error
  ///
  /// In en, this message translates to:
  /// **'Key validation failed: Public key mismatch for {tier} account'**
  String demoKeyValidationFailedPublicKey(String tier);

  /// Address validation error
  ///
  /// In en, this message translates to:
  /// **'Key validation failed: Address mismatch for {tier} account'**
  String demoKeyValidationFailedAddress(String tier);

  /// Demo account import failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to import demo account'**
  String get demoImportFailed;

  /// Demo account import failure with error
  ///
  /// In en, this message translates to:
  /// **'Failed to import demo account: {error}'**
  String demoImportFailedWithError(String error);

  /// Import API account card title and screen title
  ///
  /// In en, this message translates to:
  /// **'Import Pre-configured Account'**
  String get importApiAccountTitle;

  /// Import API account card description
  ///
  /// In en, this message translates to:
  /// **'Import a pre-configured account from the API'**
  String get importApiAccountDesc;

  /// Contact field label
  ///
  /// In en, this message translates to:
  /// **'Discord, Email, or Telegram'**
  String get importApiAccountContactLabel;

  /// Contact field hint
  ///
  /// In en, this message translates to:
  /// **'@username or name@example.com'**
  String get importApiAccountContactHint;

  /// Activation code field label
  ///
  /// In en, this message translates to:
  /// **'Activation Code'**
  String get importApiAccountCodeLabel;

  /// Activation code field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your code'**
  String get importApiAccountCodeHint;

  /// Submit button text
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get importApiAccountSubmit;

  /// API account import failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to import account from API'**
  String get importApiAccountFailed;

  /// API registration failure with error
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String importApiAccountRegistrationFailed(String error);

  /// No active account error
  ///
  /// In en, this message translates to:
  /// **'No active account found. Please create or select an account.'**
  String get walletNoActiveAccount;

  /// Invalid amount validation error
  ///
  /// In en, this message translates to:
  /// **'Invalid amount. Enter a whole-number amount.'**
  String get walletInvalidAmount;

  /// Node connection failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to node. Please ensure the node is running.'**
  String get walletNodeConnectionFailed;

  /// Transfer failure message
  ///
  /// In en, this message translates to:
  /// **'Transfer failed: {error}'**
  String walletTransferFailed(String error);

  /// Transfer not queued message
  ///
  /// In en, this message translates to:
  /// **'Transfer was not queued. Please try again.'**
  String get walletTransferNotQueued;

  /// Transfer failed dialog title
  ///
  /// In en, this message translates to:
  /// **'Transfer Failed'**
  String get walletTransferFailedTitle;

  /// Review send screen title
  ///
  /// In en, this message translates to:
  /// **'Review Send'**
  String get walletReviewSend;

  /// Amount label
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get walletAmount;

  /// Network fee label
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get walletNetworkFee;

  /// Back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get walletBack;

  /// Send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get walletSend;

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Done button/title
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get walletDone;

  /// Payment sent success title
  ///
  /// In en, this message translates to:
  /// **'Payment Sent'**
  String get walletPaymentSent;

  /// Transaction submitted success message
  ///
  /// In en, this message translates to:
  /// **'Your transaction has been submitted successfully.'**
  String get walletTransactionSubmitted;

  /// Empty state title for recent activity section
  ///
  /// In en, this message translates to:
  /// **'No transactions to display so far'**
  String get walletNoRecentActivity;

  /// Empty state subtitle explaining auto-refresh behavior
  ///
  /// In en, this message translates to:
  /// **'This page refreshes continuously and will display your transactions here.'**
  String get walletNoRecentActivitySubtitle;

  /// Node status screen title
  ///
  /// In en, this message translates to:
  /// **'Node Status'**
  String get nodeStatusTitle;

  /// Peer ID copied snackbar message
  ///
  /// In en, this message translates to:
  /// **'Peer ID copied to clipboard'**
  String get nodePeerIdCopied;

  /// Copy peer ID tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy full Peer ID'**
  String get nodeCopyPeerId;

  /// Node peers screen title
  ///
  /// In en, this message translates to:
  /// **'Node Peers'**
  String get nodePeersTitle;

  /// Peers summary header
  ///
  /// In en, this message translates to:
  /// **'{count} Peers  •  {connected} Connected  •  {connecting} Connecting'**
  String nodePeersSummary(String count, String connected, String connecting);

  /// Won slots screen title
  ///
  /// In en, this message translates to:
  /// **'Won Slots'**
  String get wonSlotsTitle;

  /// Loading epoch data message
  ///
  /// In en, this message translates to:
  /// **'Loading epoch data...'**
  String get wonSlotsLoadingEpoch;

  /// Epoch data unavailable message
  ///
  /// In en, this message translates to:
  /// **'Epoch data unavailable'**
  String get wonSlotsEpochUnavailable;

  /// No won slots message
  ///
  /// In en, this message translates to:
  /// **'No won slots data available'**
  String get wonSlotsNoData;

  /// Grouped by hour subtitle
  ///
  /// In en, this message translates to:
  /// **'Grouped by hour'**
  String get wonSlotsGroupedByHour;

  /// Grouped by day subtitle
  ///
  /// In en, this message translates to:
  /// **'Grouped by day'**
  String get wonSlotsGroupedByDay;

  /// Won label
  ///
  /// In en, this message translates to:
  /// **'Won'**
  String get wonSlotsWon;

  /// Produced label
  ///
  /// In en, this message translates to:
  /// **'Produced'**
  String get wonSlotsProduced;

  /// Missed label
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get wonSlotsMissed;

  /// Pending label
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get wonSlotsPending;

  /// Today label
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get wonSlotsToday;

  /// Produced blocks screen title
  ///
  /// In en, this message translates to:
  /// **'Produced Blocks'**
  String get producedBlocksTitle;

  /// Loading produced blocks message
  ///
  /// In en, this message translates to:
  /// **'Loading produced blocks...'**
  String get producedBlocksLoading;

  /// No produced blocks message
  ///
  /// In en, this message translates to:
  /// **'No produced blocks available'**
  String get producedBlocksNoData;

  /// Label for block success rate over the last 10 epochs
  ///
  /// In en, this message translates to:
  /// **'Block Success Rate · Last 10 Epochs'**
  String get producedBlocksSuccessRateLast10Epochs;

  /// Summary of tokens earned vs possible over the last 10 epochs
  ///
  /// In en, this message translates to:
  /// **'+{earned} \$TOKENS'**
  String producedBlocksTokensEarnedSummary(String earned, String possible);

  /// Label for tokens earned over the last 10 epochs
  ///
  /// In en, this message translates to:
  /// **'Tokens Earned · Last 10 epochs'**
  String get producedBlocksTokensEarnedLast10Epochs;

  /// Label for current slot progress within an epoch
  ///
  /// In en, this message translates to:
  /// **'Epoch Slot Progress: {current} / {total}'**
  String producedBlocksEpochSlotProgress(int current, int total);

  /// Label shown when there is zero time left in the epoch
  ///
  /// In en, this message translates to:
  /// **'0m left'**
  String get producedBlocksZeroMinutesLeft;

  /// Label showing minutes left in the epoch
  ///
  /// In en, this message translates to:
  /// **'{minutes}m left'**
  String producedBlocksMinutesLeft(int minutes);

  /// Label showing hours and minutes left in the epoch
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m left'**
  String producedBlocksHoursMinutesLeft(int hours, int minutes);

  /// Header for epoch performance metrics
  ///
  /// In en, this message translates to:
  /// **'Epoch Performance'**
  String get producedBlocksEpochPerformance;

  /// Title for checked slots metric
  ///
  /// In en, this message translates to:
  /// **'Checked Slots'**
  String get producedBlocksCheckedSlots;

  /// Subtitle showing number of evaluated slots out of total slots
  ///
  /// In en, this message translates to:
  /// **'Evaluated {evaluated} of {total}'**
  String producedBlocksEvaluatedOfSlots(int evaluated, int total);

  /// Subtitle describing how many blocks were produced out of won slots in this epoch
  ///
  /// In en, this message translates to:
  /// **'{produced} of {won} produced this epoch'**
  String producedBlocksProducedOfWon(String produced, String won);

  /// Title for missed blocks metric
  ///
  /// In en, this message translates to:
  /// **'Missed Blocks'**
  String get producedBlocksMissedBlocksTitle;

  /// Subtitle describing how many blocks were missed out of won slots in this epoch
  ///
  /// In en, this message translates to:
  /// **'{missed} of {won} missed this epoch'**
  String producedBlocksMissedOfWon(String missed, String won);

  /// Title for upcoming blocks metric
  ///
  /// In en, this message translates to:
  /// **'Upcoming Blocks'**
  String get producedBlocksUpcomingBlocksTitle;

  /// Subtitle describing how many upcoming blocks remain in this epoch
  ///
  /// In en, this message translates to:
  /// **'{upcoming} upcoming this epoch'**
  String producedBlocksUpcomingThisEpoch(String upcoming);

  /// Bottom sheet title for selecting an epoch
  ///
  /// In en, this message translates to:
  /// **'Select Epoch'**
  String get producedBlocksSelectEpoch;

  /// Mempool screen title
  ///
  /// In en, this message translates to:
  /// **'Mempool Transactions'**
  String get mempoolTitle;

  /// Failed to load mempool message
  ///
  /// In en, this message translates to:
  /// **'Failed to load mempool'**
  String get mempoolLoadFailed;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get mempoolRetry;

  /// No mempool transactions title
  ///
  /// In en, this message translates to:
  /// **'No transactions in mempool'**
  String get mempoolNoTransactions;

  /// Mempool empty message
  ///
  /// In en, this message translates to:
  /// **'The mempool is currently empty'**
  String get mempoolEmpty;

  /// Rewards breakdown screen title
  ///
  /// In en, this message translates to:
  /// **'Rewards Breakdown'**
  String get rewardsBreakdownTitle;

  /// P2P peer ID label in drawer
  ///
  /// In en, this message translates to:
  /// **'P2P Peer ID:'**
  String get drawerP2pPeerId;

  /// Close button in drawer
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get drawerClose;

  /// Generic error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// Generic placeholder for unavailable numeric values
  ///
  /// In en, this message translates to:
  /// **'--'**
  String get commonNoValuePlaceholder;

  /// Common em dash placeholder text
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get commonEmDash;

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

  /// Not available fallback text
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get nodeNotAvailable;

  /// Navigation bar label for produced blocks tab
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get navProducedBlocks;

  /// Navigation bar label for wallet tab
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get navWallet;

  /// Navigation bar label for dapps tab
  ///
  /// In en, this message translates to:
  /// **'dApps'**
  String get navDapps;

  /// Navigation bar label for node status tab
  ///
  /// In en, this message translates to:
  /// **'Node Status'**
  String get navNodeStatus;

  /// Navigation bar label for challenges tab
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get navChallenges;

  /// Navigation bar label for settings tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Claim account button text
  ///
  /// In en, this message translates to:
  /// **'Claim your account'**
  String get welcomeClaimAccount;

  /// Title for the alpha-phase welcome screen
  ///
  /// In en, this message translates to:
  /// **'Alpha Phase'**
  String get welcomeAlphaTitle;

  /// Subtitle explaining the user is part of the first wave
  ///
  /// In en, this message translates to:
  /// **'You made the first wave of people running an L1 on their mobile devices'**
  String get welcomeAlphaSubtitle;

  /// Button text for claiming a spot in the alpha
  ///
  /// In en, this message translates to:
  /// **'Claim your spot'**
  String get welcomeAlphaClaimSpot;

  /// Title for the verify access screen
  ///
  /// In en, this message translates to:
  /// **'Verify access'**
  String get onboardingVerifyAccessTitle;

  /// Subtitle explaining how to verify access
  ///
  /// In en, this message translates to:
  /// **'Use the username/registration code that has been shared with you. Username must be typed exactly as it appears in the registration email.'**
  String get onboardingVerifyAccessSubtitle;

  /// Personalized welcome title on the setup screen
  ///
  /// In en, this message translates to:
  /// **'Welcome, {userId}'**
  String onboardingWelcomeSetupTitle(String userId);

  /// Body text explaining the initial test cohort and device setup
  ///
  /// In en, this message translates to:
  /// **'You are part of the initial test cohort. This app runs a block producing node.\n\nThe next steps will configure your device to produce blocks on demand.'**
  String get onboardingWelcomeSetupBody;

  /// Button text to start the setup flow
  ///
  /// In en, this message translates to:
  /// **'Start Setup'**
  String get onboardingWelcomeSetupStartButton;

  /// Exact alarms permission screen title
  ///
  /// In en, this message translates to:
  /// **'Exact Alarms'**
  String get permExactAlarmsTitle;

  /// Section title explaining why exact alarms are needed
  ///
  /// In en, this message translates to:
  /// **'Why exact alarms are required'**
  String get permExactAlarmsWhy;

  /// Android explanation for exact alarms
  ///
  /// In en, this message translates to:
  /// **'Android restricts apps from waking the device at precise times unless explicitly allowed. Without this permission, alarms may be delayed by up to 10 minutes, causing missed blocks.\n\nDepending on your device, this permission may already be granted.'**
  String get permExactAlarmsAndroidExplanation;

  /// iOS explanation for exact alarms
  ///
  /// In en, this message translates to:
  /// **'This step is primarily for Android devices. You can continue.'**
  String get permExactAlarmsIosExplanation;

  /// Button to grant exact alarm permission
  ///
  /// In en, this message translates to:
  /// **'Grant exact alarm permission'**
  String get permGrantExactAlarm;

  /// Snackbar message when exact alarm granted
  ///
  /// In en, this message translates to:
  /// **'Exact alarm permission granted'**
  String get permExactAlarmGranted;

  /// Snackbar message to enable exact alarms in settings
  ///
  /// In en, this message translates to:
  /// **'Please enable exact alarms in Settings'**
  String get permExactAlarmEnableInSettings;

  /// Status text when permission is granted
  ///
  /// In en, this message translates to:
  /// **'Permission granted'**
  String get permGranted;

  /// Status text when permission is required
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get permRequired;

  /// Next button text
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// Finish button text
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commonFinish;

  /// Battery optimization screen title
  ///
  /// In en, this message translates to:
  /// **'Allow Background Usage'**
  String get permBatteryTitle;

  /// Section title for battery optimization explanation
  ///
  /// In en, this message translates to:
  /// **'Why this matters'**
  String get permBatteryWhyMatters;

  /// Android explanation for battery optimization
  ///
  /// In en, this message translates to:
  /// **'Android\'s battery optimization can delay or prevent background tasks from running. Disabling it for this app ensures it can wake up on time to produce your scheduled blocks, even when the phone is idle. Settings may vary by device.'**
  String get permBatteryAndroidExplanation;

  /// iOS explanation for battery optimization
  ///
  /// In en, this message translates to:
  /// **'This step applies to Android devices.'**
  String get permBatteryIosExplanation;

  /// Battery optimization impact section title
  ///
  /// In en, this message translates to:
  /// **'Impact of battery optimization:'**
  String get permBatteryImpact;

  /// Warning about enabled battery optimization
  ///
  /// In en, this message translates to:
  /// **'Alarms may be delayed 1–60 seconds, or skipped entirely.'**
  String get permBatteryWarning;

  /// Message about disabled battery optimization
  ///
  /// In en, this message translates to:
  /// **'With optimization disabled, alarms fire precisely when scheduled.'**
  String get permBatteryOptimized;

  /// Button to open battery settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permOpenBatterySettings;

  /// Warning for specific device manufacturers
  ///
  /// In en, this message translates to:
  /// **'{manufacturer} devices require additional settings. Tap Open Battery Settings for guidance.'**
  String permBatteryDeviceWarning(String manufacturer);

  /// Status when battery optimization is disabled
  ///
  /// In en, this message translates to:
  /// **'Battery optimization disabled'**
  String get permBatteryOptDisabled;

  /// Status when battery optimization is enabled
  ///
  /// In en, this message translates to:
  /// **'Battery optimization enabled'**
  String get permBatteryOptEnabled;

  /// Step instruction to tap App Battery Usage in system settings
  ///
  /// In en, this message translates to:
  /// **'Look for \"Battery\", \"App Battery Usage\", or \"Battery Optimization\" in the settings page'**
  String get onboardingBatteryStepAppUsage;

  /// Step instruction to enable background usage
  ///
  /// In en, this message translates to:
  /// **'Disable battery optimization or set the app to \"Unrestricted\" / \"No restrictions\" / \"Don\'t optimize\"'**
  String get onboardingBatteryStepAllowBackground;

  /// Step instruction explaining to tap the text label
  ///
  /// In en, this message translates to:
  /// **'If available, tap on \"Allow background usage\" to access more options'**
  String get onboardingBatteryStepTapText;

  /// Step instruction to select Unrestricted mode
  ///
  /// In en, this message translates to:
  /// **'Select Unrestricted'**
  String get onboardingBatteryStepSelectUnrestricted;

  /// Step instruction to return to the app from settings
  ///
  /// In en, this message translates to:
  /// **'Tap the back button until you return to the app'**
  String get onboardingBatteryStepReturnToApp;

  /// Title shown when unrestricted battery optimization is enabled
  ///
  /// In en, this message translates to:
  /// **'Background Usage Enabled'**
  String get onboardingBatteryUnrestrictedTitle;

  /// Body text when unrestricted battery optimization is enabled
  ///
  /// In en, this message translates to:
  /// **'Great job! The app is now able to precisely schedule background block production.'**
  String get onboardingBatteryUnrestrictedBody;

  /// Title shown when unrestricted battery optimization is not enabled
  ///
  /// In en, this message translates to:
  /// **'Tap Continue to start the main app'**
  String get onboardingBatteryDefaultTitle;

  /// Body text encouraging user to enable unrestricted battery optimization
  ///
  /// In en, this message translates to:
  /// **'We strongly recommend you enable unrestricted battery optimizations to ensure consistent background block production.'**
  String get onboardingBatteryDefaultBody;

  /// Notifications permission screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permNotificationsTitle;

  /// Explanation for notifications permission
  ///
  /// In en, this message translates to:
  /// **'Allow notifications to receive important updates. You can change this later in Settings.'**
  String get permNotificationsExplanation;

  /// Button to allow notifications
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get permAllowNotifications;

  /// Title explaining why notifications are needed for background block production
  ///
  /// In en, this message translates to:
  /// **'Allow notifications to maximize your block production success rate'**
  String get permNotificationsBlockBackgroundTitle;

  /// Body text explaining Android's requirement for a visible status
  ///
  /// In en, this message translates to:
  /// **'Notifications are essential for background block production. They alert you when your slots are coming up and ensure the app stays active to produce blocks.'**
  String get permNotificationsBlockBackgroundBody;

  /// Button text to skip enabling notifications
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get permNotificationsSkip;

  /// Message when notifications are permanently denied
  ///
  /// In en, this message translates to:
  /// **'Notifications are currently disabled. You can enable them in Settings.'**
  String get permNotificationsDisabledMessage;

  /// Button to open settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permOpenSettings;

  /// Status when notifications are enabled
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get permNotificationsEnabled;

  /// Status when notifications are disabled
  ///
  /// In en, this message translates to:
  /// **'Notifications disabled'**
  String get permNotificationsDisabled;

  /// Snackbar message when notifications denied
  ///
  /// In en, this message translates to:
  /// **'Notifications denied'**
  String get permNotificationsDenied;

  /// Snackbar message when notifications permanently denied
  ///
  /// In en, this message translates to:
  /// **'Notifications permanently denied. Enable in Settings.'**
  String get permNotificationsPermanentlyDenied;

  /// Generic notification status message
  ///
  /// In en, this message translates to:
  /// **'Notification status: {status}'**
  String permNotificationStatus(String status);

  /// Production statistics screen title
  ///
  /// In en, this message translates to:
  /// **'Production Statistics'**
  String get statsTitle;

  /// Overall statistics card title
  ///
  /// In en, this message translates to:
  /// **'Overall Statistics'**
  String get statsOverall;

  /// Won slots stat label
  ///
  /// In en, this message translates to:
  /// **'Won Slots'**
  String get statsWonSlots;

  /// Attempted stat label
  ///
  /// In en, this message translates to:
  /// **'Attempted'**
  String get statsAttempted;

  /// Produced stat label
  ///
  /// In en, this message translates to:
  /// **'Produced'**
  String get statsProduced;

  /// Failed stat label
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statsFailed;

  /// Last updated label
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get statsLastUpdated;

  /// Success rate card title
  ///
  /// In en, this message translates to:
  /// **'Success Rate'**
  String get statsSuccessRate;

  /// Empty state message for production records
  ///
  /// In en, this message translates to:
  /// **'No production records yet'**
  String get statsNoRecords;

  /// Recent records section title
  ///
  /// In en, this message translates to:
  /// **'Recent Production Records'**
  String get statsRecentRecords;

  /// Epoch label with number
  ///
  /// In en, this message translates to:
  /// **'Epoch {epoch}'**
  String statsEpoch(int epoch);

  /// Slot label with number
  ///
  /// In en, this message translates to:
  /// **'Slot {slot}'**
  String statsSlot(int slot);

  /// Block label with number
  ///
  /// In en, this message translates to:
  /// **'Block {block}'**
  String statsBlock(int block);

  /// Success rate description
  ///
  /// In en, this message translates to:
  /// **'{produced} successful out of {attempted} attempts'**
  String statsSuccessfulOf(int produced, int attempted);

  /// Status text for won slot
  ///
  /// In en, this message translates to:
  /// **'Won (not yet attempted)'**
  String get statsStatusWon;

  /// Status text for attempting production
  ///
  /// In en, this message translates to:
  /// **'Currently attempting production'**
  String get statsStatusAttempting;

  /// Status text for produced block
  ///
  /// In en, this message translates to:
  /// **'Successfully produced'**
  String get statsStatusProduced;

  /// Status text for failed production
  ///
  /// In en, this message translates to:
  /// **'Production failed'**
  String get statsStatusFailed;

  /// Time display for just now
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// Time display for minutes ago
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes ago'**
  String timeMinutesAgo(int minutes);

  /// Time display for hours ago
  ///
  /// In en, this message translates to:
  /// **'{hours} hours ago'**
  String timeHoursAgo(int hours);

  /// Time display for days ago
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String timeDaysAgo(int days);

  /// Block details screen title
  ///
  /// In en, this message translates to:
  /// **'Block Details'**
  String get blockDetailsTitle;

  /// Timeline item title
  ///
  /// In en, this message translates to:
  /// **'VRF Slot Discovered'**
  String get blockVrfSlotDiscovered;

  /// Timeline item subtitle for slot won
  ///
  /// In en, this message translates to:
  /// **'Slot {slot} won'**
  String blockSlotWon(int slot);

  /// Timeline item title
  ///
  /// In en, this message translates to:
  /// **'Block Production Scheduled'**
  String get blockProductionScheduled;

  /// Timeline item subtitle for epoch and slot
  ///
  /// In en, this message translates to:
  /// **'Epoch {epoch}, Slot {slot}'**
  String blockEpochSlot(int epoch, int slot);

  /// Timeline item title
  ///
  /// In en, this message translates to:
  /// **'Transaction Batches Included'**
  String get blockTxBatchesIncluded;

  /// Timeline item subtitle for batches and transactions
  ///
  /// In en, this message translates to:
  /// **'Included {batches} batches / {transactions} transactions'**
  String blockIncludedBatchesTx(int batches, int transactions);

  /// Timeline item subtitle when batch info unavailable
  ///
  /// In en, this message translates to:
  /// **'Included batches / transactions'**
  String get blockIncludedBatchesTxGeneric;

  /// Timeline item title
  ///
  /// In en, this message translates to:
  /// **'State Transition.'**
  String get blockStateTransition;

  /// Timeline item subtitle for state transition
  ///
  /// In en, this message translates to:
  /// **'Protocol and Consensus states updated'**
  String get blockStatesUpdated;

  /// Timeline item title
  ///
  /// In en, this message translates to:
  /// **'Applied Locally'**
  String get blockAppliedLocally;

  /// Timeline item subtitle for applied locally
  ///
  /// In en, this message translates to:
  /// **'UTXOs updated'**
  String get blockUtxosUpdated;

  /// Timeline item title
  ///
  /// In en, this message translates to:
  /// **'Block Committed'**
  String get blockCommitted;

  /// Block number label
  ///
  /// In en, this message translates to:
  /// **'Block #{height}'**
  String blockNumber(int height);

  /// Timeline item title
  ///
  /// In en, this message translates to:
  /// **'Block Confirmed'**
  String get blockConfirmed;

  /// Block hash with prefix
  ///
  /// In en, this message translates to:
  /// **'Hash: {hash}...'**
  String blockHashPrefix(String hash);

  /// Block information card title
  ///
  /// In en, this message translates to:
  /// **'Block Information'**
  String get blockInformation;

  /// Block hash label
  ///
  /// In en, this message translates to:
  /// **'Block Hash'**
  String get blockHash;

  /// Block height label
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get blockHeight;

  /// Global slot label
  ///
  /// In en, this message translates to:
  /// **'Global Slot'**
  String get blockGlobalSlot;

  /// Epoch label
  ///
  /// In en, this message translates to:
  /// **'Epoch'**
  String get blockEpoch;

  /// Producer label
  ///
  /// In en, this message translates to:
  /// **'Producer'**
  String get blockProducer;

  /// Transactions label
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get blockTransactions;

  /// Batches label
  ///
  /// In en, this message translates to:
  /// **'Batches'**
  String get blockBatches;

  /// Block at slot header
  ///
  /// In en, this message translates to:
  /// **'Block #{height} at Slot {slot}'**
  String blockAtSlot(int height, int slot);

  /// Mempool total stat label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get mempoolTotal;

  /// Mempool orphans stat label
  ///
  /// In en, this message translates to:
  /// **'Orphans'**
  String get mempoolOrphans;

  /// Mempool size stat label
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get mempoolSize;

  /// View button for mempool transaction
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get mempoolView;

  /// Coming soon dialog title
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get mempoolComingSoon;

  /// Coming soon dialog message
  ///
  /// In en, this message translates to:
  /// **'Transaction details will be available in a future update.'**
  String get mempoolDetailsComingSoon;

  /// Node connecting status
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get nodeConnecting;

  /// Node synced status
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get nodeSynced;

  /// Node syncing status
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get nodeSyncing;

  /// Node syncing status with percentage
  ///
  /// In en, this message translates to:
  /// **'Syncing ({percent}%)'**
  String nodeSyncingPercent(String percent);

  /// Node overview section header
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get nodeOverview;

  /// Peer ID label prefix
  ///
  /// In en, this message translates to:
  /// **'Peer ID: '**
  String get nodePeerId;

  /// Peer unavailable fallback text
  ///
  /// In en, this message translates to:
  /// **'(unavailable)'**
  String get peerUnavailable;

  /// Peer hidden address fallback text
  ///
  /// In en, this message translates to:
  /// **'(Hidden address)'**
  String get peerHiddenAddress;

  /// Peer height label
  ///
  /// In en, this message translates to:
  /// **'Height: {height}'**
  String peerHeight(String height);

  /// Peer slot label
  ///
  /// In en, this message translates to:
  /// **'Slot: {slot}'**
  String peerSlot(String slot);

  /// Time display for a minute ago
  ///
  /// In en, this message translates to:
  /// **'a minute ago'**
  String get timeAMinuteAgo;

  /// Time display for an hour ago
  ///
  /// In en, this message translates to:
  /// **'an hour ago'**
  String get timeAnHourAgo;

  /// Time display for yesterday
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// Time display for weeks ago
  ///
  /// In en, this message translates to:
  /// **'{weeks} week{suffix} ago'**
  String timeWeeksAgo(int weeks, String suffix);

  /// Time display for months ago
  ///
  /// In en, this message translates to:
  /// **'{months} month{suffix} ago'**
  String timeMonthsAgo(int months, String suffix);

  /// Time display for years ago
  ///
  /// In en, this message translates to:
  /// **'{years} year{suffix} ago'**
  String timeYearsAgo(int years, String suffix);

  /// Error message when leaderboard data fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load leaderboard'**
  String get leaderboardFailedToLoad;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Leaderboard screen title
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// Header for the participants list
  ///
  /// In en, this message translates to:
  /// **'All Participants'**
  String get allParticipants;

  /// Fallback name when participant has no display name
  ///
  /// In en, this message translates to:
  /// **'Participant {id}'**
  String participantFallbackName(String id);

  /// Points with abbreviated unit
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String pointsAbbreviated(String points);

  /// Callout title showing user ranking percentile
  ///
  /// In en, this message translates to:
  /// **'Better than {percent}% of participants'**
  String betterThanPercent(int percent);

  /// Encouragement for users below 50th percentile
  ///
  /// In en, this message translates to:
  /// **'Keep completing tasks to climb higher on the leaderboard.'**
  String get leaderboardClimbEncouragement;

  /// Encouragement for users above 50th percentile
  ///
  /// In en, this message translates to:
  /// **'You\'re in the top {percent}%! Keep completing challenges to secure your position.'**
  String leaderboardTopPercent(int percent);

  /// Label above total points stat
  ///
  /// In en, this message translates to:
  /// **'TOTAL POINTS'**
  String get totalPointsLabel;

  /// Label above rank stat
  ///
  /// In en, this message translates to:
  /// **'RANK'**
  String get rankLabel;

  /// Distribution bucket score range label
  ///
  /// In en, this message translates to:
  /// **'{lo}–{hi} pts'**
  String pointsRangeBucket(String lo, String hi);

  /// Technical challenge category name
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get categoryTechnical;

  /// Community challenge category name
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get categoryCommunity;

  /// Flash challenge category name
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get categoryFlash;

  /// Fallback label when no season name is available
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get seasonFallback;

  /// Fallback label when no phase/event name is available
  ///
  /// In en, this message translates to:
  /// **'Phase'**
  String get phaseFallback;

  /// Title for season picker bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Select Season'**
  String get selectSeason;

  /// Title for phase picker bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Select Phase'**
  String get selectPhase;

  /// Error message when challenges fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load challenges'**
  String get challengeFailedToLoad;

  /// Empty state for completed challenges tab
  ///
  /// In en, this message translates to:
  /// **'No completed challenges'**
  String get challengeNoCompleted;

  /// Empty state for missed challenges tab
  ///
  /// In en, this message translates to:
  /// **'No missed challenges'**
  String get challengeNoMissed;

  /// Score header label for points
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get challengePoints;

  /// CTA button to navigate to leaderboard
  ///
  /// In en, this message translates to:
  /// **'View in Leaderboard'**
  String get challengeViewInLeaderboard;

  /// Score header rank display
  ///
  /// In en, this message translates to:
  /// **'Rank {rank}'**
  String challengeRank(int rank);

  /// Detail screen total reward heading
  ///
  /// In en, this message translates to:
  /// **'Total Reward {reward}'**
  String challengeTotalReward(String reward);

  /// Section title for challenge description
  ///
  /// In en, this message translates to:
  /// **'The Why'**
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

  /// Fallback epoch earned when no point diff exists
  ///
  /// In en, this message translates to:
  /// **'+0'**
  String get challengeEpochNoChange;

  /// Fallback epoch section label
  ///
  /// In en, this message translates to:
  /// **'Last 24h'**
  String get challengeEpochLast24h;
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
