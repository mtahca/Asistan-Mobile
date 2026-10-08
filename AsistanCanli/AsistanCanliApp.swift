// Asistan Canlı — Mac'teki Asistan'ın canlı görüşme metnini iPhone'da gösterir.

import SwiftUI

@main
struct AsistanCanliApp: App {
    @StateObject private var client = LiveClient()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(client)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Arka planda bağlantı tutulamaz; ön plana dönünce yeniden bağlanıp son durumu alırız
            if phase == .active { client.activate() } else if phase == .background { client.deactivate() }
        }
    }
}
