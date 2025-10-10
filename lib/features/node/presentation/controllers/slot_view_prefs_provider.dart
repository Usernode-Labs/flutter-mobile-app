import 'package:flutter_riverpod/flutter_riverpod.dart';

class SlotViewPrefs {
  final bool showProduced;
  final bool showPending;
  final bool showMissed;

  const SlotViewPrefs({
    this.showProduced = true,
    this.showPending = true,
    this.showMissed = true,
  });

  SlotViewPrefs copyWith({
    bool? showProduced,
    bool? showPending,
    bool? showMissed,
  }) =>
      SlotViewPrefs(
        showProduced: showProduced ?? this.showProduced,
        showPending: showPending ?? this.showPending,
        showMissed: showMissed ?? this.showMissed,
      );
}

class SlotViewPrefsController extends StateNotifier<SlotViewPrefs> {
  SlotViewPrefsController() : super(const SlotViewPrefs());

  void toggleProduced() => state = state.copyWith(showProduced: !state.showProduced);
  void togglePending() => state = state.copyWith(showPending: !state.showPending);
  void toggleMissed() => state = state.copyWith(showMissed: !state.showMissed);
}

final slotViewPrefsProvider =
    StateNotifierProvider<SlotViewPrefsController, SlotViewPrefs>((ref) {
  return SlotViewPrefsController();
});
