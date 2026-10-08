// Asistan Canlı — Mac'e bağlantı: Bonjour ile bul, TLS-PSK ile bağlan, canlı metni al, talimat / sonlandır gönder.
// Tüm ağ geri çağrıları ana kuyrukta çalışır; böylece @Published alanlar doğrudan güncellenir.

import Foundation
import Network
import Security

struct LiveLine: Identifiable, Equatable {
    enum Kind: String { case caller, assistant, interrupted, you, note }
    let id: Int
    let kind: Kind
    let speaker: String
    let text: String
    let date: Date
}

struct FoundMac: Identifiable, Hashable {
    let name: String
    let endpoint: NWEndpoint
    var id: String { name }
}

final class LiveClient: ObservableObject {
    enum Phase: Equatable {
        case needsCode              // eşleştirme kodu girilmedi
        case searching              // Mac aranıyor
        case connecting(String)
        case connected
        case failed(String)
    }

    @Published private(set) var phase: Phase = .searching
    @Published private(set) var macs: [FoundMac] = []
    @Published private(set) var macName = ""
    @Published private(set) var lines: [LiveLine] = []
    @Published private(set) var inSession = false
    @Published private(set) var caller = ""
    @Published private(set) var startedAt: Date?
    @Published private(set) var status = ""
    @Published private(set) var ringing = false     // Mac'te gelen arama çalıyor, asistan cevaplayabilir
    @Published private(set) var ringer = ""

    /// Elle girilen adres (Bonjour çalışmayan ağlar / VPN için), boşsa otomatik bulma
    @Published var manualHost: String = UserDefaults.standard.string(forKey: "manualHost") ?? "" {
        didSet { UserDefaults.standard.set(manualHost, forKey: "manualHost") }
    }
    /// Birden çok Mac varsa tercih edilen
    @Published var preferredMac: String = UserDefaults.standard.string(forKey: "preferredMac") ?? "" {
        didSet { UserDefaults.standard.set(preferredMac, forKey: "preferredMac") }
    }

    private(set) var code: String = Keychain.read("pairingCode") ?? ""
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var buffer = Data()
    private var active = false          // uygulama ön planda ve bağlanmak istiyoruz
    private var retryWork: DispatchWorkItem?
    private var pingTimer: Timer?
    private var lastPong = Date()

    var hasCode: Bool { code.count == 8 }

    init() {
        if !hasCode { phase = .needsCode }
    }

    // MARK: Yaşam döngüsü

    func activate() {
        active = true
        guard hasCode else { phase = .needsCode; return }
        startBrowsing()
        connectIfPossible(force: false)   // zaten bağlıysak (kısa süreli inactive) bağlantıyı koru
    }

    func deactivate() {
        active = false
        retryWork?.cancel()
        stopPing()
        browser?.cancel(); browser = nil
        connection?.cancel(); connection = nil
    }

    func setCode(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        guard digits.count == 8 else { return }
        code = digits
        Keychain.save("pairingCode", digits)
        reconnect()
    }

    func forgetCode() {
        code = ""
        Keychain.delete("pairingCode")
        deactivate()
        lines = []
        phase = .needsCode
    }

    func reconnect() {
        deactivate()
        activate()
    }

    // MARK: Bulma

