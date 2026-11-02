import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

/// Clears the device-local zkPassport flow and registration. Used by the SV
/// bridge (`resetZkChallenge`) and native diagnostics tooling.
/// Returns false when a proof is still being processed and nothing was reset.
Future<bool> resetChallengeState(WidgetRef ref, BuildContext context) async {
  final discarded = await ref
      .read(zkPassportPipelineProvider.notifier)
      .discardPendingSession(reason: 'Reset');
  if (!discarded) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).zkChallengeBusy)),
      );
    }
    return false;
  }

  ref.read(zkIdentityStepControllerProvider.notifier).reset();
  await ref.read(zkPassportFlowControllerProvider).clearActiveRegistration();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).zkChallengeResetDone),
      ),
    );
  }
  return true;
}
