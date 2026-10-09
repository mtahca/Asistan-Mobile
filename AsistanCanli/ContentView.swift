// Asistan Canlı — ana ekran: durum çubuğu, canlı metin, talimat alanı

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var client: LiveClient
    @State private var showSettings = false

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Ayarlar")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
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
    @FocusState private var typing: Bool

    /// Mac'teki "Hazır notlar" listesiyle aynı
    static let quickNotes = [
        "Şu an müsait değilim; en kısa sürede dönüş yapacağım.",
        "Mesajını ve geri dönüş numarasını not al.",
        "Konuyu kısaca öğren, sonra görüşmeyi kibarca bitir.",
        "Acil bir durumsa bana hemen mesaj atmasını söyle.",
    ]

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
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: client.lines.last?.id) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: client.lines.last?.text) { _, _ in
                // GPT-Live son satırı yerinde günceller; metin uzayınca da altta kal
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
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
                ForEach(Self.quickNotes, id: \.self) { note in
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
