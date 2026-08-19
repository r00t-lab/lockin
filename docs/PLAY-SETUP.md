# Google Play — kurulum

App Store tarafındaki [LAUNCH.md](LAUNCH.md) + [ASC-FORMS.md](ASC-FORMS.md) ikilisinin
Android karşılığı. Sıra önemli: her adım bir sonrakini açıyor, atlarsan panel sebebini
söylemeden takılıyor.

**Kimin yapacağı işaretli.** 🧑 senin (giriş, para, imza, yasal onay), 🤖 benim
(otomatikleştirilebilen her şey).

---

## 0. Önce şu soruyu cevapla — takvimi bu belirliyor 🧑

Play Console ▸ **Settings ▸ Developer account ▸ Account details**. İki şeye bak:

- **Account type:** Personal mı Organization mı
- **Account created:** tarih

**Personal ve 13 Kasım 2023'ten sonraysa:** production erişimi için önce **12 testçiyle
14 gün kesintisiz closed testing** gerekiyor. Saat, testçiler opt-in olduğunda başlıyor —
yani Android'in ilk AAB'si iOS'tan önce yüklenmeli. Organization ya da daha eskiyse
muafsın, iki mağaza aynı hafta çıkar.

## 1. Uygulama kaydı 🧑

Play Console ▸ **Create app**

| Alan | Değer |
|---|---|
| App name | **Nagg Alarm** (iOS ile aynı) |
| Default language | English (United States) |
| App or game | App |
| Free or paid | **Free** |

⚠️ **Free/Paid geri alınamaz.** Uygulama ücretsiz, para abonelikten geliyor — Free doğru
cevap. Paid seçilirse abonelik modeli çöker ve düzeltmenin yolu yeni bir uygulama kaydı
açmaktır.

| Package name | **`com.r00tlab.nagg`** |

⚠️ **Paket adı da geri alınamaz** ve koddaki `applicationId` ile birebir eşleşmeli.
`app.lockin` başkası tarafından alınmış çıktı; bu yüzden iOS bundle id'sinin sahiplik
desenine (`com.r00tlab.lockin`) uyduruldu. Koddaki `namespace` hâlâ `app.lockin` —
o kodun paketi, dışarıdan görünmüyor ve değiştirmek her kaynak dosyayı taşımak olurdu.

## 2. Upload key 🧑

Google, gerçek imza anahtarını Play App Signing ile kendisi tutuyor. Bizim ürettiğimiz
anahtar sadece "bu paket bizden geldi" diyen **upload key**.

```bash
keytool -genkeypair -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Sorduğu parolayı bir yere yaz — **kaybedersen yeni upload key için Google'a başvurmak
gerekir**. Sonra base64'e çevir:

```bash
base64 -w0 upload.jks > upload.jks.b64
```

`upload.jks` ve `.b64` dosyasını **repoya koyma** (`.gitignore` zaten `*.jks` diyor).

## 3. GitHub Secrets 🧑

Repo ▸ Settings ▸ Secrets and variables ▸ Actions ▸ **New repository secret**. Beş tane:

| Secret | İçerik |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `upload.jks.b64` dosyasının içeriği |
| `ANDROID_KEYSTORE_PASSWORD` | keystore parolası |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key parolası (aynısını girdiysen keystore parolası) |
| `PLAY_SERVICE_ACCOUNT_JSON` | 4. adımdaki JSON'ın tamamı |

Bunları bana yapıştırma. Panele doğrudan gir; ihtiyacım olan tek şey girildiklerini
bilmek.

## 4. Service account — CI'nın Play'e yükleyebilmesi için 🧑

Play Console ▸ **Setup ▸ API access**

1. Bir Google Cloud projesi bağla (yoksa aynı ekrandan oluşturulur)
2. **Create new service account** → Cloud Console açılır → service account oluştur
3. Cloud Console'da o hesap için **JSON key** üret, indir
4. Play Console'a dön ▸ service account'a **Grant access**, yetkiler:
   - View app information
   - Manage testing track releases
   - Manage production releases *(14 gün geçtikten sonra gerekecek)*
5. JSON'ın tamamını `PLAY_SERVICE_ACCOUNT_JSON` secret'ına yapıştır

## 5. İlk AAB 🤖

Beş secret girildikten sonra tek komut:

```bash
git tag v1.0.0-android && git push origin v1.0.0-android
```

CI imzalı AAB üretip **internal** track'e yüklüyor. İmzasız bundle üretilirse job kırmızı
oluyor — imzasız yükleyip saatler sonra Play'den ret almaktansa orada durması iyi.

⚠️ **`v*` etiketi iki workflow'u birden tetikliyor:** iOS TestFlight ve Android Play. Aynı
gün çıkma kararının doğal sonucu ve bilinçli. Sadece Android istiyorsan `-android` ekli
etiket de aynı desene giriyor, yani iOS de derlenir — zararsız, sadece fazladan bir
TestFlight build'i.

## 6. Play Console formları — cevaplar hazır 🧑 tıklar, 🤖 yazdı

**App content** bölümünde sırayla:

| Form | Cevap |
|---|---|
| Privacy policy | `https://nagg.pro/privacy` |
| Ads | **Reklam içermiyor** |
| App access | Tüm işlevler kısıtsız erişilebilir — giriş/hesap yok |
| Content rating | Anket: şiddet/cinsellik/küfür/kumar/uyuşturucu **yok** → beklenen sonuç **Everyone / 3+** |
| Target audience | 13+ — çocuklara yönelik **değil** |
| News app | Hayır |
| COVID-19 / government | Hayır |
| Data safety | ↓ aşağıda |
| Financial features | Hayır |
| Health | **Hayır** — ADHD/terapi/tedavi kelimeleri hiçbir metinde geçmiyor, [ASC-FORMS.md](ASC-FORMS.md) ile aynı karar |

