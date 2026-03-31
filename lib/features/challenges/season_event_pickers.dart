import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart'
    show seasonEventContextProvider, participantEventIdsProvider;
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/design_system/src/dropdown_sheet.dart';

/// Returns the display label for the current event selection.
///
/// Shows "All Events" when no specific event is selected,
/// or the specific event name otherwise.
String eventLabel(BuildContext context, WidgetRef ref) {
  final ctx = ref.watch(seasonEventContextProvider);
  return ctx.eventName ?? AppLocalizations.of(context).allEvents;
}

/// Shows a bottom sheet picker for event selection and updates the context.
///
/// The first option is "All Events" (fetches challenges across all events),
/// followed by a divider, then individual events from the current season.
Future<void> showEventPicker(BuildContext context, WidgetRef ref) async {
  final seasons = ref.read(seasonsProvider).value?.data;
  if (seasons == null || seasons.isEmpty) return;
  final ctx = ref.read(seasonEventContextProvider);

  // Resolve current season.
  final currentSeason = ctx.seasonId != null
      ? seasons.cast<SeasonDto?>().firstWhere(
            (s) => s!.id == ctx.seasonId,
            orElse: () => seasons.first,
          )
      : seasons.first;
  if (currentSeason == null || currentSeason.events.isEmpty) return;

  // Show events the user is enrolled in: active events (auto-enrolled)
  // plus ended events the user participated in (from breakdown data).
  final participatedIds = ref.read(participantEventIdsProvider);
  final events = currentSeason.events
      .where((e) => e.isActive || participatedIds.contains(e.id))
      .toList();
  if (events.isEmpty) return;

  final l10n = AppLocalizations.of(context);

  // Build labels: "All Events" + individual event names with status.
  final labels = <String>[
    l10n.allEvents,
    ...events.map((e) {
      if (!e.isActive) return '${e.name} (${l10n.eventEnded})';
      return e.name;
    }),
  ];

  // Selected index: 0 for "All Events", 1+ for specific events.
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
    // "All Events" selected.
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
