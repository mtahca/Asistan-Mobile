// Asistan Canlı — ana ekran: durum çubuğu, canlı metin, talimat alanı

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var client: LiveClient
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            Group {
                if client.phase == .needsCode {
                    PairingView()
                } else {
                    LiveView()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !client.lines.isEmpty {
                        ShareLink(item: client.transcriptText, subject: Text("Asistan görüşmesi")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Metni paylaş")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if client.macSupportsHistory && client.phase != .needsCode {
                        Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                            .accessibilityLabel("Son görüşmeler")
                    }
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Ayarlar")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showHistory) { HistoryView() }
        }
        // Görüşme sürerken ekran kapanmasın; telefon masada dururken metin okunabilsin.
        .onChange(of: client.inSession || client.humanCall, initial: true) { _, active in
            UIApplication.shared.isIdleTimerDisabled = active
        }
    }

    private var title: String {
        if client.inSession || client.humanCall { return client.caller.isEmpty ? "Görüşmede" : client.caller }
        return "Canlı görüşme"
    }
}

// MARK: - Canlı metin

struct LiveView: View {
    @EnvironmentObject var client: LiveClient
    @State private var draft = ""
    @State private var confirmEnd = false
    @State private var ringDismissed = false
    /// Okuyucu en alttaysa yeni satırlar izlenir; yukarı kaydırınca konum korunur
    @State private var atBottom = true
    @State private var unseen = false
    @FocusState private var typing: Bool

    /// Tam ekran gelen arama; "Kapat" ile küçük karta döner
    private var ringFullScreen: Binding<Bool> {
        Binding(get: { client.phase == .connected && client.ringing && !client.inSession && !ringDismissed },
                set: { if !$0 { ringDismissed = true } })
    }

    var body: some View {
        VStack(spacing: 0) {
            StatusBar()
            Divider()
            if client.phase == .connected && client.ringing && !client.inSession { ringingCard }
            transcript
            if client.phase == .connected {
                if client.inSession { quickNoteChips }
                inputBar
            }
        }
        // Gelen aramada ve görüşme başlayınca kısa titreşim
        .sensoryFeedback(.warning, trigger: client.ringing) { _, ringing in ringing }
        .sensoryFeedback(.success, trigger: client.inSession) { _, inSession in inSession }
        .onChange(of: client.ringing) { _, ringing in if !ringing { ringDismissed = false } }
        .fullScreenCover(isPresented: ringFullScreen) { RingingView(dismissed: $ringDismissed) }
        .confirmationDialog("Görüşme sonlandırılsın mı?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("Sonlandır", role: .destructive) { client.endSession() }
        } message: {
            Text("Asistan susar ve not kaydedilir.")
        }
    }

