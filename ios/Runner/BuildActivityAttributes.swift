import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// The Live Activity shown while a project's first version is being built
/// (the `setBuildActivity` bridge method; see `BuildActivityChannel.swift`).
///
/// IMPORTANT: this file is compiled into BOTH the Runner app target, which
/// starts, updates and ends the activity, and the HomeroomWidgets extension,
/// which draws it (`HomeroomWidgets/BuildLiveActivity.swift`). ActivityKit
/// matches the two sides by this type, so it must exist in both.
///
/// Everything that can change while the build runs lives in [ContentState],
/// so a later APNs push can update it with a `content-state` like
/// `{"state": "active", "title": "Club Votes", "stage": "Building it",
/// "startedAtMs": 1760440000000, "etaAtMs": 1760441500000}`. Times are
/// milliseconds since the Unix epoch, as the bridge sends them, rather than
/// `Date`, whose default Codable form is seconds since 2001.
@available(iOS 16.1, *)
struct BuildActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    enum Phase: String, Codable {
      case active
      case ended
    }

    /// `active` while it builds; `ended` once the project is live.
    var state: Phase
    /// The project's name, e.g. "Club Votes".
    var title: String
    /// Already-localized stage words from the web, e.g. "Building it".
    var stage: String
    /// Optional second line, e.g. "Screens drawn".
    var detail: String?
    /// When this stage (or the build) started; the progress bar's origin.
    var startedAtMs: Double?
    /// When the project should be live; drives the countdown. Nil shows the
    /// stage only.
    var etaAtMs: Double?
    /// An https link that opens the project in the app.
    var deepLink: String?
    /// The ended headline as the web words it, e.g. "Club Votes is live".
    /// Nil falls back to the app's own "<title> is live".
    var endedTitle: String?
  }

  /// Stable per build, e.g. "first-version:club-votes-b7cc89".
  var activityId: String
}

@available(iOS 16.1, *)
extension BuildActivityAttributes.ContentState {
  var startedAt: Date? { startedAtMs.map { Date(timeIntervalSince1970: $0 / 1000) } }
  var etaAt: Date? { etaAtMs.map { Date(timeIntervalSince1970: $0 / 1000) } }

  /// The interval the countdown and the progress bar run over. Nil when there
  /// is no ETA, or no valid interval to draw: a `ClosedRange` whose lower
  /// bound passes its upper bound traps, so this is the only place either is
  /// built from.
  var countdownInterval: ClosedRange<Date>? {
    guard let eta = etaAt, let start = startedAt, start < eta else { return nil }
    return start...eta
  }

  /// The tap target. Only https, the same rule the bridge applies.
  var deepLinkURL: URL? {
    guard let deepLink, let url = URL(string: deepLink), url.scheme == "https" else {
      return nil
    }
    return url
  }

  /// "Building it · Screens drawn", or just the stage.
  var stageLine: String {
    [stage, detail ?? ""]
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
  }
}
#endif
