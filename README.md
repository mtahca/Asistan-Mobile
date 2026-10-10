# Asistan Mobile — Asistan Canlı (iOS)

Mac'teki [Asistan](https://github.com/mtahca/Asistan) uygulamasının **canlı metin penceresini** iPhone'da gösteren uygulama.
Asistan bir aramayı cevapladığında konuşma (arayan, asistan, sözü kesilen cümleler, notlar) iPhone'da anlık akar.
iPhone'dan **gelen aramayı asistanla cevaplayabilir**, asistana **talimat yazabilir**, görüşmeyi **sonlandırabilir** ve Mac'te **arama karşılamayı duraklatabilirsiniz**. Bunlar Mac penceresindeki düğmelerle aynı işi yapar.
"Devral" bilerek eklenmedi, çünkü Mac'in mikrofonunu hatta aktarır ve Mac başında olmayı gerektirir.

## Sürüm 0.3 (Asistan 0.8.11 ile)
- **QR ile eşleştirme:** Mac'teki "iPhone ve Odak…" penceresindeki QR kodu uygulamadan ya da iPhone Kamera ile okutun. QR, rastgele 256 bitlik bir anahtar taşır; 8 haneli kodun aksine kaydedilmiş bir bağlantıdan tahmin edilemez. QR ile eşleşen telefon 47822 portunu kullanır. 8 haneli kod eski Mac sürümleri için hâlâ seçilebilir.
- **Tam ekran gelen arama:** Büyük "Asistanla cevapla" düğmesi; "Kapat" ile küçük karta dönülür.
- **Kaydırma konumu korunur:** Yukarı kaydırıp okurken yeni satırlar sizi aşağı atmaz; "Yeni satırlar" düğmesi en alta götürür.
- **Görüşme özeti ve son görüşmeler:** Görüşme bitince özet kartı görünür; saat simgesi son görüşmelerin başlık ve özetlerini listeler. Tam döküm Mac'te kalır.
- **Hazır notlar Mac'ten gelir:** Mac'te Kişiselleştirme → Hazır notlar sekmesinde düzenlenir.

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
- iPhone uygulaması Mac'i otomatik bulur ve bağlanır. Bağlantı **TLS-PSK** ile şifrelenir. Anahtar, Mac'teki **QR kodunda** taşınan 256 bitlik rastgele anahtardan türetilir (servis `_asistan-v2._tcp`, port **47822**). Eski yöntemde anahtar 8 haneli koddan türetilir (`_asistan-canli._tcp`, port 47821); bu kod, ağdaki biri bağlantıyı kaydederse tahmin edilebilir, bu yüzden Mac'te kapatılabilir.
- Bağlanınca son görüşmenin metni ve güncel durum (görüşmede mi, arayan, süre) gönderilir. Ardından her yeni satır anında gelir.
- iOS, arka plandaki uygulamaların bağlantısını kapatır. Uygulamayı yeniden açtığınızda otomatik bağlanır ve o ana kadarki metni yeniden alır.

## Kurulum
1. **Mac:** Asistan 0.8 veya üstünü kurun (Asistan deposu, `bash build.sh`). Menü çubuğunda **iPhone ve Odak…** penceresini açıp **Asistan Mobile bağlantısını aç** kutusunu işaretleyin. Gösterilen 8 haneli kodu ve gerekiyorsa Mac adresini not edin. macOS yerel ağ için izin sorarsa izin verin.
2. **iPhone:** `AsistanCanli.xcodeproj` dosyasını Xcode 16 veya üstüyle açın. *Signing & Capabilities* bölümünde kendi Apple kimliğinizi (Team) seçin, iPhone'u bağlayın ve **Run** ile yükleyin. Ücretsiz Apple kimliğiyle yüklenen uygulama 7 gün sonra yeniden yüklenmelidir.
3. Uygulamayı açın, **QR kodu tara** ile Mac'teki kodu okutun. iOS **Kamera** ve **Yerel Ağ** izni isterse izin verin.

iPhone ve Mac aynı Wi‑Fi ağında olmalı. Bonjour çalışmayan ağlarda **Ayarlar → Elle adres** alanına Mac'in adresini yazın; Mac'teki "iPhone ve Odak…" penceresi adresi gösterir.

## Sorun giderme
| Belirti | Çözüm |
|---|---|
| "Mac aranıyor…" ekranında kalıyor | Mac'te mobil bağlantı açık mı? Aynı Wi‑Fi'da mısınız? iPhone'da Ayarlar → Gizlilik → Yerel Ağ → Asistan Canlı açık mı? |
| "Mac bağlantıyı reddetti" uyarısı | Mac'te eşleştirme yenilenmiş olabilir. Uygulamada Ayarlar → QR kodu yeniden tara. |
| "Asistan dinlemiyor" uyarısı | Mac'te "iPhone ve Odak…" penceresinden bağlantıyı açın. Mac güvenlik duvarı açıksa Asistan'a gelen bağlantı izni verin. |
| Listede "— Asistan Beta" görünüyor | Eski Beta kaydı. "— Asistan" ile biten Mac'i seçin. |

## Proje yapısı
| Dosya | İçerik |
|---|---|
| `AsistanCanli/MobileProtocol.swift` | Mac ile ortak protokol (servis, port, TLS-PSK, QR bağlantısı, çerçeveler). Asistan deposundaki `app/MobileProtocol.swift` ile birebir aynıdır; iki depodaki CI farkı yakalar. |
| `AsistanCanli/QRScannerView.swift` | QR kodu kamerayla okuma |
| `AsistanCanli/LiveClient.swift` | Bonjour ile bulma, bağlantı, yeniden bağlanma, mesajlar, anahtar zinciri |
| `AsistanCanli/ContentView.swift` | Canlı metin ekranı, durum çubuğu, hazır notlar, talimat alanı |
| `AsistanCanli/PairingView.swift` | Eşleştirme ve ayarlar |

### Protokol (sürüm 1)
Satır başına bir JSON nesnesi gönderilir. Bilinmeyen alanlar yok sayılır; yeni alanlar geriye uyumludur.
- Mac → iPhone:
  - `hello {mac, v, app, caps}` — `app`: Mac'teki Asistan sürümü (0.8.4+); `caps`: desteklenen özellikler, ör. `pause`, `quickNotes`, `history`, `secure` (0.8.11+)
  - `quickNotes {items}`, `history {items: [{id, title, ts, summary}], fresh}` (0.8.11+)
  - `state {inSession, caller, startedAt?, status, ringing, ringer, source, paused, humanCall}` — `source`: `phone` | `whatsapp` | `""` (0.8.4+)
  - `snapshot {lines}`, `reset`, `line {id, kind, speaker, text, ts}`, `pong`
  - `kind`: `caller` · `assistant` · `interrupted` · `you` · `note`
- iPhone → Mac: `note {text}`, `end`, `answer`, `ping`, `pause {on}` (0.8.4+; görüşme sırasında reddedilir)

Bu kod bulut ortamında derleyici olmadan yazıldı; Xcode'da derleme hatası çıkarsa hata metnini Claude'a vermeniz yeterlidir.
