import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/terms/providers/terms_provider.dart';
import 'package:crypto_mobile_app/features/terms/screens/terms_screen.dart';

/// Stacks [TermsScreen] over the app while the current terms version is
/// unanswered.
///
/// Renders nothing in every other case, including while the check is in flight
/// and when it fails — see [termsGateProvider] for why this fails open.
class TermsGateOverlay extends ConsumerWidget {
  const TermsGateOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Onboarding owns the screen until it finishes; a consent prompt stacked
    // over a permission request would be both confusing and dismissible-looking.
    final onboarded =
        ref.watch(hasCompletedOnboardingProvider).valueOrNull ?? false;
    if (!onboarded) return const SizedBox.shrink();

    if (!ref.watch(termsGateProvider)) return const SizedBox.shrink();

    // Its own ScaffoldMessenger, so a failed-submission snackbar is scoped to
    // the gate's Scaffold instead of racing the app's Scaffold underneath for
    // the root messenger.
    return const ScaffoldMessenger(child: TermsScreen(gateMode: true));
  }
}
