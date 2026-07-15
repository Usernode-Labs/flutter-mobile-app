import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/url_launcher.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Shown in place of the allocation when the participant has not accepted the
/// current terms.
///
/// The backend forces `total_tokens` to 0 in that state, so rendering the usual
/// reveal card would present a withheld allocation as a real balance of zero.
/// This says why the number is missing and offers the way to fix it.
class TokenAllocationGatedNotice extends StatelessWidget {
  const TokenAllocationGatedNotice({
    super.key,
    required this.onReviewTerms,
    this.termsLink,
  });

  final VoidCallback onReviewTerms;

  /// Hosted copy of the terms. The link is hidden when null.
  final String? termsLink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: Symbols.lock_sharp,
                  backgroundColor: colors.secondaryContainer,
                  iconColor: colors.onSecondaryContainer,
                ),
                SizedBox(width: spacing.space16),
                Expanded(
                  child: Text(
                    l10n.profileTokenAllocationGated,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.space12),
            Text(
              l10n.profileTokenAllocationGatedBody,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            SizedBox(height: spacing.space12),
            Row(
              children: [
                Button(
                  label: l10n.profileTokenAllocationGatedAction,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.small,
                  onTap: onReviewTerms,
                ),
                if (termsLink != null) ...[
                  SizedBox(width: spacing.space8),
                  Button(
                    label: l10n.termsViewFull,
                    variant: ButtonVariant.outlined,
                    size: ButtonSize.small,
                    onTap: () => launchExternalUrl(termsLink!),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
