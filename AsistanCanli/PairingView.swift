// Asistan Canlı — eşleştirme kodu girişi ve ayarlar

import SwiftUI
import UIKit

struct PairingView: View {
    @EnvironmentObject var client: LiveClient
    @State private var code = ""
    @State private var scanning = false
    @State private var showCode = false
    @State private var problem = ""

    private var digits: String { code.filter(\.isNumber) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .padding(.top, 40)
                Text("Mac'le eşleştir")
                    .font(.title2.bold())
                VStack(alignment: .leading, spacing: 8) {
                    Label("Mac'te Asistan menüsünden “iPhone ve Odak…” penceresini açıp mobil bağlantıyı etkinleştirin.", systemImage: "1.circle")
                    Label("Penceredeki QR kodu aşağıdaki düğmeyle okutun. iPhone Kamera ile okutup bağlantıyı açmak da olur.", systemImage: "2.circle")
                    Label("iPhone ile Mac aynı Wi-Fi ağında olmalı.", systemImage: "3.circle")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                if QRScannerView.isAvailable {
                    Button { problem = ""; scanning = true } label: {
                        Label("QR kodu tara", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                Button {
                    if !client.pair(UIPasteboard.general.string ?? "") { problem = "Panodaki metin bir Asistan eşleştirme bağlantısı değil." }
                } label: {
                    Label("Kopyalanan bağlantıyı yapıştır", systemImage: "doc.on.clipboard").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                if !problem.isEmpty {
                    Text(problem).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
                }

                DisclosureGroup("Eski Mac sürümü: 8 haneli kodla bağlan", isExpanded: $showCode) {
                    VStack(spacing: 12) {
                        TextField("1234 5678", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.system(.title, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        Button {
                            client.setCode(digits)
                        } label: {
                            Text("Kodla bağlan").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(digits.count != 8)
                    }
                    .padding(.top, 8)
                }
                .font(.callout)

                Text("Eşleştirme anahtarı bağlantıyı şifreler ve yalnızca bu iPhone'un anahtar zincirinde saklanır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .sheet(isPresented: $scanning) { ScanSheet(isPresented: $scanning) }
    }
}

/// QR tarama sayfası; geçerli kod okununca eşleşip kapanır
struct ScanSheet: View {
    @EnvironmentObject var client: LiveClient
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            QRScannerView { text in
                guard client.pair(text) else { return false }
                isPresented = false
                return true
            }
            .ignoresSafeArea()
            .navigationTitle("Mac'teki QR kodu okutun")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { isPresented = false } } }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var client: LiveClient
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var newCode = ""
    @State private var scanning = false

    var body: some View {
        NavigationStack {
            Form {
                if client.phase == .connected {
                    Section {
                        Toggle("Arama karşılamayı duraklat", isOn: Binding(get: { client.paused }, set: { client.setPaused($0) }))
                            .disabled(client.inSession || client.humanCall || !client.macSupportsPause)
                    } header: {
                        Text("Mac'teki Asistan")
                    } footer: {
                        Text(!client.macSupportsPause ? "Bu ayar Mac'te Asistan 0.8.4 veya üstünü gerektirir." + (client.macVersion.isEmpty ? "" : " Bağlı sürüm: \(client.macVersion).")
                             : (client.inSession ? "Görüşme sürerken değiştirilemez." : "Açıkken Mac gelen aramaları karşılamaz; bu, Mac menüsündeki seçenekle aynıdır."))
                    }
                }
                Section {
                    if client.macs.isEmpty {
                        Text("Ağda Mac bulunamadı").foregroundStyle(.secondary)
                    }
                    ForEach(client.macs) { mac in
                        Button {
                            client.choose(mac)
                            dismiss()
                        } label: {
                            HStack {
                                Label(mac.name, systemImage: "desktopcomputer")
                                Spacer()
                                if mac.name == client.preferredMac || (client.preferredMac.isEmpty && mac == client.macs.first) {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Bulunan Mac'ler")
                } footer: {
                    Text("Adı “— Asistan” ile biten Mac'i seçin. Eski “— Asistan Beta” kayıtları artık kullanılmıyor.")
                }

                Section {
                    TextField("ör. 192.168.1.20 ya da mac.local", text: $host)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Kaydet ve bağlan") {
                        client.manualHost = host.trimmingCharacters(in: .whitespaces)
                        client.reconnect()
                        dismiss()
                    }
                } header: {
                    Text("Elle adres (isteğe bağlı)")
                } footer: {
                    Text("Otomatik bulma çalışmıyorsa Mac'in adresini yazın; Mac'teki “iPhone ve Odak…” penceresi adresi gösterir. Boş bırakırsanız Mac otomatik bulunur. Port: \(String(client.securePairing ? LiveProtocol.securePort : LiveProtocol.port)).")
                }

                Section {
                    if client.securePairing {
                        Label("QR koduyla eşleşti" + (client.preferredMac.isEmpty ? "" : ": " + client.preferredMac), systemImage: "lock.fill")
                    }
                    if QRScannerView.isAvailable {
                        Button("QR kodu yeniden tara") { scanning = true }
                    }
                    TextField("Eski Mac için 8 haneli kod", text: $newCode)
                        .keyboardType(.numberPad)
                    Button("Kodla bağlan") {
                        client.setCode(newCode)
                        dismiss()
                    }
                    .disabled(newCode.filter(\.isNumber).count != 8)
                    Button("Eşleştirmeyi kaldır", role: .destructive) {
                        client.forgetCode()
                        dismiss()
                    }
                } header: {
                    Text("Eşleştirme")
                } footer: {
                    Text("Mac'te eşleştirmeyi yenilediyseniz yeni QR kodu okutun. 8 haneli kod yalnızca QR göstermeyen eski Asistan sürümleri içindir.")
                }
            }
            .sheet(isPresented: $scanning) { ScanSheet(isPresented: $scanning) }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Bitti") { dismiss() } }
            }
            .onAppear { host = client.manualHost }
        }
    }
}
