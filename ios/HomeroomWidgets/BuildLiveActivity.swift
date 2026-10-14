import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Build Live Activity

/// The Lock Screen and Dynamic Island presentation of a project's first
/// version being built. The app starts, updates and ends it
/// (`Runner/BuildActivityChannel.swift`); `BuildActivityAttributes` is shared
/// with the app (`Runner/BuildActivityAttributes.swift`).
///
/// Four looks, chosen from the content alone, so it stays right while the app
/// is asleep and nothing updates it:
/// - building, with an ETA: stage, a countdown and a progress bar that both
///   run on their own;
/// - building, no ETA: the stage only;
/// - stale (iOS 16.2+, ten minutes past the ETA without an update): a calm
///   "taking a little longer" and a pointer back to the app;
/// - ended: "<Project> is live".
@available(iOS 16.1, *)
struct BuildLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BuildActivityAttributes.self) { context in
      BuildActivityLockScreenView(state: context.state, isStale: context.showsStale)
        .activityBackgroundTint(BuildActivityPalette.ground)
        .activitySystemActionForegroundColor(BuildActivityPalette.ink)
        .widgetURL(context.state.deepLinkURL)
    } dynamicIsland: { context in
      let state = context.state
      let isStale = context.showsStale
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HomeroomMarkView(height: 22)
            .padding(.leading, 6)
            .frame(maxHeight: .infinity)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if let interval = state.countdownInterval, !isStale, state.state == .active {
            Text(timerInterval: interval, countsDown: true)
              .font(.title3.weight(.semibold))
              .monospacedDigit()
              .multilineTextAlignment(.trailing)
              .foregroundColor(BuildActivityPalette.accent)
              .frame(maxWidth: 72, maxHeight: .infinity, alignment: .trailing)
              .padding(.trailing, 6)
          }
        }
        DynamicIslandExpandedRegion(.center) {
          Text(state.state == .ended ? state.endedHeadline : state.title)
            .font(.headline)
            .foregroundColor(BuildActivityPalette.ink)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          BuildActivityExpandedDetail(state: state, isStale: isStale)
            .padding(.horizontal, 6)
        }
      } compactLeading: {
        HomeroomMarkView(height: 15)
          .padding(.leading, 2)
      } compactTrailing: {
        BuildActivityCompactTrailing(state: state, isStale: isStale)
      } minimal: {
        HomeroomMarkView(height: 14)
      }
      .widgetURL(state.deepLinkURL)
      .keylineTint(BuildActivityPalette.accent)
    }
  }
}

@available(iOS 16.1, *)
private extension ActivityViewContext where Attributes == BuildActivityAttributes {
  /// Past its stale date and not ended. `isStale` exists from iOS 16.2; on
  /// 16.1 the activity just keeps its last content.
  var showsStale: Bool {
    guard state.state == .active else { return false }
    if #available(iOS 16.2, *) { return isStale }
    return false
  }
}

// MARK: - Copy

/// Words the app supplies itself. Everything else (the title, the stage and
/// its detail, and usually the ended headline) arrives localized from the web.
@available(iOS 16.1, *)
enum BuildActivityCopy {
  static func isLive(_ title: String) -> String {
    String(
      localized: "\(title) is live",
      comment: "Live Activity headline once a project's first version is live"
    )
  }

  static let stale = String(
    localized: "Taking a little longer than planned",
    comment: "Live Activity, when a build is past its expected time"
  )

  static let openForLatest = String(
    localized: "Open Homeroom for the latest.",
    comment: "Live Activity, under the note that a build is taking longer"
  )

  static let remaining = String(
    localized: "left",
    comment: "Live Activity, under the countdown, as in '12:30 left'"
  )
}

@available(iOS 16.1, *)
private extension BuildActivityAttributes.ContentState {
  var endedHeadline: String { endedTitle ?? BuildActivityCopy.isLive(title) }
}

// MARK: - Lock Screen

@available(iOS 16.1, *)
struct BuildActivityLockScreenView: View {
  let state: BuildActivityAttributes.ContentState
  let isStale: Bool

