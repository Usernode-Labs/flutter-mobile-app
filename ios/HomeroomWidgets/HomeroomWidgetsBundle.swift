import SwiftUI
import WidgetKit

@main
struct HomeroomWidgetsBundle: WidgetBundle {
  var body: some Widget {
    HomeroomDappsWidget()
    // The first-version build Live Activity (BuildLiveActivity.swift).
    if #available(iOS 16.1, *) {
      BuildLiveActivityWidget()
    }
  }
}
