import Flutter
import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Native side of the `com.onhomeroom.app/build_activity` MethodChannel: the
/// Live Activity for a project's first version being built. The bridge
/// method is `setBuildActivity` (`lib/features/dapps/build_live_activity.dart`
/// validates the page's arguments and documents the contract); the extension
/// draws it (`HomeroomWidgets/BuildLiveActivity.swift`).
///
/// Methods:
/// - `isAvailable` -> Bool: ActivityKit exists here (iOS 16.1+). Fixed for
///   the process, so Dart asks once and advertises the capability from it.
/// - `setBuildActivity` -> `{supported, started?, pushToken?}`.
final class BuildActivityChannel {
  static let channelName = "com.onhomeroom.app/build_activity"

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(Self.isAvailable)
    case "setBuildActivity":
      #if canImport(ActivityKit)
      guard #available(iOS 16.1, *) else {
        result(["supported": false])
        return
      }
      // Dart has validated these already; this re-checks them because the
      // channel is the boundary the extension's rendering trusts.
      guard let request = BuildActivityRequest(call.arguments) else {
        result(FlutterError(
          code: "invalid_args",
          message: "setBuildActivity arguments are invalid",
          details: nil
        ))
        return
      }
      Task { @MainActor in
        result(await BuildActivityController.shared.enqueue(request))
      }
      #else
      result(["supported": false])
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Ends every build activity at once. A sign-out retires the session whose
  /// project it names, so it must not stay on the Lock Screen.
  static func endAll() {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }
    Task { @MainActor in
      await BuildActivityController.shared.endAll()
    }
    #endif
  }

  private static var isAvailable: Bool {
    #if canImport(ActivityKit)
    if #available(iOS 16.1, *) { return true }
    #endif
    return false
  }
}

#if canImport(ActivityKit)
/// One validated `setBuildActivity` call, as Dart forwards it.
@available(iOS 16.1, *)
struct BuildActivityRequest {
  typealias Phase = BuildActivityAttributes.ContentState.Phase

  // The same limits as Dart's BuildActivityRequest.
  static let maxActivityIdLength = 128
  static let maxTitleLength = 80
  static let maxStageLength = 80
  static let maxDetailLength = 120
  static let maxDeepLinkLength = 1024

  let activityId: String
  let state: Phase
  let title: String
  let stage: String
  let detail: String?
  let startedAtMs: Double?
  let etaAtMs: Double?
  let deepLink: String?
  let endedTitle: String?

  init?(_ arguments: Any?) {
    guard let args = arguments as? [String: Any],
          let activityId = args["activityId"] as? String,
          !activityId.isEmpty,
          activityId.count <= Self.maxActivityIdLength,
          let rawState = args["state"] as? String,
          let state = Phase(rawValue: rawState),
          let title = Self.text(args["title"], limit: Self.maxTitleLength) else {
      return nil
    }
    let stage = Self.text(args["stage"], limit: Self.maxStageLength)
    if state == .active, stage == nil { return nil }

    var deepLink: String?
    if let raw = args["deepLink"] as? String,
       raw.count <= Self.maxDeepLinkLength,
       let url = URL(string: raw),
       url.scheme == "https",
       url.host != nil {
      deepLink = raw
    }

    self.activityId = activityId
    self.state = state
    self.title = title
    self.stage = stage ?? ""
    detail = Self.text(args["detail"], limit: Self.maxDetailLength)
    startedAtMs = Self.millis(args["startedAt"])
    etaAtMs = Self.millis(args["etaAt"])
    self.deepLink = deepLink
    endedTitle = Self.text(args["endedTitle"], limit: Self.maxDetailLength)
  }

  /// The content to show. A call without `startedAt` keeps the running
  /// activity's origin, so the progress bar does not restart on every stage.
  func contentState(startedAtFallback: Double) -> BuildActivityAttributes.ContentState {
    BuildActivityAttributes.ContentState(
      state: state,
      title: title,
      stage: stage,
      detail: detail,
      startedAtMs: startedAtMs ?? startedAtFallback,
      etaAtMs: etaAtMs,
      deepLink: deepLink,
      endedTitle: endedTitle
    )
  }

