import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

/// Clears the zkPassport registration plus cached challenge state. Used by
/// the SV bridge (`resetZkChallenge`) and native diagnostics tooling.
/// Returns false when a proof is still being processed and nothing was reset.
Future<bool> resetChallengeState(WidgetRef ref, BuildContext context) async {
  final discarded = await ref
      .read(zkPassportPipelineProvider.notifier)
      .discardPendingSession(reason: 'Reset');
  if (!discarded) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A zkPassport proof is still being processed. Try again shortly.',
          ),
        ),
      );
    }
    return false;
  }

  ref.read(zkIdentityStepControllerProvider.notifier).reset();
  await ref.read(zkPassportFlowControllerProvider).clearActiveRegistration();
  ref.invalidate(challengesProvider);
  ref.invalidate(breakdownProvider);
  ref.invalidate(categorizedChallengesProvider);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Challenge state reset')),
    );
  }
  return true;
}
