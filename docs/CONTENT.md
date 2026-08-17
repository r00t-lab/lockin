# TikTok içerik sistemi

Kod 3 hafta. Bu 12 ay. Uygulamanın kaderi bu dosyada belirleniyor, `AlarmService.swift`'te
değil.

## Kanıt

- **Catchr** (balık tanıma): 71 videoda 55M izlenme → 90 günde 65K indirme, $500K ARR.
  Reklam harcaması yok.
- **Wayk** (alarm): ilk günden hazır içerik ekibiyle çıktı → 30 günde 25M izlenme,
  100K indirme, App Store #15.
- Alarmy'nin tek bir alarm videosu 23M izlenme aldı. Algoritma bu kategoriyi seviyor.

Wayk'in kurucusu şunu söylüyor: *sosyal kanıtı olmayan uygulama sessizce ölür.* Lansman
günü elinde **en az 20 hazır video** olacak.

## Hesap yapısı

**3 hesap.** Hepsi aynı uygulamayı farklı açıdan anlatır. Biri gömülürse diğerleri
devam eder — tek hesaba bağlanmak tek nokta arıza demek.

| Hesap | Açı | Ses tonu |
|---|---|---|
| `@lockinapp` | Ürün hesabı | Kuru, komik, kendiyle dalga geçen |
| `@[kendi_adın]` | Kurucu hesabı, "building this in my dorm" | Samimi, süreç paylaşımı |
| `@[3. hesap]` | Sadece öğrenci hayatı / erteleme içeriği, uygulama arada geçer | Relatable, ürün odaklı değil |

## Kadans

**Hesap başına günde 3 video. Toplam günde 9.** Pazarlık konusu değil.

Bir video 100K'yı geçerse: 48 saat içinde aynı formatın 3 varyantını çek. Algoritma
neyi sevdiğini söylüyor, tartışma.

## Format kuralları

Catchr'ın 17M / 8.6M / 5M izlenen üç videosunun ortak yapısı:

1. **Snapchat tarzı yazı overlay** — parlak reklam grafiği değil. Ne kadar amatör
   görünürse o kadar iyi.
2. **Gerçek ortam** — yurt odası, kütüphane, dağınık masa. Stüdyo değil.
3. **11 saniye** — tüm akış sıkıştırılmış. İlk 1 saniyede kanca.
4. **Sonda kutlama anı** — konfeti, streak sayısı, ses efekti.
5. **Pop kültür çapası rotasyonu** — tek çapaya bağlanma. "Duolingo owl for X",
   "Pokémon Go for X", "Animal Crossing for X" — sırayla dene.

**Yasak:** özellik listesi anlatmak. "Bu uygulama şunu yapıyor" ölür. "Bunu kendime
kurdum ve pişman oldum" patlar.

## Hashtag / topluluk

`#studytok` `#studywithme` `#collegelife` `#procrastination` `#finalsweek` `#lockin`
`#dormlife` `#studymotivation`

**Doğal viral pencereler:** Aralık (finaller), Ocak (yeni yıl kararları), Mayıs
(finaller), Ağustos-Eylül (okul başlangıcı). İçerik takvimini bunlara göre kur.

---

# İlk 20 video — çekime hazır

Her biri: kanca (ilk 1 sn) → gösterim → sonuç. Hepsi İngilizce.

## Blok A — mekanik şoku (1-5)
Amaç: "alarm sessizde bile çalıyor" gerçeğini göstermek.

**1.** *Kanca:* "POV: you told an app you'd start your essay at 7pm"
Ekran kaydı: saat 18:59 → 19:00 alarm patlıyor, telefon sessiz modda (ses ikonunu göster)
*Son:* kamera senin yüzüne döner, hiçbir şey söylemeden dizüstü bilgisayarı açarsın

**2.** *Kanca:* "I put my phone on silent. Watch."
Telefonu sessize alıyorsun, Focus açıyorsun, masaya koyuyorsun → alarm çalıyor
*Metin:* "this shouldn't be legal"

