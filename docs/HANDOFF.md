# Devir teslim — 18 Ağustos 2026

Yeni bir oturuma geçerken buradan devam et. Bu dosya "ne durumdayız ve sırada ne var"
sorusunun cevabı; kararların gerekçeleri kendi dosyalarında.

---

## Tek cümlede

Uygulama çalışıyor ve mağazaya gönderilebilecek durumda. Kalan iş kod değil: **bir cihaz
turu, üç form, bir build yüklemesi.** Cihaz turu tek başına zincir testini, üç mağaza
karesini ve paywall görüntüsünü birden veriyor.

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

**1. Cihaz turu.** [PRESUBMIT.md](PRESUBMIT.md). Yirmi beş dakika ve kalan işin çoğunu
tek seferde bitiriyor: zincir testi, üç mağaza karesi, bir de paywall görüntüsü.

- **Zincir testi (bölüm A) hâlâ yapılmadı** ve ürünün tüm iddiası bu: alarm beş kez geri
  gelip beşincide duruyor mu. Bu geçmezse gerisinin anlamı yok.
- **Kareler çekildi** (18 Ağustos, 22:49–23:05): kilit ekranı alarmı, canlı kamera,
  dört taahhütlük liste, paywall. Mağaza seti bunlarla yeniden derlendi.
  **Kalan iki kare kısa:** ikinci alarm ("Still not started" — ürünün asıl iddiası ve şu
  an hiçbir karede yok) ve güncel veriyle bahane raporu.
- **Paywall görüntüsü hazır** (`design/shots/paywall.png`, fiyatlar canlı: $7.99 /
  $44.99). Abonelik ürünlerine yüklenince `MISSING_METADATA` kalkıyor.

Kare geldiğinde `python tools/make_store_screenshots.py` — kareler artık numarayla
değil adla duruyor (`design/shots/alarm.png`, `proof.png`, …), sıra ve başlıklar
`SHOTS` listesinde.

**Şablon araçlarına dikkat:** dışarıdan gelen bir düzenleyiciden çıkan görseller
324 × 702 geldi; App Store **1290 × 2796** istiyor ve büyütmek çözüm değil. Derleyici
zaten doğru boyutta üretiyor.

**2. Formlar.** [ASC-FORMS.md](ASC-FORMS.md) — cevaplar hazır, panelde tıklanacak.
Yaş derecelendirmesi (4+) ve **App Privacy etiketi**; ikincisi gönderim için zorunlu ve
bugüne kadar hiçbir yerde yazılmamıştı.

**3. Build'i yükle.** `git tag v1.0.0 && git push origin v1.0.0` → TestFlight. Sonra
sürüme bağla.

**4. Gönder.**

**5. Yirmi video.** [CONTENT.md](CONTENT.md). Kod üç hafta sürdü, bu on iki ay.

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
