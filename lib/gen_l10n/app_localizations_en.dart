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
  String get bridge => 'Node Status';

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
}
