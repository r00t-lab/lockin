# Devir teslim — 19 Ağustos 2026

Yeni bir oturuma geçerken buradan devam et. Bu dosya "ne durumdayız ve sırada ne var"
sorusunun cevabı; kararların gerekçeleri kendi dosyalarında.

---

## Tek cümlede

**iOS App Store'da inceleme sırasında.** Android internal kanalda canlı ve mağaza sayfası
dolu; önündeki tek engel bir video ve bir banka hesabı. Kalan işin tamamı kod değil.

## iOS — gönderildi

**19 Ağustos 18:18 UTC, durum `WAITING_FOR_REVIEW`.**

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
| Abonelik ürünleri | **yok** |
| RevenueCat | `goog_REPLACE_ME` |
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
söylemiyor.

**3. RevenueCat.** Play uygulamasını ekle (`com.r00tlab.nagg`), iki ürünü `pro`
entitlement'ına bağla, `goog_` anahtarını `LockinApplication.kt`'ye göm, yeni build çıkar.

Sonra: **12 testçi opt-in → 14 gün kesintisiz → production başvurusu.** Saat testçiler
opt-in olduğunda başlıyor; o güne kadar geçen her gün doğrudan lansman gününe ekleniyor.

## Kod tarafında bugün kapananlar

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
play-*   Android'i Play'e yükler, iOS'u tetiklemeden
v*       iki mağaza birden — aynı gün lansman için
```

Ad-hoc IPA'nın dosya adında artık etiket geçiyor. Bir kez, mağaza kareleri için sınırı
kaldırılmış atılabilir bir build gerçek build sanılıp kuruldu; paywall'ın gelmemesi hata
sanıldı ve iki dosyanın adı da `Nagg.ipa` olduğu için ayırt edilemedi.

## Araçlar

```text
tools/asc_metadata.py             App Store alanları — --check okur, --apply yazar
tools/play_status.py              Play durumu — kanal, liste, görseller tek ekranda
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
- **`nagg.pro/delete-data`** — Play'in veri silme rozetini açar, zorunlu değil.
- **Abonelikler `MISSING_METADATA` (iOS)** — iki kez araştırıldı, ürünlerde eksik alan yok;
  ilk sürümle birlikte gönderildi. Panelde düzeltilecek bir şey aramak zaman kaybı.
