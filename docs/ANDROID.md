# Android — iOS ile aynı gün

Karar (16 Ağustos 2026): iki platform eş zamanlı çıkıyor. ABD'de TikTok trafiği kabaca
yarı yarıya iOS/Android — tek platformda kalmak ürettiğin her videonun yarısını çöpe
atmak demek.

## ⚠️ Uzun ayak kod değil, takvim

**Google Play, 13 Kasım 2023'ten sonra açılmış bireysel hesaplarda production erişimi
vermiyor.** Önce 12 test kullanıcısıyla **14 gün kesintisiz** closed testing yapman,
sonra production başvurusu yapman gerekiyor. 2026'da hâlâ yürürlükte.

Muafsın eğer: hesap 13 Kasım 2023'ten eskiyse **veya** organization (kurumsal) hesapsa.

### Muaf değilsen sıralama tersine dönüyor

Android'in 14 günlük saati var, iOS'un 24-48 saatlik incelemesi. Yani:

| Gün | Ne |
|---|---|
| 0 | Android APK'sını **çalışır hale getir** ve closed testing'e yükle. Mükemmel olması gerekmiyor, çalışması yeterli. |
| 0 | 12 testçiyi opt-in et — sınıf arkadaşları, yurt, Discord. Opt-in kesintisiz sayılıyor, biri çıkarsa saat sıfırlanmıyor ama sayı 12'nin altına düşmemeli. |
| 0-14 | Bu süre boyunca iOS'u bitir ve App Store'a gönder, **manual release** seç. |
| 14 | Production erişimi için başvur. |
| ~16 | İki store da hazır. Aynı gün yayınla, 20 video hazır. |

**Bugün yapılacak tek şey: 12 testçiyi bul.** Kod ondan sonra gelir — saat testçi
sayısı 12'ye ulaştığında başlıyor.

## Durum — 19 Ağustos 2026

**Kod derleniyor** (CI'da yeşil) ve iOS ile **birebir eşitlendi**. Doküman bir süre "bu
kod hiç derlenmedi" dedi; artık doğru değil.

O tur kapanan farklar:

| | Neydi |
|---|---|
| Masa kodu | Üretici vardı, **onu gösteren ekran yoktu** — kullanıcı okutması istenen kodu hiçbir yerde göremiyordu. iOS'ta kapatılan aynı çıkışsız kapı. |
| Prova | Yoktu. 20 sn + 30 sn'lik sıkıştırılmış zincir olmadan mekaniği bir cihazda doğrulamak her denemede on dakika. |
| Kutlama ekranı | Yoktu; kanıt düşüyor, ekran kapanıyordu. |
| Haftalık rapor | Onboarding ve paywall söz veriyordu, uygulamada yoktu. |
| Tanı ekranı | Yoktu. On iki testçi, on iki üretici demek. |
| Düzenleme | Kart dokunuşu kanıta gidiyordu; saati değiştirmenin tek yolu silip yeniden kurmaktı, **yani streak'i çöpe atmak**. |
| "Prove you started" kartı | Yoktu. Full-screen intent bastırılırsa kanıta dönüş yolu kalmıyordu. |
| İsim | Launcher'da ve wordmark'ta hâlâ **Lockin** yazıyordu. |

**Bilerek farklı kalan tek şey:** fotoğraf reddi metinleri. Android karanlık / parlama /
"masa değil" ayrımı yapıyor, iOS tek bir "boş kare" kontrolü. Android'inki daha iyi;
eşitleme yönü iOS'u yükseltmek olmalı, Android'i düşürmek değil.

**Kod tarafında kalan:** `goog_REPLACE_ME`. Play ürünleri oluşup RevenueCat'e bağlanana
kadar paywall boş gelir — bu yüzden paywall artık boş olduğunu **söylüyor**.

## Teknik: Android'de bu uygulama daha kolay

## Teknik: Android'de bu uygulama daha kolay

iOS'ta zor olan kısım Android'de zaten çözülmüş:

| | iOS | Android |
|---|---|---|
| Sessizi delen alarm | AlarmKit, iOS 26+ zorunlu | `AlarmManager` + full-screen intent, yıllardır var |
| Tam ekran sunum | AlarmKit yönetiyor | `Notification.fullScreenIntent` |
| API kararlılığı | iOS 26 ile yeni, imzalar oynadı | Oturmuş |
| Minimum sürüm | iOS 26 (kitleyi daraltıyor) | Android 8+ (neredeyse herkes) |

Stack: **Kotlin + Jetpack Compose.** React Native veya Capacitor deneme — tam ekran
alarm iki platformda da native davranış istiyor, köprü katmanı burada sadece acı verir.

## ⚠️ Play'in exact alarm politikası

Bu uygulamanın Android'de tek gerçek engeli.

- `USE_EXACT_ALARM` **kısıtlı bir izin.** Sadece çekirdek işlevi hassas zamanlama olan
  uygulamalar (alarm, sayaç, takvim) kullanabiliyor.
- Lockin bu tanıma **gerçekten uyuyor** — çekirdek işlevi alarm. Ama Play Console'da
  doğru beyan etmen gerekiyor.
- `SCHEDULE_EXACT_ALARM` alternatifi Android 13+'ta **varsayılan olarak reddediliyor**,
  kullanıcıdan ayrıca istemen gerekiyor. Alarm uygulaması için bu kötü bir deneyim.
- Aynı cihazda ikisinden **sadece birini** iste. Eski SDK'lar için
  `SCHEDULE_EXACT_ALARM`'ı `max-sdk` niteliğiyle beyan et.
- **Yeni politika 28 Ekim 2026'da yürürlüğe giriyor.** Android sürümünü ondan sonra
  çıkaracaksan güncel metni tekrar oku.

Beyanı yanlış yaparsan yayından kaldırma riski var. Doğru yaparsan sorun yok — bu
uygulama tam olarak iznin var olma sebebi.

## Play tarafında bugün yapılacak

1. **Hesap tipini kontrol et.** Play Console ▸ Setup ▸ Developer account. Personal mı
   organization mı, açılış tarihi ne? Cevap tüm takvimi belirliyor.
2. Personal ve Kasım 2023 sonrasıysa: **12 testçi listesini bugün topla.** Saat onlar
   opt-in ettiğinde başlıyor, sen kod yazmayı bitirdiğinde değil.
3. Payments profile'ı tamamla — Apple tarafındaki muadilini zaten hallettin, bu 15 dakika.
