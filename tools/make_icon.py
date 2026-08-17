"""Generate the Nagg app icon from the wordmark.

The icon is the wordmark cropped to its loudest half: "gg" in alarm red on the same
warm paper as the app. Four letters are unreadable at 60px on a home screen; two are
not, and "gg" is the half that carries the colour.

Run: python tools/make_icon.py
Writes ios/Lockin/Assets.xcassets/AppIcon.appiconset/icon-1024.png (and the watch copy).

Deliberately a script and not a hand-exported PNG: this project has no Mac and no
design tool in the loop, so the icon has to be reproducible from text like everything
else here. Change PAPER/RED/TEXT below and re-run.
"""
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
PAPER = (239, 238, 233)   # --ground
RED = (199, 53, 26)       # --alarm
TEXT = "gg"
FONT = "C:/Windows/Fonts/CascadiaMono.ttf"   # closest local stand-in for SF Mono

# Apple already rounds and masks the corners, so the artwork is a full-bleed square.
img = Image.new("RGB", (SIZE, SIZE), PAPER)
draw = ImageDraw.Draw(img)

# Fit the glyphs to ~64% of the canvas width, then centre on the *ink* box rather than
# the font's line box — a monospace font's line box is mostly leading, and centring on
# it parks the letters visibly high.
size = 10
while True:
    trial = ImageFont.truetype(FONT, size + 10)
    box = draw.textbbox((0, 0), TEXT, font=trial)
    if box[2] - box[0] > SIZE * 0.64:
        break
    size += 10

font = ImageFont.truetype(FONT, size)
box = draw.textbbox((0, 0), TEXT, font=font)
x = (SIZE - (box[2] - box[0])) / 2 - box[0]
y = (SIZE - (box[3] - box[1])) / 2 - box[1]
draw.text((x, y), TEXT, font=font, fill=RED)

for path in [
    "ios/Lockin/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    "ios/LockinWatch/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
]:
    img.save(path, "PNG")
    print("wrote", path)