### Data safety — iOS gizlilik etiketiyle birebir aynı cevaplar

| Soru | Cevap |
|---|---|
| Veri topluyor musunuz? | **Evet** |
| Hangi veri | **Purchase history** ve **User IDs / Device or other IDs** |
| Amaç | Yalnız **App functionality** |
| Kullanıcı kimliğine bağlı mı | **Hayır** |
| Paylaşılıyor mu (üçüncü tarafa aktarım) | **Hayır** — RevenueCat işleyici, ilan edilen "collected" tarafında |
| Şifreli aktarım | **Evet** |
| Silme talebi | **Evet** — uygulamayı silmek her şeyi siliyor |
| Fotoğraflar | **Toplanmıyor** — kanıt fotoğrafı diske hiç yazılmıyor |
| Konum, kişiler, mesajlar, kullanım verisi, teşhis | Toplanmıyor |

## 7. Abonelik ürünleri 🧑 açar, 🤖 doğrular

Monetize ▸ Products ▸ **Subscriptions**. Ödeme profili (banka + vergi) kurulu olmadan bu
ekran açılmıyor — kurulu değilse önce **Setup ▸ Payments profile**.

| | Aylık | Yıllık |
|---|---|---|
| Product ID | `nagg_pro_monthly` | `nagg_pro_annual` |
| Ad | Nagg Pro Monthly | Nagg Pro Annual |
| Base plan | 1 ay, otomatik yenilemeli | 1 yıl, otomatik yenilemeli |
| Fiyat (ABD) | **$7.99** | **$44.99** |
| Offer | 3 gün ücretsiz deneme | 3 gün ücretsiz deneme |

Product ID'ler iOS'takinden farklı olabilir — RevenueCat ikisini de aynı `pro`
entitlement'ına bağlıyor, kod sadece entitlement'a bakıyor.

## 8. RevenueCat 🧑 bağlar, 🤖 koda gömer

1. RevenueCat ▸ **+ New app** → Google Play, paket adı `com.r00tlab.nagg`
2. Play service account JSON'ını RevenueCat'e de yükle (sunucu bildirimleri için)
3. İki ürünü içeri al, **aynı `pro` entitlement'ına** bağla
4. Offering `default` içine `$rc_monthly` ve `$rc_annual` paketleri — **aylık üstte**
5. Public SDK key'i (`goog_…`) bana ver, `LockinApplication.kt` içindeki
   `goog_REPLACE_ME` yerine ben koyayım

Bu anahtar girilene kadar paywall boş görünüyor ve bunu ekranda söylüyor.

## 9. Mağaza sayfası 🤖 üretir, 🧑 yükler

| Varlık | Ölçü | Durum |
|---|---|---|
| App icon | 512 × 512 | 🤖 |
| Feature graphic | **1024 × 500** | 🤖 — Play'e özel, iOS'ta karşılığı yok |
| Telefon ekran görüntüleri | en az 2 | 🤖 App Store'daki kareler, Play ölçüsünde |
| 7" ve 10" tablet kareleri | 9:16 | 🤖 aynı kareler 1080 × 1920 kesimle |
| Short description | 80 karakter | `It comes back until you start.` |
| Full description | 4000 karakter | [STORE.md](STORE.md)'deki açıklama |

## 10. Closed testing 🧑 + ekip

Testing ▸ **Closed testing** ▸ track oluştur ▸ e-posta listesi ▸ opt-in linkini gönder.

**14 günlük saat, 12 testçi opt-in olduğunda başlıyor.** Sayı 12'nin altına düşmemeli.
Bu süre boyunca yeni build atmak serbest, saat sıfırlanmıyor.

14 gün dolunca **Apply for production access**.

---

## Sırayla, tek bakışta

