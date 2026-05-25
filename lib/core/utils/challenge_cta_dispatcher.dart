import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/url_launcher.dart';

void handleChallengeCta(BuildContext context, ChallengeDto dto) {
  final link = dto.ctaLink;
  if (link == null || link.isEmpty) return;

  switch (dto.ctaType ?? CtaType.url) {
    case CtaType.url:
      launchExternalUrl(link);
    case CtaType.app:
      context.push(link);
  }
}
