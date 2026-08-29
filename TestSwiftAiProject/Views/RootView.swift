import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("Today", systemImage: "list.bullet")
                }

            DoneTodayView()
                .tabItem {
                    Label("Done", systemImage: "checkmark.circle")
                }
        }
    }
}
