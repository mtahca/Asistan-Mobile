// Asistan Canlı — eşleştirme kodu girişi ve ayarlar

import SwiftUI

struct PairingView: View {
    @EnvironmentObject var client: LiveClient
    @State private var code = ""
    @FocusState private var focused: Bool

    private var digits: String { code.filter(\.isNumber) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .padding(.top, 40)
                Text("Mac'le eşleştir")
                    .font(.title2.bold())
                VStack(alignment: .leading, spacing: 8) {
                    Label("Mac'te Asistan menüsünden “iPhone ve Odak…” penceresini açıp mobil bağlantıyı etkinleştirin.", systemImage: "1.circle")
                    Label("Gösterilen 8 haneli eşleştirme kodunu aşağıya yazın.", systemImage: "2.circle")
                    Label("iPhone ile Mac aynı Wi-Fi ağında olmalı.", systemImage: "3.circle")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("1234 5678", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(.title, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focused)

                Button {
                    client.setCode(digits)
                } label: {
                    Text("Bağlan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(digits.count != 8)

                Text("Kod, bağlantıyı şifrelemek için kullanılır ve yalnızca bu iPhone'un anahtar zincirinde saklanır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .onAppear { focused = true }
    }
}

struct SettingsView: View {
    @EnvironmentObject var client: LiveClient
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var newCode = ""

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
                    Text("Otomatik bulma çalışmıyorsa Mac'in adresini yazın; Mac'teki “iPhone ve Odak…” penceresi adresi gösterir. Boş bırakırsanız Mac otomatik bulunur. Port: \(String(LiveProtocol.port)).")
                }

                Section {
                    TextField("Yeni 8 haneli kod", text: $newCode)
                        .keyboardType(.numberPad)
                    Button("Kodu güncelle") {
                        client.setCode(newCode)
                        dismiss()
                    }
                    .disabled(newCode.filter(\.isNumber).count != 8)
                    Button("Eşleştirmeyi kaldır", role: .destructive) {
                        client.forgetCode()
                        dismiss()
                    }
                } header: {
                    Text("Eşleştirme kodu")
                } footer: {
                    Text("Mac'te kodu yenilediyseniz yeni kodu buraya girin.")
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Bitti") { dismiss() } }
            }
            .onAppear { host = client.manualHost }
        }
    }
}
