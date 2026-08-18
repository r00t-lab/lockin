# App Store Connect formları

Üç form kaldı ve üçü de kod değil, tıklama. Üçü de gönderimi tek başına bloke ediyor,
o yüzden cevapları burada hazır duruyor: panelde düşünmek yerine kopyala.

Cevapların çoğu "yok/hayır". Değerli olan azınlık — **karar olanlar** işaretlendi.
Onları burada bir kez verip her gönderimde aynı vermek, tutarsız cevap yüzünden gelen
ikinci tur incelemeyi engelliyor.

**Panelin ne dediğini tahmin etme, oku:**

```bash
python tools/asc_metadata.py --check
```

Yaş derecelendirmesi, içerik hakları, sürüm numarası, inceleme notu, bağlı build ve iki
aboneliğin durumu tek ekranda. Yazan hâli:

```bash
python tools/asc_metadata.py --apply --phone "+90..."
```

Bu üç formun ikisini script yazıyor. **App Privacy etiketi API'de yok** (bu sürümde
`appDataUsages` 404 dönüyor) — o form panelde elle dolduruluyor, cevapları bölüm 2'de.

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

## 3. Abonelik ürünleri — `MISSING_METADATA` neden kalkmıyor

**Paywall görüntüsü zaten yüklü.** API'den okundu: iki ürünün de inceleme görüntüsü
`COMPLETE` durumda, 1290 × 2796. Yani LAUNCH.md'nin ve bu dosyanın önceki hâlinin
söylediği sebep — "görüntü eksik" — **doğru değil**. Ürünlerde dolu olanlar:

| Alan | Durum |
|---|---|
| Ad, açıklama (en-US) | ✅ |
| Fiyat ($7.99 / $44.99), bölge, 3 günlük deneme | ✅ |
| İnceleme notu | ✅ |
| İnceleme görüntüsü | ✅ ikisinde de |
| Grup görünen adı "Nagg Pro" | ✅ |

Geriye tek makul açıklama kalıyor: **abonelikler ilk kez bir uygulama sürümüyle birlikte
gönderilene kadar bu durumda kalıyor.** Sürüme henüz build bağlanmadı, dolayısıyla
gönderilecek bir şey de yok. Sıralama şu: build → sürüme bağla → gönderime abonelikleri
de ekle. Ürünlerde tıklanacak bir eksik aramak, olmayan bir şeyi aramak.

Yine de gönderim ekranı bir alan isterse, görüntü `design/shots/paywall.png` olarak
duruyor: ASC ▸ Abonelikler ▸ ürün ▸ **Review Information ▸ Screenshot**.

## 4. Sürüm numarası — sessiz tuzak

App Store sürüm kaydı **`1.0`** olarak açılmış, ama TestFlight'taki build'lerin hepsi
**`1.0.0`** (`project.yml` ▸ `MARKETING_VERSION`). Build ancak numarası kendisiyle aynı
olan sürüme bağlanabiliyor, yani build seçici boş görünecekti ve panel sebebini
söylemeyecekti. `asc_metadata.py --apply` sürüm kaydını `1.0.0` yapıyor.

TestFlight'ta duran en yeni build **17 Ağustos'tan** (build 21) — yani bugünün
düzeltmeleri onda yok. Yeni build gerekiyor: `git tag v1.0.0 && git push origin v1.0.0`,
`release.yml` derleyip TestFlight'a yüklüyor.
