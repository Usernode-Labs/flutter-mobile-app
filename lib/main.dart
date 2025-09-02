import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:crypto_mobile_app/src/rust/node.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'gen_l10n/app_localizations.dart';

void main() async {
  await RustLib.init(
    // Use symbols linked into the app (static link), not dlopen a framework.
    externalLibrary: ExternalLibrary.process(iKnowHowToUseIt: true),
  );
  NodeBuilder builder = NodeBuilder();
  // builder.initialPeersFromUrl(url: "");
  Node node = builder.build();
  NodeRpcClient rpc = node.rpc();
  node.runForeverInNewThread();
  print('peer count: ${(await rpc.status())?.peers.length}');
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
