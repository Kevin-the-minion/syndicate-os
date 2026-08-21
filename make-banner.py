#!/usr/bin/env python3
"""Compose Syndicate OS banner from the real Kevin + Hermes avatars."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math

W, H = 1280, 640
BG_TOP = (10, 14, 26)
BG_BOT = (20, 28, 52)

# --- background gradient ---
bg = Image.new("RGB", (W, H))
d = ImageDraw.Draw(bg)
for y in range(H):
    t = y / H
    r = int(BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t)
    g = int(BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t)
    b = int(BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t)
    d.line([(0, y), (W, y)], fill=(r, g, b))

# --- subtle radial glow behind title ---
glow = Image.new("L", (W, H), 0)
gd = ImageDraw.Draw(glow)
cx, cy, radius = W // 2, 300, 340
for i in range(radius, 0, -8):
    a = int(60 * (1 - i / radius) ** 2)
    gd.ellipse([cx - i, cy - i, cx + i, cy + i], fill=a)
glow = glow.filter(ImageFilter.GaussianBlur(60))
bg = Image.composite(Image.new("RGB", (W, H), (255, 200, 0)), bg, glow)

# --- faint circuit grid ---
grid = ImageDraw.Draw(bg)
for x in range(0, W, 64):
    grid.line([(x, 0), (x, H)], fill=(40, 55, 90, 40))
for y in range(0, H, 64):
    grid.line([(0, y), (W, y)], fill=(40, 55, 90, 40))

def circular(img, size, ring_color, ring_width=8):
    img = img.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([0, 0, size, size], fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    # ring
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse([ring_width // 2, ring_width // 2, size - ring_width // 2, size - ring_width // 2],
               outline=ring_color, width=ring_width)
    out = Image.alpha_composite(out, ring)
    return out

KEV = circular(Image.open("assets/kevin-avatar.png").convert("RGBA"), 300, (255, 215, 0))
HER = circular(Image.open("assets/hermes-avatar.png").convert("RGBA"), 300, (220, 230, 255))

# --- place avatars side by side, center ---
gap = 30
total = 300 * 2 + gap
x0 = (W - total) // 2
y0 = 40
bg.paste(KEV, (x0, y0), KEV)
bg.paste(HER, (x0 + 300 + gap, y0), HER)

d = ImageDraw.Draw(bg)

# --- title ---
def font(size, bold=True):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()

f_title = font(72)
f_sub = font(26)
f_tag = font(20)

title = "SYNDICATE OS"
tw = d.textlength(title, font=f_title)
d.text(((W - tw) / 2, 370), title, font=f_title, fill=(255, 255, 255))

# yellow underline
ul_w = 300
d.rounded_rectangle([(W - ul_w) / 2, 462, (W + ul_w) / 2, 468], radius=3, fill=(255, 215, 0))

sub = "SELF-HOSTED MULTI-AGENT FEDERATION"
sw = d.textlength(sub, font=f_sub)
d.text(((W - sw) / 2, 490), sub, font=f_sub, fill=(160, 178, 220))

tag = "./bootstrap.sh  ·  ./verify.sh  ·  ./scripts/demo.sh"
tw2 = d.textlength(tag, font=f_tag)
d.text(((W - tw2) / 2, 560), tag, font=f_tag, fill=(110, 126, 170))

bg.convert("RGB").save("docs/syndicate-os-banner.png", "PNG")
print("saved docs/syndicate-os-banner.png", bg.size)