  private static func text(_ value: Any?, limit: Int) -> String? {
    guard let raw = value as? String else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : String(trimmed.prefix(limit))
  }

  private static func millis(_ value: Any?) -> Double? {
    guard let number = value as? NSNumber else { return nil }
    let ms = number.doubleValue
    return ms.isFinite && ms > 0 ? ms : nil
  }
}

/// Starts, updates and ends the build Live Activity. Calls run one at a time,
/// in order: two quick stage updates must not both see "nothing running" and
/// start two activities.
@available(iOS 16.1, *)
@MainActor
final class BuildActivityController {
  typealias State = BuildActivityAttributes.ContentState

  static let shared = BuildActivityController()

  /// How long "<title> is live" stays on the Lock Screen after the end call.
  /// The page ends the activity when it sees the project live, which is
  /// usually while the person is already looking at it, so this is short.
  static let endedDismissalDelay: TimeInterval = 10 * 60
  /// The countdown gives way to "taking a little longer" this long past the
  /// ETA, unless an update moves the ETA first.
  static let staleAfterEta: TimeInterval = 10 * 60
  /// Without an ETA, a build nobody has updated for this long reads as stale.
  static let staleWithoutEta: TimeInterval = 30 * 60
  /// How long a new activity waits for ActivityKit's first push token.
  static let pushTokenWait: UInt64 = 2_000_000_000

  /// Builds whose activity the person removed from the Lock Screen. A later
  /// update for the same build must not put it back.
  private static let declinedKey = "build_activity_declined_ids"
  private static let declinedLimit = 20

  private var tail: Task<Void, Never>?
  /// `Activity.id`s this app ended, so their removal is not read as the
  /// person declining them.
  private var endedByApp = Set<String>()
  private var observed = Set<String>()

  func enqueue(_ request: BuildActivityRequest) async -> [String: Any] {
    let previous = tail
    let work = Task { @MainActor () -> [String: Any] in
      await previous?.value
      return await self.apply(request)
    }
    tail = Task { @MainActor in _ = await work.value }
    return await work.value
  }

  func endAll() async {
    for activity in Activity<BuildActivityAttributes>.activities where Self.isRunning(activity) {
      await end(activity, with: nil, dismissal: .immediate)
    }
  }

  private func apply(_ request: BuildActivityRequest) async -> [String: Any] {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      return ["supported": false]
    }

    // One build at a time: a different build's activity ends first, and so
    // does any duplicate of this one.
    var current: Activity<BuildActivityAttributes>?
    for activity in Activity<BuildActivityAttributes>.activities where Self.isRunning(activity) {
      observe(activity)
      if activity.attributes.activityId == request.activityId, current == nil {
        current = activity
      } else {
        await end(activity, with: nil, dismissal: .immediate)
      }
    }

    let now = Date().timeIntervalSince1970 * 1000
    let previousStart = current.flatMap { Self.state(of: $0).startedAtMs }
    let state = request.contentState(startedAtFallback: previousStart ?? now)

