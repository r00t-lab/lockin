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
**The ground is picked against the capture.** Five identical pale cards read as one card in
a filmstrip, and worse, a pale app screen on a pale ground disappears into it — only the
bezel separates them. So the two dark lock-screen shots sit on the alarm red, and the three
light in-app shots sit on the deep red, which lifts them without the flatness of black.

**The phone bleeds off the bottom.** These screens are sparse by design, which is right on
a phone and useless in a thumbnail — fitting a whole one in leaves half the image empty and
the content too small to read at listing size. Framing the capture in a device and letting
it run past the bottom edge shows the part that carries the message at full size, and a
phone continuing off the frame reads as deliberate where a cut-off rectangle reads as a
mistake.

**The headline is the product, not the feature.** "Rings on Silent" beats "Alarm settings".
Nobody downloads a feature list.

## Use
    1. Capture the five screens into design/shots/ under the names in SHOTS
    2. python tools/make_store_screenshots.py
    3. Upload design/store/*.png to App Store Connect

Output is 1290 x 2796 — the 6.9" size, which Apple scales down for every smaller device,
so this is the only set that has to exist.
"""
from PIL import Image, ImageDraw, ImageFont
import math
import os

W, H = 1290, 2796

PAPER = (239, 238, 233)
INK = (23, 23, 26)
LINE = (213, 212, 204)
ALARM = (168, 69, 47)      # sakinlestirilmis alarm kirmizisi, #A8452F
ALARM_PALE = (246, 217, 210)
DEEP = (168, 69, 47)       # ayni renk: tek zemin, set tek urun gibi dursun
WHITE = (255, 255, 255)

SANS = "C:/Windows/Fonts/segoeuib.ttf"
SANS_BOOK = "C:/Windows/Fonts/segoeui.ttf"
MONO = "C:/Windows/Fonts/CascadiaMono.ttf"

SRC = "design/shots"
OUT = "design/store"

# file, headline, subline, index, ground, tilt
#
# No tilt. It was tried, because the template packs all lean their devices and the energy
# looks appealing in their examples. Theirs are rendered in 3D; a flat rotation of a
# rectangle is not the same thing and reads as a crooked picture rather than a phone held
# at an angle. Straight is better than nearly.
SHOTS = [
    ("alarm.png",  "It rings on\nsilent.",
     "Through Focus. Through Do Not Disturb.",                              "01", "alarm", False),
    ("proof.png",  "Prove you\nstarted.",
     "Photograph your desk, or the alarm comes back.",                      "02", "deep", True),
    ("list.png",   "It counts the days\nyou showed up.",
     "And every one you didn't.",                                           "03", "deep", False),
    ("create.png", "Three ways\nto prove it.",
     "A photo of your desk, a 25-minute timer, or a code you taped to it.", "04", "deep", True),
    ("report.png", "Zero excuses.\nSo far.",
     "Nagg keeps the receipts.",                                            "05", "deep", False),
]


# The status bar is not the app, and the one that came off the phone says 21:31 and 8%
# battery in low-power yellow. Nobody reads a listing and thinks "their phone was dying",
# they just register something slightly off. Apple does not require the captured status
# bar -- it requires the interface below it to be the shipping app -- so the bar gets
# repainted with the marketing time and a full battery, and the app underneath is
# untouched.
#
# Detected rather than configured: a standard bar is ink at the far left and ink at the
# far right with a gap between. The lock screen capture has neither, so it is left alone
# instead of having a status bar invented over its dynamic island.
STATUS_TIME = "9:41"


def _band_geometry(shot: Image.Image):
    """Background colour, ink rows and column clusters in the top band, or None."""
    band_h = max(24, round(shot.height * 0.049))
    band = shot.crop((0, 0, shot.width, band_h)).convert("RGB")
    bg = max(band.getcolors(band.width * band.height))[1]

    px = band.load()
    ink_cols, ink_rows = [], []
    for x in range(band.width):
        for y in range(band_h):
            r, g, b = px[x, y]
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > 90:
                ink_cols.append(x)
                ink_rows.append(y)
                break

    if not ink_cols:
        return None

    clusters, start, prev = [], ink_cols[0], ink_cols[0]
    for x in ink_cols[1:]:
        if x - prev > 25:
            clusters.append((start, prev))
            start = x
        prev = x
    clusters.append((start, prev))

    if len(clusters) < 2:
        return None
    if clusters[0][0] > shot.width * 0.27 or clusters[-1][1] < shot.width * 0.84:
        return None

    rows = []
    for x in range(band.width):
        for y in range(band_h):
            r, g, b = px[x, y]
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > 90:
                rows.append(y)
    return {
        "band_h": band_h,
        "bg": bg,
        "left": clusters[0],
        "right": clusters[-1],
        "top": min(rows),
        "bottom": max(rows),
    }


def _fit_font(text: str, target_h: int) -> ImageFont.FreeTypeFont:
    size = target_h
    for _ in range(24):
        font = ImageFont.truetype(SANS, size)
        box = font.getbbox(text)
        height = box[3] - box[1]
        if abs(height - target_h) <= 1:
            return font
        size += 1 if height < target_h else -1
        size = max(8, size)
    return ImageFont.truetype(SANS, size)


def neutralise_status_bar(shot: Image.Image) -> Image.Image:
    geometry = _band_geometry(shot)
    if geometry is None:
        return shot

    bg = geometry["bg"]
    ink = WHITE if sum(bg) / 3 < 128 else INK
    top, bottom = geometry["top"], geometry["bottom"]
    h = bottom - top
    middle = (top + bottom) / 2

    shot = shot.copy()
    draw = ImageDraw.Draw(shot)
    draw.rectangle([0, 0, shot.width, geometry["band_h"]], fill=bg)

    font = _fit_font(STATUS_TIME, h)
    offset = font.getbbox(STATUS_TIME)[1]
    draw.text((geometry["left"][0], top - offset), STATUS_TIME, font=font, fill=ink)

    right = geometry["right"][1]

    # Battery, drawn full. Outline, nub, and a fill inset by the stroke.
    bat_h = round(h * 0.82)
    bat_w = round(h * 1.85)
    stroke = max(2, round(h * 0.09))
    bx1, by1 = right - round(h * 0.16), round(middle + bat_h / 2)
    bx0, by0 = bx1 - bat_w, by1 - bat_h
    draw.rounded_rectangle([bx0, by0, bx1, by1], radius=round(bat_h * 0.34),
                           outline=ink, width=stroke)
    nub_h = round(bat_h * 0.38)
    draw.rounded_rectangle(
        [bx1 + stroke, round(middle - nub_h / 2), right, round(middle + nub_h / 2)],
        radius=max(1, stroke), fill=ink,
    )
    inset = stroke + max(2, round(h * 0.12))   # daylight between shell and charge
    draw.rounded_rectangle([bx0 + inset, by0 + inset, bx1 - inset, by1 - inset],
                           radius=round(bat_h * 0.3), fill=ink)

    # Wi-Fi: three arcs and a dot, sharing a centre below the glyph.
    gap = round(h * 0.42)
    wifi_w = round(h * 1.15)
    wx1 = bx0 - gap
    wx0 = wx1 - wifi_w
    cx, cy = (wx0 + wx1) / 2, middle + h * 0.30
    for i, radius in enumerate((wifi_w * 0.5, wifi_w * 0.33, wifi_w * 0.16)):
        draw.arc([cx - radius, cy - radius, cx + radius, cy + radius],
                 start=218, end=322, fill=ink, width=max(2, round(h * 0.11)))
    dot = max(2, round(h * 0.075))
    draw.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=ink)

    # Cellular: four bars, all full.
    bar_w = round(h * 0.22)
    bar_gap = max(2, round(h * 0.12))
    sx1 = wx0 - gap
    for i in range(4):
        bar_h = h * (0.34 + 0.18 * (3 - i))   # tallest bar nearest the Wi-Fi glyph
        x1 = sx1 - i * (bar_w + bar_gap)
        draw.rounded_rectangle(
            [x1 - bar_w, middle + h * 0.42 - bar_h, x1, middle + h * 0.42],
            radius=max(1, bar_w // 3), fill=ink,
        )

    return shot


# The four-pointed sparkle. It is the one ornament allowed in here, and it earns its
# place by doing something a rectangle cannot: it breaks the silhouette of the phone so
# the image stops reading as a screenshot pasted on a colour and starts reading as a
# composed picture. Drawn, not imported -- a star is polar coordinates.
def sparkle(canvas: Image.Image, cx: float, cy: float, radius: float, colour, alpha=255):
    scale = 4  # drawn large and resampled down; the concave edges alias badly otherwise
    size = int(radius * 2 * scale)
    layer = Image.new("L", (size, size), 0)
    points = []
    for step in range(180):
        theta = step / 180 * 2 * math.pi
        pinch = abs(math.sin(2 * theta)) ** 0.62
        r = radius * scale * (1 - 0.78 * pinch)
        points.append((size / 2 + r * math.cos(theta), size / 2 + r * math.sin(theta)))
    ImageDraw.Draw(layer).polygon(points, fill=alpha)
    layer = layer.resize((int(radius * 2), int(radius * 2)), Image.LANCZOS)
    canvas.paste(Image.new("RGB", layer.size, colour),
                 (int(cx - radius), int(cy - radius)), layer)


# Placed by hand rather than scattered randomly. Three of them, in the margins the
# headline and the phone leave empty, at three different sizes so they read as depth
# instead of a pattern. A fourth one always landed on top of something.
SPARKLES = [(0.905, 0.082, 68, 255), (0.955, 0.45, 38, 195), (0.05, 0.63, 48, 170)]


def wrap(text: str, font: ImageFont.FreeTypeFont, width: int) -> list[str]:
    """Greedy wrap. Sublines are one or two lines; a third means the copy is wrong."""
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if font.getlength(trial) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def compose(shot_path: str, headline: str, subline: str, index: str,
            ground_name: str, tilt: bool = False) -> Image.Image:
    # The ground is chosen against the capture, not for its own sake. A pale app screen on
    # a pale ground vanishes into it — only the black bezel separates them, which is what
    # the first attempt looked like. Dark screens go on red; light screens go on the deep
    # red, which lifts them without the flat harshness of black.
    ground = {"alarm": ALARM, "deep": DEEP, "paper": PAPER}[ground_name]
    on_dark = ground_name in ("alarm", "deep")
    text = WHITE if on_dark else INK
    index_colour = ALARM_PALE if on_dark else ALARM
    subline_colour = ALARM_PALE if on_dark else (92, 90, 86)
    edge = (170, 40, 20) if ground_name == "alarm" else (110, 34, 18) if on_dark else LINE

    canvas = Image.new("RGB", (W, H), ground)
    draw = ImageDraw.Draw(canvas)

    label = ImageFont.truetype(MONO, 34)
    title = ImageFont.truetype(SANS, 96 if max(len(l) for l in headline.split(chr(10))) > 16 else 108)

    draw.text((96, 150), index, font=label, fill=index_colour)

    y = 232
    for line in headline.split("\n"):
        draw.text((96, y), line, font=title, fill=text)
        y += 128

    # The subline carries what the headline cannot fit: which three proofs, which
    # Focus. Set in the pale tint rather than white so it reads as the second thing
    # on the image instead of competing with the headline for the same glance.
    if subline:
        body = ImageFont.truetype(SANS_BOOK, 46)
        y += 34
        for line in wrap(subline, body, W - 96 * 2):
            draw.text((96, y), line, font=body, fill=subline_colour)
            y += 62

    shot = neutralise_status_bar(Image.open(shot_path).convert("RGB"))

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
    # A slight rotation on two of the five. Tilting every device was tried once and taken
    # back out -- a flat rotation of a flat rectangle reads as a crooked picture. Two out
    # of five reads as variation instead, and the ones that lean are the two whose screens
    # are dense enough that a straight edge would look like a wall of interface.
    if tilt:
        angle = -5.5
        device = device.rotate(angle, resample=Image.BICUBIC, expand=True)
        shape = shape.rotate(angle, resample=Image.BICUBIC, expand=True)
        outer_w, outer_h = device.size

    left = (W - outer_w) // 2
    top = y + 104
    canvas.paste(device, (left, top), shape)

    for fx, fy, radius, alpha in SPARKLES:
        sparkle(canvas, W * fx, H * fy, radius, ALARM_PALE if on_dark else ALARM, alpha)

    return canvas


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    missing = []

    for filename, headline, subline, index, ground, tilt in SHOTS:
        path = os.path.join(SRC, filename)
        if not os.path.exists(path):
            missing.append(path)
            continue
        out = os.path.join(OUT, f"store-{index}.png")
        compose(path, headline, subline, index, ground, tilt).save(out, "PNG")
        print("wrote", out)

    if missing:
        print("\nStill needed:")
        for path in missing:
            print("  ", path)


if __name__ == "__main__":
    main()
