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
/// import 'gen_l10n/app_localizations.dart';
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

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Wallet tab label
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// Node tab label
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get node;

  /// dApps tab label
  ///
  /// In en, this message translates to:
  /// **'dApps'**
  String get dapps;

  /// Profile tab label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// NFC Reader tab label
  ///
  /// In en, this message translates to:
  /// **'NFC Reader'**
  String get nfcReader;

  /// Title for empty NFC state
  ///
  /// In en, this message translates to:
  /// **'Scan your ID'**
  String get nfcEmptyTitle;

  /// Subtitle for empty NFC state
  ///
  /// In en, this message translates to:
  /// **'Use your phone to read your ePassport or eID via NFC.'**
  String get nfcEmptySubtitle;

  /// Action to scan another document
  ///
  /// In en, this message translates to:
  /// **'Scan another'**
  String get nfcScanAnother;

  /// Action to open MRZ manual entry
  ///
  /// In en, this message translates to:
  /// **'Enter MRZ manually'**
  String get nfcManualMrz;

  /// Start NFC reading
  ///
  /// In en, this message translates to:
  /// **'Start NFC scan'**
  String get nfcStartScan;

  /// MRZ entry screen title
  ///
  /// In en, this message translates to:
  /// **'Enter MRZ'**
  String get mrzTitle;

  /// No description provided for @mrzLine1.
  ///
  /// In en, this message translates to:
  /// **'MRZ line 1'**
  String get mrzLine1;

  /// No description provided for @mrzLine2.
  ///
  /// In en, this message translates to:
  /// **'MRZ line 2'**
  String get mrzLine2;

  /// No description provided for @mrzLine3.
  ///
  /// In en, this message translates to:
  /// **'MRZ line 3 (optional)'**
  String get mrzLine3;

  /// Continue from MRZ entry
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get mrzContinue;

  /// NFC reading in progress
  ///
  /// In en, this message translates to:
  /// **'Hold document to the phone...'**
  String get nfcReading;

  /// Save document
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get nfcSave;

  /// Rename document action
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get nfcRename;

  /// Delete document action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get nfcDelete;

  /// Confirm deletion
  ///
  /// In en, this message translates to:
  /// **'Delete this document?'**
  String get nfcConfirmDelete;

  /// Biometric prompt
  ///
  /// In en, this message translates to:
  /// **'Unlock to view private data'**
  String get unlockToView;

  /// Biometrics unavailable message
  ///
  /// In en, this message translates to:
  /// **'Biometrics not available'**
  String get biometricsNotAvailable;

  /// No NFC hardware
  ///
  /// In en, this message translates to:
  /// **'This device does not support NFC.'**
  String get nfcNotSupported;

  /// NFC disabled guidance
  ///
  /// In en, this message translates to:
  /// **'Please enable NFC in settings.'**
  String get nfcTurnOn;

  /// Generic NFC read error
  ///
  /// In en, this message translates to:
  /// **'Failed to read document. Check MRZ and try again.'**
  String get nfcReadFailed;

  /// Rescan overwrite confirmation
  ///
  /// In en, this message translates to:
  /// **'Document updated'**
  String get nfcUpdated;

  /// Saved confirmation
  ///
  /// In en, this message translates to:
  /// **'Document saved'**
  String get nfcSaved;

  /// Node sync status message
  ///
  /// In en, this message translates to:
  /// **'Your Local Node synced in {time}'**
  String nodeStatusSynced(String time);

  /// Total number of nodes
  ///
  /// In en, this message translates to:
  /// **'{count} Nodes Total'**
  String totalNodes(String count);

  /// Liquidity card title
  ///
  /// In en, this message translates to:
  /// **'Bring your own liquidity'**
  String get bringLiquidity;

  /// Bridge assets description
  ///
  /// In en, this message translates to:
  /// **'Bridge assets to the network within your first week'**
  String get bridgeAssetsDescription;

  /// Bridge button text
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get bridge;

  /// Verification card title
  ///
  /// In en, this message translates to:
  /// **'Complete verification'**
  String get completeVerification;

  /// Verification description
  ///
  /// In en, this message translates to:
  /// **'This verifies your identity and increases your rewards'**
  String get verificationDescription;

  /// Verify button text
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// Staking card title
  ///
  /// In en, this message translates to:
  /// **'Stake your tokens'**
  String get stakeTokens;

  /// Staking description
  ///
  /// In en, this message translates to:
  /// **'Lock tokens for a period to earn additional rewards'**
  String get stakingDescription;

  /// Stake button text
  ///
  /// In en, this message translates to:
  /// **'Stake'**
  String get stake;

  /// Multiplier section title
  ///
  /// In en, this message translates to:
  /// **'Your Multiplier'**
  String get multiplier;

  /// Expected tokens message
  ///
  /// In en, this message translates to:
  /// **'{count} Tokens expected in next {days} days'**
  String tokensExpected(String count, String days);

  /// Activity section title
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// Upcoming block message
  ///
  /// In en, this message translates to:
  /// **'Upcoming block in {time}'**
  String upcomingBlock(String time);

  /// Background scheduling message
  ///
  /// In en, this message translates to:
  /// **'Scheduled in the background'**
  String get scheduledBackground;

  /// Identity verification success
  ///
  /// In en, this message translates to:
  /// **'Identity Proven'**
  String get identityProven;

  /// Deposit success message
  ///
  /// In en, this message translates to:
  /// **'Deposit Successful'**
  String get depositSuccessful;

  /// Coming soon placeholder text
  ///
  /// In en, this message translates to:
  /// **'Coming soon...'**
  String get comingSoon;

  /// Wallet screen title
  ///
  /// In en, this message translates to:
  /// **'Wallet Management'**
  String get walletManagement;

  /// Bridge screen title
  ///
  /// In en, this message translates to:
  /// **'Node status'**
  String get crossChainBridge;

  /// Node status screen title
  ///
  /// In en, this message translates to:
  /// **'Node Status'**
  String get nodeStatus;

  /// Swap screen title
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// Token swap screen description
  ///
  /// In en, this message translates to:
  /// **'Token Swap'**
  String get tokenSwap;

  /// Rewards screen title
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// Rewards screen description
  ///
  /// In en, this message translates to:
  /// **'Rewards & Achievements'**
  String get rewardsAchievements;

  /// Your Multiplier
  ///
  /// In en, this message translates to:
  /// **'Your Multiplier'**
  String get yourMultiplier;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountTitle;

  /// No description provided for @recoveryPhraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Your recovery phrase'**
  String get recoveryPhraseTitle;

  /// No description provided for @recoveryPhraseWarning.
  ///
  /// In en, this message translates to:
  /// **'This recovery phrase is the ONLY way to restore your keys and regain access to this account if something goes wrong. Store it securely and never share it.'**
  String get recoveryPhraseWarning;

  /// No description provided for @recoveryPhraseInstruction.
  ///
  /// In en, this message translates to:
  /// **'Write these words down and store them securely. They will NOT be stored by the app and cannot be recovered.'**
  String get recoveryPhraseInstruction;

  /// No description provided for @accountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountNameLabel;

  /// No description provided for @accountNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Account 1'**
  String get accountNameHint;

  /// No description provided for @accountNameExplain.
  ///
  /// In en, this message translates to:
  /// **'This name is only stored on your device to help you identify the account. It does not affect your blockchain address or keys.'**
  String get accountNameExplain;

  /// No description provided for @seedStoredCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I have securely stored my recovery phrase.'**
  String get seedStoredCheckbox;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @balances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get balances;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get copyAddress;

  /// No description provided for @addressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get addressCopied;

  /// No description provided for @manageAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts'**
  String get manageAccounts;

  /// No description provided for @selectAccount.
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get selectAccount;

  /// No description provided for @selectAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Tap an account to switch'**
  String get selectAccountHint;

  /// No description provided for @createNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create new account'**
  String get createNewAccount;

  /// No description provided for @importFromSeed.
  ///
  /// In en, this message translates to:
  /// **'Import from seed phrase'**
  String get importFromSeed;

  /// No description provided for @importFromPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Import from private key'**
  String get importFromPrivateKey;

  /// No description provided for @deleteAllAccountsDev.
  ///
  /// In en, this message translates to:
  /// **'Delete all accounts (dev)'**
  String get deleteAllAccountsDev;

  /// No description provided for @deleteAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all accounts?'**
  String get deleteAllConfirmTitle;

  /// No description provided for @deleteAllConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove all stored accounts on this device.'**
  String get deleteAllConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @generateNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Generate new address'**
  String get generateNewAddress;

  /// No description provided for @backendStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting backend for your account...'**
  String get backendStarting;

  /// No description provided for @nodeStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading node status...'**
  String get nodeStatusLoading;

  /// No description provided for @nodeStatusError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load node status'**
  String get nodeStatusError;

  /// No description provided for @nodePeersCount.
  ///
  /// In en, this message translates to:
  /// **'Peers: {count}'**
  String nodePeersCount(String count);

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @currentBlockHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Current block height'**
  String get currentBlockHeightLabel;

  /// No description provided for @nodeStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get nodeStatusLabel;

  /// No description provided for @peersLabel.
  ///
  /// In en, this message translates to:
  /// **'Peers'**
  String get peersLabel;

  /// No description provided for @mempoolLabel.
  ///
  /// In en, this message translates to:
  /// **'Mempool'**
  String get mempoolLabel;

  /// No description provided for @evaluatedDiscoveredLabel.
  ///
  /// In en, this message translates to:
  /// **'Evaluated / Discovered Slots'**
  String get evaluatedDiscoveredLabel;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @pastSlots.
  ///
  /// In en, this message translates to:
  /// **'Past Slots'**
  String get pastSlots;

  /// No description provided for @scheduledSlot.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Slot'**
  String get scheduledSlot;

  /// No description provided for @discoveredSlot.
  ///
  /// In en, this message translates to:
  /// **'Discovered Slot {id}'**
  String discoveredSlot(String id);

  /// No description provided for @inTime.
  ///
  /// In en, this message translates to:
  /// **'in {time}'**
  String inTime(String time);

  /// No description provided for @transactionsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{count} Transactions'**
  String transactionsSuffix(String count);

  /// No description provided for @checkedAgoSeconds.
  ///
  /// In en, this message translates to:
  /// **'Checked {seconds} seconds ago'**
  String checkedAgoSeconds(String seconds);
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
