// Asistan Canlı — Mac'teki Asistan'ın canlı görüşme metnini iPhone'da gösterir.

import SwiftUI

@main
struct AsistanCanliApp: App {
    @StateObject private var client: LiveClient
    /// Saat komutları uygulama arka plandayken de gelir; köprü uygulama açılır açılmaz kurulur
    private let watch: WatchRelay

    init() {
        let client = LiveClient()
        _client = StateObject(wrappedValue: client)
        watch = WatchRelay(client: client)
    }
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(client)
                // iPhone Kamera'yla okutulan eşleştirme QR kodu asistan://pair?… bağlantısını açar
                .onOpenURL { url in _ = client.pair(url.absoluteString) }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Arka planda bağlantı tutulamaz; ön plana dönünce yeniden bağlanıp son durumu alırız
            // Saat uygulaması açıksa bağlantıyı onun için bir süre daha tutarız.
            watch.foreground = phase == .active
            if phase == .active { client.activate() } else if phase == .background && !watch.watching { client.deactivate() }
        }
    }
}
