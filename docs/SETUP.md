# Mac'te kurulum — adım adım

Bu klasördeki Swift dosyaları hazır. Xcode projesini elle üretmek kırılgan olduğu için
projeyi Xcode'da sen oluşturup dosyaları içine sürükleyeceksin. Toplam ~20 dakika.

---

## ⚠️ ÖNCE BUNU YAP — bugün, koddan önce

> **Durum: tamamlandı.** Paid Apps sözleşmesi ACTIVE ve Small Business Program açık.
> Bu bölüm referans olarak duruyor; doğrudan [0. Gereksinimler](#0-gereksinimler)'e geç.
> Abonelik ürünlerinin kurulumu ayrı bir iş ve [LAUNCH.md](LAUNCH.md)'de.

Bu ikisi arka planda bekleyen süreçler. Şimdi başlatmazsan lansman haftasında
duvara çarparsın.

### Paid Applications Agreement

**Abonelik ürünleri, sözleşme Active olmadan Sandbox'ta bile çalışmaz.** Kod
kusursuz olur, paywall boş gelir, günlerce nedenini ararsın. Apple mühendislerinin
forum cevabı net: sözleşme aktif değilse IAP ürünleri ne test ne de satın alma için
görünür.

App Store Connect ▸ Business (veya Agreements, Tax, and Banking):

1. **Paid Apps** sözleşmesini kabul et — hesap sahibi olarak, başka rolle olmaz
2. **Banking** — Türk banka hesabı (IBAN)
3. **Tax** — ABD vergi formu (**W-8BEN**). Türkiye-ABD çifte vergilendirme
   anlaşmasını doğru işaretle, stopaj düşer
4. Durum **ACTIVE** olana kadar bekle

Süre: her şey tamamsa genelde ~24 saat. Ama vergi formu incelemesi bazı vakalarda
**90 güne kadar** çıkabiliyor. Bu yüzden bugün.

### Small Business Program

Otomatik değil, **başvurmak zorundasın.** Yıllık $1M altındaysan komisyon %30 yerine
**%15**. Başvurmayı unutan geliştiriciler gelirlerinin altıda birini bağışlıyor.

### Uygulama adını rezerve et

App Store Connect'te kaydı şimdi oluştur — isim ilk kaydeden alır. "Lockin" doluysa
yedekler: **Onset**, **Startline**, **Nudged**, **No Excuse**.

---

## 0. Gereksinimler

| | |
|---|---|
| macOS | Xcode 26'yı çalıştırabilen sürüm (Sequoia veya üstü) |
| Xcode | **26 veya üstü** — AlarmKit daha eskisinde yok |
| Cihaz | **Gerçek iPhone, iOS 26+.** Simülatörde alarm sesi ve tam ekran sunum güvenilir değil, ilk günden cihazda test et |
| Hesap | Apple Developer Program, $99/yıl. Ücretsiz hesapla derleyebilirsin ama App Group + Live Activity için ücretli lazım |

## 1. Projeyi oluştur

1. Xcode → **File ▸ New ▸ Project ▸ iOS ▸ App**
2. Product Name: `Lockin`
3. Interface: **SwiftUI**, Language: **Swift**, Storage: **None**
4. Organization Identifier: kendi ters domainin (`com.seninadin`)
5. Minimum Deployment: **iOS 26.0**

## 2. Widget target ekle

1. **File ▸ New ▸ Target ▸ Widget Extension**
2. Name: `LockinWidget`
3. **"Include Live Activity" kutusunu işaretle**, "Include Configuration Intent"i işaretleme
4. Xcode "Activate scheme?" diye sorarsa **Cancel** de

## 3. Dosyaları içeri al

`ios/Lockin/` altındaki her şeyi Xcode'daki `Lockin` grubuna, `ios/LockinWidget/`
altındakini `LockinWidget` grubuna sürükle. "Copy items if needed" işaretli olsun.

**Kritik — target membership.** Şu iki dosya *her iki* target'a birden üye olmalı,
yoksa widget derlenmez:

- `Models/Commitment.swift`
- `Models/LockinMetadata.swift`
- `Intents/ProofIntent.swift`

Dosyayı seç → sağdaki File Inspector → **Target Membership** → hem `Lockin` hem
`LockinWidget` işaretli.

## 4. Capability'ler

Her iki target için de **Signing & Capabilities ▸ + Capability**:

- **App Groups** → `group.com.seninadin.lockin` adında bir grup oluştur
- Sadece app target'ında: **Push Notifications** gerekmiyor, atla

Sonra `ProofIntent.swift` içindeki `AppGroup.identifier` sabitini kendi grup adınla
değiştir. Bunu unutursan kanıt akışı sessizce çalışmaz — intent id'yi yazar, app
okuyamaz.

## 5. Info.plist anahtarları

App target ▸ Info sekmesi:

| Anahtar | Değer |
|---|---|
| `NSAlarmKitUsageDescription` | `Lockin needs alarm access so your commitments ring through Silent and Focus.` |
| `NSCameraUsageDescription` | `Lockin uses the camera so you can prove you actually started.` |

`NSAlarmKitUsageDescription` yoksa uygulama izin isterken **çöker**, uyarı vermez.
İlk çalıştırmada crash alırsan buraya bak.

## 6. RevenueCat

1. `File ▸ Add Package Dependencies` → `https://github.com/RevenueCat/purchases-ios`
2. `RevenueCat` ürününü **sadece app target'ına** ekle
3. [app.revenuecat.com](https://app.revenuecat.com) → proje aç → iOS app ekle
4. Entitlement oluştur, adı **tam olarak** `pro` olsun (kod bunu arıyor)
5. Offering oluştur, iki paket: monthly + annual
6. Public SDK key'i (`appl_…`) `LockinApp.swift` içindeki `configure(apiKey:)` çağrısına yapıştır

App Store Connect'te abonelik ürünlerini oluşturmadan paywall boş görünür — bu normal.

## 7. İlk çalıştırma testi

Sırayla şunları doğrula. Herhangi biri geçmiyorsa devam etme:

1. Uygulama açılıyor, onboarding görünüyor
2. Taahhüt eklerken **izin dialogu çıkıyor**
3. Zamanı 2 dakika sonrasına kur, telefonu **sessize al ve Focus aç**
4. Alarm **çalıyor ve tam ekran açılıyor** ← AlarmKit'in tüm değeri bu satırda
5. "I'm starting" → uygulama açılıyor → kanıt ekranı geliyor
6. "Dismiss" → 2 dakika sonra alarm **geri geliyor** ← ürünün tüm değeri bu satırda
7. Fotoğraf çek → alarm zinciri susuyor, streak 1 oluyor

### 7.1 Nag zinciri testi — "Rehearse the alarm"

6. adım gerçek sürelerle 10 dakika sürer ve her denemede baştan alınır. Ana ekrandaki
**Rehearse the alarm** aynı zinciri 20 saniye + 30 saniye aralıklarla oynatır; tüm test
üç dakikadan kısa. Prova streak'e dokunmaz, listede görünmez, paywall'a sayılmaz.

Telefon **sessizde ve Focus açıkken**, ekran kilitli, uygulama arka planda değil
**tamamen kapalı** olsun — bütün mesele uygulama çalışmadan da zincirin dönmesi.

| # | Yap | Görmen gereken |
|---|---|---|
| 1 | Rehearse'e bas, uygulamayı kapat, telefonu masaya koy | 20 sn sonra tam ekran alarm |
| 2 | **Dismiss** | 30 sn sonra alarm geri geliyor, buton artık "Still not started" |
| 3 | Yine Dismiss | Yine geliyor |
| 4 | Alarma **hiç dokunma**, kendi kendine sussun | Yine geliyor ← eski kodun kaçırdığı satır |
| 5 | 5. tekrardan sonra Dismiss | **Bir daha gelmiyor.** Gelirse bu 1 yıldız demek |
| 6 | Tekrar Rehearse → 1. alarmda "I'm starting" → kanıt verme, uygulamayı kapat | 30 sn sonra alarm geri geliyor |
| 7 | Tekrar Rehearse → "I'm starting" → "Start 25 minutes" | Zincir tamamen susuyor, streak **artmıyor** |

4. adım iOS'a özel ve en kolay atlanan yer: AlarmKit çalan alarmı kendisi susturur ve
bunu bize söylemez. Zincir önceden kurulmuş olmasaydı orada sessizce biterdi.

7. adımda streak artıyorsa prova gerçek taahhüt gibi kaydediliyor demektir — sayaç
yalancı olur, düzelt.

## 8. Derlenmezse

AlarmKit iOS 26 ile geldi ve imzalar beta'lar arasında değişti. Riskli her şey tek bir
yerde toplandı: `AlarmService.swift` içindeki `makeConfiguration` ve `makeSchedule`.

Hata bu iki fonksiyondaysa Xcode'un autocomplete'ine güven — `AlarmManager.AlarmConfiguration(`
yazıp tab'a bas, gerçek parametre listesini sana Xcode söyler. Dosyanın geri kalanına
dokunma, mimari doğru.

---

## 9. watchOS target

> **Kapsam notu (16 Ağustos 2026).** Apple Watch v1'e alındı. Ama **sırayı koru**:
> önce bölüm 7'deki ilk çalıştırma testini geçir. iPhone'da sessiz modu delen alarm
> çalışmadan bu target'a dokunma — Watch, çalışan bir alarmın uzantısı, alternatifi değil.

### 9.0 Neden ayrı bir target'a değer

AlarmKit alarmı zaten eşleşmiş Apple Watch'a **kendiliğinden yansıyor** — watch app
kurmasan da alarm bileğe ulaşır, başlık görünür, Stop butonu çalışır. Yani bu target
"alarmı bileğe getirmek" için yok. Yansıyan alarmın yapamadığı üç şey için var:

| | |
|---|---|
| Bilekten kanıt | 25 dakikalık odak sayacı telefonu eline almadan başlar |
| Complication | Sıradaki taahhüt + streak, saat kadranında, dokunmadan |
| Durum senkronu | Streak ve kaçırma sayacı iki cihazda da doğru kalır |

**Fotoğraf ve QR kanıtı bilekte yok, bilerek.** Watch'ın kamerası telefonun kamerası için
uzaktan kumanda; yataktan telefonu masaya doğrultmak kanıt değil. QR'ın tüm anlamı da
tarayıcıyı fiziksel olarak masaya götürmen. Bu iki tip telefonda kalıyor — `WristProofView`
o taahhütlerde "bunu iPhone'da bitir" diyor, yarım bir taklit sunmuyor.

### 9.1 Target'ları ekle

1. **File ▸ New ▸ Target ▸ watchOS ▸ App**
2. Product Name: `LockinWatch`
3. Interface: **SwiftUI**, Language: **Swift**
4. **"Watch App for Existing iOS App"** seçili olsun — companion app id'si otomatik bağlanır
5. Minimum Deployment: **watchOS 26.0**
6. "Include Notification Scene" **işaretleme**, "Include Complication" **işaretleme**
   (complication'ı bir sonraki adımda ayrı target olarak ekliyoruz)

Sonra complication için:

1. **File ▸ New ▸ Target ▸ watchOS ▸ Widget Extension**
2. Name: `LockinWatchWidget`
3. **"Embed in Application" → `LockinWatch`** (iOS app değil — bu en sık yapılan hata)
4. "Include Live Activity" ve "Include Configuration Intent" **işaretleme**

Bundle id'ler şu şekilde olmalı:

| Target | Bundle Identifier |
|---|---|
| `Lockin` | `com.seninadin.lockin` |
| `LockinWidget` | `com.seninadin.lockin.widget` |
| `LockinWatch` | `com.seninadin.lockin.watchkitapp` |
| `LockinWatchWidget` | `com.seninadin.lockin.watchkitapp.complication` |

Watch app'in Info.plist'inde `WKCompanionAppBundleIdentifier` **tam olarak**
`com.seninadin.lockin` olmalı. Yanlışsa uygulama derlenir, yüklenir ve WatchConnectivity
oturumu hiç açılmaz — hata da vermez.

### 9.2 Dosyaları içeri al

`ios/LockinWatch/` altındaki her şeyi Xcode'daki `LockinWatch` grubuna sürükle. Sadece
`Widget/LockinWatchWidgetBundle.swift` `LockinWatchWidget` grubuna gider.

### 9.3 Target membership — kritik tablo

Bölüm 3'teki kuralın aynısı, dört target'a genişletilmiş hâli. Bir satırı yanlış
işaretlersen ya derlenmez ya da daha kötüsü, sessizce senkron olmaz.

| Dosya | Lockin | LockinWidget | LockinWatch | LockinWatchWidget |
|---|:---:|:---:|:---:|:---:|
| `Models/Commitment.swift` | ✅ | ✅ | ✅ | ✅ |
| `Models/LockinMetadata.swift` | ✅ | ✅ | ❌ | ❌ |
| `Models/WatchSyncPayload.swift` | ✅ | ❌ | ✅ | ✅ |
| `Intents/ProofIntent.swift` | ✅ | ✅ | ❌ | ❌ |
| `Services/WatchSyncService.swift` | ✅ | ❌ | ❌ | ❌ |
| `LockinWatch/LockinWatchApp.swift` | ❌ | ❌ | ✅ | ❌ |
| `LockinWatch/Services/WatchSnapshotCache.swift` | ❌ | ❌ | ✅ | ✅ |
| `LockinWatch/Services/PhoneSyncService.swift` | ❌ | ❌ | ✅ | ❌ |
| `LockinWatch/Services/WristHaptics.swift` | ❌ | ❌ | ✅ | ❌ |
| `LockinWatch/Views/*.swift` | ❌ | ❌ | ✅ | ❌ |
| `LockinWatch/Widget/LockinWatchWidgetBundle.swift` | ❌ | ❌ | ❌ | ✅ |

İki satırın nedeni açıklama istiyor:

- **`LockinMetadata.swift` watch'ta yok.** `AlarmMetadata` protokolü AlarmKit'ten geliyor
  ve **AlarmKit'in watchOS sürümü yok.** Watch target'ına `import AlarmKit` ekleme.
  Aynı üç alan `WatchSyncPayload` içinde taşınıyor.
- **`WatchSnapshotCache.swift` iki watch target'ında birden.** Complication kendi
  process'inde çalışır ve WatchConnectivity callback'i almaz; veriyi App Group
  defaults'tan okur. Bu dosya o ortak zemin.

### 9.4 App Group ekleri

Her iki **watch** target'ında da **Signing & Capabilities ▸ + Capability ▸ App Groups**:

| Target | Grup |
|---|---|
| `LockinWatch` | `group.com.seninadin.lockin` |
| `LockinWatchWidget` | `group.com.seninadin.lockin` |

Sonra `LockinWatch/Services/WatchSnapshotCache.swift` içindeki `WatchAppGroup.identifier`
sabitini kendi grup adınla değiştir — bölüm 4'te `ProofIntent.swift` için yaptığının aynısı.

**Dikkat: App Group container'ı iPhone ile Watch arasında paylaşılmaz.** Aynı string, iki
ayrı kap. Telefonun `commitments.json`'ı watch'tan okunamaz. Veri sadece WatchConnectivity
üzerinden geçer — `WatchAppGroup` yalnızca watch app ile complication'ı birbirine bağlar.

WatchConnectivity için ayrıca bir capability gerekmiyor.

### 9.5 Watch target'ına eklenmeyecekler

| | |
|---|---|
| RevenueCat paketi | Bilekten satın alma yok, paywall telefonda |
| AlarmKit | watchOS'ta yok |
| `NSCameraUsageDescription` | Fotoğraf kanıtı bilekte yok |

### 9.6 Watch testi

Telefon testini (bölüm 7) geçtikten sonra, saat bilekteyken sırayla:

1. Watch app açılıyor, telefondaki taahhütler listede görünüyor
2. Complication'ı kadrana ekle → sıradaki taahhüt ve streak görünüyor
3. Telefondan yeni taahhüt ekle → **birkaç saniye içinde** watch listesinde beliriyor
4. Zamanı 2 dakika sonrasına kur, telefonu sessize al
5. Alarm çalıyor → **watch titriyor** ve app açıldığında doğrudan kanıt ekranı geliyor
6. Bilekten "Start 25 minutes" → sayaç başlıyor, **telefonda streak artıyor** ← bu satır
   watch target'ının tüm varlık sebebi
7. Telefonu uçak moduna al, bilekten kanıt ver, uçak modunu kapat →
   **kanıt telefona geç de olsa ulaşıyor** (`transferUserInfo` kuyruğu)

Adım 6 veya 7 geçmiyorsa target'ı yayınlama. Yansıyan alarm zaten çalışıyor; senkronu
bozuk bir watch app ürünü iyileştirmez, streak'i yalancı yapar.

### 9.7 Watch tarafı derlenmezse

Riskli tek yer `WatchSyncService.swift` içindeki `announceRinging` — `Alarm.state` ve
`.alerting` case'i AlarmKit'in beta'lar arası değişen kısmı, bölüm 8'deki iki fonksiyonla
aynı kategoride. Hata oradaysa case adını Xcode'a sordur, eşleme mantığına dokunma.

`transferCurrentComplicationUserInfo` ve `isComplicationEnabled` de sürüm sürüm adı
değişmiş API'ler; ikisi de `WatchSyncService.pushSnapshot` içinde, tek blokta.
