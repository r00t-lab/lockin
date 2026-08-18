# App Store Connect formları

Üç form kaldı ve üçü de kod değil, tıklama. Üçü de gönderimi tek başına bloke ediyor,
o yüzden cevapları burada hazır duruyor: panelde düşünmek yerine kopyala.

Cevapların çoğu "yok/hayır". Değerli olan azınlık — **karar olanlar** işaretlendi.
Onları burada bir kez verip her gönderimde aynı vermek, tutarsız cevap yüzünden gelen
ikinci tur incelemeyi engelliyor.

---

## 1. Yaş derecelendirmesi → **4+**

App Store Connect ▸ uygulama ▸ **Age Rating ▸ Edit**.

| Soru | Cevap |
|---|---|
| Şiddet (çizgi film / gerçekçi / uzun süreli) | Yok |
| Cinsel içerik, çıplaklık, müstehcen temalar | Yok |
| Küfür, kaba mizah | Yok |
| Alkol, tütün, uyuşturucu kullanımı veya göndermesi | Yok |
| Kumar (gerçek veya simüle), yarışma | Yok |
| Reklam | Yok |
| Kullanıcı üretimi içerik, mesajlaşma | Yok |
| Konum paylaşımı | Yok |
| Kontrolsüz web erişimi | **Hayır** |
| Uygulama içi satın alma | **Evet** |

Üçü fikir değil karar, ve mağaza metinlerini de bağlıyorlar:

- **Korku / gerilim teması: Yok.** Ürünün mekaniği "alarm geri geliyor"; bu bir ısrar
  mekaniği, korku teması değil. Metinlerin hiçbirinde tehdit dili kullanılmıyor —
  kullanılırsa bu cevap yalan olur ve derecelendirme 9+'a çıkar.
- **Tıbbi / tedavi bilgisi: Hayır.** Bu cevap tüm listeyi bağlıyor: ADHD, terapi, tedavi,
  teşhis kelimeleri hiçbir metinde geçemez ([STORE.md](STORE.md) ret riskleri tablosu).
  "Focus tool" güvenli taraf.
- **Kontrolsüz web erişimi: Hayır.** Uygulamadaki tek dış bağlantı paywall'daki iki sabit
  `nagg.pro` sayfası ([PaywallView.swift](../ios/Lockin/Views/PaywallView.swift)). Gömülü
  tarayıcı, arama, kullanıcının girdiği URL yok. Yeni bir bağlantı eklenirse bu cevap
  tekrar bakılmalı.

Beklenen sonuç **4+**. Farklı bir sonuç çıkıyorsa bir soru yanlış cevaplanmıştır — kabul
etme, geri dön.

## 2. App Privacy — gizlilik etiketi

App Store Connect ▸ **App Privacy**. Gönderimden önce **zorunlu**, ve hiçbir yerde
yazılmamıştı.

**Cihazdan çıkan tek şey RevenueCat trafiği.** Uygulamada başka ağ çağrısı yok: analytics
SDK'sı, crash reporter, kendi sunucumuz yok.
[SubscriptionService.swift](../ios/Lockin/Services/SubscriptionService.swift) dışında
`Purchases.` çağrısı geçen dosya yok.

| Veri | Cevap |
|---|---|
| Satın alma geçmişi | **Toplanıyor** — Uygulama işlevselliği. Kimliğe bağlı değil, izleme yok. |
| Tanımlayıcılar | **Toplanıyor** — RevenueCat'in ürettiği anonim app user id. Uygulama işlevselliği, izleme yok. |
| Kamera / fotoğraflar | **Toplanmıyor** |
| Taahhüt metinleri, saatler, streak | **Toplanmıyor** |
| Konum, kişiler, kullanım verisi, teşhis | **Toplanmıyor** |
| Tracking (ATT) | **Hayır** |

**Kamera cevabı bir iddia değil, doğrulanabilir bir olgu:** kanıt fotoğrafı diske hiç
yazılmıyor. Kodda `jpegData`, `pngData`, fotoğraf albümüne yazma çağrısı yok — kare
bellekte boş mu diye kontrol ediliyor ve bırakılıyor. Bu, "fotoğrafını istiyoruz" diyen
bir uygulama için en değerli cümle; [PRODUCT.md](PRODUCT.md) tarafında da satılabilir.

Anonim id'yi **kendimiz kimliğe bağlamıyoruz**: kodda `Purchases.shared.logIn` çağrısı
yok, yani hesap, e-posta, cihaz kimliği eşleşmesi yapılmıyor. Sonradan bir hesap sistemi
eklenirse bu satır değişir.

**Tracking "Hayır" olduğu için ATT izin penceresi de yok.** IDFA okunmuyor, reklam ağı
yok. Bu cevabı "Evet" yapan tek şey ileride bir attribution SDK'sı eklemek olur.

## 3. Abonelik ürünlerinin inceleme görüntüsü

İki ürün de `MISSING_METADATA` durumunda ve sebebi tahmin değil, biliniyor:
**her ürün için bir paywall ekran görüntüsü** gerekiyor ([LAUNCH.md](LAUNCH.md) bölüm 1).
Bu olmadan ürünler Sandbox'ta bile görünmez.

Görüntü cihaz turunda çıkıyor ([PRESUBMIT.md](PRESUBMIT.md) E1). **Ekranın canlı ürün
listesi göstermesi şart değil** — Apple satın almanın nerede gerçekleştiğini görmek
istiyor. Yani ürünler `MISSING_METADATA` iken alınan boş paywall görüntüsü de kabul
ediliyor, ve döngüyü kıran şey bu.

Aynı görüntü iki ürüne de yüklenir: ASC ▸ Abonelikler ▸ ürün ▸ **App Store Promotion /
Review Information ▸ Screenshot**.
