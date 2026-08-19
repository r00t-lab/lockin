"""Generate the Play store graphics Apple never asks for.

Three things, and the sizes are not suggestions:

  * icon-512.png       Play wants exactly 512 x 512, so it gets the app icon scaled down
  * feature-1024x500   Play-only, shown at the top of the listing and in promo slots
  * shot-*.png         the App Store images, re-cut for Play's rules

The re-cut is the part with a trap in it. The App Store set is 1320 x 2868, a ratio of
2.17:1, and Play rejects anything whose long side is more than twice the short one. So the
frames are scaled to width and the bottom is trimmed rather than squashed -- the headline
and the top of the phone are what sell the image, and the bottom of a bleeding phone is
the one part that can be lost without losing meaning.

Run: python tools/make_play_assets.py
"""
from PIL import Image, ImageDraw, ImageFont
import os

SRC_ICON = "ios/Lockin/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
SRC_SHOTS = "design/store"
OUT = "design/play"

PAPER = (239, 238, 233)
ALARM = (168, 69, 47)
ALARM_PALE = (246, 217, 210)
WHITE = (255, 255, 255)
SANS = "C:/Windows/Fonts/segoeuib.ttf"
SANS_BOOK = "C:/Windows/Fonts/segoeui.ttf"

# Play's ceiling: the longer side may be at most twice the shorter one.
SHOT_W, SHOT_H = 1080, 2160


def icon():
    img = Image.open(SRC_ICON).convert("RGB").resize((512, 512), Image.LANCZOS)
    img.save(f"{OUT}/icon-512.png", "PNG")
    print("icon-512.png")


def feature():
    """1024 x 500. Read at the size of a postage stamp in search results, so it carries the
    wordmark and one line -- a screenshot shrunk into this space is a smudge."""
    img = Image.new("RGB", (1024, 500), ALARM)
    draw = ImageDraw.Draw(img)

    mark = ImageFont.truetype(SANS, 132)
    line = ImageFont.truetype(SANS_BOOK, 40)

    # The wordmark in two colours, same split as the app: "na" in paper, "gg" in the pale
    # tint, because the whole identity is one word that will not leave you alone.
    x, y = 84, 150
    draw.text((x, y), "na", font=mark, fill=WHITE)
    x += draw.textlength("na", font=mark)
    draw.text((x, y), "gg", font=mark, fill=ALARM_PALE)

    draw.text((88, 322), "It comes back until you start.", font=line, fill=ALARM_PALE)

    img.save(f"{OUT}/feature-1024x500.png", "PNG")
    print("feature-1024x500.png")


def shots():
    for name in sorted(os.listdir(SRC_SHOTS)):
        if not name.startswith("store-") or not name.endswith(".png"):
            continue
        img = Image.open(f"{SRC_SHOTS}/{name}").convert("RGB")
        scale = SHOT_W / img.width
        img = img.resize((SHOT_W, round(img.height * scale)), Image.LANCZOS)
        img = img.crop((0, 0, SHOT_W, SHOT_H))          # trim the bottom, keep the top
        out = name.replace("store-", "shot-")
        img.save(f"{OUT}/{out}", "PNG")
        print(out, img.size)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icon()
    feature()
    shots()
