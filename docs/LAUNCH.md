# Lansman — "kod derlendi"den "uygulama canlı"ya

Hesapların hazır olduğuna göre geriye kalan tek fiddly kısım abonelik ürünleri.
Paywall'ın boş gelip gelmemesi tamamen bu dosyaya bakıyor.

**Sıra önemli:** ürünleri önce App Store Connect'te oluştur, sonra RevenueCat'e
içeri al. Ters yaparsan RevenueCat eşleştiremez.

---

## 1. App Store Connect — abonelik ürünleri

### Subscription Group

Tek grup oluştur. Adı: `Lockin Pro`

Aynı gruptaki ürünler arasında kullanıcı yükseltme/düşürme yapabilir. İki planı ayrı
gruplara koyarsan kullanıcı aylıktan yıllığa geçemez, iki ayrı abonelik ödemeye başlar.
Bu, sonradan düzeltilmesi acı veren bir hata.

### Ürünler

| Alan | Aylık | Yıllık |
|---|---|---|
| Product ID | `com.seninadin.lockin.pro.monthly` | `com.seninadin.lockin.pro.annual` |
| Reference Name | `Lockin Pro Monthly` | `Lockin Pro Annual` |
| Duration | 1 Month | 1 Year |
| Fiyat | **$7.99** | **$44.99** |
| Introductory Offer | 3 gün ücretsiz deneme | 3 gün ücretsiz deneme |

Product ID'yi sonradan **değiştiremezsin.** Yazmadan önce iki kere oku.

### Her ürün için doldurulması zorunlu

Bunlardan biri eksikse ürün "Missing Metadata"da takılır ve Sandbox'ta görünmez:

- **Localization** (en-US): Display Name + Description
- **Review screenshot** — paywall ekranının fotoğrafı, her ürün için ayrı
- **Review notes** — boş bırakabilirsin

> IAP lokalizasyon eksikliği App Review'ın en sık verdiği redlerden biri. Description
> alanını "Unlimited commitments and the weekly report." gibi gerçek bir cümleyle doldur,
> ürün adını tekrar etme.

---

## 2. RevenueCat

Sıra: **Entitlement → Product import → Attach → Offering**

1. **Product catalog ▸ Entitlements ▸ + New entitlement**
   Identifier: `pro` — kod tam olarak bunu arıyor
   ([SubscriptionService.swift](../ios/Lockin/Services/SubscriptionService.swift))

2. **Products** — App Store Connect'ten iki ürünü içeri al (1'e 1 eşleşme)

3. **Entitlement `pro` ▸ Associated Products ▸ Attach** — iki ürünü de bağla.
   Bu adımı atlarsan satın alma başarılı olur ama `isPro` false kalır. Sessiz hata,
   bulması saatler alır.

4. **Offerings ▸ + New offering** — identifier `default`, **Current** olarak işaretle
   - Package `$rc_monthly` → aylık ürün
   - Package `$rc_annual` → yıllık ürün

   Paywall paketleri offering'deki sırayla gösteriyor. **Aylığı üste koy** — Productivity
   kategorisinde gelirin %77'si aylıktan geliyor, yıllığı öne çıkarmak dönüşümü düşürüyor.

5. Public SDK key'i (`appl_…`) → [LockinApp.swift](../ios/Lockin/LockinApp.swift)
   içindeki `configure(apiKey:)`

### Sandbox testi

App Store Connect ▸ Users and Access ▸ Sandbox ▸ yeni test kullanıcısı.
Gerçek Apple ID'nle test etme.

Doğrulanacak: paywall iki paketi gösteriyor → satın al → `isPro` true → uygulamayı sil,
kur → **Restore** çalışıyor.

---

## 3. Ekran görüntüleri

2026'da Apple işi kolaylaştırdı: **sadece en büyük ekranı yüklüyorsun**, gerisini
kendisi ölçekliyor.

| | |
|---|---|
| 6.9" iPhone | **1320 × 2868 px** — zorunlu |
| 13" iPad | 2064 × 2752 px — **sadece uygulaman iPad'i destekliyorsa** |
| Adet | locale başına 1-10 (5 tane koy, sıra [STORE.md](STORE.md)'de) |

### iPad desteğini kapat

Xcode ▸ target ▸ General ▸ Supported Destinations → **iPad'i kaldır.**

Kazandığın: iPad ekran görüntüsü hazırlamıyorsun, iPad'de bozuk görünen layout için
red yemiyorsun, iPad'de test etmiyorsun. Bu uygulama telefonda kullanılıyor — iPad
desteği v1'de saf maliyet.

---

## 4. Gönderim öncesi son kontrol

Sırayla, hiçbirini atlamadan:

- [ ] `NSAlarmKitUsageDescription` ve `NSCameraUsageDescription` Info.plist'te
- [ ] App Group adı hem app hem widget target'ında aynı, `ProofIntent.swift`'teki
      sabitle eşleşiyor
- [ ] `Commitment.swift`, `LockinMetadata.swift`, `ProofIntent.swift` her iki target'a üye
- [ ] RevenueCat key gerçek key, `appl_REPLACE_ME` değil
- [ ] Terms ve Privacy sayfaları **canlı bir domainde** ve paywall'daki linkler açılıyor
- [ ] Paywall'da Restore butonu var
- [ ] Gerçek cihazda: sessiz mod + Focus açıkken alarm çalıyor
- [ ] Gerçek cihazda: Dismiss → 2 dakika sonra alarm geri geliyor
- [ ] Gerçek cihazda: fotoğraf → zincir susuyor, streak 1
- [ ] App Review notu yazıldı ([STORE.md](STORE.md)'de hazır metin var)
- [ ] Sağlık iddiası içeren tek kelime yok (ADHD / tedavi / terapi)

---

## 5. Zamanlama

| | |
|---|---|
| İnceleme süresi | genelde 24-48 saat |
| **Manual release seç** | Onay gelince sen basacaksın |

Neden manual: onay geldiği gün değil, **20 videon hazır olduğu gün** yayınla. Wayk'in
kurucusunun cümlesi — sosyal kanıtı olmayan uygulama sessizce ölür. Uygulamanın
onaylanmış ama yayınlanmamış olarak beklemesi sana hiçbir şeye mal olmuyor; hazırlıksız
yayınlanması ise ilk dalgayı yakmak demek.

İlk red gelirse panik yapma — normal. Sebebi oku, düzelt, tekrar gönder. Genelde
yukarıdaki listeden atladığın bir madde çıkıyor.
