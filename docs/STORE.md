# App Store metinleri

**İsim: Nagg Alarm.** Lockin, Unsnooze ve Nagg üçü de doluydu — tek kelimelik kısa
isimler App Store'da pratikte tükenmiş durumda. İkinci kelime eklemek çakışmayı
bitiriyor ve `alarm` en değerli arama kelimemiz olduğu için bedava ASO kazancı.

Ana ekranda yine tek kelime görünüyor: `CFBundleDisplayName` = **Nagg**.

İç isimler (`Lockin` target'ları, `com.r00tlab.lockin` bundle ID) bilerek değişmedi.
Kullanıcı görmüyor, ve kayıtlı identifier'ları geçersiz kılmak boşuna risk olurdu.

## İsim ve alt başlık

```
Name:     Nagg Alarm
Subtitle: It comes back until you start
```

**Düzeltme:** önceki alt başlık ("Prove you started, or it returns") **32 karakterdi**,
sınır 30. Doküman "sınırında" diyordu, değildi — App Store Connect'e girmeye çalışınca
yakalandı. Şimdiki 29 karakter.

Alt başlık ASO için ismin kadar önemli. `alarm` artık isimde
geçtiği için alt başlığı mekaniği anlatmaya ayırdık — asıl merak uyandıran şey o.

## Anahtar kelimeler (100 karakter, virgülle, boşluksuz)

```
snooze,focus,study,procrastination,accountability,deadline,streak,homework,motivation,timer
```

İsimde ve alt başlıkta geçen kelimeleri buraya tekrar yazma — Apple zaten indeksliyor,
karakter israfı olur.

## Açıklama

```
You don't have a motivation problem. You have a starting problem.

Every focus app waits for you to open it. Nagg comes to find you.

Set a commitment — "start the essay at 7pm", "leave for class at 8:20", "gym at 5".
When the time comes, Nagg rings through Silent mode, through Focus, through Do Not
Disturb. It takes over your Lock Screen. And it does not go away because you tapped
dismiss.

PROVE IT OR IT COMES BACK
Photograph your desk. Scan the code you taped to it. Start a 25-minute timer.
Until you do one of those, the alarm returns every two minutes.

BUILT ON APPLE'S ALARM ENGINE
Nagg uses AlarmKit, the same system that powers the Clock app. That's why it rings
when everything else stays quiet.

IT KEEPS SCORE
Streaks for the days you started. And a weekly report of every excuse you made,
whether you want it or not.

FREE
Two commitments, free forever. Nagg Pro unlocks unlimited commitments and the
weekly report.
```

## Ekran görüntüleri — 5 tane, bu sırayla

Sıra önemli: ilk iki görsel indirmenin çoğunu belirliyor, çünkü çoğu kişi kaydırmıyor.

### Kareler ve dosya adları

Kareler numarayla değil adla duruyor: `design/shots/alarm.png`, `proof.png`, `list.png`,
`create.png`, `report.png`. Numaralı hâlde "3 hangisiydi" sorusu bir kez yanlış cevaplandı
ve kanıt ekranı iki karede birden çıktı — ad bunu imkânsız kılıyor.

Sıra `tools/make_store_screenshots.py` içindeki `SHOTS` listesinde ve bugün şu:

| # | Kare | Başlık |
|---|---|---|
| 01 | `alarm.png` — kilit ekranı, "Write the essay intro" | It rings on silent. |
| 02 | `proof.png` — kanıt ekranı, kamera canlı | Prove you started. |
| 03 | `list.png` — dört taahhüt, biri kanıtlı, streak 1 | It counts the days you showed up. |
| 04 | `create.png` — yeni taahhüt, üç kanıt tipi | Three ways to prove it. |
| 05 | `report.png` — bahane raporu | Zero excuses. So far. |

**İki kare hâlâ eksik ve ikisi de kısa:**

- **İkinci alarm**, butonu "Still not started" yazan. Hedef listedeki 02 bu; geldiğinde
  kanıt ekranı 03'e kayar. Ürünün asıl iddiası ("dismiss işe yaramıyor") şu an hiçbir
  karede görünmüyor.
- **Taze bahane raporu.** Eldeki kare "Brush your teeth" ve sıfırlarla dolu, yani 03'teki
  streak 1 ile çelişiyor. Sayı şeridine dokunup yeniden çekmek on saniye.

| # | Hangi ekran | Nasıl ulaşılır |
|---|---|---|
| 01 | Kilit ekranında tam ekran alarm | Prova → uygulamayı kapat → kilitle → 20 sn |
| 02 | **İkinci** alarm, butonu "Still not started" | İlk alarmda Dismiss → 30 sn bekle |
| 03 | Kanıt ekranı, **kamera canlıyken** | Zincir dönerken uygulamayı aç |
| 04 | Dolu liste, streak > 0 | 3-4 taahhüt ekle, birini kanıtla |
| 05 | Bahane raporu | Üstteki sayı şeridine dokun |

### Metinler

```text
01  It rings on silent
    Through Focus. Through Do Not Disturb.

02  Dismiss doesn't work
    It comes back. Up to five times.

03  Prove you started
    Photograph your desk, or it rings again.

04  It counts the days you showed up
    And every one you didn't.

05  Zero excuses. So far.
    Nagg keeps the receipts.
```

### Renkler

```text
Arka plan   #A8452F      sakinleştirilmiş alarm kırmızısı
Başlık      #FFFFFF
Alt satır   #F6D9D2
```

Zemin uygulamanın alarm kırmızısıyla akraba, ama tam ekran kaplarken `#C7351A` kadar
bağırmıyor. Mağazada gördüğü rengi açtığı uygulamada bulan kişi doğru yere geldiğini
anlıyor — jenerik bir gradient bu bağı koparır.

### Kurallar

- **Telefon çerçevesi kullan**, düz ekran görüntüsü koyma. İkisi hafif eğik (02 ve 04),
  üçü düz: eğimi hepsine vermek kareyi eğri asılmış tabloya çeviriyor, hiç vermemek beş
  aynı dikdörtgen demek.
- **Rozet uydurma.** "Editors' Choice", "App of the Year", basın logoları — hiçbiri
  bizim değil. "Editors' Choice" Apple'ın kendi ödülü; uydurmak ret değil **kaldırma**
  sebebi. Şablonlar bunları yer tutucu olarak bırakıyor, sil.
- **Yorum uydurma.** Sıfır kullanıcı varken "-Emilia, harika uygulama" yazmak hem kural
  ihlali hem ilk gerçek kullanıcı geldiğinde ödenecek bir borç.
- **Başlık ekranın gösterdiğini iddia etsin.** Rapor sıfır bahane gösteriyorsa "her
  bahaneyi hatırlar" yazma. Metinle kare çelişirse ikisi de inandırıcılığını kaybeder.
- **Özellik değil sonuç yaz.** "Alarm ayarları" kimseyi indirtmiyor, "sessizde çalar"
  indirtiyor.
- **Durum çubuğu boyanır, uygulama asla.** Derleyici saati 9:41 yapıp pili dolduruyor;
  altındaki arayüz kareden çıktığı gibi kalıyor. Apple'ın kontrol ettiği şey arayüzün
  gönderilen uygulama olması, çubuğun telefondan çıkan çubuk olması değil. Kilit ekranı
  karesi dokunulmadan geçiyor — orada boyanacak çubuk yok.
- **Her karenin bir alt satırı var.** Başlık vaadi satıyor, alt satır tek somut ayrıntıyı
  veriyor: hangi üç kanıt, hangi iki mod. Derleyici ikisini de basıyor.

`tools/make_store_screenshots.py` ham kareleri mağaza boyutuna çeviriyor: kareyi
`design/shots/` içine yukarıdaki adla koy, çalıştır, `design/store/` çıkar. Çıktı
**1290 × 2796** — 6.9" boyutu, Apple küçük cihazlara kendisi ölçekliyor. Şablon
araçlarından çıkan 300-400 piksellik görseller yüklenmiyor; ölçek tek yönlü.

## Değerlendirme notu (App Review'a)

**1.0.0 bu alan yüzünden reddedildi (20 Ağustos 2026, Guideline 2.1 — Information Needed.)**
Eski not yalnızca "nasıl test edilir"i anlatıyordu. İnceleme yedi şey soruyor ve altısını
cevaplayan bir not da geri geliyor. Aşağıdaki metin yedisini de, **sorulduğu sırayla ve
numaralı** cevaplıyor — 5. maddeyi arayan biri düz yazı okumak zorunda kalmasın diye.

`tools/asc_metadata.py` içindeki `REVIEW_NOTES` ile birebir aynı; oradan yazılıyor,
elle panele girilmiyor. **App Store Connect bu alanı 4000 karakterle sınırlıyor** (şu an
3609 karakter).

```
Nagg is an alarm you have to prove yourself to. Answering the review questions in order.

1. SCREEN RECORDING
Attached to this reply in Resolution Center. Recorded on a physical iPhone on the current
iOS, from launch, covering: creating a commitment; the alarm ringing in Silent mode with a
Focus on; the alarm returning after Dismiss; clearing it with photo proof; the paywall and
purchase; and every permission prompt.

2. DEVICES AND OS TESTED
iPhone 14 Pro Max, iOS 26.6 (physical device). Silent/Focus behaviour, the alarm chain, the
camera proof flow and a sandbox purchase were all verified on it.

3. WHAT IT DOES, AND FOR WHOM
For people who miss deadlines they set themselves, students above all. The problem is
starting, not waking: an ordinary reminder is swiped away in one gesture and nothing
happens, so the task slides another day. You commit to a task and a time. At that time the
alarm rings through Silent and Focus, and the only way to silence it for good is to prove
you started -- a photo of your desk, a 25-minute focus timer, or scanning a QR "desk code"
you print and tape to your desk. Dismissing without proof reschedules up to five times,
then stops. The value is a commitment device that asks for evidence, and a streak that only
counts days you actually began.

4. SETUP AND ACCESS TO EVERY FEATURE
No account, no login, no demo credentials, no sample files. Nothing is stored off-device.

FASTEST PATH: "Rehearse the alarm" on the main screen replays the whole mechanic in about a
minute (rings after 20s, nags 30s apart) instead of waiting for a real alarm. It asks which
proof type to demonstrate. Rehearsals do not affect streaks.

The real thing, if you prefer:
a. Tap + and create a commitment two minutes out. Pick a proof type.
b. Put the device in Silent mode and turn on any Focus.
c. It rings full screen and audible. This is AlarmKit, the framework behind Apple's own
   Clock app; ringing through Silent and Focus is the system's intended behaviour.
d. Tap Dismiss WITHOUT proving. It returns in two minutes. This is the feature, not a bug,
   and it is capped at five returns before stopping on its own.
e. Tap "I'm starting" for the proof screen. Any photo of a desk clears it; the image is
   checked on device and discarded immediately.
f. Diagnostics: press and hold the "nagg" wordmark on the main screen -- permissions, camera
   availability, and how many alarms are in the chain.

SUBSCRIPTION: free for two commitments. A third opens the paywall -- Nagg Pro Monthly and
Nagg Pro Annual, each with a 3-day free trial, each showing title, duration and price next
to links to the Terms and the privacy policy. Apple handles every payment.

PERMISSIONS: Alarms (AlarmKit), so a commitment can ring through Silent and Focus; this is
the whole product. Camera, only to photograph a desk or scan a desk code as proof. Photo
library, only as a fallback when no camera is available.

5. EXTERNAL SERVICES
RevenueCat, for subscription state only: it gets an anonymous identifier generated on the
device plus the receipt Apple issues, and never a name, email, commitment or photo. Apple
StoreKit handles payment. There is no backend server, no analytics or advertising SDK, no AI
service and no third-party sign-in. Commitments, streaks and proof never leave the device.

6. REGIONAL DIFFERENCES
None. Identical in every storefront; English only. Prices follow Apple's regional pricing.

7. REGULATED INDUSTRY OR PROTECTED CONTENT
Neither. A personal productivity app with no third-party or licensed material, no medical or
treatment claims, not directed at children.
```

**Ekran kaydı ayrı bir iş ve bu notun yerini tutmuyor:** Apple fiziksel cihazda, açılıştan
başlayan, izin uyarılarını ve abonelik akışını içeren bir kayıt istiyor. Çekim listesi
[PRESUBMIT.md](PRESUBMIT.md) sonunda.

## Reddedilme riskleri ve önlemi

| Risk | Önlem |
|---|---|
| "Kullanıcı alarmı kapatamıyor" | Stop butonu her zaman var, nag 5'te duruyor. Review notunda bunu açıkça yaz. |
| Sağlık iddiası incelemesi | ADHD / tedavi / terapi kelimelerini hiçbir yerde kullanma. "Focus tool" de. |
| Eksik restore | Paywall'da "Restore" butonu var — silme. |
| Eksik terms/privacy linki | Domain al, iki statik sayfa koy. Paywall'daki linkler çalışmak zorunda. |
| `NSAlarmKitUsageDescription` eksik | Uygulama izin isterken çöker. Info.plist'i iki kere kontrol et. |
