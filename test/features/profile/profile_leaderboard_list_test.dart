import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/profile/widgets/profile_leaderboard_list.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: themeWithExtensions(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders leaderboard entries', (tester) async {
    await tester.pumpWidget(_wrap(const ProfileLeaderboardList(
      emptyLabel: 'Leaderboard unavailable.',
      entries: [
        ProfileLeaderboardEntryData(
          rank: '1',
          name: 'node-alpha',
          points: '18,420 pts',
        ),
        ProfileLeaderboardEntryData(
          rank: '44',
          name: 'You',
          points: '8,000 pts',
          isCurrentUser: true,
        ),
      ],
    )));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('node-alpha'), findsOneWidget);
    expect(find.text('18,420 pts'), findsOneWidget);
    expect(find.text('44'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('8,000 pts'), findsOneWidget);
  });

  testWidgets('renders empty state', (tester) async {
    await tester.pumpWidget(_wrap(const ProfileLeaderboardList(
      entries: [],
      emptyLabel: 'Leaderboard unavailable.',
    )));

    expect(find.text('Leaderboard unavailable.'), findsOneWidget);
  });

  testWidgets('marks the current user row with a surface', (tester) async {
    await tester.pumpWidget(_wrap(const ProfileLeaderboardRow(
      entry: ProfileLeaderboardEntryData(
        rank: '44',
        name: 'You',
        points: '8,000 pts',
        isCurrentUser: true,
      ),
    )));

    final rowMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byType(ProfileLeaderboardRow),
        matching: find.byType(Material),
      ),
    );

    expect(rowMaterial.color, isNot(Colors.transparent));
  });
}
