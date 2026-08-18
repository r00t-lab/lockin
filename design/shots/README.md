# Ham ekran görüntüleri

Telefondan çektiğin kareler buraya **adıyla** gelir — numarayla değil:

```text
alarm.png        kilit ekranında çalan alarm
proof.png        kanıt ekranı, kamera canlıyken
list.png         dolu liste, biri kanıtlı, streak > 0
create.png       yeni taahhüt ekranı, üç kanıt tipi
report.png       bahane raporu
second-ring.png  ikinci alarm, butonu "Still not started"  (eksik)
paywall.png      abonelik ekranı — mağaza karesi değil, ürün inceleme görüntüsü
```

Numaralı isimler bir kez yanlış eşleşti ve aynı kare iki mağaza görselinde birden çıktı;
ad bunu imkânsız kılıyor.

`python tools/make_store_screenshots.py` bunları mağaza boyutuna (1290 × 2796) çevirir.

Bu klasördeki dosyalar uygulamanın **gerçek yakalamaları** olmak zorunda. Uydurulmuş
arayüz hem sahte durur hem App Review'ın kontrol ettiği şeydir.
