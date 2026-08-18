"""Generate the Nagg app icon.

The artwork is a twin-bell alarm clock in alarm red on the app's own paper ground —
`design/icon-clock-source.png`, generated from the prompt in docs/VISUALS.md.

This script does one thing to it that matters: it knocks the clock face out in paper.
The generated art has a solid body, which is fine at poster size and turns into a red
blob at 60px — and 60px is the only size that decides anything, because that is how big
the icon is on a home screen. A hollow face gives it structure that survives the shrink.
The radius is tuned: much larger and the body becomes a thin ring that reads as fragile.

Run: python tools/make_icon.py

Deliberately a script and not a hand-exported PNG. There is no Mac and no design tool in
this loop, so the icon has to be reproducible from text like everything else in the repo.
Retune FACE_RADIUS, re-run, and look at the 60px column before believing anything.
"""
from PIL import Image, ImageDraw

SOURCE = "design/icon-clock-source.png"
SIZE = 1024
PAPER = (239, 238, 233)          # --ground, matching NaggStyle

# Centre of the clock body and the size of the hole, both as a fraction of the canvas.
FACE_CENTRE = (0.500, 0.612)
FACE_RADIUS = 0.14

TARGETS = [
    "ios/Lockin/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    "ios/LockinWatch/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
]

img = Image.open(SOURCE).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)

# Punch the face. Drawn at 4x and downsampled — a circle drawn straight at final size has
# visibly stepped edges against a flat field this large.
scale = 4
mask = Image.new("L", (SIZE * scale, SIZE * scale), 0)
cx, cy = FACE_CENTRE[0] * SIZE * scale, FACE_CENTRE[1] * SIZE * scale
r = FACE_RADIUS * SIZE * scale
ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
mask = mask.resize((SIZE, SIZE), Image.LANCZOS)

img.paste(Image.new("RGB", (SIZE, SIZE), PAPER), (0, 0), mask)

for path in TARGETS:
    img.save(path, "PNG")
    print("wrote", path)
