// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Usernode';

  @override
  String get appTagline => 'Tu Puerta de Entrada a DeFi';

  @override
  String get initializingNode => 'Inicializando nodo...';

  @override
  String get home => 'Inicio';

  @override
  String get wallet => 'Billetera';

  @override
  String get node => 'Nodo';

  @override
  String nodeStatusSynced(String time) {
    return 'Tu Nodo Local sincronizado en $time';
  }

  @override
  String totalNodes(String count) {
    return '$count Nodos en Total';
  }

  @override
  String get bringLiquidity => 'Aporta tu propia liquidez';

  @override
  String get bridgeAssetsDescription =>
      'Transfiere activos a la red en tu primera semana';

  @override
  String get bridge => 'Transferir';

  @override
  String get completeVerification => 'Completa la verificación';

  @override
  String get verificationDescription =>
      'Esto verifica tu identidad y aumenta tus recompensas';

  @override
  String get verify => 'Verificar';

  @override
  String get stakeTokens => 'Haz staking de tus tokens';

  @override
  String get stakingDescription =>
      'Bloquea tokens por un período para obtener recompensas adicionales';

  @override
  String get stake => 'Staking';

  @override
  String get multiplier => 'Tu Multiplicador';

  @override
  String tokensExpected(String count, String days) {
    return '$count Tokens esperados en los próximos $days días';
  }

  @override
  String get activity => 'Actividad';

  @override
  String upcomingBlock(String time) {
    return 'Próximo bloque en $time';
  }

  @override
  String get scheduledBackground => 'Programado en segundo plano';

  @override
  String get identityProven => 'Identidad Verificada';

  @override
  String get depositSuccessful => 'Depósito Exitoso';

  @override
  String get comingSoon => 'Próximamente...';

  @override
  String get walletManagement => 'Gestión de Billetera';

  @override
  String get crossChainBridge => 'Puente Entre Cadenas';

  @override
  String get nodeStatus => 'Estado del Nodo';

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
