import 'package:crypto_mobile_app/features/dapps/web_content_process_recovery.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // testWidgets for its fake clock: the loop window is a Timer.
  late List<String> calls;

  WebContentProcessRecovery recovery({
    AppLifecycleState? state = AppLifecycleState.resumed,
  }) =>
      WebContentProcessRecovery(
        lifecycleState: state,
        reload: () => calls.add('reload'),
        onGaveUp: () => calls.add('gave up'),
      );

  void goToBackground(WebContentProcessRecovery recovery) => recovery
    ..noteLifecycleState(AppLifecycleState.inactive)
    ..noteLifecycleState(AppLifecycleState.hidden)
    ..noteLifecycleState(AppLifecycleState.paused);

  void comeBack(WebContentProcessRecovery recovery) => recovery
    ..noteLifecycleState(AppLifecycleState.hidden)
    ..noteLifecycleState(AppLifecycleState.inactive)
    ..noteLifecycleState(AppLifecycleState.resumed);

  setUp(() => calls = []);

  testWidgets('reloads at once when the process dies in the foreground',
      (tester) async {
    final subject = recovery()..noteProcessTerminated();
    expect(calls, ['reload']);
    subject.dispose();
  });

  testWidgets('before any lifecycle state, the app is in the foreground',
      (tester) async {
    final subject = recovery(state: null)..noteProcessTerminated();
    expect(calls, ['reload']);
    subject.dispose();
  });

  testWidgets('a process lost in the background is reloaded on resume',
      (tester) async {
    final subject = recovery(state: AppLifecycleState.paused)
      ..noteProcessTerminated();
    expect(calls, isEmpty);
    subject
      ..noteLifecycleState(AppLifecycleState.hidden)
      ..noteLifecycleState(AppLifecycleState.inactive);
    expect(calls, isEmpty);
    subject.noteLifecycleState(AppLifecycleState.resumed);
    expect(calls, ['reload']);
    // One reload per termination.
    goToBackground(subject);
    comeBack(subject);
    expect(calls, ['reload']);
    subject.dispose();
  });

  testWidgets('a page that kills its process on load is not reloaded again',
      (tester) async {
    final subject = recovery()..noteProcessTerminated();
    await tester.pump(const Duration(seconds: 2));
    subject.noteProcessTerminated();
    expect(calls, ['reload', 'gave up']);
    // The window closing on its own does not restart the loop.
    await tester.pump(WebContentProcessRecovery.defaultLoopWindow);
    expect(calls, ['reload', 'gave up']);
    subject.dispose();
  });

  testWidgets('a termination after the loop window is reloaded again',
      (tester) async {
    final subject = recovery()..noteProcessTerminated();
    await tester.pump(WebContentProcessRecovery.defaultLoopWindow);
    subject.noteProcessTerminated();
    expect(calls, ['reload', 'reload']);
    subject.dispose();
  });

  testWidgets('a termination after a trip to the background is not a loop',
      (tester) async {
    final subject = recovery()..noteProcessTerminated();
    goToBackground(subject);
    subject.noteProcessTerminated();
    expect(calls, ['reload']);
    comeBack(subject);
    expect(calls, ['reload', 'reload']);
    subject.dispose();
  });

  testWidgets('after giving up, the next return from the background retries',
      (tester) async {
    final subject = recovery()
      ..noteProcessTerminated()
      ..noteProcessTerminated();
    expect(calls, ['reload', 'gave up']);
    goToBackground(subject);
    expect(calls, ['reload', 'gave up']);
    comeBack(subject);
    expect(calls, ['reload', 'gave up', 'reload']);
    subject.dispose();
  });

  testWidgets('does nothing once disposed', (tester) async {
    final subject = recovery(state: AppLifecycleState.paused)
      ..noteProcessTerminated()
      ..dispose();
    comeBack(subject);
    subject.noteProcessTerminated();
    expect(calls, isEmpty);
  });
}
