import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A `setBuildActivity` call that showed nothing.
class BuildActivityException implements Exception {
  const BuildActivityException(this.code, this.message);

  /// `invalid_args` (the page sent something outside the contract) or
  /// `failed` (native could not act on a valid request). Sent to the page as
  /// `errorInfo.code`.
  final String code;

  /// A plain English sentence, the bridge's `error`.
  final String message;

  @override
  String toString() => 'BuildActivityException($code, $message)';
}

/// What the build looks like now: `active` while it builds, `ended` once the
/// project is live.
enum BuildActivityState { active, ended }

/// One validated `setBuildActivity` request. Each call describes the whole
/// activity: an optional field that is left out is cleared, except
/// [startedAtMs], which keeps the running activity's origin so the progress
/// bar does not restart.
@immutable
class BuildActivityRequest {
  const BuildActivityRequest({
    required this.activityId,
    required this.state,
    required this.title,
    this.stage,
    this.detail,
    this.startedAtMs,
    this.etaAtMs,
    this.deepLink,
    this.endedTitle,
  });

  /// Stable per build, e.g. `first-version:club-votes-b7cc89`.
  final String activityId;
  final BuildActivityState state;

  /// The project's name, e.g. "Club Votes".
  final String title;

  /// Already-localized stage words, e.g. "Building it". Required while
  /// [state] is active; an ended activity shows the "is live" headline.
  final String? stage;

  /// Optional second line, e.g. "Screens drawn".
  final String? detail;

  /// Milliseconds since the epoch when this stage (or the build) started.
  final int? startedAtMs;

  /// Milliseconds since the epoch when the project should be live. Drives a
  /// countdown that keeps running with the app asleep. Null shows the stage
  /// only.
  final int? etaAtMs;

  /// An https URL that opens the project in the app when the activity is
  /// tapped.
  final String? deepLink;

  /// The ended headline, already localized, e.g. "Club Votes is live". When
  /// omitted the app shows its own "`<title>` is live".
  final String? endedTitle;

  static const maxActivityIdLength = 128;
  static const maxTitleLength = 80;
  static const maxStageLength = 80;
  static const maxDetailLength = 120;
  static const maxDeepLinkLength = 1024;

  /// 2020-01-01 to 2100-01-01: anything outside is a unit mistake (seconds
  /// for milliseconds) rather than a time.
  static const _minEpochMs = 1577836800000;
  static const _maxEpochMs = 4102444800000;

  static final RegExp _activityIdPattern = RegExp(r'^[A-Za-z0-9][\w.:-]*$');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Reads the page's `args`. Throws a [BuildActivityException] with code
  /// `invalid_args` naming the first field outside the contract.
  factory BuildActivityRequest.parse(Object? args) {
    if (args is! Map) throw _invalid('args must be an object');

    final activityId = args['activityId'];
    if (activityId is! String ||
        activityId.length > maxActivityIdLength ||
        !_activityIdPattern.hasMatch(activityId)) {
      throw _invalid(
        'activityId must be 1-$maxActivityIdLength letters, digits, '
        "'.', ':', '_' or '-'",
      );
    }

    final state = switch (args['state']) {
      'active' => BuildActivityState.active,
      'ended' => BuildActivityState.ended,
      _ => throw _invalid("state must be 'active' or 'ended'"),
    };

    final title = _text(args, 'title', maxTitleLength, required: true)!;
    final stage = _text(
      args,
      'stage',
      maxStageLength,
      required: state == BuildActivityState.active,
    );
    final detail = _text(args, 'detail', maxDetailLength);
    final endedTitle = _text(args, 'endedTitle', maxDetailLength);
    final startedAtMs = _epochMs(args, 'startedAt');
    final etaAtMs = _epochMs(args, 'etaAt');
    if (startedAtMs != null && etaAtMs != null && etaAtMs <= startedAtMs) {
      throw _invalid('etaAt must be after startedAt');
    }

    return BuildActivityRequest(
      activityId: activityId,
      state: state,
      title: title,
      stage: stage,
      detail: detail,
      startedAtMs: startedAtMs,
      etaAtMs: etaAtMs,
      deepLink: _deepLink(args['deepLink']),
      endedTitle: endedTitle,
    );
  }

  /// The arguments of the native `setBuildActivity` channel call.
  Map<String, Object?> toChannelArguments() => {
        'activityId': activityId,
        'state': state.name,
        'title': title,
        'stage': stage,
        'detail': detail,
        'startedAt': startedAtMs,
        'etaAt': etaAtMs,
        'deepLink': deepLink,
        'endedTitle': endedTitle,
      };

  static BuildActivityException _invalid(String message) =>
      BuildActivityException('invalid_args', message);

