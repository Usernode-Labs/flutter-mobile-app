import SwiftUI
import WidgetKit
#if canImport(AppIntents)
import AppIntents
#endif

// MARK: - Shared storage

/// A homescreen-pinned dapp, mirrored from the Flutter app's registry via
/// `HomeShortcutsChannel.swift` (App Group defaults + `pinned_icons/`).
struct PinnedDapp: Codable, Identifiable {
  let id: String
  let name: String
  let deepLink: String
  let pinnedAtMs: Int64?
}

enum PinnedDappsStore {
  static let appGroupId = "group.org.usernode.app"
  static let pinnedDappsKey = "pinned_dapps"
  /// Which half of the pinned list the small (2x2) widget shows: 0 for
  /// dapps 1-4, 1 for dapps 5-8. Flipped by the page-dots tap.
  static let smallPageKey = "widget_small_page"

  static func load() -> [PinnedDapp] {
    guard let defaults = UserDefaults(suiteName: appGroupId),
          let json = defaults.string(forKey: pinnedDappsKey),
          let data = json.data(using: .utf8)
    else { return [] }
    return (try? JSONDecoder().decode([PinnedDapp].self, from: data)) ?? []
  }

  static func loadSmallPage() -> Int {
    let page = UserDefaults(suiteName: appGroupId)?.integer(forKey: smallPageKey) ?? 0
    return page == 1 ? 1 : 0
  }

  static func icon(for id: String) -> UIImage? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    ) else { return nil }
    let url = container
      .appendingPathComponent("pinned_icons", isDirectory: true)
      .appendingPathComponent("\(id).png")
    return UIImage(contentsOfFile: url.path)
  }
}

// MARK: - App Intents

#if canImport(AppIntents)
/// Shows a specific 2x2 page in the small widget. Runs in-process in
/// the widget extension (no app launch); WidgetKit reloads the timeline
/// automatically once the intent completes, so the provider re-reads the
/// page from the App Group.
///
/// Both arrows use this intent — the arrow for the page already on
/// screen re-sets the same value, which is a visual no-op. That makes
/// every tap on the arrow row land on a harmless button: nothing falls
/// through to the widget-level `widgetURL`, and hit-region overlap
/// between the two buttons can't cause surprising behavior.
@available(iOS 17.0, *)
struct SetSmallWidgetPageIntent: AppIntent {
  static var title: LocalizedStringResource = "Show pinned dApps page"
  static var isDiscoverable: Bool = false

  @Parameter(title: "Page")
  var page: Int

  init() {}
  init(page: Int) {
    self.page = page
  }

  func perform() async throws -> some IntentResult {
    let defaults = UserDefaults(suiteName: PinnedDappsStore.appGroupId)
    defaults?.set(page == 1 ? 1 : 0, forKey: PinnedDappsStore.smallPageKey)
    return .result()
  }
}

// NOTE: OpenPinnedDappIntent (per-icon launch for the small widget) lives
// in Runner/PinnedDappIntents.swift and is compiled into BOTH the app and
// this extension: openAppWhenRun intents execute in the app's process, so
// the type must exist there or taps silently no-op.
#endif

// MARK: - Timeline

struct PinnedDappsEntry: TimelineEntry {
  let date: Date
  let dapps: [PinnedDapp]
  let smallPage: Int
}

struct PinnedDappsProvider: TimelineProvider {
  func placeholder(in context: Context) -> PinnedDappsEntry {
    PinnedDappsEntry(date: Date(), dapps: [], smallPage: 0)
  }

  func getSnapshot(in context: Context, completion: @escaping (PinnedDappsEntry) -> Void) {
    completion(PinnedDappsEntry(
      date: Date(),
      dapps: PinnedDappsStore.load(),
      smallPage: PinnedDappsStore.loadSmallPage()
    ))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedDappsEntry>) -> Void) {
    // Content only changes when the app pins/unpins a dapp (the app
    // triggers reloadAllTimelines then) or when the page-flip intent
    // runs (WidgetKit reloads automatically) — no periodic refresh.
    let entry = PinnedDappsEntry(
      date: Date(),
      dapps: PinnedDappsStore.load(),
      smallPage: PinnedDappsStore.loadSmallPage()
    )
    completion(Timeline(entries: [entry], policy: .never))
  }
}

// MARK: - Views

