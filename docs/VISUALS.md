# Görsel üretim promptları

Bu dosya bir üretim modeline (ChatGPT / Gemini / Midjourney) verilecek promptları tutar.
Amaç tek: üretilen her görsel, uygulamanın `NaggStyle.swift`'teki kimliğiyle aynı odadan
çıkmış görünsün. Kimliği prompt'ta tarif etmezsen model varsayılanına döner — mor gradient,
parlak 3D, yuvarlak köşeli cam. O uygulama başka bir uygulama.

## Modele ne yaptırma

- **Ekran görüntüsü yaptırma.** Uygulamanın arayüzünü uydurtma. Hem sahte durur hem de
  App Review "ekran görüntüsü uygulamayı yansıtmıyor" diye reddedebilir. Telefon ekranının
  içi **gerçek yakalama** olmak zorunda.
- **Okunaklı yazı yaptırma.** Görsel modelleri harfleri bozar. Store görsellerindeki büyük
  başlıkları sen koy (Figma, Canva, hatta Keynote). Modelden sadece altındaki zemini al.
- **Telefon çerçevesi yaptırma.** Apple'ın kendi cihaz çerçevelerini indir
  (developer.apple.com → Design → Resources). Üretilmiş bir "iPhone benzeri" cihaz,
  bilenlerin gözüne batar.

## Her prompt'un başına yapıştırılacak stil bloğu

```
Art direction: warm off-white paper background #EFEEE9, not white. Ink black #17171A.
One accent only: a burnt vermilion red #C7351A. Optional deep red #4A1409 for shadows
inside red areas. Flat, matte, printed-poster feel — Swiss editorial design, early
Muji catalogue, risograph. Absolutely no gradients, no glossy 3D, no glassmorphism,
no drop shadows, no lens flare, no neon, no purple, no blue. Generous empty space.
Grain is welcome; polish is not. Nothing should look like a stock app-marketing render.
```

---

## A. Uygulama ikonu

Şu an `tools/make_icon.py` wordmark'ın "gg" yarısını basıyor ve iş görüyor. Alternatif
arıyorsan üç yön; hepsi 1:1, metinsiz denemesi daha güvenli.

**A1 — nesne olarak alarm**
```
[stil bloğu]
A single flat illustration of an old mechanical twin-bell alarm clock, drawn as a bold
solid silhouette in vermilion red on the paper background. Extremely simplified: two
bells, one body, no numerals, no hands, no face detail. Centred, filling about 60% of a
square canvas. Icon design, not a scene. No text.
```

**A2 — geri gelen şey**
```
[stil bloğu]
A square icon showing a single thick vermilion arrow curving back on itself into a full
loop, like a return arrow that never ends. Solid flat shape, rounded terminals, no
outline, no arrowhead detail beyond one simple triangle. Centred on paper background.
Geometric and calm, not dynamic. No text.
```

**A3 — uyandıran şey (en soyut)**
```
[stil bloğu]
A square icon: three concentric vermilion arcs radiating from a small solid dot at the
bottom centre, like sound leaving a source. Flat, even stroke weight, wide gaps between
arcs. Nothing else on the canvas. No text.
```

Üçünü de üret, ana ekranda küçültüp bak. **60 piksel testini geçmeyen ikon ikon değildir** —
telefonun ana ekranındaki gerçek boyut bu.

---

## B. Store ekran görüntüsü zeminleri

