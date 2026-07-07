import SwiftUI
import WidgetKit

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

  static func load() -> [PinnedDapp] {
    guard let defaults = UserDefaults(suiteName: appGroupId),
          let json = defaults.string(forKey: pinnedDappsKey),
          let data = json.data(using: .utf8)
    else { return [] }
    return (try? JSONDecoder().decode([PinnedDapp].self, from: data)) ?? []
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

// MARK: - Timeline

struct PinnedDappsEntry: TimelineEntry {
  let date: Date
  let dapps: [PinnedDapp]
}

struct PinnedDappsProvider: TimelineProvider {
  func placeholder(in context: Context) -> PinnedDappsEntry {
    PinnedDappsEntry(date: Date(), dapps: [])
  }

  func getSnapshot(in context: Context, completion: @escaping (PinnedDappsEntry) -> Void) {
    completion(PinnedDappsEntry(date: Date(), dapps: PinnedDappsStore.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedDappsEntry>) -> Void) {
    // Content only changes when the app pins/unpins a dapp, and the app
    // triggers reloadAllTimelines then — no periodic refresh needed.
    let entry = PinnedDappsEntry(date: Date(), dapps: PinnedDappsStore.load())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

// MARK: - Views

private extension View {
  // iOS 17 requires containerBackground for widgets; earlier versions
  // reject it, so branch on availability.
  @ViewBuilder func widgetContainerBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    } else {
      background(Color(UIColor.systemBackground))
    }
  }
}

struct DappIconView: View {
  let dapp: PinnedDapp
  let iconSize: CGFloat

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
          .fill(Color.accentColor.opacity(0.15))
          .frame(width: iconSize, height: iconSize)
          .overlay(
            Text(String(dapp.name.prefix(1)).uppercased())
              .font(.system(size: iconSize * 0.45, weight: .semibold))
              .foregroundColor(.accentColor)
          )
      }
      Text(dapp.name)
        .font(.caption2)
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

  // Small widgets support a single tap target, so show the most recently
  // pinned dapp and deep-link the whole widget.
  private var smallView: some View {
    let dapp = entry.dapps[0]
    return DappIconView(dapp: dapp, iconSize: 56)
      .widgetURL(URL(string: dapp.deepLink))
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
  }
}
