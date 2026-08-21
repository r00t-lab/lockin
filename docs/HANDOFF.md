# Devir teslim — 20 Ağustos 2026

Yeni bir oturuma geçerken buradan devam et. Bu dosya "ne durumdayız ve sırada ne var"
sorusunun cevabı; kararların gerekçeleri kendi dosyalarında.

---

## Tek cümlede

**iOS App Store'da inceleme sırasında.** Android internal kanalda canlı ve mağaza sayfası
dolu; önündeki tek engel bir video ve bir banka hesabı. Kalan işin tamamı kod değil.

**20 Ağustos'ta değişenler:** RevenueCat'in Android anahtarı kondu ve doğrulandı, ama Play
tarafında **hâlâ hiç abonelik ürünü yok** — anahtar tek başına bir şey satmıyor. Bu ikisinin
arasındaki boşluk Android'de çıkışsız bir kapı yaratıyordu; kapatıldı. `nagg.pro/delete-data`
yayında ve site artık iki platformdan bahsediyor. Android'in birim testleri ilk kez CI'da
koşuyor.

## iOS — REDDEDİLDİ, düzeltildi, yeniden gönderim sende

**20 Ağustos: `REJECTED` — Guideline 2.1, Information Needed.** İşlevsellik reddi değil,
kod hatası değil: App Review Information ▸ **Notes** alanı incelemenin sorduğu yedi şeyden
yalnızca birini (nasıl test edilir) cevaplıyordu.

**Yapıldı:** Notes yeniden yazıldı, yedi maddeyi sorulduğu sırayla ve numaralı cevaplıyor
(3609/4000 karakter), `tools/asc_metadata.py` içinde kalıcı ve ASC'ye yazılıp geri okunarak
doğrulandı. Metin [STORE.md](STORE.md)'de.

**Sende kalan iki adım:**
1. **Ekran kaydı** — fiziksel cihaz, açılıştan başlayan, izin uyarıları ve abonelik akışı
   dahil. Çekim listesi [PRESUBMIT.md](PRESUBMIT.md) sonunda. Prova modunu **kullanma**.
2. **Resolution Center'a yanıt** — kaydı ekle, "notes güncellendi" de, yeniden gönder.
   Bu adım API'de yok; `resolutionCenterThreads` uçları 404 veriyor, panel işi.

Red metninin kendisi de API'de yok — bir daha aramaya değmez.

**Yeni build gerekmiyor.** Bağlı build 25 geçerli; reddedilen şey binary değil.

---

**Önceki gönderim: 19 Ağustos 18:18 UTC.**

| | |
|---|---|
| Sürüm | 1.0.0, **build 25** bağlı |
| Yayın tipi | **Manual** — onay gelse bile sen basmadan yayınlanmaz |
| Kategori | Productivity + Utilities |
| Yaş derecelendirmesi | 4+ (25 soru) |
| Gizlilik etiketi | yayınlandı |
| Ekran görüntüleri | 6,9" ve 6,5", beşer kare |
| Zincir testi | cihazda geçti |
| Satın alma | sandbox'ta test edildi |

Durum: `python tools/asc_metadata.py --check`

**Onay gelince hemen yayınlama.** [CONTENT.md](CONTENT.md)'deki 20 video hazır olduğu gün
bas. Onaylanmış ama yayınlanmamış beklemek bedava; hazırlıksız yayınlanmak ilk dalgayı
yakmak.

**Red gelirse** Resolution Center'daki mesajı oku. En olası itiraz "kullanıcı alarmı
kapatamıyor" — inceleme notunda cevabı yazılı: Stop butonu her zaman var, zincir beşte
duruyor.

**Yapılmamış ve doğrudan para kaybettiren tek şey:** Apple **Small Business Program**
başvurusu. Yıllık 1M doların altında komisyon %30 yerine %15. Google Play bunu otomatik
veriyor, Apple başvuru istiyor; başvuru birkaç dakika.

## Android — üç engel, üçü de kod değil