    private var ringingCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: client.source == "whatsapp" ? "message.fill" : "phone.arrow.down.left.fill").foregroundStyle(.green)
                Text(client.ringer.isEmpty ? "Gelen arama" : "Gelen arama: \(client.ringer)")
                    .font(.headline)
                Spacer(minLength: 0)
            }
            Button { client.answerCall() } label: {
                Label("Asistanla cevapla", systemImage: "phone.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
            .disabled(client.paused)
            if client.paused {
                Text("Mac'te arama karşılama duraklatılmış. Ayarlar'dan sürdürebilirsiniz.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if client.lines.isEmpty {
                        emptyState
                    }
                    ForEach(client.lines) { line in
                        LineView(line: line).id(line.id)
                    }
                    if let summary = client.latestSummary, !client.inSession {
                        SummaryCard(item: summary)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                        .onAppear { atBottom = true; unseen = false }
                        .onDisappear { atBottom = false }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: client.lines.last?.id) { _, _ in follow(proxy, animated: true) }
            .onChange(of: client.lines.last?.text) { _, _ in
                // GPT-Live son satırı yerinde günceller; metin uzayınca da altta kal
                follow(proxy, animated: false)
            }
            .onChange(of: client.latestSummary) { _, _ in follow(proxy, animated: true) }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            .overlay(alignment: .bottom) {
                if unseen && !atBottom {
                    Button {
                        unseen = false
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    } label: {
                        Label("Yeni satırlar", systemImage: "arrow.down")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
            }
        }
    }

    /// Yalnızca okuyucu en alttayken kaydır; yukarıdaki satırı okurken yer değişmesin
    private func follow(_ proxy: ScrollViewProxy, animated: Bool) {
        guard atBottom else { unseen = true; return }
        if animated { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) } }
        else { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(client.phase == .connected ? "Asistan bir aramayı cevapladığında konuşma burada canlı görünür." : "Mac'e bağlanınca son görüşmenin metni burada görünür.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var quickNoteChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(client.quickNotes, id: \.self) { note in
                    Button {
                        draft = note
                        typing = true
                    } label: {
                        Text(note)
                            .font(.footnote)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Button(role: .destructive) { confirmEnd = true } label: {
                    Image(systemName: "phone.down.fill")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!client.inSession)
                .accessibilityLabel("Görüşmeyi sonlandır")

                TextField(client.inSession ? "Asistana talimat yaz" : "Görüşme yokken talimat gönderilemez", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .disabled(!client.inSession)

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(!client.inSession || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Gönder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func send() {
        client.sendNote(draft)
        draft = ""
    }
}

// MARK: - Durum çubuğu

struct StatusBar: View {
    @EnvironmentObject var client: LiveClient

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.subheadline.weight(.semibold))
                if let detail = detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
            }
            Spacer(minLength: 0)
            if client.inSession || client.humanCall, let t0 = client.startedAt {
                HStack(spacing: 6) {
                    if !client.source.isEmpty {
                        Image(systemName: client.source == "whatsapp" ? "message.fill" : "phone.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(client.source == "whatsapp" ? "WhatsApp" : "Telefon")
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(elapsed(from: t0, to: ctx.date))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else if case .connecting = client.phase {
                ProgressView()
            } else if case .searching = client.phase {
                ProgressView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private var color: Color {
        switch client.phase {
        case .connected:
            if client.inSession { return .green }
            if client.humanCall { return .purple }
            return client.paused ? .gray : .blue
        case .connecting, .searching: return .orange
        case .failed, .needsCode: return .red
        }
    }

    private var headline: String {
        switch client.phase {
        case .connected:
            if client.inSession { return "Görüşmede — asistan konuşuyor" }
            if client.humanCall { return "Görüşmeyi siz devraldınız" }
            if client.paused { return "Duraklatıldı — arama karşılanmıyor" }
            return client.macName.isEmpty ? "Mac'e bağlı" : client.macName + " bağlı"
        case .connecting(let name): return "\(name) Mac'ine bağlanılıyor…"
        case .searching: return "Mac aranıyor…"
        case .failed: return "Bağlantı yok"
        case .needsCode: return "Eşleştirme gerekli"
        }
    }

    private var detail: String? {
        switch client.phase {
        case .connected:
            if client.inSession || client.humanCall { return nil }
            return client.status.isEmpty ? nil : client.status
        case .searching: return "Mac ile aynı Wi-Fi ağında olun; Mac'te “iPhone ve Odak…” penceresinden mobil bağlantı açık olmalı."
        case .failed(let msg): return msg
        default: return nil
        }
    }

    private func elapsed(from: Date, to: Date) -> String {
        let s = max(0, Int(to.timeIntervalSince(from)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Tek satır

struct LineView: View {
    let line: LiveLine

    var body: some View {
        switch line.kind {
        case .note:
            Text(line.text)
                .font(.footnote)
                .foregroundStyle(line.text.hasPrefix("⚠️") ? .orange : .secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.vertical, 2)
        default:
            HStack {
                if alignRight { Spacer(minLength: 40) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(line.speaker)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(line.text)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                if !alignRight { Spacer(minLength: 40) }
            }
        }
    }

    /// Arayan solda, asistan ve senin talimatların sağda
    private var alignRight: Bool { line.kind != .caller }

    private var tint: Color {
        switch line.kind {
        case .caller: return .blue
        case .assistant: return .green
        case .interrupted: return .orange
        case .you: return .purple
        case .note: return .secondary
        }
    }
}

// MARK: - Gelen arama (tam ekran)

struct RingingView: View {
    @EnvironmentObject var client: LiveClient
    @Binding var dismissed: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: client.source == "whatsapp" ? "message.circle.fill" : "phone.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .accessibilityLabel(client.source == "whatsapp" ? "WhatsApp araması" : "Telefon araması")
            VStack(spacing: 6) {
                Text("Gelen arama").font(.headline).foregroundStyle(.secondary)
                Text(client.ringer.isEmpty ? "Bilinmeyen arayan" : client.ringer)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                if !client.macName.isEmpty {
                    Text(client.macName).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
            if client.paused {
                Text("Mac'te arama karşılama duraklatılmış. Ayarlar'dan sürdürebilirsiniz.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Button {
                client.answerCall()
            } label: {
                Label("Asistanla cevapla", systemImage: "phone.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(client.paused)
            .padding(.horizontal, 24)
            Button("Kapat") { dismissed = true }
                .font(.body.weight(.medium))
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Görüşme özeti ve geçmiş

struct SummaryCard: View {
    let item: HistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Görüşme özeti", systemImage: "doc.text")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(item.summary.isEmpty ? "Özet hazırlanamadı; döküm Mac'te kaydedildi." : item.summary)
                .font(.callout)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct HistoryView: View {
    @EnvironmentObject var client: LiveClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if client.history.isEmpty {
                    Text("Henüz görüşme notu yok").foregroundStyle(.secondary)
                }
                ForEach(client.history) { item in
                    NavigationLink {
                        ScrollView {
                            Text(item.summary.isEmpty ? "Bu görüşme için özet yok. Tam döküm Mac'teki notlar klasöründe." : item.summary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .navigationTitle(item.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ShareLink(item: item.title + "\n\n" + item.summary) { Image(systemName: "square.and.arrow.up") }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline.weight(.semibold))
                            if !item.summary.isEmpty {
                                Text(item.summary).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Son görüşmeler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Bitti") { dismiss() } }
            }
        }
    }
}