  var body: some View {
    Group {
      if state.state == .ended {
        ended
      } else if isStale {
        stale
      } else {
        building
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var building: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        HomeroomMarkView(height: 26)
        VStack(alignment: .leading, spacing: 2) {
          titleText(state.title)
          secondaryText(state.stageLine)
        }
        Spacer(minLength: 8)
        if let interval = state.countdownInterval {
          VStack(alignment: .trailing, spacing: 0) {
            Text(timerInterval: interval, countsDown: true)
              .font(.title3.weight(.semibold))
              .monospacedDigit()
              .multilineTextAlignment(.trailing)
              .foregroundColor(BuildActivityPalette.ink)
              .frame(maxWidth: 80, alignment: .trailing)
            Text(BuildActivityCopy.remaining)
              .font(.caption)
              .foregroundColor(BuildActivityPalette.inkSecondary)
          }
        }
      }
      if let interval = state.countdownInterval {
        BuildActivityProgress(interval: interval)
      }
    }
  }

  private var stale: some View {
    HStack(alignment: .center, spacing: 12) {
      HomeroomMarkView(height: 26)
      VStack(alignment: .leading, spacing: 2) {
        titleText(state.title)
        secondaryText(BuildActivityCopy.stale)
        Text(BuildActivityCopy.openForLatest)
          .font(.footnote)
          .foregroundColor(BuildActivityPalette.inkSecondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
  }

  private var ended: some View {
    HStack(alignment: .center, spacing: 12) {
      HomeroomMarkView(height: 26)
      VStack(alignment: .leading, spacing: 2) {
        titleText(state.endedHeadline)
        if let detail = state.detail {
          secondaryText(detail)
        }
      }
      Spacer(minLength: 8)
      Image(systemName: "checkmark.circle.fill")
        .font(.title2)
        .foregroundColor(BuildActivityPalette.accent)
        .accessibilityHidden(true)
    }
  }

  private func titleText(_ text: String) -> some View {
    Text(text)
      .font(.headline)
      .foregroundColor(BuildActivityPalette.ink)
      .lineLimit(1)
  }

  private func secondaryText(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundColor(BuildActivityPalette.inkSecondary)
      .lineLimit(1)
  }
}

// MARK: - Dynamic Island

@available(iOS 16.1, *)
struct BuildActivityExpandedDetail: View {
  let state: BuildActivityAttributes.ContentState
  let isStale: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if state.state == .ended {
        if let detail = state.detail { line(detail) }
      } else if isStale {
        line(BuildActivityCopy.stale)
        Text(BuildActivityCopy.openForLatest)
          .font(.footnote)
          .foregroundColor(BuildActivityPalette.inkSecondary)
          .lineLimit(1)
      } else {
        line(state.stageLine)
        if let interval = state.countdownInterval {
          BuildActivityProgress(interval: interval)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func line(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundColor(BuildActivityPalette.inkSecondary)
      .lineLimit(1)
  }
}

@available(iOS 16.1, *)
struct BuildActivityCompactTrailing: View {
  let state: BuildActivityAttributes.ContentState
  let isStale: Bool

  var body: some View {
    if state.state == .ended {
      Image(systemName: "checkmark.circle.fill")
        .foregroundColor(BuildActivityPalette.accent)
        .accessibilityHidden(true)
    } else if let interval = state.countdownInterval, !isStale {
      // A timer text takes all the width it is offered; pin it to what
      // "00:00" needs or it pushes the island wide.
      Text(timerInterval: interval, countsDown: true)
        .font(.system(size: 15, weight: .semibold))
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .foregroundColor(BuildActivityPalette.accent)
        .frame(width: 46, alignment: .trailing)
    } else {
      Image(systemName: "hourglass")
        .foregroundColor(BuildActivityPalette.accent)
        .accessibilityHidden(true)
    }
  }
}

// MARK: - Pieces

/// Fills from the stage's start to the ETA on its own; no update needed.
@available(iOS 16.1, *)
struct BuildActivityProgress: View {
  let interval: ClosedRange<Date>

  var body: some View {
    ProgressView(timerInterval: interval, countsDown: false) {
      EmptyView()
    } currentValueLabel: {
      EmptyView()
    }
    .progressViewStyle(.linear)
    .tint(BuildActivityPalette.accent)
  }
}

/// The app icon's colours: cream on dark ink, with the platform's blue for
/// the one thing that moves. Fixed rather than adaptive, so the Lock Screen
/// reads the same over any wallpaper and matches the black Dynamic Island.
enum BuildActivityPalette {
  /// #171717, the app icon's ground.
  static let ground = Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255)
  /// #FFFEF4, the app icon's mark.
  static let ink = Color(red: 1, green: 254 / 255, blue: 244 / 255)
  static let inkSecondary = ink.opacity(0.68)
  /// #5AA9FF, the platform's accent on a dark ground.
  static let accent = Color(red: 90 / 255, green: 169 / 255, blue: 1)
}

/// The Homeroom mark (the H with its sparkle) at a given height.
struct HomeroomMarkView: View {
  let height: CGFloat
  var color: Color = BuildActivityPalette.ink

  var body: some View {
    HomeroomMarkShape()
      .fill(color)
      .frame(width: height * HomeroomMarkShape.aspectRatio, height: height)
      .accessibilityHidden(true)
  }
}

/// `assets/brand/src/mark-black.svg` as a vector shape, so it stays sharp at
/// every Live Activity size without an asset catalog in the extension.
struct HomeroomMarkShape: Shape {
  /// The SVG's viewBox, 378 x 300.
  static let viewBox = CGSize(width: 378, height: 300)
  static let aspectRatio = viewBox.width / viewBox.height

  func path(in rect: CGRect) -> Path {
    let scale = min(rect.width / Self.viewBox.width, rect.height / Self.viewBox.height)
    let origin = CGPoint(
      x: rect.midX - Self.viewBox.width * scale / 2,
      y: rect.midY - Self.viewBox.height * scale / 2
    )
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }

    var p = Path()
    // The H.
    p.move(to: pt(282.189, 0.018))
    p.addCurve(to: pt(287.489, 21.427), control1: pt(293.177, -0.605), control2: pt(288.538, 14.682))
    p.addCurve(to: pt(281.788, 53.716), control1: pt(285.905, 32.243), control2: pt(284, 43.011))
    p.addLine(to: pt(266.215, 133.631))
    p.addCurve(to: pt(255.815, 215.829), control1: pt(261.47, 158.905), control2: pt(253.667, 190.232))
    p.addCurve(to: pt(264.084, 232.79), control1: pt(256.366, 220.783), control2: pt(259.692, 230.204))
    p.addCurve(to: pt(324.219, 210.07), control1: pt(284.827, 245.01), control2: pt(310.841, 225.149))
    p.addCurve(to: pt(333.65, 199.543), control1: pt(326.038, 208.023), control2: pt(331.965, 199.835))
    p.addCurve(to: pt(331.86, 212.815), control1: pt(340.38, 201.027), control2: pt(333.91, 209.31))
    p.addCurve(to: pt(211.715, 261.345), control1: pt(313.045, 244.972), control2: pt(244.904, 303.554))
    p.addCurve(to: pt(210.475, 173.268), control1: pt(195.524, 240.754), control2: pt(205.895, 198.505))
    p.addCurve(to: pt(191.045, 176.206), control1: pt(204.051, 173.857), control2: pt(197.465, 175.394))
    p.addCurve(to: pt(159.87, 179.135), control1: pt(180.723, 177.511), control2: pt(170.247, 178.385))
    p.addCurve(to: pt(156.553, 196.671), control1: pt(159.221, 184.031), control2: pt(157.523, 191.621))
    p.addLine(to: pt(148.885, 235.802))
    p.addLine(to: pt(143.91, 262.1))
    p.addCurve(to: pt(122.179, 287.814), control1: pt(140.066, 282.074), control2: pt(141.043, 280.208))
    p.addCurve(to: pt(91.531, 300), control1: pt(112.216, 291.83), control2: pt(101.685, 296.154))
    p.addCurve(to: pt(88.499, 295.149), control1: pt(89.644, 298.559), control2: pt(88.2, 297.774))
    p.addCurve(to: pt(91.392, 278.551), control1: pt(89.131, 289.592), control2: pt(90.342, 284.049))
    p.addLine(to: pt(98.846, 240.768))
    p.addCurve(to: pt(109.372, 187.118), control1: pt(102.015, 222.82), control2: pt(105.524, 204.933))
    p.addLine(to: pt(109.168, 187.156))
    p.addCurve(to: pt(29.365, 242.87), control1: pt(80.303, 192.726), control2: pt(41.34, 213.558))
    p.addCurve(to: pt(27.985, 250.494), control1: pt(28.577, 244.8), control2: pt(29.377, 248.673))
    p.addCurve(to: pt(16.354, 246.979), control1: pt(24.748, 254.747), control2: pt(19.122, 249.066))
    p.addCurve(to: pt(39.32, 164.777), control1: pt(-18.486, 220.706), control2: pt(8.614, 179.535))
    p.addCurve(to: pt(53.482, 157.03), control1: pt(43.866, 162.592), control2: pt(48.496, 159.119))
    p.addCurve(to: pt(117.64, 141.63), control1: pt(73.638, 148.585), control2: pt(95.904, 143.669))
    p.addCurve(to: pt(131.239, 75.308), control1: pt(124.515, 122.017), control2: pt(126.011, 95.84))
    p.addCurve(to: pt(138.789, 47.849), control1: pt(132.63, 69.849), control2: pt(134.25, 50.785))
    p.addCurve(to: pt(170.677, 34.24), control1: pt(147.904, 41.953), control2: pt(160.588, 38.389))
    p.addCurve(to: pt(185.528, 27.919), control1: pt(175.511, 32.277), control2: pt(180.441, 28.64))
    p.addCurve(to: pt(188.795, 34.759), control1: pt(188.438, 27.622), control2: pt(189.078, 32.813))
    p.addCurve(to: pt(183.13, 63), control1: pt(187.414, 44.262), control2: pt(184.895, 53.552))
    p.addLine(to: pt(168.863, 138.998))
    p.addCurve(to: pt(191.045, 137.184), control1: pt(175.211, 138.852), control2: pt(184.739, 138.113))
    p.addCurve(to: pt(217.82, 130.139), control1: pt(208.259, 133.879), control2: pt(201.647, 135.532))
    p.addCurve(to: pt(233.597, 45.952), control1: pt(222.813, 102.028), control2: pt(228.072, 73.964))
    p.addCurve(to: pt(239.622, 15.043), control1: pt(234.64, 40.391), control2: pt(237.641, 18.314))
    p.addCurve(to: pt(244.507, 11.12), control1: pt(240.826, 13.053), control2: pt(242.425, 12.076))
    p.addCurve(to: pt(256.552, 7.479), control1: pt(248.259, 9.397), control2: pt(252.598, 8.66))
    p.addCurve(to: pt(282.189, 0.018), control1: pt(265.06, 4.94), control2: pt(273.564, 2.138))
    p.closeSubpath()
    // The sparkle.
    p.move(to: pt(332.572, 79.328))
    p.addCurve(to: pt(334.906, 80.22), control1: pt(333.662, 79.599), control2: pt(333.905, 79.704))
    p.addCurve(to: pt(338.107, 91.457), control1: pt(335.931, 81.654), control2: pt(337.325, 89.173))
    p.addCurve(to: pt(364.112, 120.729), control1: pt(343.766, 108.044), control2: pt(346.465, 115.586))
    p.addCurve(to: pt(376.749, 124.279), control1: pt(368.374, 121.972), control2: pt(372.863, 122.226))
    p.addCurve(to: pt(377.296, 126.998), control1: pt(377.462, 125.223), control2: pt(377.328, 125.836))
    p.addCurve(to: pt(376.704, 128.109), control1: pt(377.13, 127.312), control2: pt(376.931, 127.683))
    p.addCurve(to: pt(345.614, 142.885), control1: pt(367.07, 132.072), control2: pt(352.546, 133.991))
    p.addCurve(to: pt(336.745, 165.5), control1: pt(342.146, 147.337), control2: pt(338.123, 159.819))
    p.addCurve(to: pt(333.046, 172.978), control1: pt(335.98, 168.65), control2: pt(335.684, 171.234))
    p.addLine(to: pt(331.13, 172.309))
    p.addCurve(to: pt(326.552, 157.414), control1: pt(329.027, 170.349), control2: pt(327.492, 160.796))
    p.addCurve(to: pt(323.481, 148.255), control1: pt(325.681, 154.312), control2: pt(324.656, 151.256))
    p.addCurve(to: pt(320.467, 142.056), control1: pt(322.967, 146.922), control2: pt(321.419, 143.093))
    p.addCurve(to: pt(300.113, 131.507), control1: pt(315.508, 136.663), control2: pt(307.057, 133.292))
    p.addCurve(to: pt(290.073, 128.786), control1: pt(296.633, 130.613), control2: pt(293.323, 130.111))
    p.addCurve(to: pt(288.352, 126.776), control1: pt(288.765, 128.252), control2: pt(288.712, 127.821))
    p.addCurve(to: pt(289.389, 124.806), control1: pt(288.55, 125.826), control2: pt(288.546, 125.392))
    p.addCurve(to: pt(296.304, 122.436), control1: pt(291.163, 123.575), control2: pt(294.23, 123.021))
    p.addCurve(to: pt(318.19, 112.247), control1: pt(304.132, 120.229), control2: pt(312.004, 117.815))
    p.addCurve(to: pt(332.572, 79.328), control1: pt(326.564, 104.714), control2: pt(327.962, 82.632))
    p.closeSubpath()
    return p
  }
}
