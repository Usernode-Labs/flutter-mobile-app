import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
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
  });

  final VoidCallback onReviewTerms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warning = theme.extension<AppSemanticColors>()!.warning;
    final spacing = theme.extension<AppSpacing>()!;

    return Card(
      color: warning.colorContainer,
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: Symbols.warning_amber_sharp,
                  backgroundColor: warning.color,
                  iconColor: warning.onColor,
                ),
                SizedBox(width: spacing.space16),
                Expanded(
                  child: Text(
                    l10n.profileTokenAllocationGated,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: warning.onColorContainer,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.space12),
            Text(
              l10n.profileTokenAllocationGatedBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: warning.onColorContainer,
              ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
