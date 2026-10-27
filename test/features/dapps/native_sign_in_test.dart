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

  // The sheet shows a generic line; the page reports this one to the
  // platform's log, so a failure on a phone can be told apart from the server.
  test('a failure says what the provider said, in its message', () async {
    Matcher failedSaying(String text) => throwsA(isA<NativeSignInException>()
        .having((e) => e.code, 'code', 'failed')
        .having((e) => e.message, 'message', text));
    final google = build(
      googleRequest: () async => throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'Invalid\n  client',
      ),
    );
    await expectLater(
      google.signIn({'provider': 'google', 'nonce': 'n'}),
      failedSaying(
          'Google sign-in did not finish (clientConfigurationError: Invalid client).'),
    );
    final apple = build(
      appleRequest: (_) async =>
          throw const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.failed,
        message: 'nope',
      ),
    );
    await expectLater(
      apple.signIn({'provider': 'apple', 'nonce': 'n'}),
      failedSaying('Apple sign-in did not finish (failed: nope).'),
    );
    await expectLater(
      build(googleRequest: () async => null)
          .signIn({'provider': 'google', 'nonce': 'n'}),
      failedSaying('Google sign-in did not finish '
          '(noIdToken: the sheet finished without an ID token).'),
    );
    final plugin = build(googleRequest: () async => throw Exception('boom'));
    await expectLater(
      plugin.signIn({'provider': 'google', 'nonce': 'n'}),
      failedSaying(
          'Google sign-in did not finish (_Exception: Exception: boom).'),
    );
  });

  test('a reason is one line of at most 200 characters', () {
    expect(NativeSignIn.reason('unknownError', null), 'unknownError');
    expect(NativeSignIn.reason('x', 'a\n\tb'), 'x: a b');
    expect(NativeSignIn.reason('x', 'y' * 500).length, 200);
  });
}
