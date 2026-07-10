import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/url_launcher.dart';

String? challengeCtaLink(ChallengeDto dto) {
  final link = dto.ctaLink?.trim();
  return link == null || link.isEmpty ? null : link;
}

bool hasChallengeCta(ChallengeDto dto) => challengeCtaLink(dto) != null;

void handleChallengeCta(BuildContext context, ChallengeDto dto) {
  final link = challengeCtaLink(dto);
  if (link == null) return;

  switch (dto.ctaType ?? CtaType.url) {
    case CtaType.url:
      launchExternalUrl(link);
    case CtaType.app:
      context.push(link);
  }
}
