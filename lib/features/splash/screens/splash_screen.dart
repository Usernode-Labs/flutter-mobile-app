import 'package:crypto_mobile_app/features/splash/widgets/launch_cover.dart';
import 'package:flutter/material.dart';

/// Shown while the native session starts, before the router and the SV shell
/// exist: a still continuation of the native launch screen ([LaunchCover]).
///
/// It used to fade in from nothing, spring from 92% scale and slide up, with
/// a large "Homeroom" title, a tagline and a spinner under a smaller mark, so
/// the launch image visibly turned into a different screen. Now the user sees
/// one screen from the tap until the page has painted.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const LaunchCover();
}