`docs/STORE.md`'de beş görsel var, sırası önemli. Her biri için: modelden **zemini** al,
üstüne gerçek cihaz yakalamasını ve başlığı sen bindir. Boyut 1290×2796 (6.9"), zemini
en az 2048×2048 üret sonra kırp.

**B1 — "Rings on Silent. Rings on Focus."**
```
[stil bloğu]
A vertical poster background. The lower two thirds is empty paper. The upper third is a
solid vermilion red field with a soft torn-paper edge where it meets the paper, as if a
red sheet was ripped and laid on top. Nothing else. Leave the entire lower area empty
for a phone to be placed on later. No text, no objects, no devices.
```

**B2 — "Dismiss doesn't work"**
```
[stil bloğu]
A vertical poster background: five identical vermilion rectangles arranged in a staggered
descending diagonal down the paper, each slightly lower and slightly more opaque than the
one before, like the same thing arriving over and over. Flat shapes, no shadow, no
perspective. Large empty margins. No text, no devices.
```

**B3 — "Prove you started"**
```
[stil bloğu]
A vertical poster background: a top-down flat-lay of a plain student desk on paper-toned
ground — closed laptop, one notebook, one pen, a mug. Rendered as a flat two-colour
illustration in ink black line on paper, with a single vermilion element (the mug).
Drawn, not photographic. Lower half left empty. No text.
```

**B4 — "14 days. Zero excuses."**
```
[stil bloğu]
A vertical poster background: a grid of 14 filled vermilion squares and 2 empty
paper-coloured squares with thin ink outlines, arranged as a calendar block in the upper
area. Perfectly aligned, generous gaps, flat colour. The lower half is empty paper.
No numbers, no text.
```

**B5 — "It remembers everything"**
```
[stil bloğu]
A vertical poster background: a long narrow paper receipt curling down the centre of the
frame, printed in faint ink, with several lines struck through in vermilion. The text on
the receipt must be illegible abstract line texture, not real letters. Flat illustration,
soft grain. Empty margins both sides. No readable text.
```

---

## C. TikTok kapak / atmosfer görselleri

`docs/CONTENT.md`'deki 20 video için. Video ham çekim olacak — bunlar sadece kapak karesi
ve arada kullanılacak duraklama planları.

**C1 — yurt odası, sabah**
```
[stil bloğu]
A flat two-colour illustration of a dim dorm room at 6:50am: unmade bed, one desk, a
laptop closed, curtains shut. Ink line drawing on paper background. A single vermilion
glow coming from a phone face-down on the desk — the only colour in the frame.
Vertical 9:16. No text, no people's faces.
```

**C2 — erteleme**
```
[stil bloğu]
A flat illustration, vertical 9:16: a single hand reaching out from under a duvet toward
a phone, drawn as ink line work on paper. The phone screen is solid vermilion. Everything
else is line only. Quiet, slightly sad, not comedic. No text, no face.
```

**C3 — masaya oturmak**
```
[stil bloğu]
A flat illustration, vertical 9:16, ink line on paper: an empty chair pushed back from a
desk with an open laptop, seen from behind. Warm and still. One vermilion object on the
desk. No people, no text.
```

---

## D. Masa kodu sticker sayfası

Masa kodu kanıt tipi için kullanıcının yazdırıp masasına yapıştıracağı sayfa. QR'ın
**kendisini modele ürettirme** — QR uygulamadan gelir, uydurulmuş QR okunmaz. Modelden
sadece etrafındaki çerçeveyi al.

```
[stil bloğu]
A printable sticker sheet design, square, portrait A4 proportions. A large empty white
square placeholder centred in the upper area with a thin ink border — leave it completely
blank, a QR code will be pasted there later. Below it, a thin vermilion horizontal rule.
Around the edges, thin ink cut-marks at the corners. Flat, printed-matter look,
no gradients. No text anywhere.
```

---

## Kalite kontrolü

Üretilen her görseli şuradan geçir:

1. **Mor veya mavi var mı?** Varsa at. Bu palette o renkler yok.
2. **Gradient veya parlaklık var mı?** Varsa at. Kimlik düz ve mat.
3. **Model yazı yazmış mı?** Yazmışsa at — okunaklı bile olsa yazıyı sen koyacaksın.
4. **Uygulama arayüzü uydurmuş mu?** Uydurmuşsa at, App Review riski.
5. **Ana ekranda 60 piksele küçülttüğünde ne oluyor?** (Sadece ikon için.)

İlk üçü ilk denemede sık çıkar. Prompt'u yumuşatma, **stil bloğunu tekrar yapıştır** —
model konuşma uzadıkça kendi varsayılanlarına kayıyor.
