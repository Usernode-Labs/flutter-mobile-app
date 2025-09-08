import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
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
      'Feature flags loaded: ' +
          FeatureFlags.ordered
              .where(FeatureFlags.isEnabled)
              .toList()
              .toString());
  // Initialize FRB only; start backend only if an account exists
  await RustBackendService.instance.init();
  final started = await RustBackendService.instance.startForActiveAccount();
  Log.i('MAIN', 'Backend startForActiveAccount => ' + started.toString());

  Log.i('MAIN', 'Running app UI');
  runApp(const CryptoMobileApp());
}

class CryptoMobileApp extends StatelessWidget {
  const CryptoMobileApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Usernode',
      theme: AppTheme.lightTheme,
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
