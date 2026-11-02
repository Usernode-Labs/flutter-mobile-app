import 'package:crypto_mobile_app/core/services/native_connectivity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectivitySnapshot', () {
    test('names each link once, in the order given', () {
      final snapshot = ConnectivitySnapshot.of(const [
        ConnectivityResult.wifi,
        ConnectivityResult.vpn,
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
      ]);
      expect(snapshot.via, ['wifi', 'vpn', 'mobile']);
      expect(snapshot.online, isTrue);
      expect(snapshot.toJson(), {
        'online': true,
        'via': ['wifi', 'vpn', 'mobile'],
      });
    });

    test('none is offline', () {
      final snapshot = ConnectivitySnapshot.of(const [ConnectivityResult.none]);
      expect(snapshot.toJson(), {
        'online': false,
        'via': ['none'],
      });
    });

    test('an empty reading is offline', () {
      expect(ConnectivitySnapshot.of(const []).toJson(), {
        'online': false,
        'via': <String>[],
      });
    });

    test('any link besides none is online', () {
      for (final result in ConnectivityResult.values) {
        if (result == ConnectivityResult.none) continue;
        expect(ConnectivitySnapshot.of([result]).online, isTrue,
            reason: result.name);
      }
    });

    test('readings with the same links are equal', () {
      expect(
        ConnectivitySnapshot.of(const [
          ConnectivityResult.mobile,
          ConnectivityResult.mobile,
        ]),
        ConnectivitySnapshot.of(const [ConnectivityResult.mobile]),
      );
      expect(
        ConnectivitySnapshot.of(const [
          ConnectivityResult.wifi,
          ConnectivityResult.vpn,
        ]),
        isNot(ConnectivitySnapshot.of(const [
          ConnectivityResult.vpn,
          ConnectivityResult.wifi,
        ])),
      );
    });
  });
}