| | |
|---|---|
| Paket | `com.r00tlab.nagg` |
| Internal kanal | **canlı**, versionCode 30, imzalı |
| Mağaza sayfası | ad, açıklamalar, ikon, feature graphic, 5 telefon + 5 tablet ×2 — **App Store'dakilerin aynısı** |
| App content | 11 formdan **10'u bitti** |
| Abonelik ürünleri | **yok** — API'den doğrulandı, `subscriptions: 0` |
| RevenueCat | anahtar **konuldu ve geçerli** (`goog_VuGm…`), ama offering'de **0 paket** |
| Kapalı test | App content bitmeden **kilitli** |

Durum: `python tools/play_status.py`

### Sıradaki üç iş, bu sırayla

**1. Ön plan hizmeti videosu.** App content'teki son madde; kapalı test kilidini bu açıyor.
Android cihazda, kesmesiz, 30-60 saniye: uygulamayı aç → **Rehearse** → uygulamayı kapat ve
kilitle → alarm çalsın → **bildirim gölgesini aç, ön plan bildirimi görünsün** (inceleyicinin
aradığı tek kare bu) → kanıtla sustur → bildirim kaybolsun. YouTube'a **liste dışı** yükle,
linki forma yapıştır. Aynı kayıt [CONTENT.md](CONTENT.md)'deki 3 numaralı TikTok videosunun
ham malzemesi.

**2. Ödeme profili.** Ayarlar ▸ Ödeme profili, banka + vergi. Bu olmadan abonelik ürünleri
oluşturulamıyor: API'den denendi, `PERMISSION_DENIED` dönüyor ve bu bir yetki sorunu
**değil** — Play para uçlarını satıcı hesabı olmadan hiç açmıyor, ama hata mesajı bunu
söylemiyor. (Ürünleri *listeleme* ucu artık 200 dönüyor; kapalı olan yazma tarafı.)

**3. RevenueCat — anahtar tamam, ürünler değil.** `goog_` anahtarı `LockinApplication.kt`'de
ve 20 Ağustos'ta doğrudan RevenueCat'e sorularak doğrulandı: anahtar geçerli, Android
uygulaması projeye ekli. Eksik olan tek şey ürünler:

```text
iOS      default offering → 2 paket → $rc_monthly, $rc_annual → App Store ürünleri
Android  default offering → 0 paket
```

Yani **yeni bir offering açman gerekmiyor.** Play'de iki ürün oluşunca, RevenueCat'te
*mevcut* `$rc_monthly` / `$rc_annual` paketlerine Android ürünü olarak eklenecekler. Sonra
bir `play-*` etiketi: Play'deki versionCode 30 anahtardan önce derlendi, yani mağazadaki
build'de anahtar **yok**.

Doğrulamak için (public SDK anahtarı, okuma):

```bash
curl -s -H "Authorization: Bearer goog_VuGmfmntKCuLaSfWpgedvdhlHxE" -H "X-Platform: android"   https://api.revenuecat.com/v1/subscribers/probe/offerings
```

Sonra: **12 testçi opt-in → 14 gün kesintisiz → production başvurusu.** Saat testçiler
opt-in olduğunda başlıyor; o güne kadar geçen her gün doğrudan lansman gününe ekleniyor.

## Kod tarafında 20 Ağustos'ta kapananlar

- **Çıkışsız kapı, Android sürümü.** Play'de ürün yok → RevenueCat paket sunmuyor → paywall
  boş; ama ücretsiz sınır yine de uygulanıyordu. İki taahhüdü olan bir testçi ne üçüncüyü
  ekleyebiliyor ne de ödeyip geçebiliyordu. iOS'ta bunun kaçışı vardı (`canAddAnother`,
  RevenueCat hiç yapılandırılmadıysa `true` döner); Android'de yoktu — **ve o kontrolü
  birebir kopyalamak işe yaramazdı**, çünkü Android anahtarı artık gerçek. Eksik olan anahtar
  değil, ürünler. Kapı artık doğru soruyu soruyor: *satacak bir şey var mı?*
  - `SellState` üç durumlu: `UNKNOWN` / `NOTHING_TO_SELL` / `READY`. Sınırı **yalnızca**
    gerçekten aldığımız bir cevap kaldırıyor; başarısız sorgu `UNKNOWN` kalıp sınırı
    koruyor, yoksa ağdan hızlı davranan herkes bedava taahhüt kazanırdı.
  - Ürünler oluşturulduğu an sınır kendiliğinden geri geliyor; sonra ayrıca bir iş yok.