  /// A one-line string: runs of whitespace (newlines included) become one
  /// space. Absent, null or blank is null, which only a required field
  /// refuses.
  static String? _text(
    Map<dynamic, dynamic> args,
    String key,
    int maxLength, {
    bool required = false,
  }) {
    final raw = args[key];
    if (raw != null && raw is! String) throw _invalid('$key must be a string');
    final text = (raw as String?)?.replaceAll(_whitespace, ' ').trim() ?? '';
    if (text.isEmpty) {
      if (required) throw _invalid('$key is required');
      return null;
    }
    if (text.length > maxLength) {
      throw _invalid('$key must be at most $maxLength characters');
    }
    return text;
  }

  static int? _epochMs(Map<dynamic, dynamic> args, String key) {
    final raw = args[key];
    if (raw == null) return null;
    if (raw is! num ||
        !raw.isFinite ||
        raw < _minEpochMs ||
        raw > _maxEpochMs) {
      throw _invalid('$key must be milliseconds since the epoch');
    }
    return raw.round();
  }

  static String? _deepLink(Object? raw) {
    if (raw == null) return null;
    final uri = raw is String && raw.length <= maxDeepLinkLength
        ? Uri.tryParse(raw)
        : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw _invalid(
        'deepLink must be an https URL of at most $maxDeepLinkLength '
        'characters',
      );
    }
    return raw as String;
  }
}

/// The iOS Live Activity for a project's first version being built: the
/// project, the stage and the time left, on the Lock Screen and in the
/// Dynamic Island, ending with "`<Project>` is live".
///
/// Bridge method `setBuildActivity` (privileged: the trusted top-frame shell
/// only). Args are [BuildActivityRequest]'s fields under their wire names
/// (`activityId`, `state`, `title`, `stage`, `detail`, `startedAt`, `etaAt`,
/// `deepLink`, `endedTitle`). Resolves `{supported, started?, pushToken?}`:
/// - `supported` is false where nothing can show: not iOS 16.1+, or Live
///   Activities switched off for the app.
/// - `started` is true when an activity for `activityId` is showing after
///   the call (started now, or updated); false when ActivityKit refused to
///   start one (it starts only while the app is in the foreground), when the
///   person removed this build's activity earlier, or after `ended`.
/// - `pushToken` is the activity's ActivityKit push token (hex), when iOS
///   issued one, for a later server push to update it.
///
/// The same `activityId` updates the running activity; a different one ends
/// the previous build's activity first. `ended` shows "`<title>` is live" (or
/// `endedTitle`) and leaves it on the Lock Screen for ten minutes.
///
/// Native side: `ios/Runner/BuildActivityChannel.swift`; the views:
/// `ios/HomeroomWidgets/BuildLiveActivity.swift`.
class BuildLiveActivity {
  BuildLiveActivity({
    MethodChannel channel = const MethodChannel(channelName),
    bool? isSupportedPlatform,
  })  : _channel = channel,
        _isSupportedPlatform = isSupportedPlatform;

  static const channelName = 'com.onhomeroom.app/build_activity';
  static const capability = 'setBuildActivity';

  static final BuildLiveActivity instance = BuildLiveActivity();

  final MethodChannel _channel;
  final bool? _isSupportedPlatform;
  Future<bool>? _available;

  bool get _onIOS =>
      _isSupportedPlatform ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether this device has ActivityKit (iOS 16.1+). Fixed for the process,
  /// so native is asked once. Whether the person allows Live Activities can
  /// change at any time and is answered per call as `supported`.
  Future<bool> isAvailable() => _available ??= _probe();

  /// `[capability]` where the method can show something, otherwise empty.
  Future<List<String>> capabilities() async =>
      [if (await isAvailable()) capability];

  /// Applies the page's `args`. Where nothing can show (not iOS 16.1+) it
  /// resolves `supported: false` whatever the args; otherwise it throws a
  /// [BuildActivityException] for args outside the contract.
  Future<Map<String, Object?>> apply(Object? args) async {
    if (!await isAvailable()) return const {'supported': false};
    final request = BuildActivityRequest.parse(args);
    final Map<String, Object?>? reply;
    try {
      reply = await _channel.invokeMapMethod<String, Object?>(
        'setBuildActivity',
        request.toChannelArguments(),
      );
    } on MissingPluginException {
      return const {'supported': false};
    } on PlatformException catch (error) {
      debugPrint('[BuildLiveActivity] native refused: $error');
      throw const BuildActivityException(
        'failed',
        'The build activity could not be shown.',
      );
    }
    return _sanitize(reply);
  }

  Future<bool> _probe() async {
    if (!_onIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('[BuildLiveActivity] availability unknown: $error');
      return false;
    }
  }

  /// Passes on only the contract's keys, with their types.
  static Map<String, Object?> _sanitize(Map<String, Object?>? reply) {
    final supported = reply?['supported'] == true;
    if (!supported) return const {'supported': false};
    final started = reply?['started'];
    final pushToken = reply?['pushToken'];
    return {
      'supported': true,
      'started': started == true,
      if (pushToken is String && pushToken.isNotEmpty) 'pushToken': pushToken,
    };
  }
}
