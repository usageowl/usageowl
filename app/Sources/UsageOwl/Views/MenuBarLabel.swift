import SwiftUI

/// Menu bar label: ONE pre-composed template image (see MenuBarImageRenderer).
/// Multi-child labels lose every image after the first when MenuBarExtra
/// bridges the label to the AppKit status item.
struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        Image(nsImage: store.menuBarImage)
    }
}
