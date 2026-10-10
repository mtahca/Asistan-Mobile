// Asistan Saat — kadran bileşeni: boşta gri, arama çalınca yeşil, görüşmede kırmızı. Dokununca Asistan Saat açılır.

import SwiftUI
import WidgetKit

struct LightEntry: TimelineEntry {
    let date: Date
    let light: WatchState.Light
}

struct LightProvider: TimelineProvider {
    func placeholder(in context: Context) -> LightEntry { LightEntry(date: Date(), light: .idle) }

    func getSnapshot(in context: Context, completion: @escaping (LightEntry) -> Void) {
        completion(LightEntry(date: Date(), light: WatchLink.stored()?.light() ?? .idle))
    }

    /// Renk durum bayatlayınca kendiliğinden griye döner; yeni durum gelince uygulama zaman çizelgesini yeniler
    func getTimeline(in context: Context, completion: @escaping (Timeline<LightEntry>) -> Void) {
        let now = Date()
        let state = WatchLink.stored()
        var entries = [LightEntry(date: now, light: state?.light(at: now) ?? .idle)]
        if let expiry = state?.lightExpiry, expiry > now { entries.append(LightEntry(date: expiry, light: .idle)) }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct LightView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LightEntry

    private var color: Color {
        switch entry.light {
        case .idle: return .gray
        case .ringing: return .green
        case .call: return .red
        }
    }

    private var symbol: String { entry.light == .call ? "phone.down.fill" : "phone.fill" }

    private var label: String {
        switch entry.light {
        case .idle: return "Asistan"
        case .ringing: return "Arama var"
        case .call: return "Görüşmede"
        }
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(label, systemImage: symbol)
        case .accessoryCorner:
            Image(systemName: symbol).font(.title2).foregroundStyle(color).widgetLabel(label)
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: symbol).font(.title2.bold()).foregroundStyle(color)
            }
        }
    }
}

@main
struct AsistanSaatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AsistanDurum", provider: LightProvider()) { entry in
            LightView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .accessibilityLabel(Text("Asistan"))
        }
        .configurationDisplayName("Asistan")
        .description("Arama gelince yeşil, görüşmede kırmızı. Dokununca Asistan açılır.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}
