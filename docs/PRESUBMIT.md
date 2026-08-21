# Gönderim öncesi test

Her App Store gönderiminden önce baştan sona. Yaklaşık 25 dakika.

**Neyi test etmiyoruz:** streak aritmetiği, kaçırma türetme, hafta sonu kuralı ve veri
göçü `ios/LockinTests` içindeki 17 testle her push'ta koşuyor. Onları elle doğrulamak
cihaz vaktini, yalnızca cihazın gösterebildiği şeylerden çalar.

**Cihaz kurulumu:** telefon **sessizde**, **bir Focus açık**, uygulama arka planda değil
**tamamen kapalı**, ekran kilitli. Bu üçü kapalıyken yapılan test hiçbir şey kanıtlamaz —
ürünün tüm iddiası tam olarak bu koşullarda çalmak.

## Bu turda çıkan dört görüntü

Test turu doğru ekranları zaten sırayla açıyor. Mağaza görüntülerini ayrı bir turda
çekmek aynı işi ikinci kez yapmak olur — dördü de aşağıdaki adımların içinde, yan tuş +
ses açma ile çıkıyor.

| Ne zaman | Ne çekilecek | Nereye |
|---|---|---|
| **A2** — ikinci alarm ekrandayken | Butonu **"Still not started"** yazan tam ekran alarm | `design/shots/second-ring.png` |
| **B1** — kanıt ekranı | **Kamera canlıyken** — siyah dikdörtgen değil | `design/shots/proof.png` ✅ |
| **D1** sonrası | Dolu liste: 3-4 taahhüt, biri kanıtlanmış, **streak > 0** | `design/shots/list.png` ✅ |
| Rapor | Sayı şeridine dokun — **güncel veriyle** | `design/shots/report.png` |
| **E1** — paywall açıkken | Paywall'ın tamamı | `design/shots/paywall.png` ✅ |

✅ olanlar 18 Ağustos akşamı çekildi. Kalan ikisi: **ikinci alarm** (ürünün asıl
iddiası, hiçbir karede yok) ve **güncel veriyle rapor** (eldeki kare "Brush your teeth"
ve sıfırlarla, liste karesindeki streak 1 ile çelişiyor).

Listedeki isimler öğrenciye hitap etsin: "Write the essay intro", "Leave for class",
"Get to the gym", "Read 20 pages" — çekilen kare bunlarla dolu ve doğru olan bu.

Saat ve pil önemsiz — derleyici durum çubuğunu 9:41 ve dolu pille yeniden boyuyor.

Tur bitince, sırayla:

1. `python tools/make_store_screenshots.py`
2. Yeni kare listeye giriyorsa `SHOTS`'a ekle — dosya adı, başlık, alt satır, sıra,
   zemin, eğim. Başlık karenin gösterdiğini iddia etmeli; "Dismiss doesn't work" ancak
   ikinci alarm karesi geldiğinde yazılabilir.
3. Paywall görüntüsünü iki abonelik ürününe de yükle
   ([ASC-FORMS.md](ASC-FORMS.md) bölüm 3) — `MISSING_METADATA`'yı kaldıran tek şey bu.

---

## A. Mekanik — bu geçmezse gerisi anlamsız

| # | Yap | Görmen gereken |
|---|---|---|
| A1 | Rehearse → **fotoğraf** → uygulamayı kapat → kilitle | 20 sn sonra tam ekran alarm, sesli |
| A2 | **Dismiss** | 30 sn sonra alarm geri geliyor, buton "Still not started" |
| A3 | Yine Dismiss | Yine geliyor |
| A4 | Alarma **hiç dokunma**, kendi sussun | **Yine geliyor** |
| A5 | 5. tekrardan sonra Dismiss | **Bir daha gelmiyor** |

A4 iOS'a özel ve en kolay atlanan satır: AlarmKit çalan alarmı kendi susturur ve bunu bize
söylemez. Zincir önceden kurulmamış olsaydı orada sessizce biterdi.

A5 geçmezse **gönderme.** Durmayan alarm 1 yıldız yağmuru demek.

## B. Üç kanıt tipi

| # | Yap | Görmen gereken |
|---|---|---|
| B1 | Prova (fotoğraf) → kanıt ekranı | **Canlı kamera görüntüsü**, siyah dikdörtgen değil |
| B2 | "Take the photo" | Titreşim, sonra yeşil rakamlı kutlama ekranı, sonra listeye dönüş |
| B3 | Lensi kapat, çek | Reddediliyor: "That frame is empty" |
| B4 | Prova (sayaç) → "Start 25 minutes" | Zincir susuyor, kutlama ekranı |
| B5 | + ile masa kodu taahhüdü kur | Kaydeder kaydetmez QR sayfası açılıyor |
| B6 | Kodu ekranda bırak, provada okut | Zincir susuyor |
| B7 | Başka bir QR okut | "Wrong code. That's not your desk." |

## C. Kanıta giden üç yol

Üçü de çalışmalı. Biri çalışmazsa kullanıcı nag'lenirken cevapsız kalır.

| # | Yol | Görmen gereken |
|---|---|---|
| C1 | Kilit ekranındaki **"I'm starting"** | Uygulama açılıyor, doğrudan kanıt ekranı |
| C2 | Zincir dönerken **uygulamayı kendin aç** | Doğrudan kanıt ekranı — butona dokunmadan |
| C3 | Karttaki **"Prove you started"** | Kanıt ekranı |

