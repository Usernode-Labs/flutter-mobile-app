import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// A native sign-in the web shell asked for that produced no ID token.
class NativeSignInException implements Exception {
  const NativeSignInException(this.code, this.message);

  /// `cancelled` (the person closed the sheet), `invalid_args`,
  /// `unsupported` or `failed`. Sent to the page as `errorInfo.code`.
  final String code;

  /// A plain English sentence, the bridge's `error`. A `failed` one ends
  /// with what the provider's SDK said, in brackets ([NativeSignIn.reason]):
  /// the page reports it to the platform, which logs it, because the sheet
  /// itself only ever shows its generic "That did not work" line.
  final String message;

  @override
  String toString() => 'NativeSignInException($code, $message)';
}

/// Asks Apple for an ID token carrying [hashedNonce].
typedef AppleIdTokenRequest = Future<String?> Function(String hashedNonce);

/// Asks Google for an ID token.
typedef GoogleIdTokenRequest = Future<String?> Function();

/// Sign in with Apple and Google for the web shell's sign-in sheet
/// (`signInWithProvider`; social-vibecoding NATIVE-BRIDGE.md, "Native
/// sign-in"). The providers' own web pages refuse the app's web view, so
/// the page asks for the app's sheet instead and sends the ID token it
/// returns to the platform, which verifies it and signs the person in.
///
/// The page's nonce is single use. Apple's sheet carries its SHA-256 (lower
/// case hex), as Apple's documentation asks. Google's SDK takes a nonce only
/// once per process, at initialisation, so its tokens carry none; the
/// platform takes such a token only while it is fresh, and only once.
class NativeSignIn {
  NativeSignIn({
    required this.appleAvailable,
    required this.googleAvailable,
    AppleIdTokenRequest? apple,
    GoogleIdTokenRequest? google,
  })  : _apple = apple ?? _appleIdToken,
        _google = google ?? _GoogleSession().idToken;

  /// This build's configuration: Apple on iOS, whose Runner.entitlements
  /// carries Sign in with Apple; Google where its client IDs were given at
  /// build time (AppConfig.googleServerClientId, and on iOS
  /// AppConfig.googleIosClientId too).
  factory NativeSignIn.fromAppConfig() {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final hasServerClient = AppConfig.googleServerClientId.isNotEmpty;
    return NativeSignIn(
      appleAvailable: isIOS,
      googleAvailable: hasServerClient &&
          (isAndroid || (isIOS && AppConfig.googleIosClientId.isNotEmpty)),
    );
  }

  static final NativeSignIn instance = NativeSignIn.fromAppConfig();

  static const String appleCapability = 'signInWithApple';
  static const String googleCapability = 'signInWithGoogle';
  static const int _nonceMaxLength = 200;

  final bool appleAvailable;
  final bool googleAvailable;
  final AppleIdTokenRequest _apple;
  final GoogleIdTokenRequest _google;

  /// The bridge capabilities this build advertises.
  List<String> get capabilities => [
        if (appleAvailable) appleCapability,
        if (googleAvailable) googleCapability,
      ];

  /// The nonce as Apple's sheet carries it.
  static String hashedNonce(String nonce) =>
      sha256.convert(utf8.encode(nonce)).toString();

  /// The provider's ID token for the page's `{ provider, nonce }`.
  Future<String> signIn(Object? args) async {
    final provider = args is Map ? args['provider'] : null;
    final nonce = args is Map ? args['nonce'] : null;
    if ((provider != 'apple' && provider != 'google') ||
        nonce is! String ||
        nonce.isEmpty ||
        nonce.length > _nonceMaxLength) {
      throw const NativeSignInException(
        'invalid_args',
        'provider (apple or google) and nonce are required',
      );
    }
    final apple = provider == 'apple';
    final label = apple ? 'Apple' : 'Google';
    if (apple ? !appleAvailable : !googleAvailable) {
      throw NativeSignInException(
        'unsupported',
        '$label sign-in is not available in this app build',
      );
    }
    String? token;
    try {
      token = apple ? await _apple(hashedNonce(nonce)) : await _google();
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) throw _cancelled;
      throw _failed(label, reason(error.code.name, error.message));
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) throw _cancelled;
      throw _failed(label, reason(error.code.name, error.description));
    } on Exception catch (error) {
      // A plugin that is missing or answers off-script (PlatformException,
      // MissingPluginException) is a failure the page should hear about too.
      throw _failed(label, reason(error.runtimeType.toString(), '$error'));
    }
    if (token == null || token.isEmpty) {
      throw _failed(label, 'noIdToken: the sheet finished without an ID token');
    }
    return token;
  }

  static const NativeSignInException _cancelled =
      NativeSignInException('cancelled', 'Sign-in was cancelled.');

  static const int _reasonMaxLength = 200;

  /// `code: description`, on one line and at most [_reasonMaxLength]
  /// characters: what a provider's SDK said when its sheet failed.
  @visibleForTesting
  static String reason(String code, String? description) {
    final text = (description ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final line = text.isEmpty ? code : '$code: $text';
    return line.length <= _reasonMaxLength
        ? line
        : line.substring(0, _reasonMaxLength);
  }

  static NativeSignInException _failed(String label, String reason) {
    debugPrint('[NativeSignIn] $label refused: $reason');
    return NativeSignInException(
      'failed',
      '$label sign-in did not finish ($reason).',
    );
  }
}

Future<String?> _appleIdToken(String hashedNonce) async {
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: const [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: hashedNonce,
  );
  return credential.identityToken;
}

/// Google's SDK is initialised once per process, on the first sign-in.
class _GoogleSession {
  Future<void>? _ready;

  Future<String?> idToken() async {
    final google = GoogleSignIn.instance;
    _ready ??= google.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? AppConfig.googleIosClientId
          : null,
      serverClientId: AppConfig.googleServerClientId,
    );
    await _ready;
    final account = await google.authenticate();
    return account.authentication.idToken;
  }
}
