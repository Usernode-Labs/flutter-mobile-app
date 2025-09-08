import 'package:flutter/material.dart';
import 'theme/theme.dart';
import 'screens/splash/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'gen_l10n/app_localizations.dart';
import 'services/rust_backend_service.dart';
import 'config/feature_flags.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load feature flags from assets (if provided) before rendering UI
  Log.i('MAIN', 'Initializing application');
  await FeatureFlags.loadFromAssetIfAvailable();
  Log.d(
      'MAIN',
      'Feature flags loaded: ${FeatureFlags.ordered
              .where(FeatureFlags.isEnabled)
              .toList()}');
  // Initialize FRB only; start backend only if an account exists
  await RustBackendService.instance.init();
  final started = await RustBackendService.instance.startForActiveAccount();
  Log.i('MAIN', 'Backend startForActiveAccount => $started');

  Log.i('MAIN', 'Running app UI');
  runApp(const CryptoMobileApp());
}

class CryptoMobileApp extends StatelessWidget {
  const CryptoMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Usernode',
      theme: MaterialTheme(ThemeData.light().textTheme).light(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en'), // English
      ],
      home: SplashScreen(),
    );
  }
}
