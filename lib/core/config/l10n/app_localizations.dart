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
