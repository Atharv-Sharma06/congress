import SwiftUI

@main
struct CivicAIApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var metricsStore = MetricsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(metricsStore)
                .tint(Theme.Palette.primary)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.selectedLocation == nil {
                LocationPickerView { county in
                    appState.selectedLocation = county
                }
                .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Theme.Motion.standard), value: appState.selectedLocation == nil)
    }
}

struct MainTabView: View {
    @SceneStorage("civicai.selectedTab") private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            ExploreView()
                .tabItem { Label("Explore", systemImage: "square.grid.2x2.fill") }
                .tag(1)

            CompareView()
                .tabItem { Label("Compare", systemImage: "arrow.left.and.right") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
    }
}
