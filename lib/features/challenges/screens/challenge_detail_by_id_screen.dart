import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/challenge_bands_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenge_detail_screen.dart';

class ChallengeDetailByIdScreen extends ConsumerWidget {
  const ChallengeDetailByIdScreen({super.key, required this.challengeId});

  final int? challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(leaderboardBootstrapProvider);

    final id = challengeId;
    if (id == null) return _redirectToChallengesRoot(context);

    final bands = ref.watch(challengeBandsProvider);
    final challenge = bands?.byId[id];
    if (challenge != null) {
      return ChallengeDetailScreen(challenge: challenge);
    }

    final challenges = ref.watch(challengesProvider);
    if (challenges.isLoading && challenges.valueOrNull == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _redirectToChallengesRoot(context);
  }

  Widget _redirectToChallengesRoot(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(AppRoutes.challenges);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