- **Placeholder anahtar artık reddediliyor** (iOS'taki gibi). Onunla `configure` etmek
  gürültüyle değil, *döngüyle* başarısız oluyor.
- **Android'in birim testleri hiçbir şey tarafından koşulmuyordu.** `AlarmScheduleTest`
  repoda duruyordu ve tekrarlama matematiğini kimseye kanıtlamıyordu. CI artık `gradle test`
  koşuyor ve **hangi assertion'ın patladığını** annotation olarak yazıyor — tarayıcı açmadan.
  Yeni `PaywallGateTest` "+" tuşunun kararını sabitliyor.
- **Tanı ekranına Subscription bölümü**: anahtar konmuş mu, raf durumu, paket sayısı, Pro.
  "Paywall boş" ile "paywall yüklenemedi" telefonda aynı görünüyor ve sebepleri zıt.
- **`AlarmScheduleTest` ilk koşusunda beş testten beşi patladı** ve bu testin hatasıydı,
  ürünün değil: `Commitment.hour` `fireAtMillis`'i **sistem** saat diliminde çözüyor (doğru
  olan bu — 07:00 diyen kişi bulunduğu yerdeki 07:00'ı kastediyor), test ise onu
  Istanbul'da kuruyordu. Yazıldığı makinede fark sıfır, UTC runner'da üç saat. *Bir yıl
  boyunca yeşildiler çünkü hiç koşmadılar.*
- **`nagg.pro/delete-data` yayında** ve site artık tek platform varsaymıyor. Terms "ödeme
  Apple Account'a yansır" diyordu, Support "hangi iPhone" diye soruyordu; Play aynı
  sayfaları linkliyor ve Android'de faturayı Google kesiyor. `index.html`'e dokunulmadı —
  "iPhone gerektirir" Android production'a çıkana kadar doğru.

## Kod tarafında 19 Ağustos'ta kapananlar

- **Odak sayacı görünmüyordu.** Kanıt tuşa basıldığı an kaydediliyor ve kutlama ekranı
  aynı çalıştırmada devralıp geri sayımı yok ediyordu. Artık kutlama, sayaç bitene ya da
  kullanıcı "Done" diyene kadar bekliyor. **Aynı hata Android'de de vardı.**
- **Kanıttan sonra "I'm not doing it" ekranda kalıyordu** ve o buton bahane kaydediyor —
  tek dokunuşla, o gün gerçekten başlamış birinin hanesine kaçırma yazılabiliyordu.
- **Android iOS ile birebir eşitlendi:** prova modu, masa kodu ekranı (üretici vardı,
  gösteren ekran yoktu), kutlama ekranı, haftalık rapor, tanı ekranı, taahhüt düzenleme
  (streak korunarak), "Prove you started" kartı, "No alarm set" uyarısı, paywall boş-durum
  metni, ve launcher adı `Lockin` → **Nagg**.
- **Build numarası binary'ye ulaşmıyordu.** Üretilen Info.plist kendi `CFBundleVersion`'ını
  taşıyor ve komut satırındaki ayarı yeniyordu; iki yükleme de "build 1" çıktı. Plist artık
  ayara referans veriyor, workflow numarayı spec'e yazıyor ve yazdığını doğruluyor.
- **Android release imzalanmıyordu** — workflow keystore'u çözüyor, Gradle kullanmıyordu.

## Erişimler — nerede ne var

| | |
|---|---|
| ASC API anahtarı | `~/Downloads/AuthKey_JJCLLBWGL7.p8` |
| Play service account | `~/Downloads/project-03b3d6d8-d75b-446e-aaf-1bde7f7299b1.json` |
| Upload keystore | `~/nagg-upload.jks`, parolası `~/nagg-github-secrets.txt` |
| Play hesabı | Vexnova, kişisel, `kibolar04kibolar@gmail.com`, konsol `/u/7` |

Play service account'ına Nagg için *test kanalına yayınlama*, *test kanallarını yönetme*
ve **hesap düzeyinde** *mağazadaki varlığı yönetme* verildi. Uygulama düzeyindeki aynı
isimli kutu gri görünüyor ve **yetmiyor** — ikisi ayrı yetki, tek isim.

**Yeni imza anahtarıyla ilk yükleme,** anahtarın SHA-256 parmak izi **Android geliştirici
doğrulaması ▸ paket ▸ Anahtar ekle** ile kaydedilmeden `commit` aşamasında reddediliyor.
Hata ne anahtarı ne de yeri söylüyor.

## Etiketler — hangisi ne yapıyor

```text
ipa-*    ad-hoc iOS build, herkese açık release olarak yayınlanır
apk-*    test APK'sı, herkese açık indirme linki
play-*   Android'i derler ve imzalar; Play'e yükleme aşağıdaki nedenle ELLE
v*       iki mağaza birden — aynı gün lansman için
```

**`play-*` Play'e yüklemiyor — hiç yüklemedi.** `PLAY_SERVICE_ACCOUNT_JSON` **GitHub
secret'ı yok** (service account JSON'ı yalnızca `~/Downloads`'ta, `tools/play_status.py`
onu oradan okuyor). Secret olmayınca "Upload to Play closed testing" adımı **sessizce
atlanıyor** ve koşu yeşil görünüyor — internal kanaldaki her versionCode aslında elle
yüklenmiş. Workflow artık bu durumda `::warning::` basıyor.

