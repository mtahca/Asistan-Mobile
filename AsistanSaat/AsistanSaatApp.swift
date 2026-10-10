// Asistan Saat — gelen aramayı asistana cevaplatır, görüşmeyi bitirir, o anki görüşmeyi gösterir.

import SwiftUI

@main
struct AsistanSaatApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let link = PhoneLink.shared

    var body: some Scene {
        WindowGroup {
            SaatView()
                .environmentObject(link)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { link.start() } else { link.stop() }
        }
        // iPhone kadran bileşeni için durum gönderdiğinde saat arka planda uyandırılır
        .backgroundTask(.watchConnectivity) { await PhoneLink.shared.drain() }
    }
}