1. 🧑 Hesap tipini ve tarihini oku *(0)*
2. 🧑 Uygulamayı oluştur *(1)*
3. 🧑 Upload key üret *(2)*
4. 🧑 Beş secret gir *(3, 4)*
5. 🤖 İlk AAB internal track'e *(5)*
6. 🧑 App content formları — cevaplar yukarıda *(6)*
7. 🧑 Ödeme profili + iki abonelik *(7)*
8. 🧑 RevenueCat → 🤖 `goog_` anahtarı koda *(8)*
9. 🤖 Mağaza görselleri → 🧑 yükler *(9)*
10. 🧑 Closed testing + 12 testçi → 14 gün → production başvurusu *(10)*

---

## Durum — 19 Ağustos 2026

**Internal track canlı.** Paket `com.r00tlab.nagg`, versionCode **30**, imzalı AAB API'den
yüklendi ve yayınlandı.

Yol boyunca çıkan üç şey, üçü de bir daha aranmasın diye:

- **Upload key'in Android geliştirici doğrulamasına kaydedilmesi gerekiyor.** Yeni bir
  imza anahtarıyla yapılan ilk yükleme `commit` aşamasında *"all keys should be registered"*
  diye reddediliyor. Anahtarın SHA-256 parmak izi **Android geliştirici doğrulaması ▸
  paket ▸ Anahtar ekle** ile eklenince geçiyor. Parmak izi:
  `keytool -list -v -keystore <jks> -alias upload`
- **Hizmet hesabı GitHub secret'ı gerektirmiyor.** CI imzalı AAB'yi herkese açık release
  olarak yayınlıyor, yükleme Play API'sinden yapılıyor. Yetki: *test kanallarına yayınlama*
  + *test kanallarını yönetme*.
- **Mağaza metinleri API'den yazılamıyor** — *mağazadaki varlığı yönetme* yetkisi hesap
  düzeyinden geliyor ve hizmet hesabında etkili değil. Metinler konsoldan girilecek.

**Closed testing henüz açılamıyor:** taslak uygulamada kapalı test sürümü ancak `draft`
statüsüyle oluşturulabiliyor; gerçek yayın için önce **App content** formlarının bitmesi
gerekiyor. Yani 14 günlük saat, formlar tamamlanmadan başlamıyor.

### Mağaza görselleri nereden geliyor

`tools/make_play_assets.py` üçünü de üretiyor ve hepsi türetilmiş — repoda tutulmuyor,
her seferinde yeniden yapılabiliyor:

- **İkon** uygulamanın kendi 1024'lük ikonundan 512'ye
- **Feature graphic** (1024 × 500) Play'e özel; App Store'da karşılığı yok, o yüzden
  wordmark ve tek satırla çizildi — arama sonucunda pul boyutunda görünüyor, oraya
  küçültülmüş bir ekran görüntüsü koymak leke demek
- **Ekran görüntüleri** doğrudan **App Store'da yayında olan karelerden** indiriliyor
  (ASC API, `imageAsset.templateUrl`). İki mağazada farklı görsel olması, aynı ürünün iki
  ayrı sürümü gibi görünmesi demekti.

Tek dönüşüm boyut: Apple kareleri 1260 × 2736, yani 2.17:1. **Play uzun kenarın kısa
kenarın iki katını aşmasına izin vermiyor**, o yüzden genişliğe ölçeklenip alttan
kırpılıyor (1080 × 2160). Tabletler 9:16 istediği için onlara 1080 × 1920 kesim gidiyor.

### 19 Ağustos, ikinci tur — neyin otomatikleşebildiği

**Mağaza girişi API'den yazılabiliyor artık.** Hizmet hesabına hesap düzeyinde
*Mağazadaki varlığı yönetme* verildi; `edits.listings` yazıp commit etmek çalışıyor.
Uygulama düzeyindeki aynı isimli kutu gri görünüyor ve **yetmiyor** — hesap düzeyinde
işaretlenmesi gerekiyor, bu ikisi ayrı şey.

**Abonelik ürünleri hâlâ oluşturulamıyor ve sebebi yetki değil.** Aynı hesapla mağaza
girişi commit'i geçerken `applications/{package}/subscriptions` POST'u
`PERMISSION_DENIED` dönüyor. Play, **ödeme profili (satıcı hesabı) kurulmadan** para
uçlarını hiç açmıyor; hata mesajı bunu söylemiyor, "izin yok" diyor. Yani:

    ödeme profili → abonelik ürünleri → RevenueCat → goog_ anahtarı → yeni build

Bu zincirin ilk halkası bankaya ve vergi bilgisine bağlı; orası bende olamaz.

**Gövde/parametre tuzağı:** `regionsVersion` istek gövdesinde değil, **sorgu
parametresi** (`?regionsVersion.version=2022/02`). Gövdeye koyunca "Cannot find field",
hiç koymayınca "Regions Version must be specified" diyor.
