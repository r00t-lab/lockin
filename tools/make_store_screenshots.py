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

## Three decisions that make these convert
**The first two are red.** A store listing is skimmed as a filmstrip of thumbnails, and
five identical pale cards read as one card. Putting the alarm's own colour behind the two
claims that matter gives the eye somewhere to land and matches what the product actually
feels like. Three, four and five go back to paper, so the set has a shape.

**Only the part that carries the message is shown.** These screens are deliberately sparse,
which is right on a phone and wrong in a thumbnail — over half the frame would be empty
ground. Each capture is cropped to a fraction set by eye, then scaled up. Automatic
trimming was tried and does not work here: the last row of content is the rail pinned to
the bottom of the screen, so nothing gets cut and the gap in the middle survives.

**The headline is the product, not the feature.** "Rings on Silent" beats "Alarm settings".
Nobody downloads a feature list.

## Use
    1. Capture the five screens (see SHOTS) into design/shots/ as 1.png … 5.png
    2. python tools/make_store_screenshots.py
    3. Upload design/store/*.png to App Store Connect

Output is 1290 x 2796 — the 6.9" size, which Apple scales down for every smaller device,
so this is the only set that has to exist.
"""
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1290, 2796

PAPER = (239, 238, 233)
INK = (23, 23, 26)
LINE = (213, 212, 204)
ALARM = (199, 53, 26)
ALARM_PALE = (246, 217, 210)
WHITE = (255, 255, 255)

SANS = "C:/Windows/Fonts/segoeuib.ttf"
MONO = "C:/Windows/Fonts/CascadiaMono.ttf"

SRC = "design/shots"
OUT = "design/store"

# file, headline, index, ground, keep
#
# `keep` is the fraction of the capture to show, measured from the top. These screens put
# their content at the top and a rail at the very bottom with a large gap between — right
# on a phone, useless in a thumbnail. Automatic trimming does not help, because the last
# row of content is that bottom rail, so nothing gets cut. The fraction is set by eye per
# shot instead, which is honest about it being a judgement rather than a measurement.
SHOTS = [
    ("1.png", "Rings on Silent.\nRings on Focus.",       "01", "alarm", 1.00),
    ("2.png", "Dismiss\ndoesn't work.",                  "02", "alarm", 1.00),
    ("3.png", "Prove you started.\nOr it rings again.",  "03", "paper", 0.72),
    ("4.png", "It counts the days\nyou showed up.",      "04", "paper", 0.34),
    # Honest about what the capture shows — an empty ledger. "So far" does the threatening.
    ("5.png", "Zero excuses.\nSo far.",                  "05", "paper", 0.52),
]


def compose(shot_path: str, headline: str, index: str, ground_name: str, keep: float) -> Image.Image:
    loud = ground_name == "alarm"
    ground = ALARM if loud else PAPER
    text = WHITE if loud else INK
    index_colour = ALARM_PALE if loud else ALARM
    edge = (170, 40, 20) if loud else LINE

    canvas = Image.new("RGB", (W, H), ground)
    draw = ImageDraw.Draw(canvas)

    label = ImageFont.truetype(MONO, 34)
    title = ImageFont.truetype(SANS, 108)

    draw.text((96, 150), index, font=label, fill=index_colour)

    y = 232
    for line in headline.split("\n"):
        draw.text((96, y), line, font=title, fill=text)
        y += 128

    shot = Image.open(shot_path).convert("RGB")
    if keep < 1.0:
        shot = shot.crop((0, 0, shot.width, int(shot.height * keep)))

    # A short crop gets a narrower margin, so the little that is left lands as large as
    # possible. A full-height capture keeps the wider margin — it needs the breathing room
    # and it is tall enough to read anyway.
    margin = 96 if keep >= 0.7 else 64
    target_w = W - margin * 2
    shot = shot.resize((target_w, int(shot.height * (target_w / shot.width))), Image.LANCZOS)

    region_top = y + 96
    region_bottom = H - 110
    if shot.height > region_bottom - region_top:
        shot = shot.crop((0, 0, shot.width, region_bottom - region_top))

    # Centred in what is left rather than pinned under the headline. Pinned, a short crop
    # leaves a single hole at the bottom that reads as a mistake; centred, the same space
    # splits in two and reads as margin.
    top = region_top + (region_bottom - region_top - shot.height) // 2

    radius = 56
    mask = Image.new("L", (shot.width * 2, shot.height * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, shot.width * 2 - 1, shot.height * 2 - 1], radius=radius * 2, fill=255
    )
    mask = mask.resize(shot.size, Image.LANCZOS)
    canvas.paste(shot, (margin, top), mask)

    # A hairline, never a drop shadow — the identity has no shadows anywhere.
    draw.rounded_rectangle(
        [margin, top, margin + shot.width - 1, top + shot.height - 1],
        radius=radius, outline=edge, width=2,
    )
    return canvas


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    missing = []

    for filename, headline, index, ground, keep in SHOTS:
        path = os.path.join(SRC, filename)
        if not os.path.exists(path):
            missing.append(path)
            continue
        out = os.path.join(OUT, f"store-{index}.png")
        compose(path, headline, index, ground, keep).save(out, "PNG")
        print("wrote", out)

    if missing:
        print("\nStill needed:")
        for path in missing:
            print("  ", path)


if __name__ == "__main__":
    main()
