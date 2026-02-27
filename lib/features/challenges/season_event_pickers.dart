import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/design_system/src/dropdown_sheet.dart';

/// Returns the display label for the current season.
String seasonLabel(BuildContext context, WidgetRef ref) {
  final ctx = ref.watch(seasonEventContextProvider);
  return ctx.seasonName ?? AppLocalizations.of(context).seasonFallback;
}

/// Returns the display label for the current event/phase.
String eventLabel(BuildContext context, WidgetRef ref) {
  final ctx = ref.watch(seasonEventContextProvider);
  return ctx.eventName ?? AppLocalizations.of(context).phaseFallback;
}

/// Picks the latest event within [season]: the active one, or the last in the list.
SeasonEventDto? _latestEvent(SeasonDto season) {
  if (season.events.isEmpty) return null;
  return season.events
          .cast<SeasonEventDto?>()
          .firstWhere((e) => e!.isActive, orElse: () => null) ??
      season.events.last;
}

/// Shows a bottom sheet picker for season selection and updates the context.
///
/// When the season changes, the event is auto-selected to the latest phase.
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
    title: AppLocalizations.of(context).selectSeason,
    selectedIndex: selectedIndex,
  );

  if (result == null) return;

  final season = seasons[result];
  if (ctx.seasonId != season.id) {
    final event = _latestEvent(season);
    final newCtx = SeasonEventContext(
      seasonId: season.id,
      seasonName: season.name,
      eventId: event?.id,
      eventName: event?.name,
    );
    ref.read(seasonEventContextProvider.notifier).state = newCtx;
    LeaderboardBootstrap.persistSeasonEvent(newCtx);
  }
}

/// Shows a bottom sheet picker for event/phase selection and updates the context.
Future<void> showEventPicker(BuildContext context, WidgetRef ref) async {
  final seasons = ref.read(seasonsProvider).value?.data;
  if (seasons == null || seasons.isEmpty) return;
  final ctx = ref.read(seasonEventContextProvider);

  final currentSeason = ctx.seasonId != null
      ? seasons.cast<SeasonDto?>().firstWhere(
            (s) => s!.id == ctx.seasonId,
            orElse: () => seasons.first,
          )
      : seasons.first;
  final events = currentSeason?.events;
  if (events == null || events.isEmpty) return;

  final labels = events.map((e) => e.name).toList();
  final selectedIndex = ctx.eventId == null
      ? labels.length - 1
      : events
          .indexWhere((e) => e.id == ctx.eventId)
          .clamp(0, labels.length - 1);

  final result = await showDropdownSheet(
    context: context,
    labels: labels,
    title: AppLocalizations.of(context).selectPhase,
    selectedIndex: selectedIndex,
  );

  if (result == null) return;

  final seasonId = ctx.seasonId ?? currentSeason!.id;
  final seasonName = ctx.seasonName ?? currentSeason!.name;
  final event = events[result];

  final newCtx = SeasonEventContext(
    seasonId: seasonId,
    seasonName: seasonName,
    eventId: event.id,
    eventName: event.name,
  );
  ref.read(seasonEventContextProvider.notifier).state = newCtx;
  LeaderboardBootstrap.persistSeasonEvent(newCtx);
}
