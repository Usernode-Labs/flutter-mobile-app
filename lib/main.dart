import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/theme/theme.dart';
import 'package:crypto_mobile_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SentryUtil.bootstrap(() async {
    SentryUtil.addBreadcrumb(category: 'app', message: 'startup begin');
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
    final started =
        await RustBackendService.instance.startForActiveAccount();
    Log.i('MAIN', 'Backend startForActiveAccount => $started');
    await SentryUtil.captureMessage(
        started ? 'backend startForActiveAccount: started' : 'backend startForActiveAccount: skipped');

    Log.i('MAIN', 'Running app UI');
    SentryUtil.addBreadcrumb(category: 'app', message: 'runApp');
    runApp(const CryptoMobileApp());
  });
}

class CryptoMobileApp extends StatelessWidget {
  const CryptoMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Usernode',
      theme: MaterialTheme(ThemeData.light().textTheme).light(),
      darkTheme: MaterialTheme(ThemeData.dark().textTheme).dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      navigatorObservers: SentryUtil.navigatorObservers(),
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
