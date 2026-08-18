# Lansman — "kod derlendi"den "uygulama canlı"ya

Hesapların hazır olduğuna göre geriye kalan tek fiddly kısım abonelik ürünleri.
Paywall'ın boş gelip gelmemesi tamamen bu dosyaya bakıyor.

**Sıra önemli:** ürünleri önce App Store Connect'te oluştur, sonra RevenueCat'e
içeri al. Ters yaparsan RevenueCat eşleştiremez.

---

## 1. App Store Connect — abonelik ürünleri

> **Durum: kuruldu (18 Ağustos 2026).** Grup ve iki ürün App Store Connect API'siyle
> oluşturuldu, fiyatlar ve denemeler bağlandı. Aşağısı artık plan değil, kayıt.

### Kurulmuş hâli

| | Aylık | Yıllık |
|---|---|---|
| Product ID | `com.r00tlab.lockin.pro.monthly` | `com.r00tlab.lockin.pro.annual` |
| ASC id | `6802574125` | `6802574534` |
| Görünen ad | Nagg Pro Monthly | Nagg Pro Annual |
| Süre | 1 ay | 1 yıl |
| Fiyat (USA) | **$7.99** | **$44.99** |
| Deneme | 3 gün ücretsiz | 3 gün ücretsiz |

Grup: `Nagg Pro` (id `22317019`), görünen adı da **Nagg Pro** — Ayarlar ▸ Abonelikler'de
kullanıcının gördüğü başlık bu. İkisi de **aynı grup, aynı seviye (groupLevel 1)**, yani
kullanıcı aylıkla yıllık arasında serbestçe geçebiliyor. Ayrı gruplara koymak iki ayrı
abonelik ödemesine yol açardı ve sonradan düzeltmesi acı verirdi.

**Product ID'ler `lockin` içeriyor ve bu bilinçli.** Kullanıcı product ID'yi hiçbir yerde
görmüyor; gördüğü şey yukarıdaki "görünen ad". İç isimlerin `Lockin` kalması kararıyla
tutarlı, bundle id ile birebir eşleşiyor.

### Fiyat gerekçesi

Alarmy ~$5/ay ve $59.99/yıl alıyor — yıllığında neredeyse hiç indirim yok. Biz $7.99/ay ile
onun üstündeyiz, çünkü Nagg *uyandırma* satmıyor: farklı iş, farklı fiyat. RevenueCat SOSA
2026 verisi ucuz fiyatın iki kez cezalandırdığını gösteriyor — yüksek fiyatlı uygulamalar
%2.8, düşük fiyatlılar %1.4 dönüşüyor. Yıllık $44.99 ise aylığın 12 katına göre **%53
indirim**; dönem bazlı kullanan öğrencide erken churn'ü kilitlediği için burada değerli.

Fiyat sonradan değiştirilebilir. **Product ID değiştirilemez** — geri dönülemez karar oydu
ve verildi.

### Kalan tek eksik: review ekran görüntüsü

İki ürün de şu an `MISSING_METADATA`. Sebep tek: her ürün için bir **paywall ekran
görüntüsü** gerekiyor. Bu olmadan ürünler Sandbox'ta bile görünmez ve paywall boş gelir.

Cihazda paywall'ı aç, ekran görüntüsü al, iki ürüne de yükle. Apple'ın istediği şey satın
almanın nerede gerçekleştiğini görmek — ekranın canlı ürün listesi göstermesi şart değil.

---

## 2. RevenueCat

Sıra: **Entitlement → Product import → Attach → Offering**

1. **Product catalog ▸ Entitlements ▸ + New entitlement**
   Identifier: `pro` — kod tam olarak bunu arıyor
   ([SubscriptionService.swift](../ios/Lockin/Services/SubscriptionService.swift))

2. **Products** — App Store Connect'ten iki ürünü içeri al (1'e 1 eşleşme):
   `com.r00tlab.lockin.pro.monthly` ve `com.r00tlab.lockin.pro.annual`

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