**3.** *Kanca:* "The dismiss button is a trap"
Dismiss'e basıyorsun → 2 dakika sonra alarm geri geliyor → tekrar → tekrar
*Metin:* "it comes back 5 times"

**4.** *Kanca:* "It won't stop until I photograph my desk"
Yatakta yatıyorsun, alarm çalıyor, kalkıp masanın fotoğrafını çekiyorsun
*Son:* alarm susuyor, streak 1 oluyor

**5.** *Kanca:* "I taped a QR code to my desk so I can't lie"
Masadaki stickerı gösteriyorsun → alarm çalıyor → odanın öbür ucundan masaya yürüyorsun

## Blok B — pop kültür çapaları (6-10)
Amaç: yabancı bir mekaniği tanıdık bir şeye bağlamak. Catchr'ın kazandığı taktik.

**6.** "It's the Duolingo owl but for your degree"

**7.** "Pokémon Go made you walk. This makes you study."

**8.** "My roommate set this up on my phone as a prank and now I have a 12 day streak"

**9.** "This app is my mom but it lives in my pocket"

**10.** "Rate my excuses" — haftalık bahane raporunu ekranda göster, sesli oku, kendine gül

## Blok C — deney formatı (11-15)
Amaç: izleyicinin sonu merak etmesi. En yüksek izlenme süresi bu blokta.

**11.** "Day 1 of letting an app decide when I study" *(seri başlangıcı — 7 gün çek)*

**12.** "I gave this app control of my mornings for a week. Here's my GPA before and after."

**13.** "I set 6 commitments in one day. I regret everything."

**14.** "Trying to cheat my own app" — tavanın fotoğrafını çekiyorsun, uygulama reddediyor

**15.** "24 hours of not being able to procrastinate"

## Blok D — duygusal / relatable (16-20)
Amaç: ürünü değil, sorunu anlatmak. En çok kaydedilen blok.

**16.** *Kanca:* "I don't have a motivation problem. I have a starting problem."
Sessiz, samimi, kamera karşısı. Ürün son 3 saniyede giriyor.

**17.** "Every productivity app waits for you to open it. This one comes to find you."

**18.** "Finals week starts in 14 days and I've opened Notion 40 times and written nothing"

**19.** "Show me your study setup, I'll show you my alarm going off in it"
*(duet/stitch yemi — insanların cevap vermesi için)*

**20.** "Things I stopped doing when an app started yelling at me"
Liste formatı: doom scrolling in bed / 'I'll start at 8' / starting at 11pm

---

## Lansman haftası planı

| Gün | Ne |
|---|---|
| -7 | 20 videonun hepsini çek ve kurgula. Hepsi hazır olmadan yayına girme. |
| -3 | 3 hesabı aç, bio + link hazır, profil fotoğrafı koy. Boş hesap açıp beklet — yeni hesap + ilk gün 9 video şüpheli görünür. |
| 0 | App Store canlı. Blok A'nın 5 videosunu 3 hesaba dağıt. |
| 1-7 | Günde 9 video. Blok B, C, D sırayla. |
| 7 | En iyi performans gösteren 3 videonun formatını tespit et, 2. hafta boyunca sadece o formatın varyantlarını çek. |

## İlk 2 hafta kuralı

**Kod yazmadan önce bu testi yap.** Bir TikTok hesabı aç ve uygulama yokken 14 gün
günde 3 video at: kendi erteleme sorunun, çalışma rutinin, "keşke böyle bir şey olsa"
videoları.

**Eşik: tek bir video 50K izlenmeyi geçmeli.**

Geçmiyorsa sorun format ve o sorunu çözmeden yazacağın 3 haftalık kod boşa gider.
Geçiyorsa hangi formatın tuttuğunu zaten öğrenmiş olarak lansmana girersin.
