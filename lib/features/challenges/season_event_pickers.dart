import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart'
    show seasonEventContextProvider, participantEventIdsProvider;
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/design_system/src/dropdown_sheet.dart';

/// Returns the display label for the current season selection.
String seasonLabel(BuildContext context, WidgetRef ref) {
  final ctx = ref.watch(seasonEventContextProvider);
  if (ctx.seasonName != null) return ctx.seasonName!;

  final seasons = ref.watch(seasonsProvider).valueOrNull;
  if (seasons == null || seasons.isEmpty) {
    return AppLocalizations.of(context).allSeasons;
  }

  final activeSeason = seasons.cast<SeasonDto?>().firstWhere(
        (s) => s!.isActive,
        orElse: () => null,
      );
  return activeSeason?.name ?? seasons.last.name;
}

/// Returns the display label for the current event selection.
///
/// Shows "All Events" when no specific event is selected,
/// or the specific event name otherwise.
String eventLabel(BuildContext context, WidgetRef ref) {
  final ctx = ref.watch(seasonEventContextProvider);
  return ctx.eventName ?? AppLocalizations.of(context).allEvents;
}

/// Shows a bottom sheet picker for season selection and updates the context.
///
/// Selecting a season resets the event scope to "All Events" for that season.
Future<void> showSeasonPicker(BuildContext context, WidgetRef ref) async {
  final seasons = ref.read(seasonsProvider).valueOrNull;
  if (seasons == null || seasons.isEmpty) return;

  final ctx = ref.read(seasonEventContextProvider);
  final l10n = AppLocalizations.of(context);

  final labels = [
    for (final season in seasons) _seasonOptionLabel(season, l10n),
  ];

  final selectedIndex = ctx.seasonId == null
      ? seasons.indexWhere((season) => season.isActive)
      : seasons.indexWhere((season) => season.id == ctx.seasonId);

  final result = await showDropdownSheet(
    context: context,
    labels: labels,
    title: l10n.selectSeason,
    selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
  );

  if (result == null) return;

  final season = seasons[result];
  final newCtx = SeasonEventContext(
    seasonId: season.id,
    seasonName: season.name,
  );

  ref.read(seasonEventContextProvider.notifier).state = newCtx;
  LeaderboardBootstrap.persistSeasonEvent(newCtx);
}

String _seasonOptionLabel(SeasonDto season, AppLocalizations l10n) {
  if (season.isActive) return season.name;

  final endsAt =
      season.endsAt != null ? DateTime.tryParse(season.endsAt!) : null;
  if (endsAt != null && endsAt.toUtc().isBefore(DateTime.now().toUtc())) {
    return '${season.name} (${l10n.eventEnded})';
  }

  return season.name;
}

/// Shows a bottom sheet picker for event selection and updates the context.
///
/// The first option is "All Events" (fetches challenges across all events),
/// followed by a divider, then individual events from the current season.
Future<void> showEventPicker(BuildContext context, WidgetRef ref) async {
  final seasons = ref.read(seasonsProvider).valueOrNull;
  if (seasons == null || seasons.isEmpty) return;
  final ctx = ref.read(seasonEventContextProvider);

  final currentSeason = ctx.seasonId != null
      ? seasons.cast<SeasonDto?>().firstWhere(
            (s) => s!.id == ctx.seasonId,
            orElse: () => seasons.first,
          )
      : seasons.first;
  if (currentSeason == null || currentSeason.events.isEmpty) return;

  final participatedIds = ref.read(participantEventIdsProvider);
  final events = currentSeason.events
      .where((e) => e.isActive || participatedIds.contains(e.id))
      .toList();
  if (events.isEmpty) return;

  final l10n = AppLocalizations.of(context);

  final labels = <String>[
    l10n.allEvents,
    ...events.map((e) {
      if (!e.isActive) return '${e.name} (${l10n.eventEnded})';
      return e.name;
    }),
  ];

  final selectedIndex = ctx.eventId == null
      ? 0
      : events.indexWhere((e) => e.id == ctx.eventId) + 1;

  final result = await showDropdownSheet(
    context: context,
    labels: labels,
    title: l10n.selectEvent,
    selectedIndex: selectedIndex.clamp(0, labels.length - 1),
    dividerAfterIndex: 0,
  );

  if (result == null) return;

  final seasonId = ctx.seasonId ?? currentSeason.id;
  final seasonName = ctx.seasonName ?? currentSeason.name;

  final SeasonEventContext newCtx;
  if (result == 0) {
    newCtx = SeasonEventContext(
      seasonId: seasonId,
      seasonName: seasonName,
    );
  } else {
    final event = events[result - 1];
    newCtx = SeasonEventContext(
      seasonId: seasonId,
      seasonName: seasonName,
      eventId: event.id,
      eventName: event.name,
    );
  }

  ref.read(seasonEventContextProvider.notifier).state = newCtx;
  LeaderboardBootstrap.persistSeasonEvent(newCtx);
}
