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

**The phone bleeds off the bottom.** These screens are sparse by design, which is right on
a phone and useless in a thumbnail — fitting a whole one in leaves half the image empty and
the content too small to read at listing size. Framing the capture in a device and letting
it run past the bottom edge shows the part that carries the message at full size, and a
phone continuing off the frame reads as deliberate where a cut-off rectangle reads as a
mistake.

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

# file, headline, index, ground
#
# No tilt. It was tried, because the template packs all lean their devices and the energy
# looks appealing in their examples. Theirs are rendered in 3D; a flat rotation of a
# rectangle is not the same thing and reads as a crooked picture rather than a phone held
# at an angle. Straight is better than nearly.
SHOTS = [
    ("1.png", "Rings on Silent.\nRings on Focus.",       "01", "alarm"),
    ("2.png", "Dismiss\ndoesn't work.",                  "02", "alarm"),
    ("3.png", "Prove you started.\nOr it rings again.",  "03", "paper"),
    ("4.png", "It counts the days\nyou showed up.",      "04", "paper"),
    # Honest about what the capture shows — an empty ledger. "So far" does the threatening.
    ("5.png", "Zero excuses.\nSo far.",                  "05", "paper"),
]


def compose(shot_path: str, headline: str, index: str, ground_name: str) -> Image.Image:
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

    # The capture goes inside a drawn device rather than sitting as a bare rounded card.
    # STORE.md asks for a phone frame and it is right to: a flat rectangle reads as a
    # picture of an app, a framed one reads as a phone somebody is holding.
    #
    # Drawn rather than downloaded from a template pack. Those come wrapped in a house
    # style — gradients, angled devices, badges — and using one would throw away the
    # identity the rest of the app was built around. A bezel is four numbers.
    device_w = int(W * 0.86)
    scale = device_w / shot.width
    screen = shot.resize((device_w, int(shot.height * scale)), Image.LANCZOS)

    bezel = max(10, device_w // 46)
    outer_w = screen.width + bezel * 2
    outer_h = screen.height + bezel * 2
    outer_r = int(outer_w * 0.115)
    inner_r = max(4, outer_r - bezel)

    device = Image.new("RGB", (outer_w, outer_h), (12, 12, 14))
    mask = Image.new("L", (screen.width * 2, screen.height * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, screen.width * 2 - 1, screen.height * 2 - 1], radius=inner_r * 2, fill=255
    )
    device.paste(screen, (bezel, bezel), mask.resize(screen.size, Image.LANCZOS))

    shape = Image.new("L", (outer_w * 2, outer_h * 2), 0)
    ImageDraw.Draw(shape).rounded_rectangle(
        [0, 0, outer_w * 2 - 1, outer_h * 2 - 1], radius=outer_r * 2, fill=255
    )
    shape = shape.resize((outer_w, outer_h), Image.LANCZOS)

    # Pinned under the headline and allowed to run off the bottom edge. That bleed is what
    # replaces cropping: on a sparse screen the eye gets the part that matters at full
    # size, and a phone continuing past the frame reads as deliberate where a cut-off
    # rectangle reads as a mistake.
    left = (W - outer_w) // 2
    top = y + 104
    canvas.paste(device, (left, top), shape)

    return canvas


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    missing = []

    for filename, headline, index, ground in SHOTS:
        path = os.path.join(SRC, filename)
        if not os.path.exists(path):
            missing.append(path)
            continue
        out = os.path.join(OUT, f"store-{index}.png")
        compose(path, headline, index, ground).save(out, "PNG")
        print("wrote", out)

    if missing:
        print("\nStill needed:")
        for path in missing:
            print("  ", path)


if __name__ == "__main__":
    main()
