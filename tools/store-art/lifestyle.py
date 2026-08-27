"""Key the chroma screen out of a generated lifestyle scene and drop a real app
capture into it.

The scene is AI-generated; the phone screen is not. That split is deliberate --
Play requires screenshots to represent the actual app, and a generated UI is
invented text in a layout that isn't ours.
"""
import pathlib
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = pathlib.Path(__file__).parent
REPO = pathlib.Path(__file__).resolve().parents[2]
FONTS = REPO / "mobile/assets/fonts"
SCENES = HERE / "scenes"      # generated lifestyle scenes, chroma-key screen
CAPTURES = HERE / "captures"  # real device captures
OUT = HERE / "out"

NAVY = (0x26, 0x32, 0x58)
GOLD = (0xB8, 0x9A, 0x3E)
WHITE = (0xFF, 0xFF, 0xFF)


def font(weight, size):
    return ImageFont.truetype(str(FONTS / f"Montserrat-{weight}.ttf"), size)


def chroma_mask(scene, threshold=45):
    r, g, b = scene.split()
    rb = ImageChops.lighter(r, b)
    return ImageChops.subtract(g, rb).point(lambda v: 255 if v > threshold else 0)


def place_screen(scene_path, shot_path, crop_top=105, shrink=1):
    """Return the scene with the real capture composited into the green area."""
    scene = Image.open(scene_path).convert("RGB")
    mask = chroma_mask(scene)
    x0, y0, x1, y1 = mask.getbbox()
    w, h = x1 - x0, y1 - y0

    shot = Image.open(shot_path).convert("RGB")
    if crop_top:
        shot = shot.crop((0, crop_top, shot.width, shot.height))

    # cover-fit the capture into the screen box, centred
    scale = max(w / shot.width, h / shot.height)
    sized = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
    left = (sized.width - w) // 2
    sized = sized.crop((left, 0, left + w, h))

    # the keyed mask carries the phone's real rounded corners, so the edge is
    # the render's own rather than one we guess at
    screen_mask = mask.crop((x0, y0, x1, y1)).filter(ImageFilter.GaussianBlur(0.6))
    out = scene.copy()
    out.paste(sized, (x0, y0), screen_mask)
    return out, (x0, y0, x1, y1)


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


def scrim(img, height, alpha=248, power=1.5):
    """Darken the top so white type holds against a bright photo.

    A gentler falloff was tried first and the subline disappeared into a cream
    wall -- on a bright interior the scrim has to be near-opaque where the type
    actually sits, not merely tinted.
    """
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for y in range(height):
        t = (1 - (y / height)) ** power
        d.line([(0, y), (img.size[0], y)], fill=NAVY + (int(alpha * t),))
    base = img.convert("RGBA")
    base.alpha_composite(layer)
    return base.convert("RGB")


def hero(scene_path, shot_path, headline, subline, out_name):
    composed, _ = place_screen(scene_path, shot_path)
    W, H = 1080, 1920
    scale = max(W / composed.width, H / composed.height)
    img = composed.resize((round(composed.width * scale), round(composed.height * scale)), Image.LANCZOS)
    img = img.crop(((img.width - W) // 2, 0, (img.width - W) // 2 + W, H))

    img = scrim(img, 880)
    d = ImageDraw.Draw(img)
    margin, y = 84, 120
    d.rounded_rectangle([margin, y, margin + 92, y + 8], 4, fill=GOLD)
    y += 46
    hf = font("ExtraBold", 66)
    for line in wrap(d, headline, hf, W - margin * 2):
        d.text((margin, y), line, font=hf, fill=WHITE)
        y += 82
    y += 12
    sf = font("Medium", 32)
    for line in wrap(d, subline, sf, W - margin * 2):
        d.text((margin, y), line, font=sf, fill=(0xE4, 0xE8, 0xF4))
        y += 44
    img.save(OUT / out_name, "PNG")
    return OUT / out_name


def feature(scene_path, shot_path, out_name):
    """1024x500 banner: crop a landscape band around the subject."""
    composed, (x0, y0, x1, y1) = place_screen(scene_path, shot_path)
    FW, FH = 1024, 500
    band_h = round(composed.width * FH / FW)
    cy = (y0 + y1) // 2
    top = max(0, min(composed.height - band_h, cy - band_h // 2))
    img = composed.crop((0, top, composed.width, top + band_h)).resize((FW, FH), Image.LANCZOS)

    layer = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x in range(round(FW * 0.62)):
        t = 1 - (x / (FW * 0.62))
        d.line([(x, 0), (x, FH)], fill=NAVY + (int(232 * t),))
    img = img.convert("RGBA")
    img.alpha_composite(layer)
    img = img.convert("RGB")

    logo = Image.open(REPO / "mobile/assets/images/logo-full-white-metro.png").convert("RGBA")
    lw = 260
    logo = logo.resize((lw, round(lw * logo.height / logo.width)), Image.LANCZOS)
    img.paste(logo, (64, 84), logo)

    d = ImageDraw.Draw(img)
    y = 84 + logo.height + 30
    d.rounded_rectangle([64, y, 64 + 78, y + 7], 4, fill=GOLD)
    y += 38
    hf = font("ExtraBold", 46)
    for line in ["Complete pet care", "in one membership"]:
        d.text((64, y), line, font=hf, fill=WHITE)
        y += 58
    img.save(OUT / out_name, "PNG")
    return OUT / out_name


if __name__ == "__main__":
    # Two scenes, two jobs. A phone-forward close shot makes the hero, because
    # the app has to be readable; a wider room shot makes the banner, because a
    # cropped close-up collides its own UI with the headline.
    shot = CAPTURES / "home.png"
    close, wide = SCENES / "hero.jpg", SCENES / "banner.jpg"
    if close.exists():
        p = hero(close, shot, "Complete pet care in one membership",
                 "Wellness benefits, a digital pet ID, and claims you file from your phone.",
                 "01-home.png")
        print(f"  {p.name}  {Image.open(p).size}")
    else:
        print(f"  skip hero: {close} missing")
    if wide.exists():
        p = feature(wide, shot, "00-feature-graphic.png")
        print(f"  {p.name}  {Image.open(p).size}")
    else:
        print(f"  skip banner: {wide} missing")
