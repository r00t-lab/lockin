# Devir teslim — 18 Ağustos 2026

Yeni bir oturuma geçerken buradan devam et. Bu dosya "ne durumdayız ve sırada ne var"
sorusunun cevabı; kararların gerekçeleri kendi dosyalarında.

---

## Tek cümlede

Sürüm gönderime hazır duruyor: build bağlı, kareler yüklü, formlar dolu. Kalan üç şey
kod değil: **gizlilik etiketi** (panelde, API'de yok), **zincir testi** (cihazda, üç
dakika) ve **Gönder düğmesi**.

## Bugün kapanan hatalar

Hepsi cihazda doğrulandı ya da testlerle korunuyor:

- **Nag zinciri hiç çalışmıyordu.** AlarmKit'in Stop'u uygulamayı uyandırmıyor; zincir
  tepkiseldi, yani hiç kurulmuyordu. Artık alarm kurulurken 5 nag da yazılıyor.
- **Streak hiç kırılmıyordu.** Kaçırma bildirilemediği için takvimden türetiliyor.
- **Masa kodu kullanıcıyı kilitliyordu** — QR'ı üreten ekran yoktu.
- **Kamera açılmıyordu.** Sheet içinden sheet sunmak sessizce başarısız oluyordu; kamera
  artık gömülü `AVCaptureSession`.
- **"+" uygulamayı çökertiyordu.** `@Environment` uygulamadan tamamen çıkarıldı.
- **Ekleme kilitliydi.** Satacak ürün yokken ücretsiz sınır uygulanıyordu.
- **CI sertifika kotasını dolduruyordu.** Boru hattı artık kendi çöpünü topluyor.

**Değişmez kural:** çalan alarm ile kanıt arasındaki hiçbir şey bir SwiftUI sunumuna
bağlı olamaz. Bu üç kez ısırdı.

## Kurulmuş altyapı

| | Durum |
|---|---|
| Abonelik ürünleri | ✅ `com.r00tlab.lockin.pro.monthly` $7.99 · `.annual` $44.99, 3 gün deneme |
| RevenueCat | ✅ entitlement `pro`, iki ürün bağlı, `default` offering |
| Alan adı | ✅ `nagg.pro`, Cloudflare Workers, kaynak `gh-pages` dalı |
| Hukuki sayfalar | ✅ `/terms` `/privacy` `/support` — **`.html` yazma**, host uzantıyı kırpıyor |
| Mağaza metinleri | ✅ isim, subtitle, açıklama, anahtar kelimeler, üç URL |
| Testler | ✅ 17 birim testi, her push'ta CI'da |

## Sırada — önem sırasıyla

**1. Zincir testi.** [PRESUBMIT.md](PRESUBMIT.md) bölüm A, üç dakika, telefon sessizde ve
bir Focus açıkken. **Hâlâ yapılmadı** ve gönderimden önce geçmesi gereken tek şey bu:
beşinci tekrardan sonra alarm duruyor mu. Durmayan alarm tek yıldız yağmuru demek.

**2. App Privacy etiketi.** Panelde, [ASC-FORMS.md](ASC-FORMS.md) bölüm 2'deki tabloyu
satır satır. API'de yok (`appDataUsages` bu sürümde 404), o yüzden tek elle iş bu.

**3. Gönder.** Panelde "Add for Review": sürüm + iki abonelik aynı gönderime giriyor.
Abonelikler `MISSING_METADATA` görünmeye devam ediyor ve panelde doldurulacak alanları
yok — ilk kez bir sürümle gönderilince çözülüyor.

**4. Yirmi video.** [CONTENT.md](CONTENT.md). Kod üç hafta sürdü, bu on iki ay.

### 19 Ağustos gecesi kapananlar

`python tools/asc_metadata.py --check` her zaman güncel hâli basar. O gece yazılanlar:

| | |
|---|---|
| Yaş derecelendirmesi | 25 soru → **4+** (Brezilya L). 2025'te eklenen altı alan olmadan API PATCH'i reddediyor |
| **Kategori** | **hiç ayarlanmamıştı** — kategorisiz uygulama gönderilemez. Productivity + Utilities |
| Sürüm numarası | `1.0` → **`1.0.0`**. Build ancak numarası aynı olan sürüme bağlanır; seçici sebepsiz boş görünecekti |
| Yayın tipi | **Manual** — onay günü değil, yirmi video hazır olduğu gün |
| İçerik hakları | üçüncü taraf içerik yok |
| App Review notu + iletişim | [STORE.md](STORE.md)'deki metin, telefon ve e-posta |
| Build | `v1.0.0` etiketi → TestFlight → **sürüme bağlandı** (build 1, `usesNonExemptEncryption` false) |
| Mağaza kareleri | 6,9" ve 6,5" yuvaları dolu, beşer kare, `COMPLETE` |

## Bekleyen

- **Family Controls entitlement** — odak oturumunda uygulama engelleme (v1.1). Başvuru
  Apple'da, birkaç gün–birkaç hafta. Geliştirme entitlement'ı onaysız çalışıyor, yani
  beklerken yazılabilir. Gerekçe `docs/PRODUCT.md`.
- **Abonelik ürünleri `MISSING_METADATA`.** İki teori de yanlış çıktı: alanlar dolu ve
  **inceleme görüntüsü de yüklü** (API'den okundu, ikisinde de `COMPLETE`). Kalan tek
  açıklama, aboneliklerin ilk kez bir uygulama sürümüyle gönderilmeyi bekliyor olması.
  Panelde aranacak eksik alan yok — [ASC-FORMS.md](ASC-FORMS.md) bölüm 3.

## Araçlar

```text
tools/asc_metadata.py             App Store Connect alanları — --check okur, --apply yazar
tools/make_icon.py                ikon (design/icon-clock-source.png'den)
tools/make_store_screenshots.py   mağaza görselleri (durum çubuğunu da temizler)
docs/PRESUBMIT.md                 gönderim öncesi tur — test + dört görüntü
docs/ASC-FORMS.md                 yaş derecelendirmesi, gizlilik etiketi, ürün görüntüsü
```

**Tanı ekranı:** uygulamada wordmark'a uzun bas. Kamera izni, capture session kurulabiliyor
mu, zincirde kaç alarm var (**6 sağlıklı, 1 = zincir yok**), App Group erişilebilir mi.

**Log:** 3uTools gerçek zamanlı log, filtre `NAGG`.

**CI hatası:** `api.github.com/repos/r00t-lab/lockin/check-runs/<id>/annotations` — public,
giriş gerektirmiyor.
