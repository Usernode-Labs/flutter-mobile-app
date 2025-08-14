import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 🔥 NEW
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🔥 NEW

void main() {
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

      // 🔥 NEW: Internationalization support
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en'), // English
        Locale('es'), // Spanish
        Locale('fr'), // French (you can add more)
        Locale('de'), // German
      ],

      home: SplashScreen(),
    );
  }
}