/// Adaptive branded background with a subtle violet cast (matching the
/// dapp tiles' violet accent): off-white in light mode, off-black in
/// dark mode. Home-screen widgets are composited onto an opaque backdrop
/// by the system, so transparency/materials render as plain white — a
/// tinted card is the styled alternative. Dynamic UIColors resolve per
/// appearance, so one gradient serves both modes.
private enum WidgetBackground {
  private static func adaptive(
    light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)
  ) -> Color {
    Color(UIColor { traits in
      let (r, g, b) = traits.userInterfaceStyle == .dark ? dark : light
      return UIColor(red: r, green: g, blue: b, alpha: 1)
    })
  }

  static let gradient = LinearGradient(
    colors: [
      adaptive(light: (0.97, 0.96, 0.99), dark: (0.13, 0.11, 0.20)),
      adaptive(light: (0.94, 0.93, 0.97), dark: (0.07, 0.07, 0.11)),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

private extension View {
  // iOS 17 requires containerBackground for widgets; earlier versions
  // reject it, so branch on availability.
  @ViewBuilder func widgetContainerBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(WidgetBackground.gradient, for: .widget)
    } else {
      background(WidgetBackground.gradient)
    }
  }
}

/// Matches the dapps-home tile styling (Tailwind violet-600 at 20% for
/// the letter-tile background, violet-400 for the letter). Dapps pinned
/// from the home screen usually ship a canvas-rendered PNG of the exact
/// in-app tile; this fallback covers registry entries without one.
private enum TileColors {
  static let background = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255).opacity(0.2)
  static let letter = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)
}

struct DappIconView: View {
  let dapp: PinnedDapp
  let iconSize: CGFloat
  var nameFont: Font = .caption2

  var body: some View {
    VStack(spacing: 4) {
      if let icon = PinnedDappsStore.icon(for: dapp.id) {
        Image(uiImage: icon)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: iconSize, height: iconSize)
          .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous))
      } else {
        RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
          .fill(TileColors.background)
          .frame(width: iconSize, height: iconSize)
          .overlay(
            Text(String(dapp.name.prefix(1)).uppercased())
              .font(.system(size: iconSize * 0.45, weight: .bold))
              .foregroundColor(TileColors.letter)
          )
      }
      Text(dapp.name)
        .font(nameFont)
        .lineLimit(1)
        .foregroundColor(.primary)
    }
  }
}

struct EmptyStateView: View {
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "square.grid.2x2")
        .font(.title2)
        .foregroundColor(.secondary)
      Text("Pin a dApp from the Usernode app to see it here.")
        .font(.caption)
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
    }
    .padding()
  }
}

