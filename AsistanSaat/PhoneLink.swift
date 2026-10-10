// Asistan Saat — iPhone'daki Asistan Canlı ile bağlantı. Komutlar ve durum WatchConnectivity ile taşınır.

import Foundation
import WatchConnectivity
import WatchKit
import WidgetKit

final class PhoneLink: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneLink()

    @Published private(set) var state = WatchLink.stored() ?? WatchState()
    @Published private(set) var reachable = false
    @Published private(set) var sending: String?        // gönderilen komut, yanıt gelene kadar
    @Published private(set) var problem: String?

    private var poll: Timer?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: Uygulama açıkken

    /// Ekran açıkken iPhone'dan durumu ister; iPhone da bu sürece Mac bağlantısını tutar
    func start() {
        poll?.invalidate()
        refresh()
        poll = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stop() {
        poll?.invalidate(); poll = nil
    }

    func refresh() { send(WatchLink.watch) }

    func answer() { send(WatchLink.answer) }

    func end() { send(WatchLink.end) }

    private func send(_ command: String) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            reachable = false
            if command != WatchLink.watch { problem = "iPhone'a ulaşılamıyor. iPhone yakında ve açık olmalı." }
            return
        }
        if command != WatchLink.watch { sending = command; problem = nil }
        session.sendMessage(["t": command], replyHandler: { reply in
            DispatchQueue.main.async {
                if let s = WatchLink.state(from: reply) { self.apply(s) }
                if command != WatchLink.watch {
                    self.sending = nil
                    if reply["queued"] as? Bool == true { self.problem = "iPhone Mac'e bağlanıyor; komut bağlanınca gönderilecek." }
                    WKInterfaceDevice.current().play(.click)
                }
            }
        }, errorHandler: { _ in
            DispatchQueue.main.async {
                if command != WatchLink.watch {
                    self.sending = nil
                    self.problem = "Komut iPhone'a iletilemedi; tekrar deneyin."
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        })
    }

    // MARK: Durum

    private func apply(_ s: WatchState) {
        let before = state
        state = s
        if s.linked { problem = problem?.contains("bağlanıyor") == true ? nil : problem }
        WatchLink.store(s)
        if s.light() != before.light() {
            WidgetCenter.shared.reloadAllTimelines()
            if s.light() == .ringing { WKInterfaceDevice.current().play(.notification) }
        }
    }

    private func receive(_ message: [String: Any]) {
        guard let s = WatchLink.state(from: message) else { return }
        DispatchQueue.main.async { self.apply(s) }
    }

    /// Arka planda uyandırıldığında bekleyen aktarımlar teslim edilsin
    func drain() async {
        for _ in 0..<20 {
            if !WCSession.default.hasContentPending { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        DispatchQueue.main.async {
            self.reachable = session.isReachable
            if self.poll != nil { self.refresh() }
        }
        receive(context)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.reachable = session.isReachable
            if session.isReachable && self.poll != nil { self.refresh() }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { receive(message) }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { receive(applicationContext) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { receive(userInfo) }
}
