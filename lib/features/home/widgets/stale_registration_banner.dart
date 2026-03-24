import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Dismissable warning banner shown when the persisted registration belongs
/// to a previous season/event. Soft mode — does not block the user.
class StaleRegistrationBanner extends ConsumerStatefulWidget {
  const StaleRegistrationBanner({super.key});

  @override
  ConsumerState<StaleRegistrationBanner> createState() =>
      _StaleRegistrationBannerState();
}

class _StaleRegistrationBannerState
    extends ConsumerState<StaleRegistrationBanner> {
  bool? _dismissed; // null = loading, true/false = loaded

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed =
        prefs.getBool(NetworkPrefs.prefixKey(staleBannerDismissedKey)) ?? false;
    if (mounted) setState(() => _dismissed = dismissed);
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NetworkPrefs.prefixKey(staleBannerDismissedKey), true);
  }

  @override
  Widget build(BuildContext context) {
    final freshness = ref.watch(registrationFreshnessProvider);

    // Hidden while loading, dismissed, or not stale
    if (_dismissed != false || freshness != RegistrationFreshness.stale) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return MaterialBanner(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space16,
        vertical: spacing.space12,
      ),
      leading: Icon(
        Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
      ),
      content: Text(
        l10n.registrationStaleBannerBody,
        style: theme.textTheme.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: _dismiss,
          child: Text(l10n.registrationStaleBannerDismiss),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.staleRegistration),
          child: Text(l10n.registrationStaleAction),
        ),
      ],
    );
  }
}