C2 en önemlisi: alarmın kendi butonu cihazda güvenilir davranmıyor ve tek yol o olamaz.

## D. Taahhüt yönetimi

| # | Yap | Görmen gereken |
|---|---|---|
| D1 | + → taahhüt ekle | Listede beliriyor |
| D2 | Wordmark'a **uzun bas** → tanı ekranı | O taahhüt için **`alarms in chain` = 6** |
| D3 | Karta dokun → saati değiştir → kaydet | Streak **korunuyor**, sıfırlanmıyor |
| D4 | × ile sil | Kart gidiyor |
| D5 | Uygulamayı öldür, tekrar aç | Taahhütler ve sayılar yerinde |

D2 kritik: `6` sağlıklı zincir (zil + 5 nag). **`1` görürsen zincir kurulamamış** demektir
ve bu başka hiçbir ekranda görünmez.

## E. Abonelik

| # | Yap | Görmen gereken |
|---|---|---|
| E1 | 3. taahhüdü eklemeyi dene | Paywall açılıyor |
| E2 | Paywall | **$7.99** ve **$44.99** görünüyor, "Nothing to sell yet" değil |
| E3 | Terms ve Privacy linkleri | `nagg.pro` sayfaları açılıyor |
| E4 | Sandbox hesabıyla satın al | Pro açılıyor, 3. taahhüt eklenebiliyor |
| E5 | Restore | Pro geri geliyor |

## F. İlk izlenim

| # | Yap | Görmen gereken |
|---|---|---|
| F1 | Uygulamayı sil, IPA'yı yeniden kur | Onboarding geliyor |
| F2 | Ana ekran | İkon 60 pikselde okunuyor |
| F3 | İlk taahhütte | Alarm izni **o anda** isteniyor, açılışta değil |
| F4 | Uçak modu | Uygulama normal çalışıyor — her şey cihazda |

---

## Bir şey geçmezse

Önce **tanı ekranı** (wordmark'a uzun bas). Kamera izni, cihazda capture session kurulabiliyor
mu, zincirde kaç alarm var, App Group erişilebilir mi, okunmamış proof id var mı — hepsi orada.

Sonra 3uTools gerçek zamanlı log, filtre **`NAGG`**. Uygulamanın yazdığı her satır o işaretle
başlıyor:

```text
NAGG scheduled: ... alarms=6 ...     zincir kuruldu, kaç alarmla
NAGG intent: perform ...             alarmın butonu intent'i calistirdi
NAGG handoff: from intent | mid-chain | nothing to prove
NAGG camera: session configured | shutter | captured
```

---

## İnceleme ekran kaydı (Guideline 2.1)

1.0.0 bu kayıt istenerek reddedildi. Apple'ın maddesi net: **fiziksel cihazda**, güncel
iOS'ta, **uygulamanın açılışıyla başlayan** tek bir kayıt; içinde izin uyarıları ve
abonelik akışı görünecek. Simülatör kaydı ve montaj kabul edilmiyor.

Sıra bu, çünkü izinler bir kez sorulur: **uygulamayı önce sil, sonra kur.** İzin
uyarılarını kaçırırsan kaydı baştan çekersin.

| # | Ne görünmeli | Neden |
|---|---|---|
| 1 | Ana ekrandan ikona dokunup **soğuk açılış** | "Kayıt açılıştan başlamalı" |
| 2 | **Alarm izni** uyarısı ve kabulü | "Hassas veri/cihaz özelliği isteyen uyarılar" |
| 3 | **Bildirim izni** uyarısı | aynı madde |
| 4 | `+` ▸ taahhüt oluştur, 2 dakika sonrası, kanıt tipi **Desk photo** | "tipik kullanıcı akışı" |
| 5 | Kontrol merkezinden **sessiz mod** + **Focus** aç, ikonları görünsün | ürünün tüm iddiası |
| 6 | Alarmın tam ekran ve **sesli** çalması | aynı |
| 7 | **Dismiss** — kanıt vermeden. Alarmın geri gelmesi | özellik olduğu görülmeli |
| 8 | "I'm starting" ▸ **kamera izni** uyarısı ▸ masa fotoğrafı ▸ alarmın susması | izin + akışın kapanışı |
| 9 | `+` ile üçüncü taahhüt ▸ **paywall**: başlık, süre, fiyat, Terms ve Privacy linkleri | "ücretli içeriğe erişim" |
| 10 | **Satın alma akışı** — sandbox hesabıyla, Apple'ın ödeme sayfası açılana kadar | "satın alma veya abonelik akışları dahil" |

**Süreyi kısaltmak için 4-8 arası yerine "Rehearse the alarm" kullanma.** Prova mekaniği
doğru gösteriyor ama incelemeci *gerçek* akışı istiyor; prova ayrıca "REHEARSAL" etiketi
taşıyor ve bu, kaydın gerçek kullanımı göstermediği izlenimi verir. Provayı yalnızca
TikTok çekimlerinde kullan.

Uygulamada **olmayan** ve bu yüzden kayıtta aranmayacak şeyler: hesap kaydı/oturum açma/
hesap silme, kullanıcı tarafından oluşturulan içerik, raporlama ve engelleme. Notes bunların
bulunmadığını zaten söylüyor.

Kaydı **Resolution Center'daki yanıta** ekle. Notes alanı `tools/asc_metadata.py --apply`
ile zaten güncellendi; yanıtta kısaca "notes güncellendi + kayıt ekte" demek yeterli.
