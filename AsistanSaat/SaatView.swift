// Asistan Saat — tek ekran: çalıyorsa Cevapla, görüşmedeyse Bitir ve canlı metin, değilse durum.

import SwiftUI

struct SaatView: View {
    @EnvironmentObject var link: PhoneLink

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            ScrollView {
                VStack(spacing: 10) {
                    switch link.state.light(at: context.date) {
                    case .ringing: ringing
                    case .call: call
                    case .idle: idle
                    }
                    if let problem = link.problem {
                        Text(problem).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var ringing: some View {
        VStack(spacing: 8) {
            Text(link.state.ringer.isEmpty ? "Gelen arama" : link.state.ringer)
                .font(.headline).lineLimit(2).multilineTextAlignment(.center)
            Button(action: link.answer) {
                Label("Cevapla", systemImage: "phone.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .tint(.green)
            .buttonStyle(.borderedProminent)
            .disabled(link.sending != nil)
            Text("Asistan cevaplar").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var call: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(link.state.caller.isEmpty ? "Görüşmede" : link.state.caller).font(.headline).lineLimit(1)
                    if let start = link.state.startedAt {
                        Text(start, style: .timer).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            Button(action: link.end) {
                Label("Bitir", systemImage: "phone.down.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .disabled(link.sending != nil)
            if !link.state.status.isEmpty {
                Text(link.state.status).font(.footnote).foregroundStyle(.orange)
            }
            ForEach(link.state.lines.reversed()) { line in
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.speaker).font(.caption2.bold()).foregroundStyle(line.caller ? .blue : .green)
                    Text(line.text).font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var idle: some View {
        VStack(spacing: 8) {
            Image(systemName: "phone.fill").font(.largeTitle).foregroundStyle(.gray)
            Text("Görüşme yok").font(.headline)
            Text(statusText).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var statusText: String {
        if !link.reachable { return "iPhone'a ulaşılamıyor." }
        return link.state.linked ? "Asistan'a bağlı." : "iPhone Mac'teki Asistan'a bağlanıyor…"
    }
}
