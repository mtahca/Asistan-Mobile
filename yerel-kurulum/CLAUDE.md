# Asistan + Asistan Canlı (iPhone): Claude için çalışma talimatı

Bu dosya `~/Documents/Claude/Asistan` klasöründe çalışan Claude Code içindir.
Kullanıcıyla **Türkçe** konuş. Kullanıcı yazılımcı değil, bu yüzden adımları kısa ve net anlat. Komutları kendin çalıştır; yalnızca Xcode arayüzünde yapılması gereken işleri (Apple kimliği seçmek, iPhone'a "Güven" demek gibi) kullanıcıya bırak.

## Hedef
Mac'teki Asistan uygulamasının **canlı metin penceresini** iPhone'da gösteren **Asistan Canlı** uygulamasını derleyip kullanıcının iPhone'una yüklemek. Bunun için iki parça gerekir:

1. **Mac tarafı (bu klasör):** Asistan uygulaması canlı metni yerel ağa yayınlamalı. Bunu `app/MobileBridge.swift` dosyası ve `app/main.swift`, `build.sh`, `app/Info.plist` dosyalarındaki küçük eklemeler sağlar.
2. **iPhone tarafı:** SwiftUI uygulaması. Kaynağı GitHub'daki `mtahca/Asistan-Mobile` reposunda, `claude/wonderful-cray-s99poi` dalında.

Önemli: bu kod bulut ortamında, **derleyici olmadan** yazıldı ve hiç derlenmedi. Derleme hataları çıkması beklenir. Bunları düzeltmek senin işin (bkz. "Derlenmemiş kod: dikkat edilecek yerler").

## Klasör ve dosya kuralları
- Bu klasörde gizli ve kişisel veriler var: `.env`, `notlar/`, `*.log`, `talimat_*`, `caller.json`, `asistan_tercihleri.json`. **Bunların içeriğini okuma, yazdırma ya da değiştirme.** API anahtarlarını asla ekrana basma.
- `agent.py`, `realtime_mode.py`, `live_mode.py` bu iş için değişmeyecek.
- Bir dosyayı değiştirmeden önce yedekle: `cp app/main.swift app/main.swift.yedek-$(date +%Y%m%d-%H%M)`.
- Klasör bir git deposuysa (`git status` çalışıyorsa) değişikliklerden önce durumu kontrol et ve kullanıcının commit edilmemiş işini ezme.

## Adım 1: MobileBridge.swift doğru yerde mi?
Kullanıcı `MobileBridge.swift` dosyasını GitHub'dan indirip bu klasöre koydu. Muhtemelen kök klasörde, ama `app/` altında olmalı:

```bash
cd ~/Documents/Claude/Asistan
ls MobileBridge.swift app/MobileBridge.swift 2>/dev/null
# Kökteyse taşı:
[ -f MobileBridge.swift ] && [ ! -f app/MobileBridge.swift ] && mv MobileBridge.swift app/
```

İndirilen dosyanın gerçekten Swift kodu olduğunu kontrol et. Bir HTML sayfası (GitHub giriş sayfası gibi) inmiş olabilir:
`head -5 app/MobileBridge.swift` çıktısı `// Asistan — iPhone köprüsü` ile başlamalı. Başlamıyorsa kullanıcıdan dosyayı GitHub'daki "Download raw file" düğmesiyle yeniden indirmesini iste.

## Adım 2: Mac uygulamasına bağlantı noktalarını ekle
Tek başına `MobileBridge.swift` yetmez. `app/main.swift`, `build.sh` ve `app/Info.plist` dosyalarında da değişiklik gerekir. Bu değişiklikler aşağıdaki yamada (patch) var. Aynı yama, Asistan-Mobile reposunda `yerel-kurulum/mac-entegrasyon.patch` dosyası olarak da duruyor.

Uygulama yöntemi:
1. Önce yamanın temiz uygulanıp uygulanmadığını dene: `git apply --check yama.patch` (klasör git deposu değilse `patch -p1 --dry-run < yama.patch`).
2. Temiz uygulanıyorsa uygula.
3. Uygulanmıyorsa (yerel `main.swift` GitHub'dakinden farklıysa) değişiklikleri **elle**, aşağıdaki özetteki anlamı koruyarak ekle.

Değişikliklerin özeti:
- **`build.sh`:** `swiftc` satırı `app/main.swift app/MobileBridge.swift` ile iki dosyayı derlemeli.
- **`app/Info.plist`:** `NSLocalNetworkUsageDescription` ve `NSBonjourServices` (`_asistan-canli._tcp`) anahtarları eklenmeli.
- **`AppDelegate` sınıfına şunlar eklenmeli:**
  - Alanlar: `lazy var mobile = MobileBridge()` ve `var mobileItem: NSMenuItem!`.
  - `applicationDidFinishLaunching` içinde, `buildLiveWindow()` çağrısından sonra `mobile.onNote`, `mobile.onEnd`, `mobile.onClientsChanged` geri çağrıları bağlanmalı.
  - Menüye, "Canlı metin penceresini aç" öğesinin altına **"iPhone'dan izle…"** öğesi (`showMobileBridge`) eklenmeli.
  - `refreshLiveChrome()` sonunda `mobile.setState(...)` çağrılmalı.
  - `appendLive` ve `appendLiveNote` sonunda `mobile.append(...)` çağrılmalı. Satırın türü renge göre belirlenir: mavi = arayan, turuncu = sözü kesildi, mor = senin talimatın, diğerleri = asistan.
  - `sendNote()` içindeki mantık, Mac penceresi ve iPhone ortak kullanabilsin diye `deliverNote(_:fromPhone:)` fonksiyonuna taşınmalı.
  - `updateLive` içinde "ARAMA OTURUMU BAŞLADI" satırı gelince `mobile.reset()` çağrılmalı.
  - Yeni fonksiyonlar: `refreshMobileItem()` ve `showMobileBridge()` (aç/kapat ve eşleştirme kodunu gösteren NSAlert).

```diff
diff --git a/app/Info.plist b/app/Info.plist
index 2b1f4c1..780bba1 100644
--- a/app/Info.plist
+++ b/app/Info.plist
@@ -14,5 +14,7 @@
     <key>LSUIElement</key><true/>
     <key>NSMicrophoneUsageDescription</key><string>Asistan, aramadaki sesi dinlemek için mikrofon/ses girişine erişir.</string>
     <key>NSContactsUsageDescription</key><string>Asistan, gelen aramada arayanin adini ve numarasini bulmak icin Rehbere bakar.</string>
+    <key>NSLocalNetworkUsageDescription</key><string>Asistan, canlı görüşme metnini yerel ağdaki iPhone'unuza (Asistan Canlı) gönderir.</string>
+    <key>NSBonjourServices</key><array><string>_asistan-canli._tcp</string></array>
 </dict>
 </plist>
diff --git a/app/main.swift b/app/main.swift
index bf7f3c8..8092353 100644
--- a/app/main.swift
+++ b/app/main.swift
@@ -864,6 +864,8 @@ final class AppDelegate: NSObject, NSApplicationDelegate {
     var sessionStartedAt: Date?
     var sessionCaller = ""
     var modeCache: (Date, String) = (.distantPast, "")
+    lazy var mobile = MobileBridge()   // canlı metni iPhone'daki Asistan Canlı uygulamasına yayınlar
+    var mobileItem: NSMenuItem!
 
     func applicationDidFinishLaunching(_ n: Notification) {
         resolveProjectDir()
@@ -893,6 +895,9 @@ final class AppDelegate: NSObject, NSApplicationDelegate {
         buildStatusItem()
         buildPanel()
         buildLiveWindow()
+        mobile.onNote = { [weak self] t in self?.deliverNote(t, fromPhone: true) }
+        mobile.onEnd = { [weak self] in self?.endSession() }
+        mobile.onClientsChanged = { [weak self] in self?.refreshMobileItem() }
         let st = setupStatus()
         if st.audio && st.py && st.key { startAgent() } else { showSetup() }
         Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in self?.tick() }
@@ -1105,6 +1110,8 @@ final class AppDelegate: NSObject, NSApplicationDelegate {
         dndItem.state = dndAuto ? .on : .off
         menu.addItem(.separator())
         _ = add("Canlı metin penceresini aç", #selector(openLiveWindow), "l")
+        mobileItem = add("iPhone'dan izle…", #selector(showMobileBridge))
+        refreshMobileItem()
         takeItem = add("Görüşmeyi devral (asistan çıkar)", #selector(takeOver), "d")
         endItem = add("Görüşmeyi sonlandır (asistan susar)", #selector(endSession), "e")
         menu.addItem(.separator())
@@ -1175,6 +1182,7 @@ final class AppDelegate: NSObject, NSApplicationDelegate {
             title += " — " + (sessionCaller.isEmpty ? "arayan" : sessionCaller) + " · \(sec / 60):" + (ss < 10 ? "0" : "") + "\(ss)"
         }
         if w.title != title { w.title = title }
+        mobile.setState(inSession: inSession, caller: sessionCaller, startedAt: sessionStartedAt, status: statusLine.title)
     }
 
     func updateStatus() {
@@ -1319,29 +1327,38 @@ final class AppDelegate: NSObject, NSApplicationDelegate {
             .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor]))
         liveText.textStorage?.append(a)
         liveText.scrollToEndOfDocument(nil)
+        let kind = color == .systemBlue ? "caller" : color == .systemOrange ? "interrupted" : color == .systemPurple ? "you" : "assistant"
+        mobile.append(kind: kind, speaker: speaker, text: text)
     }
 
     func appendLiveNote(_ text: String) {
         liveText.textStorage?.append(NSAttributedString(string: text + "\n\n", attributes: [
             .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor]))
         liveText.scrollToEndOfDocument(nil)
+        mobile.append(kind: "note", speaker: "", text: text)
     }
 
     /// Yazılan notu çalışan ajana iletir; ajan bunu konuşmanın akışında arayana söyler
     @objc func sendNote() {
-        let text = noteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
-        guard !text.isEmpty else { return }
+        if deliverNote(noteField.stringValue) { noteField.stringValue = "" }
+    }
+
+    /// Notu ajana iletir (Mac penceresinden ya da iPhone'dan); gönderildiyse true
+    @discardableResult
+    func deliverNote(_ raw: String, fromPhone: Bool = false) -> Bool {
+        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
+        guard !text.isEmpty else { return false }
         guard inSession else {
             appendLiveNote("Not gönderilemedi: şu an görüşme yok.")
-            return
+            return false
         }
         let oneLine = text.replacingOccurrences(of: "\n", with: " ")
         if let data = ("NOT:" + oneLine + "\n").data(using: .utf8) {
             try? agentInput?.write(contentsOf: data)
         }
-        noteField.stringValue = ""
-        appendLive("Senin talimatın", oneLine + "  (asistana talimat olarak gönderildi)", color: .systemPurple)
-        logLine("Not gönderildi: \(oneLine)")
+        appendLive("Senin talimatın", oneLine + "  (asistana talimat olarak gönderildi" + (fromPhone ? ", iPhone'dan)" : ")"), color: .systemPurple)
+        logLine("Not gönderildi\(fromPhone ? " (iPhone)" : ""): \(oneLine)")
+        return true
     }
 
     /// Görüşmeyi devral: asistan kısa bir geçiş cümlesi söyler, çıkar; ses cihazları eski haline döner, arama açık kalır
@@ -1484,6 +1501,44 @@ final class AppDelegate: NSObject, NSApplicationDelegate {
     }
     @objc func openLiveWindow() { liveWindow.orderFrontRegardless() }
 
+    func refreshMobileItem() {
+        guard let it = mobileItem else { return }
+        it.state = mobile.enabled ? .on : .off
+        let n = mobile.clientCount
+        it.title = "iPhone'dan izle…" + (mobile.enabled && n > 0 ? " (\(n) cihaz bağlı)" : "")
+    }
+
+    /// iPhone köprüsü: aç/kapat, eşleştirme kodunu göster/yenile
+    @objc func showMobileBridge() {
+        NSApp.activate(ignoringOtherApps: true)
+        let a = NSAlert()
+        a.messageText = "iPhone'dan canlı metni izle"
+        if mobile.enabled {
+            a.informativeText = "Açık. iPhone'da Asistan Canlı uygulamasını açın; Mac aynı Wi-Fi ağında otomatik bulunur.\n\n"
+                + "Eşleştirme kodu:  \(mobile.displayCode)\n\n"
+                + "Bağlı cihaz: \(mobile.clientCount). Bağlantı bu kodla şifrelenir; kodu yenilerseniz bağlı cihazların kodu yeniden girmesi gerekir."
+            a.addButton(withTitle: "Tamam")
+            a.addButton(withTitle: "Kapat (yayını durdur)")
+            a.addButton(withTitle: "Yeni kod üret")
+        } else {
+            a.informativeText = "Açtığınızda görüşmenin canlı metni yerel ağdaki iPhone'unuza (Asistan Canlı uygulaması) şifreli olarak gönderilir. "
+                + "iPhone'dan asistana talimat yazabilir ve görüşmeyi sonlandırabilirsiniz.\n\nmacOS gelen bağlantılar ya da yerel ağ için izin sorabilir; izin verin."
+            a.addButton(withTitle: "Aç")
+            a.addButton(withTitle: "Vazgeç")
+        }
+        let r = a.runModal()
+        if mobile.enabled {
+            if r == .alertSecondButtonReturn { mobile.setEnabled(false) }
+            else if r == .alertThirdButtonReturn { mobile.regenerateCode(); showMobileBridge(); return }
+        } else if r == .alertFirstButtonReturn {
+            mobile.setEnabled(true)
+            refreshMobileItem()
+            showMobileBridge()
+            return
+        }
+        refreshMobileItem()
+    }
+
     /// Ajan çıktısındaki satırı ("[13:58:08] ARAYAN: ...") canlı pencereye yansıtır
     func updateLive(_ line: String) {
         var msg = line
@@ -1491,6 +1546,7 @@ final class AppDelegate: NSObject, NSApplicationDelegate {
         msg = msg.trimmingCharacters(in: .whitespaces)
         if msg.contains("ARAMA OTURUMU BAŞLADI") {
             liveText.string = ""
+            mobile.reset()
             if showLive { liveWindow.orderFrontRegardless() }
         } else if msg.hasPrefix("arayan: ") {
             appendLiveNote("Arayan: " + String(msg.dropFirst("arayan: ".count)))
diff --git a/build.sh b/build.sh
index 6c8ef12..367aebb 100755
--- a/build.sh
+++ b/build.sh
@@ -5,7 +5,7 @@ cd "$(dirname "$0")"
 APP="Asistan.app"
 rm -rf "$APP"
 mkdir -p "$APP/Contents/MacOS"
-swiftc -O -o "$APP/Contents/MacOS/Asistan" app/main.swift
+swiftc -O -o "$APP/Contents/MacOS/Asistan" app/main.swift app/MobileBridge.swift
 cp app/Info.plist "$APP/Contents/Info.plist"
 # Kaynaklar: ajan, kurulum betiği, bağımlılık listesi, ses dosyaları
 RES="$APP/Contents/Resources"
```

## Adım 3: Mac uygulamasını derle ve dene
```bash
cd ~/Documents/Claude/Asistan
swiftc -typecheck app/main.swift app/MobileBridge.swift   # önce hızlı tür denetimi
bash build.sh
```
Hata varsa düzelt ve tekrar dene. Sonra:
1. Çalışan eski Asistan'ı kapat (menü → Çıkış) ve yenisini aç. Uygulama `/Applications` altına kuruluysa, kullanıcıya yeni derlenen `Asistan.app` ile değiştirmek isteyip istemediğini sor.
2. Kullanıcıdan menü çubuğundaki **iPhone'dan izle… → Aç** seçeneğine basmasını iste. macOS'un "gelen bağlantı" ya da "yerel ağ" izin sorularına izin verilmeli.
3. Dinlemeyi doğrula: `lsof -nP -iTCP:47821 -sTCP:LISTEN` ve `dns-sd -B _asistan-canli._tcp` (Ctrl+C ile durdur). `app.log` içinde "iPhone köprüsü dinliyor" satırı görünmeli: `grep -n "iPhone" app.log | tail`. Yalnızca bu satırları göster, logun tamamını değil.

## Adım 4: iPhone uygulamasını indir
iOS projesini bu klasörün **içine değil, yanına** koy:

```bash
cd ~/Documents/Claude
git clone -b claude/wonderful-cray-s99poi https://github.com/mtahca/Asistan-Mobile.git
```

Repo gizli olduğu için klonlama kimlik sorarsa önce `gh auth status` ile kontrol et; `gh` kuruluysa `gh repo clone mtahca/Asistan-Mobile -- -b claude/wonderful-cray-s99poi` kullan. Bu da olmazsa kullanıcıdan dalı GitHub'dan zip olarak indirip `~/Documents/Claude/Asistan-Mobile` klasörüne açmasını iste.

Proje yapısı:
- `AsistanCanli.xcodeproj`: Xcode 16 projesi. Dosyalar "senkronize klasör" ile eklenir; `AsistanCanli/` altına koyulan her `.swift` dosyası otomatik olarak derlenir.
- `AsistanCanli-Info.plist`: yerel ağ izni ve Bonjour servisi. Diğer ayarlar otomatik üretilir.
- `AsistanCanli/LiveProtocol.swift`: Mac ile ortak protokol.
- `AsistanCanli/LiveClient.swift`: Mac'i bulma, bağlanma, mesaj alma ve gönderme.
- `AsistanCanli/ContentView.swift` ve `AsistanCanli/PairingView.swift`: ekranlar.

## Adım 5: iPhone uygulamasını derle
Önce imzasız bir simülatör derlemesiyle derleme hatalarını ayıkla:

```bash
cd ~/Documents/Claude/Asistan-Mobile
xcodebuild -project AsistanCanli.xcodeproj -target AsistanCanli \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning:|BUILD" | head -50
```

Xcode yüklü değilse ya da `xcode-select -p` komut satırı araçlarını gösteriyorsa kullanıcıya şunu söyle: App Store'dan Xcode kurulmalı, ardından `sudo xcode-select -s /Applications/Xcode.app` çalıştırılmalı (sudo komutunu kullanıcı kendisi çalıştırır).

**Simülatörde deneme:** simülatör Mac'in ağını kullandığı için Bonjour ile Mac'teki Asistan'ı bulabilir. Telefona yüklemeden önce bağlantıyı burada dene:
```bash
xcrun simctl list devices available | grep iPhone | head -3
# Bir cihaz seçip Xcode'dan Run, ya da:
xcodebuild -project AsistanCanli.xcodeproj -scheme AsistanCanli -destination 'platform=iOS Simulator,name=iPhone 16' build
```
Proje içinde paylaşılan bir scheme yok. Xcode, proje ilk kez açıldığında scheme'i kendisi oluşturur; `-scheme` hata verirse kullanıcıdan projeyi bir kez Xcode'da açmasını iste: `open AsistanCanli.xcodeproj`.

**iPhone'a yükleme** kullanıcının Xcode arayüzünde yapması gereken bir iştir. Ona adım adım anlat:
1. `open AsistanCanli.xcodeproj`
2. Sol üstte proje → TARGETS **AsistanCanli** → **Signing & Capabilities** → **Team**: kendi Apple kimliği. Yoksa "Add Account…" ile eklenir.
3. Bundle ID (`com.mtahca.asistan.canli`) başka bir hesapta kayıtlı diye hata verirse, sonuna bir ek yap (ör. `.mehmet`).
4. iPhone'u kabloyla bağla. iPhone'da "Bu bilgisayara güven" denmeli ve **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu** açılmalı (telefon yeniden başlar).
5. Üstteki cihaz menüsünden iPhone'u seç ve ▶︎ Run'a bas.
6. İlk açılışta iPhone'da **Ayarlar → Genel → VPN ve Aygıt Yönetimi** bölümünde geliştirici sertifikasına güven.
7. Ücretsiz Apple kimliğiyle yüklenen uygulama 7 gün sonra açılmaz; aynı adımlarla yeniden yüklenir.

## Adım 6: Uçtan uca test
1. Mac: menü → **iPhone'dan izle…**. Açıksa 8 haneli kodu gösterir.
2. iPhone: uygulamayı aç, kodu gir. **Yerel Ağ** izni sorulursa izin ver.
3. Durum çubuğu "<Mac adı> bağlı" göstermeli ve Mac'teki menü öğesinde "(1 cihaz bağlı)" yazmalı.
4. Gerçek bir arama ya da Asistan'ın test aramasıyla metnin iPhone'da canlı aktığını, talimat gönderilebildiğini ve "Sonlandır" düğmesinin çalıştığını doğrula.
5. Yanlış kodla bağlanmayı dene. Bağlantı reddedilmeli ve uygulama "Eşleştirme kodu yanlış…" demeli.

## Derlenmemiş kod: dikkat edilecek yerler
- **TLS-PSK** (`LiveProtocol.tlsOptions`): `sec_protocol_options_add_pre_shared_key` için `DispatchData` → `__DispatchData` dönüşümü ve `tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!` satırı. Desen Apple'ın "TicTacToe" (Network.framework) örneğiyle aynıdır. Hata verirse o örneğe göre düzelt.
- **`MobileBridge.setState`:** `NSDictionary(...).isEqual(to:)` ile `[String: Any]` karşılaştırması. Derlenmezse basit bir eşitlik kontrolüyle değiştir.
- **iOS:** `Scene.onChange(of:initial:)` ve `View.onChange(of:) { _, _ in }` iOS 17 API'leridir; hedef sürüm 17.0. Swift dil modu 5.0'dır; Swift 6'nın katı eşzamanlılık denetimine geçme.
- **`LiveClient`** `@MainActor` değildir, tüm ağ geri çağrıları `.main` kuyruğunda çalışır. Bunu bozma.

## Değişmemesi gereken sözleşmeler
- Servis türü `_asistan-canli._tcp`, port `47821`, PSK kimliği `asistan-canli` ve HMAC girdisi `asistan-canli-v1`. Bunlar iki tarafta aynı olmalı.
- `enum LiveProtocol` bloğu `app/MobileBridge.swift` (Mac) ve `AsistanCanli/LiveProtocol.swift` (iOS) dosyalarında **birebir aynı** kalmalı. Birini değiştirirsen ötekini de aynı şekilde değiştir. Kontrol için:
  ```bash
  diff <(sed -n '/^enum LiveProtocol/,/^}/p' ~/Documents/Claude/Asistan/app/MobileBridge.swift) \
       <(sed -n '/^enum LiveProtocol/,/^}/p' ~/Documents/Claude/Asistan-Mobile/AsistanCanli/LiveProtocol.swift)
  ```
- Mesajlar satır başına bir JSON nesnesidir.
  - Mac → iPhone: `hello`, `state`, `snapshot`, `reset`, `line {id, kind, speaker, text, ts}`, `pong`.
  - iPhone → Mac: `note {text}`, `end`, `ping`.
- Özellik Mac'te **varsayılan olarak kapalıdır**; kullanıcı açmadan ağa hiçbir şey yayınlanmaz. Bunu değiştirme.

## Sorun giderme
| Belirti | Bakılacak yer |
|---|---|
| iPhone "Mac aranıyor…" diyor | Mac'te özellik açık mı (`lsof -iTCP:47821`)? Aynı Wi‑Fi'da mı? iPhone'da Ayarlar → Gizlilik → Yerel Ağ → Asistan Canlı açık mı? Misafir ağları cihazları birbirinden yalıtabilir. |
| "Asistan dinlemiyor" | Mac güvenlik duvarı: Sistem Ayarları → Ağ → Güvenlik Duvarı → Seçenekler → Asistan'a gelen bağlantılara izin ver. |
| "Eşleştirme kodu yanlış" | Mac'te kod yenilenmiş olabilir. iPhone'da Ayarlar → Kodu güncelle. |
| Bağlantı kuruluyor ama metin gelmiyor | `app.log` içinde `iPhone bağlandı` satırı var mı? `appendLive` / `appendLiveNote` içindeki `mobile.append` çağrıları eklendi mi? |

## İş bitince
- Mac tarafındaki değişiklikler GitHub'daki `mtahca/Asistan` reposunun `claude/wonderful-cray-s99poi` dalıyla aynı amaçta. Yerel klasör bir git deposuysa commit etmeyi **kullanıcıya sor**; kendiliğinden push etme.
- iOS projesinde yaptığın düzeltmeleri `~/Documents/Claude/Asistan-Mobile` içinde commit et. Push etmeden önce kullanıcıya sor.
- Yedek dosyalarını (`*.yedek-*`) kullanıcı onaylayınca sil.