struct UsernodeDappsWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: PinnedDappsEntry

  var body: some View {
    Group {
      if entry.dapps.isEmpty {
        EmptyStateView()
      } else if family == .systemSmall {
        smallView
      } else {
        mediumView
      }
    }
    .widgetContainerBackground()
  }

  // 2x2 grid mirroring the medium widget's first (or second) row pair.
  // WidgetKit has no swipe gestures, so paging is tap-to-flip via the
  // arrow buttons at the bottom (iOS 17+). Individual icons launch
  // their dapp on iOS 18+; on older versions the whole widget
  // deep-links to the first visible dapp via widgetURL.
  private var smallView: some View {
    let all = Array(entry.dapps.prefix(8))
    let hasSecondPage = all.count > 4
    let page = hasSecondPage ? entry.smallPage : 0
    let visible = page == 1 ? Array(all.dropFirst(4)) : Array(all.prefix(4))
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 2)
    // A single page renders no arrow row, so the freed height goes to
    // bigger tiles instead of dead space at the bottom. A lone dapp is
    // centered at ~60pt to visually match a regular home-screen icon.
    let iconSize: CGFloat = hasSecondPage ? 42 : 48
    let gridSpacing: CGFloat = hasSecondPage ? 6 : 10

    if all.count == 1, let dapp = all.first {
      // Label width is capped relative to the tile (same margin ratio as
      // a grid cell), so long names truncate instead of spanning the
      // whole widget.
      return AnyView(
        smallCell(dapp, iconSize: 60, nameFont: .system(size: 11))
          .frame(width: 92)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .widgetURL(URL(string: dapp.deepLink))
      )
    }

    // Grid pinned to the top, arrows pinned to the bottom. The grid sits
    // in a ZStack keyed by page: when the flip intent lands, WidgetKit
    // animates the old grid out and the new one in, and `.move` on each
    // (leading for page 0, trailing for page 1) turns that into a
    // horizontal slide — forward pushes left, back pushes right — instead
    // of the default cross-fade. ZStack (not the VStack directly) so the
    // outgoing and incoming grids overlap during the transition rather
    // than stacking; .clipped() keeps the slide inside the widget.
    return AnyView(VStack(spacing: 4) {
      ZStack(alignment: .top) {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
          ForEach(visible) { dapp in
            smallCell(dapp, iconSize: iconSize)
          }
        }
        .id(page)
        .transition(.move(edge: page == 1 ? .trailing : .leading))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .clipped()
      .padding(.horizontal, 8)
      .padding(.top, 8)
      if hasSecondPage {
        pageControl(page: page)
      }
    }
    .padding(.bottom, 8)
    .widgetURL(URL(string: visible.first?.deepLink ?? "usernode://app")))
  }

  @ViewBuilder private func smallCell(
    _ dapp: PinnedDapp, iconSize: CGFloat, nameFont: Font = .system(size: 9)
  ) -> some View {
    let icon = DappIconView(dapp: dapp, iconSize: iconSize, nameFont: nameFont)
    #if canImport(AppIntents)
    if #available(iOSApplicationExtension 18.0, *) {
      Button(intent: OpenPinnedDappIntent(deepLink: dapp.deepLink)) { icon }
        .buttonStyle(.plain)
    } else {
      icon
    }
    #else
    icon
    #endif
  }

  // Back/forward arrows: only the arrow pointing at the hidden page is
  // tappable; the other is grayed out. With exactly two pages a single
  // toggle intent serves both directions. Each arrow is a visible chip:
  // the tinted fill IS the hit box, so there's no guessing where to tap.
  // (An invisible fill matching the widget background proved unreliable —
  // WidgetKit derives a button's tappable region from what the label
  // actually renders, and background-colored fills left dead zones.)
  @ViewBuilder private func pageControl(page: Int) -> some View {
    HStack(spacing: 6) {
      pageArrow(systemName: "arrow.left", targetPage: 0, enabled: page == 1)
      pageArrow(systemName: "arrow.right", targetPage: 1, enabled: page == 0)
    }
    .frame(height: 22)
    .padding(.horizontal, 8)
  }

  @ViewBuilder private func pageArrow(
    systemName: String, targetPage: Int, enabled: Bool
  ) -> some View {
    let chip = RoundedRectangle(cornerRadius: 7, style: .continuous)
      .fill(Color.primary.opacity(enabled ? 0.08 : 0.03))
      .overlay(
        Image(systemName: systemName)
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(enabled ? .primary : Color.primary.opacity(0.2))
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    #if canImport(AppIntents)
    if #available(iOSApplicationExtension 17.0, *) {
      // Both chips are always buttons with the same intent type. The
      // "disabled" one targets the page already on screen, so tapping
      // it is a visual no-op — and its taps never fall through to
      // widgetURL (which would launch an app from an inert-looking
      // control).
      Button(intent: SetSmallWidgetPageIntent(page: targetPage)) { chip }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    } else {
      chip
    }
    #else
    chip
    #endif
  }

  private var mediumView: some View {
    let dapps = Array(entry.dapps.prefix(8))
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    return LazyVGrid(columns: columns, spacing: 10) {
      ForEach(dapps) { dapp in
        if let url = URL(string: dapp.deepLink) {
          Link(destination: url) {
            DappIconView(dapp: dapp, iconSize: 44)
          }
        } else {
          DappIconView(dapp: dapp, iconSize: 44)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
}

// MARK: - Widget

struct UsernodeDappsWidget: Widget {
  static let kind = "UsernodeDappsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: PinnedDappsProvider()) { entry in
      UsernodeDappsWidgetView(entry: entry)
    }
    .configurationDisplayName("Usernode dApps")
    .description("Quick access to the dApps you pinned in Usernode.")
    .supportedFamilies([.systemSmall, .systemMedium])
    // Reclaim the default ~16pt system content margins; the views apply
    // their own tighter padding so the small grid gets larger icons.
    .contentMarginsDisabled()
  }
}