    private func startBrowsing() {
        guard browser == nil else { return }
        let params = NWParameters()
        params.includePeerToPeer = true
        let b = NWBrowser(for: .bonjour(type: LiveProtocol.serviceType, domain: nil), using: params)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            self.macs = results.compactMap { r in
                if case let .service(name, _, _, _) = r.endpoint { return FoundMac(name: name, endpoint: r.endpoint) }
                return nil
            }.sorted { $0.name < $1.name }
            self.connectIfPossible(force: false)
        }
        b.stateUpdateHandler = { [weak self] st in
            if case .failed(let e) = st {
                self?.phase = .failed("Yerel ağ taranamadı: \(e.localizedDescription). Ayarlar > Gizlilik > Yerel Ağ'da Asistan Canlı'ya izin verin.")
            }
        }
        b.start(queue: .main)
        browser = b
    }

    /// Hedef: elle adres > tercih edilen Mac > bulunan ilk Mac
    private func target() -> (String, NWEndpoint)? {
        let host = manualHost.trimmingCharacters(in: .whitespaces)
        if !host.isEmpty, let port = NWEndpoint.Port(rawValue: LiveProtocol.port) {
            return (host, .hostPort(host: NWEndpoint.Host(host), port: port))
        }
        if let m = macs.first(where: { $0.name == preferredMac }) ?? macs.first { return (m.name, m.endpoint) }
        return nil
    }

    private func connectIfPossible(force: Bool) {
        guard active, hasCode else { return }
        if !force, connection != nil { return }
        guard let t = target() else {
            if connection == nil { phase = .searching }
            return
        }
        connect(name: t.0, endpoint: t.1)
    }

    func choose(_ mac: FoundMac) {
        preferredMac = mac.name
        manualHost = ""
        connection?.cancel(); connection = nil
        connect(name: mac.name, endpoint: mac.endpoint)
    }

    // MARK: Bağlantı

    private func connect(name: String, endpoint: NWEndpoint) {
        retryWork?.cancel()
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        buffer = Data()
        phase = .connecting(name)
        let c = NWConnection(to: endpoint, using: LiveProtocol.parameters(code: code))
        c.stateUpdateHandler = { [weak self, weak c] st in
            guard let self = self, let c = c, c === self.connection else { return }
            switch st {
            case .ready:
                self.phase = .connected
                self.lastPong = Date()
                self.startPing()
                self.receive(on: c)
            case .waiting(let e), .failed(let e):
                self.fail(c, self.describe(e))
            case .cancelled:
                break
            default: break
            }
        }
        connection = c
        c.start(queue: .main)
    }

    private func describe(_ e: NWError) -> String {
        if case .tls = e { return "Mac bağlantıyı reddetti. Eşleştirme kodu yanlış ya da Mac'te yenilenmiş olabilir." }
        if case .posix(let p) = e, p == .ECONNREFUSED {
            return "Mac'e ulaşıldı ama Asistan dinlemiyor. Mac'te menüden “iPhone'dan izle…” seçeneğini açın."
        }
        return "Mac'e bağlanılamadı (\(e.localizedDescription)). Aynı Wi-Fi ağında olduğunuzdan emin olun."
    }

    private func fail(_ c: NWConnection, _ message: String) {
        c.stateUpdateHandler = nil
        c.cancel()
        if connection === c { connection = nil }
        stopPing()
        phase = .failed(message)
        scheduleRetry()
    }

    private func scheduleRetry() {
        retryWork?.cancel()
        guard active else { return }
        let w = DispatchWorkItem { [weak self] in self?.connectIfPossible(force: true) }
        retryWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }

    private func receive(on c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self, weak c] data, _, done, err in
            guard let self = self, let c = c, c === self.connection else { return }
            if let data = data, !data.isEmpty {
                self.buffer.append(data)
                while let nl = self.buffer.firstIndex(of: 0x0A) {
                    let line = self.buffer.subdata(in: self.buffer.startIndex..<nl)
                    self.buffer.removeSubrange(self.buffer.startIndex...nl)
                    if let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] { self.handle(obj) }
                }
            }
            if let err = err { self.fail(c, self.describe(err)); return }
            if done { self.fail(c, "Mac bağlantıyı kapattı."); return }
            self.receive(on: c)
        }
    }

    private func handle(_ obj: [String: Any]) {
        lastPong = Date()
        switch obj["t"] as? String {
        case "hello":
            macName = obj["mac"] as? String ?? ""
        case "state":
            inSession = obj["inSession"] as? Bool ?? false
            caller = obj["caller"] as? String ?? ""
            status = obj["status"] as? String ?? ""
            startedAt = (obj["startedAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
            ringing = obj["ringing"] as? Bool ?? false
            ringer = obj["ringer"] as? String ?? ""
        case "snapshot":
            lines = (obj["lines"] as? [[String: Any]] ?? []).compactMap(LiveClient.parseLine)
        case "reset":
            lines = []
        case "line":
            if let l = LiveClient.parseLine(obj) { lines.append(l) }
        default: break
        }
    }

    private static func parseLine(_ o: [String: Any]) -> LiveLine? {
        guard let id = o["id"] as? Int, let text = o["text"] as? String else { return nil }
        return LiveLine(id: id,
                        kind: LiveLine.Kind(rawValue: o["kind"] as? String ?? "") ?? .note,
                        speaker: o["speaker"] as? String ?? "",
                        text: text,
                        date: Date(timeIntervalSince1970: o["ts"] as? Double ?? Date().timeIntervalSince1970))
    }

    // MARK: Gönderme

    private func send(_ obj: [String: Any]) {
        guard let c = connection, phase == .connected, let d = LiveProtocol.encode(obj) else { return }
        c.send(content: d, completion: .contentProcessed { _ in })
    }

    func sendNote(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        send(["t": "note", "text": t])
    }

    func endSession() { send(["t": "end"]) }

    /// Çalan aramayı asistanla cevapla (Mac'te Odak modu açık olmasa da)
    func answerCall() { send(["t": "answer"]) }

    /// Wi-Fi değişince bağlantı sessizce ölebilir: 10 sn'de bir yokla, 25 sn yanıt yoksa yeniden bağlan
    private func startPing() {
        stopPing()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self, let c = self.connection else { return }
            if Date().timeIntervalSince(self.lastPong) > 25 { self.fail(c, "Mac yanıt vermiyor; yeniden bağlanılıyor…"); return }
            self.send(["t": "ping"])
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}

/// Eşleştirme kodu anahtar zincirinde saklanır
enum Keychain {
    private static func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "AsistanCanli",
         kSecAttrAccount as String: key]
    }

    static func read(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func save(_ key: String, _ value: String) {
        delete(key)
        var q = query(key)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}
