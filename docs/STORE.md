# App Store metinleri

İsim müsaitliğini App Store Connect'te kontrol et. "Lockin" alınmışsa yedekler:
**Onset**, **Startline**, **Nudged**, **No Excuse**.

## İsim ve alt başlık

```
Name:     Lockin
Subtitle: The alarm you can't ignore
```

Alt başlık 30 karakter sınırında ve ASO için ismin kadar önemli. "alarm" kelimesi
mutlaka içinde olsun — aradıkları kelime o.

## Anahtar kelimeler (100 karakter, virgülle, boşluksuz)

```
alarm,focus,study,procrastination,accountability,deadline,streak,homework,motivation,timer
```

İsimde ve alt başlıkta geçen kelimeleri buraya tekrar yazma — Apple zaten indeksliyor,
karakter israfı olur.

## Açıklama

```
You don't have a motivation problem. You have a starting problem.

Every focus app waits for you to open it. Lockin comes to find you.

Set a commitment — "start the essay at 7pm", "leave for class at 8:20", "gym at 5".
When the time comes, Lockin rings through Silent mode, through Focus, through Do Not
Disturb. It takes over your Lock Screen. And it does not go away because you tapped
dismiss.

PROVE IT OR IT COMES BACK
Photograph your desk. Scan the code you taped to it. Start a 25-minute timer.
Until you do one of those, the alarm returns every two minutes.

BUILT ON APPLE'S ALARM ENGINE
Lockin uses AlarmKit, the same system that powers the Clock app. That's why it rings
when everything else stays quiet.

IT KEEPS SCORE
Streaks for the days you started. And a weekly report of every excuse you made,
whether you want it or not.

FREE
Two commitments, free forever. Lockin Pro unlocks unlimited commitments and the
weekly report.
```

## Ekran görüntüleri — 5 tane, bu sırayla

Sıra önemli: ilk iki görsel indirmenin çoğunu belirliyor, çünkü çoğu kişi kaydırmıyor.

1. **Tam ekran alarm** + üstte yazı: *"Rings on Silent. Rings on Focus."*
2. **Dismiss → 2 dakika sonra tekrar** + yazı: *"Dismiss doesn't work"*
3. **Kanıt ekranı, masa fotoğrafı** + yazı: *"Prove you started"*
4. **Streak ekranı** + yazı: *"14 days. Zero excuses."*
5. **Bahane raporu** + yazı: *"It remembers everything"*

Her görselde telefon çerçevesi kullan, düz ekran görüntüsü koyma. Metin büyük olsun —
App Store'da küçük görünüyorlar.

## Değerlendirme notu (App Review'a)

```
Lockin schedules alarms with AlarmKit. To test:
1. Create a commitment set 2 minutes from now
2. Put the device in Silent mode and enable a Focus
3. The alarm will fire full screen
4. Tapping "Dismiss" without providing proof reschedules the alarm once, after 2 minutes
   (capped at 5 repeats)
5. Tapping "I'm starting" opens the proof screen; any photo of a desk clears the alarm

Demo account is not required. All data is stored on device.
```

## Reddedilme riskleri ve önlemi

| Risk | Önlem |
|---|---|
| "Kullanıcı alarmı kapatamıyor" | Stop butonu her zaman var, nag 5'te duruyor. Review notunda bunu açıkça yaz. |
| Sağlık iddiası incelemesi | ADHD / tedavi / terapi kelimelerini hiçbir yerde kullanma. "Focus tool" de. |
| Eksik restore | Paywall'da "Restore" butonu var — silme. |
| Eksik terms/privacy linki | Domain al, iki statik sayfa koy. Paywall'daki linkler çalışmak zorunda. |
| `NSAlarmKitUsageDescription` eksik | Uygulama izin isterken çöker. Info.plist'i iki kere kontrol et. |
