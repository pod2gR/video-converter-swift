import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.currentPage {
            case .select:
                SelectView()
            case .settings:
                SettingsView()
            case .progress:
                ProgressView()
            }
        }
        .frame(minWidth: 720, idealWidth: 800, minHeight: 560, idealHeight: 600)
    }
}
