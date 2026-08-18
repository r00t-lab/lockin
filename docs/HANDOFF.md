# Devir teslim — 18 Ağustos 2026

Yeni bir oturuma geçerken buradan devam et. Bu dosya "ne durumdayız ve sırada ne var"
sorusunun cevabı; kararların gerekçeleri kendi dosyalarında.

---

## Tek cümlede

Uygulama çalışıyor ve mağazaya gönderilebilecek durumda. Kalan iş kod değil: **üç ekran
görüntüsü, bir build yüklemesi, bir yaş derecelendirmesi.**

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

**1. Zincir testi.** `docs/PRESUBMIT.md` bölüm A. Üç dakika. **Hâlâ yapılmadı** ve ürünün
tüm iddiası bu: alarm beş kez geri gelip beşincide duruyor mu.

**2. Üç ekran görüntüsü.** Mevcut mağaza görsellerinde başlıklarla kareler eşleşmiyor.
Eksik olanlar:
- İkinci alarm, butonu **"Still not started"** yazan
- Kanıt ekranı, **kamera canlıyken**
- **Dolu liste**, 3-4 gerçek taahhüt ve streak > 0 (öğrenciye hitap eden isimler:
  "Write the essay intro", "Leave for class", "Gym at 5")

Üçü de tek prova turunda çıkıyor. `tools/make_store_screenshots.py` ham kareyi mağaza
boyutuna çeviriyor; `design/shots/1..5.png` koy, çalıştır.

**3. Build'i yükle.** `git tag v1.0.0 && git push origin v1.0.0` → TestFlight. Sonra
sürüme bağla.

**4. Yaş derecelendirmesi.** App Store Connect'te yapılmamış.

**5. Gönder.**

**6. Yirmi video.** `docs/CONTENT.md`. Kod üç hafta sürdü, bu on iki ay.

## Bekleyen

- **Family Controls entitlement** — odak oturumunda uygulama engelleme (v1.1). Başvuru
  Apple'da, birkaç gün–birkaç hafta. Geliştirme entitlement'ı onaysız çalışıyor, yani
  beklerken yazılabilir. Gerekçe `docs/PRODUCT.md`.
- **Abonelik ürünleri `MISSING_METADATA`.** API'nin gösterdiği her alan dolu; muhtemelen
  ilk gönderimde uygulama sürümüyle birlikte çözülüyor. Panelde kontrol et.

## Araçlar

```text
tools/make_icon.py                ikon (design/icon-clock-source.png'den)
tools/make_store_screenshots.py   mağaza görselleri
docs/PRESUBMIT.md                 gönderim öncesi 25 dakikalık test
```

**Tanı ekranı:** uygulamada wordmark'a uzun bas. Kamera izni, capture session kurulabiliyor
mu, zincirde kaç alarm var (**6 sağlıklı, 1 = zincir yok**), App Group erişilebilir mi.

**Log:** 3uTools gerçek zamanlı log, filtre `NAGG`.

**CI hatası:** `api.github.com/repos/r00t-lab/lockin/check-runs/<id>/annotations` — public,
giriş gerektirmiyor.
