# Asistan Mobile — Asistan Canlı (iOS)

Mac'teki [Asistan](https://github.com/mtahca/Asistan) uygulamasının **canlı metin penceresini** iPhone'da gösteren uygulama.
Asistan bir aramayı cevapladığında konuşma (arayan, asistan, sözü kesilen cümleler, notlar) iPhone'da anlık akar.
iPhone'dan **gelen aramayı asistanla cevaplayabilir**, asistana **talimat yazabilir**, görüşmeyi **sonlandırabilir** ve Mac'te **arama karşılamayı duraklatabilirsiniz**. Bunlar Mac penceresindeki düğmelerle aynı işi yapar.
"Devral" bilerek eklenmedi, çünkü Mac'in mikrofonunu hatta aktarır ve Mac başında olmayı gerektirir.

## Sürüm 0.2 (Asistan 0.8.4 ile)
- **Hazır notlar:** Görüşme sırasında yazı alanının üstünde Mac'tekiyle aynı dört hazır talimat; dokununca alana girer, göndermeden düzenlenebilir.
- **Titreşim:** Gelen aramada ve görüşme başlayınca kısa haptik uyarı.
- **Ekran açık kalır:** Görüşme sürerken iPhone ekranı kapanmaz.
- **Paylaş:** Sol üstteki düğme görüşme metnini saat damgalı düz metin olarak paylaşır.
- **Duraklat:** Ayarlar'da "Arama karşılamayı duraklat" anahtarı Mac menüsündeki seçeneği telefondan değiştirir (görüşme yokken).
- **Durum:** Arama kaynağı (Telefon/WhatsApp) simgesi, "Görüşmeyi siz devraldınız" ve "Duraklatıldı" durumları; Mac'teki uyarılar (ör. asistanın sesinin arayana gitmediği şüphesi) turuncu gösterilir.
- **Metin:** Çok satırlı talimat alanı; GPT-Live'ın yerinde güncellediği son satırda da altta kalır.
- Eşleştirme ve ayar metinleri Asistan 0.8'in menü adlarına göre güncellendi ("iPhone ve Odak…").

Asistan 0.8.0–0.8.3 ile de çalışır; duraklatma anahtarı ve kaynak simgesi yalnızca 0.8.4+ Mac'te görünür.

## Nasıl çalışır
- Mac'teki Asistan, yerel ağda Bonjour ile `_asistan-canli._tcp` servisini (port **47821**) yayınlar. Servis adı "— Asistan" ile biter.
- iPhone uygulaması Mac'i otomatik bulur ve bağlanır. Bağlantı **TLS-PSK** ile şifrelenir. Anahtar, Mac'te gösterilen 8 haneli **eşleştirme kodundan** türetilir. Kodu bilmeyen bir cihaz bağlanamaz ve metni göremez.
- Bağlanınca son görüşmenin metni ve güncel durum (görüşmede mi, arayan, süre) gönderilir. Ardından her yeni satır anında gelir.
- iOS, arka plandaki uygulamaların bağlantısını kapatır. Uygulamayı yeniden açtığınızda otomatik bağlanır ve o ana kadarki metni yeniden alır.

## Kurulum
1. **Mac:** Asistan 0.8 veya üstünü kurun (Asistan deposu, `bash build.sh`). Menü çubuğunda **iPhone ve Odak…** penceresini açıp **Asistan Mobile bağlantısını aç** kutusunu işaretleyin. Gösterilen 8 haneli kodu ve gerekiyorsa Mac adresini not edin. macOS yerel ağ için izin sorarsa izin verin.
2. **iPhone:** `AsistanCanli.xcodeproj` dosyasını Xcode 16 veya üstüyle açın. *Signing & Capabilities* bölümünde kendi Apple kimliğinizi (Team) seçin, iPhone'u bağlayın ve **Run** ile yükleyin. Ücretsiz Apple kimliğiyle yüklenen uygulama 7 gün sonra yeniden yüklenmelidir.
3. Uygulamayı açın, kodu girin. iOS **Yerel Ağ** izni isterse izin verin.

iPhone ve Mac aynı Wi‑Fi ağında olmalı. Bonjour çalışmayan ağlarda **Ayarlar → Elle adres** alanına Mac'in adresini yazın; Mac'teki "iPhone ve Odak…" penceresi adresi gösterir.

## Sorun giderme
| Belirti | Çözüm |
|---|---|
| "Mac aranıyor…" ekranında kalıyor | Mac'te mobil bağlantı açık mı? Aynı Wi‑Fi'da mısınız? iPhone'da Ayarlar → Gizlilik → Yerel Ağ → Asistan Canlı açık mı? |
| "Eşleştirme kodu yanlış" uyarısı | Mac'te kod yenilenmiş olabilir. Uygulamada Ayarlar → Kodu güncelle. |
| "Asistan dinlemiyor" uyarısı | Mac'te "iPhone ve Odak…" penceresinden bağlantıyı açın. Mac güvenlik duvarı açıksa Asistan'a gelen bağlantı izni verin. |
| Listede "— Asistan Beta" görünüyor | Eski Beta kaydı. "— Asistan" ile biten Mac'i seçin. |

## Proje yapısı
| Dosya | İçerik |
|---|---|
| `AsistanCanli/LiveProtocol.swift` | Mac ile ortak protokol (servis adı, port, TLS-PSK). Asistan deposundaki `app/MobileProtocol.swift` ile birebir aynı kalmalı. |
| `AsistanCanli/LiveClient.swift` | Bonjour ile bulma, bağlantı, yeniden bağlanma, mesajlar, anahtar zinciri |
| `AsistanCanli/ContentView.swift` | Canlı metin ekranı, durum çubuğu, hazır notlar, talimat alanı |
| `AsistanCanli/PairingView.swift` | Eşleştirme ve ayarlar |

### Protokol (sürüm 1)
Satır başına bir JSON nesnesi gönderilir. Bilinmeyen alanlar yok sayılır; yeni alanlar geriye uyumludur.
- Mac → iPhone:
  - `hello {mac, v, app}` — `app`: Mac'teki Asistan sürümü (0.8.4+)
  - `state {inSession, caller, startedAt?, status, ringing, ringer, source, paused, humanCall}` — `source`: `phone` | `whatsapp` | `""` (0.8.4+)
  - `snapshot {lines}`, `reset`, `line {id, kind, speaker, text, ts}`, `pong`
  - `kind`: `caller` · `assistant` · `interrupted` · `you` · `note`
- iPhone → Mac: `note {text}`, `end`, `answer`, `ping`, `pause {on}` (0.8.4+; görüşme sırasında reddedilir)

Bu kod bulut ortamında derleyici olmadan yazıldı; Xcode'da derleme hatası çıkarsa hata metnini Claude'a vermeniz yeterlidir.
