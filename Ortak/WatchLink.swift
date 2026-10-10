// Asistan Saat — iPhone ile Apple Watch arasında taşınan durum. Asistan Canlı, Asistan Saat ve kadran bileşeni ortak kullanır.

import Foundation

struct WatchLine: Codable, Equatable, Identifiable {
    var id: Int
    var speaker: String
    var text: String
    var caller: Bool
}

/// Mac'teki Asistan'ın o anki durumu; yalnızca şu anki görüşme (geçmiş saate gelmez)
struct WatchState: Codable, Equatable {
    enum Light: String { case idle, ringing, call }

    var linked = false          // iPhone, Mac'teki Asistan'a bağlı
    var ringing = false
    var ringer = ""
    var inSession = false
    var caller = ""
    var startedAt: Date?
    var status = ""
    var lines: [WatchLine] = []
    var updated = Date()

    /// Uzun süre güncellenmeyen bir "çalıyor" ya da "görüşmede" durumu ikonu yanlış renkte bırakmasın
    func light(at now: Date = Date()) -> Light {
        let age = now.timeIntervalSince(updated)
        if inSession && age < WatchLink.callStale { return .call }
        if ringing && !inSession && age < WatchLink.ringStale { return .ringing }
        return .idle
    }

    /// Renk bu tarihte griye döner (bileşen zaman çizelgesi için)
    var lightExpiry: Date? {
        if inSession { return updated.addingTimeInterval(WatchLink.callStale) }
        if ringing { return updated.addingTimeInterval(WatchLink.ringStale) }
        return nil
    }

    /// Yalnızca içerik karşılaştırması; updated her gönderimde değişir
    func sameContent(_ other: WatchState?) -> Bool {
        guard var o = other else { return false }
        o.updated = updated
        return o == self
    }
}

enum WatchLink {
    static let appGroup = "group.com.mtahca.asistan"
    static let ringStale: TimeInterval = 90
    static let callStale: TimeInterval = 30 * 60
    static let lineLimit = 8

    // Saatten iPhone'a giden komutlar
    static let watch = "watch"      // saat uygulaması açık: durumu gönder, bağlantıyı tut
    static let answer = "answer"
    static let end = "end"

    static func message(_ s: WatchState) -> [String: Any] {
        ["t": "state", "state": (try? JSONEncoder().encode(s)) ?? Data()]
    }

    static func state(from message: [String: Any]) -> WatchState? {
        guard let data = message["state"] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchState.self, from: data)
    }

    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static func store(_ s: WatchState) {
        defaults.set(try? JSONEncoder().encode(s), forKey: "watchState")
    }

    static func stored() -> WatchState? {
        defaults.data(forKey: "watchState").flatMap { try? JSONDecoder().decode(WatchState.self, from: $0) }
    }
}
