import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
