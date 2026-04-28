import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AppSleepScreen extends StatelessWidget {
  const AppSleepScreen({
    super.key,
    required this.snapshot,
  });

  final AppSleepSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.space24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Symbols.bedtime_sharp,
                    size: sizing.iconDisplayLarge,
                    color: semantic.technical.color,
                  ),
                  SizedBox(height: spacing.space24),
                  Text(
                    l10n.appSleepTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: spacing.space12),
                  Text(
                    _scheduledWakeText(context, l10n),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: spacing.space24),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.space16,
                      vertical: spacing.space12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius:
                          theme.extension<AppRadii>()!.borderRadiusMedium,
                    ),
                    child: Text(
                      l10n.appSleepTapToWake,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _scheduledWakeText(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final scheduledWakeAt = snapshot.scheduledWakeAt;
    if (scheduledWakeAt == null) {
      return l10n.appSleepUntilUnknown;
    }

    final material = MaterialLocalizations.of(context);
    final date = material.formatMediumDate(scheduledWakeAt);
    final time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(scheduledWakeAt),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );

    final dateTimeText = '$date $time';
    final slotNumber = snapshot.scheduledWakeSlotNumber;
    if (slotNumber != null) {
      return l10n.appSleepUntilSlot(slotNumber, dateTimeText);
    }

    return l10n.appSleepUntilTime(dateTimeText);
  }
}
