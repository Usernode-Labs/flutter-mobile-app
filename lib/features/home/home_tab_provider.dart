import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the currently selected tab index in the HomeScreen's NavigationBar.
final currentHomeTabProvider = StateProvider<int>((ref) => 0);


