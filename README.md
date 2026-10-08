# Asistan Mobile — Asistan Canlı (iOS)

Mac'teki [Asistan](https://github.com/mtahca/Asistan) uygulamasının **canlı metin penceresini** iPhone'da gösteren uygulama.
Asistan bir aramayı cevapladığında konuşma (arayan, asistan, sözü kesilen cümleler, notlar) iPhone'da anlık akar.
iPhone'dan asistana **talimat yazabilir** ve **görüşmeyi sonlandırabilirsiniz**. Bunlar Mac penceresindeki düğmelerle aynı işi yapar.
"Devral" bilerek eklenmedi, çünkü Mac'in mikrofonunu hatta aktarır ve Mac başında olmayı gerektirir.

## Nasıl çalışır
- Mac'teki Asistan, yerel ağda Bonjour ile `_asistan-canli._tcp` servisini (port **47821**) yayınlar.
- iPhone uygulaması Mac'i otomatik bulur ve bağlanır. Bağlantı **TLS-PSK** ile şifrelenir. Anahtar, Mac'te gösterilen 8 haneli **eşleştirme kodundan** türetilir. Kodu bilmeyen bir cihaz bağlanamaz ve metni göremez.
- Bağlanınca son görüşmenin metni ve güncel durum (görüşmede mi, arayan, süre) gönderilir. Ardından her yeni satır anında gelir.
- iOS, arka plandaki uygulamaların bağlantısını kapatır. Uygulamayı yeniden açtığınızda otomatik bağlanır ve o ana kadarki metni yeniden alır.

## Kurulum
1. **Mac:** Asistan'ı bu özelliği içeren sürümle derleyin (`bash build.sh`, Asistan deposu). Menü çubuğunda **iPhone'dan izle…** öğesini seçip **Aç**'a basın. Gösterilen 8 haneli kodu not edin. macOS gelen bağlantılar ya da yerel ağ için izin sorarsa izin verin.
2. **iPhone:** `AsistanCanli.xcodeproj` dosyasını Xcode 16 veya üstüyle açın. *Signing & Capabilities* bölümünde kendi Apple kimliğinizi (Team) seçin, iPhone'u bağlayın ve **Run** ile yükleyin. Ücretsiz Apple kimliğiyle yüklenen uygulama 7 gün sonra yeniden yüklenmelidir.
3. Uygulamayı açın, kodu girin. iOS **Yerel Ağ** izni isterse izin verin.

iPhone ve Mac aynı Wi‑Fi ağında olmalı. Farklı bir ağdan (ör. Tailscale/VPN üzerinden) bağlanmak için uygulamada **Ayarlar → Elle adres** alanına Mac'in adresini yazın.

## Sorun giderme
| Belirti | Çözüm |
|---|---|
| "Mac aranıyor…" ekranında kalıyor | Mac'te "iPhone'dan izle…" açık mı? Aynı Wi‑Fi'da mısınız? iPhone'da Ayarlar → Gizlilik → Yerel Ağ → Asistan Canlı açık mı? |
| "Eşleştirme kodu yanlış" uyarısı | Mac'te kod yenilenmiş olabilir. Uygulamada Ayarlar → Kodu güncelle. |
| "Asistan dinlemiyor" uyarısı | Mac'te menüden "iPhone'dan izle…" → Aç. Mac güvenlik duvarı açıksa Asistan'a gelen bağlantı izni verin. |

## Proje yapısı
| Dosya | İçerik |
|---|---|
| `AsistanCanli/LiveProtocol.swift` | Mac ile ortak protokol (servis adı, port, TLS-PSK). Asistan deposundaki `app/MobileBridge.swift` dosyasındaki aynı blokla birebir aynı kalmalı. |
| `AsistanCanli/LiveClient.swift` | Bonjour ile bulma, bağlantı, yeniden bağlanma, mesajlar, anahtar zinciri |
| `AsistanCanli/ContentView.swift` | Canlı metin ekranı, durum çubuğu, talimat alanı |
| `AsistanCanli/PairingView.swift` | Eşleştirme ve ayarlar |

### Protokol (sürüm 1)
Satır başına bir JSON nesnesi gönderilir.
- Mac → iPhone: `hello {mac, v}`, `state {inSession, caller, startedAt?, status}`, `snapshot {lines}`, `reset`, `line {id, kind, speaker, text, ts}`, `pong`
  - `kind`: `caller` · `assistant` · `interrupted` · `you` · `note`
- iPhone → Mac: `note {text}`, `end`, `ping`
