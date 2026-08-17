# Lockin

> Söz verdiğin işe başlamanı zorlayan alarm. iOS 26 + AlarmKit.

**Alarmy uyanmanı sağlıyor. Lockin başlamanı sağlıyor.**

---

## Nereden başlanır

| Sırayla oku | Ne var içinde |
|---|---|
| [docs/PRODUCT.md](docs/PRODUCT.md) | Ürün tanımı, neden şimdi, v1 kapsamı ve **kapsam dışı bıraktıklarımız** |
| [docs/SETUP.md](docs/SETUP.md) | Mac'te Xcode kurulumu, adım adım, ~20 dakika |
| [docs/MONETIZATION.md](docs/MONETIZATION.md) | Fiyat, RevenueCat, gelir matematiği, vergi |
| [docs/CONTENT.md](docs/CONTENT.md) | TikTok sistemi + **çekime hazır 20 video senaryosu** |
| [docs/STORE.md](docs/STORE.md) | App Store metinleri, ekran görüntüsü sırası, red riskleri |
| [docs/LAUNCH.md](docs/LAUNCH.md) | Abonelik ürünleri + RevenueCat kurulumu, gönderim kontrol listesi |
| [docs/ANDROID.md](docs/ANDROID.md) | Android ne zaman, neden 10. haftada, Play'in exact alarm politikası |

## Kod

```
ios/Lockin/
  LockinApp.swift              uygulama girişi, kanıt hand-off'u
  Models/
    Commitment.swift           tek domain nesnesi
    LockinMetadata.swift       AlarmKit'in taşıdığı payload
  Services/
    AlarmService.swift         ⭐ AlarmKit + nag zinciri — ürünün kalbi
    CommitmentStore.swift      App Group içinde JSON, veritabanı yok
    SubscriptionService.swift  RevenueCat sarmalayıcı
  Intents/
    ProofIntent.swift          "I'm starting" butonu → uygulamayı aç
  Views/
    OnboardingView.swift       3 ekran, izin isteme yok
    CommitmentListView.swift   ana ekran
    NewCommitmentView.swift    izin tam burada isteniyor
    ProofView.swift            ⭐ foto / sayaç / QR — 8 saniyede bitmeli
    PaywallView.swift          aylık öne, yıllık tasarruf olarak
    CaptureViews.swift         kamera + QR okuyucu sarmalayıcıları
ios/LockinWidget/
  LockinWidgetBundle.swift     Live Activity + Dynamic Island
ios/LockinWatch/               bilekten kanıt + complication (watchOS 26)
android/                       Kotlin + Compose sürümü
prototype/index.html           çalışan tarayıcı prototipi
```

## Bir sonraki 4 adım

1. **Bugün, 30 dakika:** App Store Connect'te uygulama kaydını oluştur ve **adı rezerve
   et** — isim ilk kaydedene gidiyor. Sonra abonelik ürünlerini kur:
   [docs/LAUNCH.md](docs/LAUNCH.md) bölüm 1. Hesap tarafındaki her şey (Paid Apps
   sözleşmesi, Small Business Program) zaten hazır.
2. **Bugün, geri kalan:** TikTok hesabını aç ve ilk videoyu at. Kod yazma.
   [docs/CONTENT.md](docs/CONTENT.md) sonundaki "İlk 2 hafta kuralı"nı oku — eşiği
   geçemezsen yazacağın kod boşa gider.
3. **Bu hafta:** [docs/SETUP.md](docs/SETUP.md)'i takip edip projeyi derle. Tek hedef:
   telefonu sessize alıp Focus açtığında alarmın çalması. O çalıştığı an ürün var
   demektir, gerisi ekran.
4. **3. hafta:** Kanıt akışını bitir, 20 videoyu çek, lansman.

Android [docs/ANDROID.md](docs/ANDROID.md)'de — 10. haftada, iOS'ta 30 günde 5.000
indirmeyi geçtiğin an. Önce değil.

## Kaynaklar

Ürün kararlarının dayandığı veri:

- [RevenueCat — State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps) — fiyat ve dönüşüm
- [MacRumors — iOS 26 third-party alarm apps](https://www.macrumors.com/2025/06/11/ios-26-third-party-alarm-apps/) — AlarmKit'in ne açtığı
- [First1000 — Wayk: 25M views, 100K downloads in 30 days](https://read.first1000.co/p/how-an-alarm-app-got-25-million-views) — kategori kanıtı
- [Playkit — Catchr fish ID case study](https://playkit.substack.com/p/fish-id-app) — içerik formatı
- [Indie Hackers — Alarmy: $11M/yıl](https://www.indiehackers.com/post/alarmy-the-11-million-alarm-clock-app-c74024c017) — pazar büyüklüğü
- [Apple — AlarmKit](https://developer.apple.com/documentation/alarmkit) — API
