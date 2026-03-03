import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab indices matching the [IndexedStack] order in HomeScreen.
abstract final class HomeTab {
  static const int challenges = 0;
  static const int wallet = 1;
  static const int dapps = 2;
  static const int nodeStatus = 3;
  static const int settings = 4;
}

/// Tracks the currently selected tab index in the HomeScreen's NavigationBar.
final currentHomeTabProvider = StateProvider<int>((ref) => HomeTab.challenges);
