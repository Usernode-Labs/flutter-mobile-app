import 'dart:async';

import 'package:crypto_mobile_app/core/bootstrap/proving_parameters_preparation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> flushAsync() => Future<void>.delayed(Duration.zero);

void main() {
  group('foreground proving parameter preparation', () {
    test('coalesces callers and retains their pending future across retry',
        () async {
      final preparation = ProvingParametersPreparation();
      addTearDown(preparation.dispose);
      final finish = Completer<void>();
      var attempts = 0;
      var settled = false;
      final first = preparation.run((report) async {
        attempts++;
        report(attempts == 1 ? 6 : 8, 10);
        if (attempts == 1) throw StateError('connection interrupted');
        await finish.future;
      });
      unawaited(first.then((_) => settled = true));
      final second = preparation.run((_) async {
        fail('a concurrent caller must share the original attempt');
      });
      expect(identical(first, second), isTrue);

      await flushAsync();
      expect(attempts, 1);
      expect(settled, isFalse);
      expect(preparation.value!.failed, isTrue);
      expect(preparation.value!.completedBytes, 6);
      expect(preparation.value!.totalBytes, 10);

      preparation.retry();
      preparation.retry();
      await flushAsync();
      expect(attempts, 2);
      expect(settled, isFalse);
      expect(preparation.value!.failed, isFalse);
      expect(preparation.value!.completedBytes, 8);

      finish.complete();
      await Future.wait([first, second]);
      expect(settled, isTrue);
      expect(preparation.value, isNull);
      preparation.retry(); // No pending failure to resume.
      await preparation.run((_) async => attempts++);
      expect(attempts, 3);
      expect(preparation.value, isNull);
    });

    test('progress fractions are bounded and unknown totals stay indeterminate',
        () {
      expect(const ProvingParametersProgress(1, 0).fraction, 0);
      expect(const ProvingParametersProgress(-1, 10).fraction, 0);
      expect(const ProvingParametersProgress(5, 10).fraction, .5);
      expect(const ProvingParametersProgress(12, 10).fraction, 1);
    });
  });

  group('proving parameter polling', () {
    test('cached-ready status avoids preparation and progress polling',
        () async {
      var checks = 0;
      await pollProvingParameters(
        prepare: () async => fail('already initialized'),
        status: () async {
          checks++;
          return (true, 10, 10);
        },
        report: (_, __) => fail('cached data must not show a download'),
      );
      expect(checks, 1);
    });

    test('a preparation error waits for the in-flight status call to finish',
        () async {
      final preparation = Completer<void>();
      final status = Completer<(bool, int, int)>();
      var checks = 0;
      var settled = false;
      final progress = <(int, int)>[];
      final polling = pollProvingParameters(
        prepare: () => preparation.future,
        status: () async {
          checks++;
          if (checks == 1) return (false, 0, 10);
          return status.future;
        },
        report: (completed, total) => progress.add((completed, total)),
        interval: Duration.zero,
      );
      final observed = polling.then<void>((_) => settled = true,
          onError: (Object _, StackTrace __) => settled = true);
      final expectation = expectLater(polling, throwsStateError);
      await flushAsync();
      expect(checks, 2);
      preparation.completeError(StateError('download failed'));
      await flushAsync();
      expect(settled, isFalse,
          reason: 'session drain must still own the status call');
      status.complete((false, 3, 10));
      await expectation;
      await observed;
      expect(settled, isTrue);
      expect(progress, [(0, 10), (3, 10)]);
      await flushAsync();
      expect(checks, 2, reason: 'no polling may continue after failure');
    });

    test('a status error joins the still-running preparation', () async {
      final preparation = Completer<void>();
      final secondCheck = Completer<(bool, int, int)>();
      var checks = 0;
      var settled = false;
      final polling = pollProvingParameters(
        prepare: () => preparation.future,
        status: () async {
          checks++;
          if (checks == 1) return (false, 0, 10);
          return secondCheck.future;
        },
        report: (_, __) {},
        interval: Duration.zero,
      );
      final observed = polling.then<void>((_) => settled = true,
          onError: (Object _, StackTrace __) => settled = true);
      final expectation = expectLater(polling, throwsStateError);
      await flushAsync();
      secondCheck.completeError(StateError('status unavailable'));
      await flushAsync();
      expect(settled, isFalse,
          reason: 'preparation must not outlive the admitted callback');
      preparation.complete();
      await expectation;
      await observed;
      expect(settled, isTrue);
      await flushAsync();
      expect(checks, 2);
    });

    test('successful preparation also joins an in-flight progress call',
        () async {
      final preparation = Completer<void>();
      final status = Completer<(bool, int, int)>();
      var checks = 0;
      var settled = false;
      final progress = <(int, int)>[];
      final polling = pollProvingParameters(
        prepare: () => preparation.future,
        status: () async {
          checks++;
          if (checks == 1) return (false, 2, 10);
          return status.future;
        },
        report: (completed, total) => progress.add((completed, total)),
        interval: Duration.zero,
      );
      unawaited(polling.then((_) => settled = true));
      await flushAsync();
      preparation.complete();
      await flushAsync();
      expect(settled, isFalse);
      status.complete((true, 10, 10));
      await polling;
      expect(settled, isTrue);
      expect(progress, [(2, 10), (10, 10)]);
      expect(checks, 2);
    });
  });
}
