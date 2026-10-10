// Asistan Canlı — Apple Watch köprüsü. Saat Mac'e doğrudan bağlanamaz (watchOS buna izin vermez);
// komutları ve durumu iPhone taşır. Saat bir şey isteyince iOS uygulamayı arka planda uyandırır.

import Combine
import Foundation
import UIKit
import WatchConnectivity

final class WatchRelay: NSObject, WCSessionDelegate {
    private let client: LiveClient
    private var changes: AnyCancellable?
    private var lastSent: WatchState?
    /// Saat uygulaması açıkken iPhone arka planda da Mac bağlantısını tutar
    private var watchUntil = Date.distantPast
    private var idleTimer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    /// Mac'e bağlanınca gönderilecek komut; bayatlarsa (çalma bittiyse) atılır
    private var pending: (command: String, at: Date)?
    var foreground = true

    var watching: Bool { Date() < watchUntil }

    init(client: LiveClient) {
        self.client = client
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        changes = client.objectWillChange
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.clientChanged() }
    }

    func state() -> WatchState {
        var s = WatchState()
        s.linked = client.phase == .connected
        s.ringing = client.ringing
        s.ringer = client.ringer
        s.inSession = client.inSession
        s.caller = client.caller
        s.startedAt = client.startedAt
        s.status = client.status
        s.lines = client.lines.suffix(WatchLink.lineLimit).map {
            WatchLine(id: $0.id, speaker: $0.speaker, text: String($0.text.prefix(400)), caller: $0.kind == .caller)
        }
        return s
    }

    private func clientChanged() {
        flushPending()
        let s = state()
        guard !s.sameContent(lastSent) else { return }
        let lightChanged = s.light() != lastSent?.light()
        lastSent = s
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let message = WatchLink.message(s)
        if session.isReachable { session.sendMessage(message, replyHandler: nil, errorHandler: nil) }
        guard lightChanged else { return }
        // Saat uygulaması kapalıyken de son durum hazır olsun; kadranda bileşen varsa saat hemen uyandırılır.
        try? session.updateApplicationContext(message)
        if session.isComplicationEnabled && session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(message)
        }
    }

    private func flushPending() {
        guard let p = pending, client.phase == .connected else { return }
        pending = nil
        guard Date().timeIntervalSince(p.at) < 20 else { return }
        perform(p.command)
    }

    private func perform(_ command: String) {
        if command == WatchLink.answer { client.answerCall() } else if command == WatchLink.end { client.endSession() }
    }

    // MARK: Saatten gelenler

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handle(message, reply: replyHandler)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message, reply: { _ in })
    }

    private func handle(_ message: [String: Any], reply: @escaping ([String: Any]) -> Void) {
        let command = message["t"] as? String ?? ""
        DispatchQueue.main.async {
            self.keepAwake()
            if command == WatchLink.answer || command == WatchLink.end {
                if self.client.phase == .connected { self.perform(command) } else { self.pending = (command, Date()) }
            }
            var answer = WatchLink.message(self.state())
            answer["queued"] = self.pending != nil
            reply(answer)
        }
    }

    /// Saat istedikçe 20 sn daha bağlı kal; uygulama arka plandaysa iOS'tan ek süre iste
    private func keepAwake() {
        watchUntil = Date().addingTimeInterval(20)
        if !foreground && backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Asistan Saat") { [weak self] in self?.release() }
        }
        client.activate()
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 21, repeats: false) { [weak self] _ in
            guard let self = self, !self.watching else { return }
            self.release()
        }
    }

    /// Saat sustu: ön planda değilsek bağlantıyı bırak
    private func release() {
        if !foreground { client.deactivate() }
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.lastSent = nil; self.clientChanged() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.lastSent = nil; self.clientChanged() }
    }
}
