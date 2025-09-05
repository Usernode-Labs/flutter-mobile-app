import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'gen_l10n/app_localizations.dart';
// import 'services/rust_backend_service.dart';
import 'config/feature_flags.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load feature flags from assets (if provided) before rendering UI
  await FeatureFlags.loadFromAssetIfAvailable();
  // Initialize and start the Rust backend via the dedicated service
  //await RustBackendService.instance.init();
  //await RustBackendService.instance.startNode();

  // Optional: quick health log
  // final status = await RustBackendService.instance.getStatus();
  // ignore: avoid_print
  // print('peer count: ${status?.peers.length}');

  runApp(CryptoMobileApp());
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
        Locale('es'), // Spanish
      ],
      home: SplashScreen(),
    );
  }
}
