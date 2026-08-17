# Para modeli

## Fiyat

```
Free   →  2 aktif taahhüt
Pro    →  $7.99/ay   veya   $44.99/yıl   (3 gün ücretsiz deneme)
```

### Neden bu fiyat

RevenueCat'in 2026 raporu 115.000+ uygulama, $16B+ gelir ve 1 milyar+ işlemi kapsıyor.
İki bulgu fiyatı belirliyor:

1. **Yüksek fiyatlı uygulamalar indirmeleri ~2 kat daha iyi dönüştürüyor** — medyan
   %2.8'e karşı %1.4. Ucuz fiyatlamak iki kere ceza yiyor: hem birim başına az
   kazanıyorsun hem de daha az insan alıyor.
2. **Productivity kategorisinde gelirin %77'si aylık plandan** geliyor (Health &
   Fitness'ta %68 yıllık). Yani paywall'da **aylığı öne koy**, yıllığı "tasarruf"
   olarak yanına ekle — tersini yapma.

### Neden 2 ücretsiz taahhüt

Bir tane mekaniği hissettirmez. Üç tane yaşamaya yeter. İki tane, kullanıcının alarmın
gerçekten sessizi deldiğini görmesine yeter ve üçüncü işi eklemek istediğinde duvara
çarpar. Bu sayıyı sonradan yumuşatma.

## Hedef pazar

**Sadece İngilizce. ABD, İngiltere, Kanada, Avustralya.**

RevenueCat verisi: Kuzey Amerika D35 indirme→ödeme oranı **%2.6**, Hindistan/Güneydoğu
Asya **%1.4**. Aynı emek, iki kat fark — ve mutlak ARPU farkı çok daha büyük.

Türkçe lokalizasyon yapma. TikTok'ta Türkçe içerik üretme. Türkiye'den geliyor olman
hiçbir dezavantaj değil çünkü videolarda yüzün gerekmiyor: Catchr'ın 17M izlenen videosu
sadece ekran kaydı + üstüne yazıydı.

## Gelir matematiği

Apple Small Business Program'a başvur — yıllık $1M altındaysan komisyon %30 değil **%15**.
Başvurmayı unutan geliştiriciler gelirlerinin altıda birini bağışlıyor.

Aylık $7.99 → Apple sonrası **~$6.79 net**.

| Senaryo | 6. ay toplam indirme | Dönüşüm | Aktif abone | Net aylık |
|---|---|---|---|---|
| Kötü | 4.000 | %1.5 | ~60 | ~$400 |
| Orta | 15.000 | %2.5 | ~375 | ~$2.500 |
| İyi | 60.000 | %3.0 | ~1.800 | ~$12.000 |

Referans: **$2.500/ay'a ulaşan uygulamaların %60'ı $5.000'a da ulaşıyor.** İlk eşik asıl
mesele. Solo geliştirici için gerçekçi üst çeyrek sonuç 12-18 ayda $3.000-15.000/ay.

## Maliyetler (ilk yıl)

| Kalem | Tutar |
|---|---|
| Apple Developer Program | $99/yıl |
| RevenueCat | $0 — aylık $2.500 gelire kadar ücretsiz |
| Backend | $0 — v1'de backend yok, her şey cihazda |
| Domain (terms/privacy sayfaları için zorunlu) | ~$12/yıl |
| LLM API (v1.1 syllabus importu) | ~$0.002/istek, kullanıcı başına ayda birkaç kez |
| **Toplam** | **~$150** |

Bu proje para harcayarak değil, video çekerek büyür.

## Ölçeceğin 4 sayı

Haftada bir, pazar akşamı. Fazlasını ölçme.

1. **İndirme** — TikTok çalışıyor mu?
2. **İndirme → deneme başlatma** — onboarding + paywall çalışıyor mu?
3. **Deneme → ödeme** — ürün vaadini tutuyor mu?
4. **D30 abone kalma** — nag zinciri insanları kaçırıyor mu, tutuyor mu?

3. adım düşükse ürün sorunu. 2. adım düşükse paywall sorunu. 1. adım düşükse içerik
sorunu — ve ilk 3 ayda sorun neredeyse her zaman 1. adımdır.

## Vergi ve ödeme (Türkiye)

- Apple bireysel geliştirici hesabına, Türk banka hesabına ödeme yapıyor.
- App Store Connect'te **W-8BEN** formunu doldurman gerekiyor (ABD stopajı için).
  Türkiye-ABD çifte vergilendirme anlaşması var, doğru doldurursan stopaj düşüyor.
- Şirket kurmadan başlayabilirsin. Gelir düzenli hale gelince mali müşavire git —
  önce değil.
