"""Play Store listing art for MetroPaws.

Composites a real app capture into a branded frame at Play's recommended
1080x1920, using the project's own tokens and Montserrat weights. Output is
24-bit RGB (no alpha) because Play rejects an alpha channel.

The bundled Montserrat subsets carry 232 codepoints and NO peso sign (U+20B1),
so headline copy must never contain it -- it renders as tofu. Write "PHP".
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter

REPO = pathlib.Path(__file__).resolve().parents[2]
FONTS = REPO / "mobile/assets/fonts"
OUT = pathlib.Path(__file__).parent / "out"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1080, 1920

# theme.dart tokens, verbatim
NAVY = (0x26, 0x32, 0x58)
NAVY_DEEP = (0x1A, 0x1E, 0x32)
GOLD = (0xB8, 0x9A, 0x3E)
CREAM = (0xF8, 0xF7, 0xF4)
ON_NAVY_MUTED = (0xBF, 0xC5, 0xDC)
WHITE = (0xFF, 0xFF, 0xFF)


def font(weight, size):
    return ImageFont.truetype(str(FONTS / f"Montserrat-{weight}.ttf"), size)


def vertical_gradient(size, top, bottom):
    w, h = size
    grad = Image.new("RGB", (1, h))
    px = grad.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return grad.resize((w, h), Image.BILINEAR)


def paw_watermark(canvas, cx, cy, scale, alpha):
    """The brand's paw texture: heart-ish pad plus four toes, no claws --
    the same 'general paw' the pet card emboss uses."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ink = WHITE + (alpha,)

    def blob(dx, dy, rx, ry):
        d.ellipse(
            [cx + dx * scale - rx * scale, cy + dy * scale - ry * scale,
             cx + dx * scale + rx * scale, cy + dy * scale + ry * scale],
            fill=ink,
        )

    # metacarpal pad
    blob(0, 42, 62, 50)
    blob(-30, 30, 40, 40)
    blob(30, 30, 40, 40)
    # four toes
    blob(-62, -34, 25, 32)
    blob(-22, -62, 26, 34)
    blob(22, -62, 26, 34)
    blob(62, -34, 25, 32)

    canvas.alpha_composite(layer)


def device_frame(shot_path, width, crop_top=105):
    """Rounded screen with a hairline bezel and a soft drop shadow.

    crop_top drops the device status bar -- the clock, battery and any stray
    notification icon are not part of the product and date the image.
    """
    shot = Image.open(shot_path).convert("RGB")
    if crop_top:
        shot = shot.crop((0, crop_top, shot.width, shot.height))
    height = round(width * shot.height / shot.width)
    shot = shot.resize((width, height), Image.LANCZOS)

    radius = round(width * 0.075)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width - 1, height - 1], radius, fill=255)

    pad = 90
    plate = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))

    shadow = Image.new("RGBA", plate.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [pad, pad + 16, pad + width, pad + height + 16], radius + 6, fill=(0, 0, 0, 130)
    )
    plate.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(34)))

    framed = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    framed.paste(shot, (0, 0), mask)
    ImageDraw.Draw(framed).rounded_rectangle(
        [0, 0, width - 1, height - 1], radius, outline=(255, 255, 255, 46), width=3
    )
    plate.alpha_composite(framed, (pad, pad))
    return plate


def wrap(draw, text, fnt, max_w):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def screenshot(shot_path, headline, subline, out_name, accent=GOLD):
    canvas = vertical_gradient((W, H), NAVY, NAVY_DEEP).convert("RGBA")
    paw_watermark(canvas, W - 90, 250, 1.5, 16)
    paw_watermark(canvas, 120, H - 300, 1.1, 12)
    d = ImageDraw.Draw(canvas)

    margin = 84
    y = 132

    # gold rule: the one accent, and it marks the headline
    d.rounded_rectangle([margin, y, margin + 92, y + 8], 4, fill=accent + (255,))
    y += 46

    h_font = font("ExtraBold", 66)
    for line in wrap(d, headline, h_font, W - margin * 2):
        d.text((margin, y), line, font=h_font, fill=WHITE)
        y += 82

    y += 14
    s_font = font("Medium", 32)
    for line in wrap(d, subline, s_font, W - margin * 2):
        d.text((margin, y), line, font=s_font, fill=ON_NAVY_MUTED)
        y += 44

    plate = device_frame(shot_path, 600)
    canvas.alpha_composite(plate, ((W - plate.width) // 2, y + 46))

    canvas.convert("RGB").save(OUT / out_name, "PNG")
    return OUT / out_name


def feature_graphic(out_name="00-feature-graphic.png"):
    """The 1024x500 banner above the screenshots. Play may crop it and can
    overlay a play button, so nothing important goes near the edges or the
    centre -- the lockup sits left, the texture right."""
    FW, FH = 1024, 500
    canvas = vertical_gradient((FW, FH), NAVY, NAVY_DEEP).convert("RGBA")
    paw_watermark(canvas, FW - 150, 250, 1.7, 20)
    paw_watermark(canvas, FW - 340, 430, 1.0, 14)
    d = ImageDraw.Draw(canvas)

    logo = Image.open(REPO / "mobile/assets/images/logo-full-white-metro.png").convert("RGBA")
    lw = 300
    logo = logo.resize((lw, round(lw * logo.height / logo.width)), Image.LANCZOS)
    canvas.alpha_composite(logo, (72, 92))

    y = 92 + logo.height + 34
    d.rounded_rectangle([72, y, 72 + 84, y + 7], 4, fill=GOLD + (255,))
    y += 40

    h = font("ExtraBold", 50)
    for line in ["Complete pet care", "in one membership"]:
        d.text((72, y), line, font=h, fill=WHITE)
        y += 62

    canvas.convert("RGB").save(OUT / out_name, "PNG")
    return OUT / out_name


# The listing, in order. Sources are captures/<name>.png -- see README.md.
LISTING = [
    ("home",     "Complete pet care in one membership",
     "Wellness benefits, a digital pet ID, and claims you file from your phone."),
    ("pawprint", "Your pet’s ID, always in your pocket",
     "Show the Digital Pawprint at any partner clinic."),
    ("benefits", "See exactly what you can claim back",
     "Every peso of your plan’s benefit, across all your pets."),
    ("claim",    "File a claim in a few taps",
     "Snap the receipt, pick the pet, submit. We take it from there."),
    ("add-pet",  "Add your pet in minutes",
     "A few details and three photos — that’s the whole set-up."),
]

if __name__ == "__main__":
    caps = pathlib.Path(__file__).parent / "captures"
    for i, (name, head, sub) in enumerate(LISTING, start=1):
        src = caps / f"{name}.png"
        if not src.exists():
            print(f"  skip {name}: {src} missing")
            continue
        out = screenshot(src, head, sub, f"{i:02d}-{name}.png")
        print(f"  {out.name}  {Image.open(out).size}")
    print(f"  {feature_graphic().name}  {Image.open(OUT / '00-feature-graphic.png').size}")
