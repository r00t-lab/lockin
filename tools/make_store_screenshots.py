"""Turn raw device captures into App Store screenshots.

## Why this is a script
The five store screenshots decide most of the downloads and the first two decide most of
those, because hardly anyone swipes. They also get remade every time the copy changes, the
app changes, or a rejection asks for something different. Doing that by hand in an image
editor is an hour each time and drifts out of the app's identity a little more every round.

## What it does and does not do
It does not invent an interface. The phone capture is the real app — anything else is both
dishonest and a rejection risk, since App Review checks that screenshots show the shipping
app. All this adds is the headline, the ground and the framing, in the same palette and
type as `NaggStyle.swift`.

## Use
    1. Capture the five screens on the phone (see SHOTS below) and drop them in
       design/shots/ as 1.png … 5.png
    2. python tools/make_store_screenshots.py
    3. Upload design/store/*.png to App Store Connect

Output is 1290 x 2796 — the 6.9" size, which Apple will scale down for every smaller
device, so this is the only set that has to exist.
"""
from PIL import Image, ImageDraw, ImageFont
import os

# 6.9" — iPhone 16 Pro Max and friends. One set covers the rest.
W, H = 1290, 2796

PAPER = (239, 238, 233)
INK = (23, 23, 26)
INK3 = (142, 142, 136)
LINE = (213, 212, 204)
ALARM = (199, 53, 26)

SANS = "C:/Windows/Fonts/segoeuib.ttf"
MONO = "C:/Windows/Fonts/CascadiaMono.ttf"

SRC = "design/shots"
OUT = "design/store"

# Order matters and is not arbitrary: `docs/STORE.md` puts the two strongest claims first
# because most people never swipe past them.
SHOTS = [
    ("1.png", "Rings on Silent.\nRings on Focus.",      "01"),
    ("2.png", "Dismiss doesn't work.",                  "02"),
    ("3.png", "Prove you started.",                     "03"),
    ("4.png", "It counts the days\nyou showed up.",     "04"),
    ("5.png", "It remembers\nevery excuse.",            "05"),
]


def compose(shot_path: str, headline: str, index: str) -> Image.Image:
    canvas = Image.new("RGB", (W, H), PAPER)
    draw = ImageDraw.Draw(canvas)

    label = ImageFont.truetype(MONO, 34)
    title = ImageFont.truetype(SANS, 96)

    # The small red index doubles as a reading order cue in the store's filmstrip.
    draw.text((96, 150), index, font=label, fill=ALARM)

    y = 230
    for line in headline.split("\n"):
        draw.text((96, y), line, font=title, fill=INK)
        y += 118

    # The device capture, full width minus a margin, pinned below the headline. Cropped
    # from the bottom rather than squashed if it is too tall — an aspect-distorted
    # screenshot is instantly obvious and reads as carelessness.
    shot = Image.open(shot_path).convert("RGB")
    target_w = W - 192
    scale = target_w / shot.width
    shot = shot.resize((target_w, int(shot.height * scale)), Image.LANCZOS)

    top = y + 90
    room = H - top - 96
    if shot.height > room:
        shot = shot.crop((0, 0, shot.width, room))

    radius = 56
    mask = Image.new("L", (shot.width * 2, shot.height * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, shot.width * 2 - 1, shot.height * 2 - 1], radius=radius * 2, fill=255
    )
    mask = mask.resize(shot.size, Image.LANCZOS)
    canvas.paste(shot, (96, top), mask)

    # A hairline instead of a drop shadow. The identity has no shadows anywhere.
    draw.rounded_rectangle(
        [96, top, 96 + shot.width - 1, top + shot.height - 1],
        radius=radius, outline=LINE, width=2,
    )
    return canvas


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    missing = []

    for filename, headline, index in SHOTS:
        path = os.path.join(SRC, filename)
        if not os.path.exists(path):
            missing.append(path)
            continue
        out = os.path.join(OUT, f"store-{index}.png")
        compose(path, headline, index).save(out, "PNG")
        print("wrote", out)

    if missing:
        print("\nStill needed:")
        for path in missing:
            print("  ", path)


if __name__ == "__main__":
    main()
