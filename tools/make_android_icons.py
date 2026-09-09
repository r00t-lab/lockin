"""Generate the Android launcher icons from the icon iOS already ships.

Android had a hand-drawn vector launcher icon: a different picture from the one on the
App Store. One product with two icons is two products as far as anyone scrolling a home
screen is concerned, so this renders the same 1024 PNG that tools/make_icon.py produces
for iOS into the mipmap densities Android wants.

Two layers, because Android needs both:

* Legacy `ic_launcher.png` — the whole square, for devices below API 26.
* Adaptive `ic_launcher_foreground.png` — the artwork inset to 66/108 of the canvas,
  which is the only part guaranteed to survive an OEM mask, with the paper ground
  knocked out so the `ic_launcher_background` colour supplies it instead. Without the
  inset a circular mask crops the bells off the top of the clock.

Run: python tools/make_android_icons.py
"""
import os

from PIL import Image

SOURCE = "ios/Lockin/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
RES = "android/app/src/main/res"

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

PAPER = (239, 238, 233)   # --ground, the same value colors.xml uses for the background
TOLERANCE = 14            # the source is a JPEG-ish render; the ground is not exactly flat
SAFE = 66 / 108           # adaptive-icon safe zone


def main():
    art = Image.open(SOURCE).convert("RGB")

    for density, px in LEGACY.items():
        out = os.path.join(RES, "mipmap-" + density)
        os.makedirs(out, exist_ok=True)
        small = art.resize((px, px), Image.LANCZOS)
        small.save(os.path.join(out, "ic_launcher.png"), "PNG")
        small.save(os.path.join(out, "ic_launcher_round.png"), "PNG")

    for density, px in FOREGROUND.items():
        out = os.path.join(RES, "mipmap-" + density)
        os.makedirs(out, exist_ok=True)
        inner = int(px * SAFE)
        layer = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        clock = art.resize((inner, inner), Image.LANCZOS).convert("RGBA")
        pixels = clock.load()
        for y in range(inner):
            for x in range(inner):
                r, g, b, _ = pixels[x, y]
                if (abs(r - PAPER[0]) < TOLERANCE and abs(g - PAPER[1]) < TOLERANCE
                        and abs(b - PAPER[2]) < TOLERANCE):
                    pixels[x, y] = (r, g, b, 0)
        offset = (px - inner) // 2
        layer.paste(clock, (offset, offset), clock)
        layer.save(os.path.join(out, "ic_launcher_foreground.png"), "PNG")

    print("wrote %d densities" % len(LEGACY))


if __name__ == "__main__":
    main()
