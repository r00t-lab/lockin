# Lockin — ürün tanımı

> Söz verdiğin işe başlamanı zorlayan alarm.

## Tek cümlelik konum

Alarmy uyanmanı sağlıyor. Lockin **başlamanı** sağlıyor.

## Neden şimdi

Haziran 2025'te Apple **AlarmKit**'i üçüncü partilere açtı. Bu API iOS 26'dan itibaren
herhangi bir uygulamanın sessiz modu ve Focus'u delen, kilit ekranını ve Dynamic Island'ı
ele geçiren alarm çalmasına izin veriyor. Daha önce bu sadece Apple'ın Saat uygulamasına
aitti.

Kategori kanıtlı:

- **Alarmy** — ~$500K/ay, ayda 500K indirme. Eski, reklam dolu, ASO ile büyümüş.
- **Wayk** — Şubat 2026'da 3 kişilik ekiple çıktı, 30 günde 25M TikTok izlenme,
  100K indirme, App Store #15.
- Things, Todoist, TickTick, Fantastical, Google Calendar — **hiçbiri AlarmKit'e geçmedi.**

Yani "uyanma" koltuğu doluyor, **"işe başlama" koltuğu boş.**

## Kime

Üniversite öğrencisi. Ödevi var, biliyor, başlamıyor. Alarmy kurmuyor çünkü sorunu
uyanmak değil. Notion kuruyor, açmıyor. Pomodoro uygulaması indiriyor, açmıyor —
çünkü onu açmaya karar vermek zaten yapamadığı şey.

Buradaki asıl içgörü: **odak uygulamaları kullanıcının onları açmasını bekliyor.**
Lockin kullanıcıyı buluyor.

## Temel döngü

1. Kullanıcı taahhüt kurar: *"19:00'da bitirme ödevinin girişini yaz"*
2. 19:00'da alarm çalar — sessizde, Focus'ta, ses kapalıyken
3. **"I'm starting"** → uygulama açılır → kanıt ekranı
4. **"Dismiss"** → alarm 2 dakika sonra geri gelir. 5 kez.
5. Kanıt verilir → zincir kırılır, streak +1
6. Pazar günü "bahane raporu" gelir

## Kanıt tipleri

| Tip | Nasıl | Neden |
|---|---|---|
| Fotoğraf | Masanın/açık ekranın fotoğrafı, cihazda Vision ile kontrol | Yataktan kalkmayı zorunlu kılar |
| Odak sayacı | 25 dakikalık sayaç başlatılır | En düşük sürtünme, giriş seviyesi |
| Masa kodu | Masaya yapıştırılan QR okutulur | En sert mod, fiziksel olarak masaya gitmen gerekir |

## MVP kapsamı — v1'de OLAN

- Taahhüt oluştur / sil / tekrarlı gün seçimi
- AlarmKit alarmı + Live Activity + Dynamic Island
- Üç kanıt tipi
- Nag zinciri (dismiss → 2 dk sonra tekrar, max 5)
- Streak ve kaçırma sayacı
- Paywall (2 ücretsiz taahhüt sınırı)

## v1'de OLMAYAN — bilerek

Bunları eklemek isteyeceksin. Ekleme. Her biri lansmanı bir hafta geciktirir ve
hiçbiri ilk 1.000 kullanıcıyı getirmez.

- ❌ Hesap sistemi / giriş — cihazda kalsın
- ❌ Arkadaş / sosyal / grup
- ❌ iPad
- ❌ Widget (Live Activity dışında)
- ❌ Tema, ses seçimi, ikon değiştirme
- ❌ **Syllabus AI importu** — bu v1.1, ayrı bir viral dalga olarak saklıyoruz
- ❌ Türkçe veya başka dil. Sadece İngilizce.

## Kapsam genişletmesi — 16 Ağustos 2026

Apple Watch ve Android v1'e alındı (önceki plan: Android 10. hafta, Watch hiç yok).

**Riski bilerek alıyoruz:** üç platform, tek kişi. Sıralamayı koru — iOS derlenip
gerçek cihazda sessiz modu delene kadar diğer ikisine dokunma. iOS çalışmıyorsa
diğer ikisi zaten anlamsız.

Watch'ın büyük kısmı bedava geliyor: AlarmKit alarmları zaten saate düşüyor. Ayrı
watchOS uygulamasının tek işi telefonu eline almadan kanıtlamak ve komplikasyon.

## v1.1 — syllabus importu

Ders programının / syllabus'un fotoğrafını veya PDF'ini at, LLM tüm teslim tarihlerini
okusun ve **geriye doğru** çalışma taahhütlerini otomatik kursun.

Bunu v1'e koymamanın sebebi teknik değil, pazarlama: tek başına viral olabilecek bir
özellik. Lansmandan 6-8 hafta sonra, ilk içerik dalgası yavaşladığında çıkar. Ekran
kaydı 8 saniye sürer, bu da onu doğrudan TikTok formatına sokar.

## Kırmızı çizgiler

- **Sağlık iddiası yok.** ADHD, tedavi, terapi kelimelerini App Store metninde ve
  uygulama içinde kullanma. "Focus tool" de. Sağlık iddiası hem reddedilme hem de
  Apple'ın sağlık kategorisi incelemesi demek.
- **Stop butonu kaldırılamaz.** Apple izin vermez. Sertlik nag zincirinden gelir.
- **Nag'in bir sonu olmalı.** 5'te durur. Durmazsa 1 yıldız yağar.
- **Kanıt kontrolü hoşgörülü olsun.** Yanlış reddedilen bir fotoğraf, kabul edilen
  sahte bir fotoğraftan çok daha kötü. Sahtekârlık yapan zaten parayı ödemiş.