İki seçenek:
- **Konsol açmadan, elle:** `tools/play_upload.py` bunun için yazıldı.

  ```bash
  curl -LO https://github.com/r00t-lab/lockin/releases/download/play-9/app-release.aab
  python tools/play_upload.py app-release.aab internal
  ```

  `production`'ı bilerek kabul etmiyor; terfi bir karar, bayrak değil.
- **Bir kez otomatikleştir:** Settings ▸ Secrets ▸ Actions ▸ `PLAY_SERVICE_ACCOUNT_JSON`,
  içeriğe o JSON'ın tamamını yapıştır. Sonraki `play-*` kendi yükler ve bu adım gereksizleşir.

Ad-hoc IPA'nın dosya adında artık etiket geçiyor. Bir kez, mağaza kareleri için sınırı
kaldırılmış atılabilir bir build gerçek build sanılıp kuruldu; paywall'ın gelmemesi hata
sanıldı ve iki dosyanın adı da `Nagg.ipa` olduğu için ayırt edilemedi.

## Araçlar

```text
tools/asc_metadata.py             App Store alanları — --check okur, --apply yazar
tools/play_status.py              Play durumu — kanal, liste, görseller tek ekranda
tools/play_upload.py              imzalı .aab'yi test kanalına yükler (production'a değil)
tools/make_store_screenshots.py   iOS mağaza kareleri (durum çubuğunu da temizler)
tools/make_play_assets.py         Play görselleri — App Store karelerinden türetilir
tools/make_icon.py                ikon
docs/PRESUBMIT.md                 cihaz turu
docs/ASC-FORMS.md, PLAY-SETUP.md  panel formlarının cevapları, gerekçeleriyle
```

**Tanı ekranı:** iki uygulamada da wordmark'a uzun bas. Android'de ayrıca **pil muafiyeti**
satırı var — bir Android alarmının sessizce hiç çalmamasının en yaygın sebebi.

**Log:** iOS'ta 3uTools, filtre `NAGG`.

**Değişmez kural:** çalan alarm ile kanıt arasındaki hiçbir şey bir SwiftUI sunumuna
bağlı olamaz. Bu üç kez ısırdı.

## Bekleyen

- **Family Controls entitlement** — odak oturumunda uygulama engelleme (v1.1). Başvuru
  Apple'da. Gerekçe [PRODUCT.md](PRODUCT.md).
- **İkinci alarm karesi** — mağaza görselinde "Dismiss doesn't work" başlığının altındaki
  kare hâlâ *ilk* alarm. Butonu "Still not started" yazan kareyi çekmek bir prova turu.
- ~~`nagg.pro/delete-data`~~ — **yayında.** Play ▸ App content ▸ Data safety'deki veri
  silme URL'sine `https://nagg.pro/delete-data` girilebilir.
- **Abonelikler `MISSING_METADATA` (iOS)** — iki kez araştırıldı, ürünlerde eksik alan yok;
  ilk sürümle birlikte gönderildi. Panelde düzeltilecek bir şey aramak zaman kaybı.