    switch request.state {
    case .active:
      if let current {
        await update(current, to: state)
        var reply: [String: Any] = ["supported": true, "started": true]
        if let token = current.pushToken { reply["pushToken"] = Self.hex(token) }
        return reply
      }
      if Self.isDeclined(request.activityId) {
        return ["supported": true, "started": false]
      }
      guard let activity = start(activityId: request.activityId, state: state) else {
        return ["supported": true, "started": false]
      }
      observe(activity)
      var reply: [String: Any] = ["supported": true, "started": true]
      if let token = await firstPushToken(of: activity) { reply["pushToken"] = token }
      return reply

    case .ended:
      // Nothing running for this build: the person is in the app (the page
      // only runs there), so a fresh "is live" on the Lock Screen would only
      // be clutter.
      guard let current else { return ["supported": true, "started": false] }
      await end(
        current,
        with: state,
        dismissal: .after(Date().addingTimeInterval(Self.endedDismissalDelay))
      )
      return ["supported": true, "started": false]
    }
  }

  /// ActivityKit only starts an activity while the app is in the foreground,
  /// and refuses it when the person has turned Live Activities off. Both are
  /// a `started: false`, not an error. The push-token request needs the push
  /// entitlement; a build without it still gets a local activity.
  private func start(activityId: String, state: State) -> Activity<BuildActivityAttributes>? {
    let attributes = BuildActivityAttributes(activityId: activityId)
    for pushType in [PushType.token, nil] as [PushType?] {
      do {
        if #available(iOS 16.2, *) {
          return try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: Self.staleDate(for: state)),
            pushType: pushType
          )
        }
        return try Activity.request(
          attributes: attributes,
          contentState: state,
          pushType: pushType
        )
      } catch {
        print("[BuildActivity] request failed (push: \(pushType == nil ? "none" : "token")): \(error)")
      }
    }
    return nil
  }

  private func update(_ activity: Activity<BuildActivityAttributes>, to state: State) async {
    if #available(iOS 16.2, *) {
      await activity.update(ActivityContent(state: state, staleDate: Self.staleDate(for: state)))
    } else {
      await activity.update(using: state)
    }
  }

  private func end(
    _ activity: Activity<BuildActivityAttributes>,
    with state: State?,
    dismissal: ActivityUIDismissalPolicy
  ) async {
    endedByApp.insert(activity.id)
    if #available(iOS 16.2, *) {
      await activity.end(
        state.map { ActivityContent(state: $0, staleDate: nil) },
        dismissalPolicy: dismissal
      )
    } else {
      await activity.end(using: state, dismissalPolicy: dismissal)
    }
  }

  /// Notes when the person removes a running activity, so the same build
  /// does not start a new one on its next update.
  private func observe(_ activity: Activity<BuildActivityAttributes>) {
    guard observed.insert(activity.id).inserted else { return }
    let systemId = activity.id
    let activityId = activity.attributes.activityId
    Task { @MainActor in
      for await state in activity.activityStateUpdates where state == .dismissed {
        if !self.endedByApp.contains(systemId) {
          Self.recordDeclined(activityId)
        }
        break
      }
    }
  }

  /// The first push token arrives shortly after the request. Wait a moment
  /// for it, never longer: the page is waiting on this answer.
  private func firstPushToken(of activity: Activity<BuildActivityAttributes>) async -> String? {
    if let token = activity.pushToken { return Self.hex(token) }
    return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
      let once = ResumeOnce(continuation)
      let listener = Task { @MainActor in
        for await token in activity.pushTokenUpdates {
          once.resume(Self.hex(token))
          return
        }
        once.resume(nil)
      }
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: Self.pushTokenWait)
        listener.cancel()
        once.resume(activity.pushToken.map(Self.hex))
      }
    }
  }

  static func staleDate(for state: State) -> Date {
    if let eta = state.etaAt { return eta.addingTimeInterval(staleAfterEta) }
    return Date().addingTimeInterval(staleWithoutEta)
  }

  private static func state(of activity: Activity<BuildActivityAttributes>) -> State {
    if #available(iOS 16.2, *) { return activity.content.state }
    return activity.contentState
  }

  /// Active, or stale (iOS 16.2+): still on screen and still updatable.
  private static func isRunning(_ activity: Activity<BuildActivityAttributes>) -> Bool {
    switch activity.activityState {
    case .ended, .dismissed: return false
    default: return true
    }
  }

  private static func isDeclined(_ activityId: String) -> Bool {
    (UserDefaults.standard.stringArray(forKey: declinedKey) ?? []).contains(activityId)
  }

  private static func recordDeclined(_ activityId: String) {
    var ids = UserDefaults.standard.stringArray(forKey: declinedKey) ?? []
    ids.removeAll { $0 == activityId }
    ids.append(activityId)
    UserDefaults.standard.set(Array(ids.suffix(declinedLimit)), forKey: declinedKey)
  }

  private static func hex(_ token: Data) -> String {
    token.map { String(format: "%02x", $0) }.joined()
  }
}

/// Resumes a continuation exactly once, whichever of its racers is first.
private final class ResumeOnce<T> {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<T, Never>?

  init(_ continuation: CheckedContinuation<T, Never>) {
    self.continuation = continuation
  }

  func resume(_ value: T) {
    lock.lock()
    let pending = continuation
    continuation = nil
    lock.unlock()
    pending?.resume(returning: value)
  }
}
#endif
