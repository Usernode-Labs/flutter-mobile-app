import 'package:crypto_mobile_app/features/dapps/native_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  NativeSignIn build({
    bool apple = true,
    bool google = true,
    AppleIdTokenRequest? appleRequest,
    GoogleIdTokenRequest? googleRequest,
  }) =>
      NativeSignIn(
        appleAvailable: apple,
        googleAvailable: google,
        apple: appleRequest ?? (_) async => 'apple.id.token',
        google: googleRequest ?? () async => 'google.id.token',
      );

  Matcher refusedWith(String code) => throwsA(
        isA<NativeSignInException>().having((e) => e.code, 'code', code),
      );

  test('advertises only the providers this build can show', () {
    expect(build().capabilities, ['signInWithApple', 'signInWithGoogle']);
    expect(build(apple: false).capabilities, ['signInWithGoogle']);
    expect(build(google: false).capabilities, ['signInWithApple']);
    expect(build(apple: false, google: false).capabilities, isEmpty);
  });

  test('Apple gets the SHA-256 of the page nonce, as lowercase hex', () async {
    String? asked;
    final signIn = build(appleRequest: (nonce) async {
      asked = nonce;
      return 'apple.id.token';
    });
    expect(
      await signIn.signIn({'provider': 'apple', 'nonce': 'abc'}),
      'apple.id.token',
    );
    expect(
      asked,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(NativeSignIn.hashedNonce('abc'), asked);
  });

  test('Google returns its ID token', () async {
    expect(
      await build().signIn({'provider': 'google', 'nonce': 'n'}),
      'google.id.token',
    );
  });

  test('refuses bad arguments and providers this build cannot show', () {
    final signIn = build(google: false);
    expect(signIn.signIn(null), refusedWith('invalid_args'));
    expect(signIn.signIn({'provider': 'github', 'nonce': 'n'}),
        refusedWith('invalid_args'));
    expect(signIn.signIn({'provider': 'apple'}), refusedWith('invalid_args'));
    expect(signIn.signIn({'provider': 'apple', 'nonce': 'x' * 201}),
        refusedWith('invalid_args'));
    expect(signIn.signIn({'provider': 'google', 'nonce': 'n'}),
        refusedWith('unsupported'));
  });

  test('a closed sheet is cancelled; anything else failed', () {
    final apple = build(
      appleRequest: (_) async =>
          throw const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.canceled,
        message: 'closed',
      ),
    );
    expect(apple.signIn({'provider': 'apple', 'nonce': 'n'}),
        refusedWith('cancelled'));
    final appleFailed = build(
      appleRequest: (_) async =>
          throw const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.failed,
        message: 'nope',
      ),
    );
    expect(appleFailed.signIn({'provider': 'apple', 'nonce': 'n'}),
        refusedWith('failed'));
    final google = build(
      googleRequest: () async => throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      ),
    );
    expect(google.signIn({'provider': 'google', 'nonce': 'n'}),
        refusedWith('cancelled'));
    final empty = build(googleRequest: () async => null);
    expect(empty.signIn({'provider': 'google', 'nonce': 'n'}),
        refusedWith('failed'));
  });
}
