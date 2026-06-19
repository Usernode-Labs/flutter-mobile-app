import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab indices matching the [IndexedStack] order in HomeScreen.
abstract final class HomeTab {
  static const int challenges = 0;
  static const int activity = 1;
  static const int wallet = 2;
  static const int dapps = 3;
  static const int nodeStatus = 4;
  static const int settings = 5;
}

/// Tracks the currently selected tab index in the HomeScreen's NavigationBar.
final currentHomeTabProvider = StateProvider<int>((ref) => HomeTab.challenges);
