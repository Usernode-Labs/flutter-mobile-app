import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/design_system/src/dropdown_sheet.dart';

/// Returns the display label for the current season.
String seasonLabel(WidgetRef ref) {
  final ctx = ref.watch(seasonEventContextProvider);
  return ctx.seasonName ?? 'Season';
}

/// Returns the display label for the current event.
String eventLabel(WidgetRef ref) {
  final ctx = ref.watch(seasonEventContextProvider);
  return ctx.eventName ?? 'All Events';
}

/// Shows a bottom sheet picker for season selection and updates the context.
Future<void> showSeasonPicker(BuildContext context, WidgetRef ref) async {
  final seasons = ref.read(seasonsProvider).value?.data;
  if (seasons == null || seasons.isEmpty) return;

  final labels = seasons.map((s) => s.name).toList();
  final ctx = ref.read(seasonEventContextProvider);
  final selectedIndex = ctx.seasonId == null
      ? 0
      : seasons
          .indexWhere((s) => s.id == ctx.seasonId)
          .clamp(0, labels.length - 1);

  final result = await showDropdownSheet(
    context: context,
    labels: labels,
    title: 'Select Season',
    selectedIndex: selectedIndex,
  );

  if (result == null) return;

  final season = seasons[result];
  if (ctx.seasonId != season.id) {
    ref.read(seasonEventContextProvider.notifier).state = SeasonEventContext(
      seasonId: season.id,
      seasonName: season.name,
    );
  }
}

/// Shows a bottom sheet picker for event selection and updates the context.
Future<void> showEventPicker(BuildContext context, WidgetRef ref) async {
  final seasons = ref.read(seasonsProvider).value?.data;
  if (seasons == null || seasons.isEmpty) return;
  final ctx = ref.read(seasonEventContextProvider);

  // Find the current season's events; fall back to first season if
  // the context hasn't been populated yet (cold start).
  final currentSeason = ctx.seasonId != null
      ? seasons.cast<SeasonDto?>().firstWhere(
            (s) => s!.id == ctx.seasonId,
            orElse: () => seasons.first,
          )
      : seasons.first;
  final events = currentSeason?.events;
  if (events == null || events.isEmpty) return;

  final labels = ['All Events', ...events.map((e) => e.name)];
  final selectedIndex = ctx.eventId == null
      ? 0
      : events.indexWhere((e) => e.id == ctx.eventId) + 1;

  final result = await showDropdownSheet(
    context: context,
    labels: labels,
    title: 'Select Event',
    selectedIndex: selectedIndex.clamp(0, labels.length - 1),
  );

  if (result == null) return;

  // Use the resolved season so the context is always populated.
  final seasonId = ctx.seasonId ?? currentSeason!.id;
  final seasonName = ctx.seasonName ?? currentSeason!.name;

  if (result == 0) {
    // "All Events" — clear eventId by constructing a new instance
    ref.read(seasonEventContextProvider.notifier).state = SeasonEventContext(
      seasonId: seasonId,
      seasonName: seasonName,
    );
  } else {
    final event = events[result - 1];
    ref.read(seasonEventContextProvider.notifier).state = SeasonEventContext(
      seasonId: seasonId,
      seasonName: seasonName,
      eventId: event.id,
      eventName: event.name,
    );
  }
}
