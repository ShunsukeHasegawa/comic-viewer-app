"""Derive launcher / splash images from the Web icon (icon-512x512.png).

Outputs (assets/branding/):
  icon_foreground.png   adaptive icon foreground (transparent, bubble within 66dp safe zone)
  icon_monochrome.png   Android 13 themed icon (white silhouette, text cut out)
  splash_logo.png       pre-Android 12 splash + Flutter SplashScreen (bubble only)
  splash_android12.png  Android 12+ splash icon (bubble within 2/3 circle)
"""
import math
import sys
from collections import deque

from PIL import Image

root = sys.argv[1]
src = Image.open(f"{root}/assets/branding/icon-512x512.png").convert("RGBA")
W, H = src.size
px = src.load()
TEAL_R = 37
GREY_R = 84


def t_from_teal(r):
    return max(0.0, min(1.0, (r - TEAL_R) / (255 - TEAL_R)))


# Outside region: flood from the border over everything that is not pure white.
outside = [[False] * W for _ in range(H)]
q = deque()
for x in range(W):
    q.append((x, 0))
    q.append((x, H - 1))
for y in range(H):
    q.append((0, y))
    q.append((W - 1, y))
while q:
    x, y = q.popleft()
    if x < 0 or y < 0 or x >= W or y >= H or outside[y][x]:
        continue
    r = px[x, y][0]
    if r >= 250:  # bubble interior
        continue
    outside[y][x] = True
    q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

bubble = Image.new("RGBA", (W, H))
mono = Image.new("RGBA", (W, H))
bp = bubble.load()
mp = mono.load()
for y in range(H):
    for x in range(W):
        r, g, b, _ = px[x, y]
        if outside[y][x]:
            a = round(t_from_teal(r) * 255)
            bp[x, y] = (255, 255, 255, a)
            mp[x, y] = (255, 255, 255, a)
        else:
            bp[x, y] = (r, g, b, 255)
            a = round(max(0.0, min(1.0, (r - GREY_R) / (255 - GREY_R))) * 255)
            mp[x, y] = (255, 255, 255, a)

bbox = bubble.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
print("bubble bbox", bbox)
bubble = bubble.crop(bbox)
mono = mono.crop(bbox)
bw, bh = bubble.size

# Max radius (from the bbox centre) of any visible pixel: what has to fit in a circle.
ba = bubble.getchannel("A").load()
cx, cy = bw / 2, bh / 2
rmax = 0.0
for y in range(bh):
    for x in range(bw):
        if ba[x, y] > 8:
            rmax = max(rmax, math.hypot(x + 0.5 - cx, y + 0.5 - cy))
print("bubble size", bw, bh, "rmax", rmax, "rmax/width", rmax / bw)


def place(img, canvas, radius_px):
    """Scale img so its rmax == radius_px and centre it on a transparent canvas."""
    s = radius_px / rmax
    w, h = round(bw * s), round(bh * s)
    scaled = img.resize((w, h), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(scaled, ((canvas - w) // 2, (canvas - h) // 2))
    print(f"  canvas={canvas} bubble={w}x{h} scale={s:.3f}")
    return out, w


# Adaptive icon: 108dp canvas, 66dp safe zone -> radius 33/108 of canvas.
FG = 1024
print("foreground")
fg, fg_w = place(bubble, FG, FG * 33 / 108)
fg.save(f"{root}/assets/branding/icon_foreground.png", optimize=True)
print("monochrome")
mo, _ = place(mono, FG, FG * 33 / 108)
mo.save(f"{root}/assets/branding/icon_monochrome.png", optimize=True)
print("  foreground bubble width in dp:", fg_w / FG * 108)

# Android 12 splash: 288dp canvas (xxxhdpi 1152px), visible circle 192dp.
# Leave 6dp of margin so the antialiased corners are not shaved by the mask.
A12 = 1152
print("android12")
a12, a12_w = place(bubble, A12, A12 * 90 / 288)
a12.save(f"{root}/assets/branding/splash_android12.png", optimize=True)
logo_dp = a12_w / 4
print("  android12 bubble width in dp:", logo_dp)

# Pre-12 splash / Flutter splash: same on-screen size as Android 12 (xxxhdpi = 4x).
print("splash_logo")
w = round(logo_dp * 4)
h = round(bh * w / bw)
bubble.resize((w, h), Image.LANCZOS).save(
    f"{root}/assets/branding/splash_logo.png", optimize=True
)
print(f"  {w}x{h} -> {w / 4:.1f}dp x {h / 4:.1f}dp")

# iOS splash: the tool treats the image as @3x, so render the same pt size at 3x.
print("splash_logo_ios")
w3 = round(logo_dp * 3)
h3 = round(bh * w3 / bw)
bubble.resize((w3, h3), Image.LANCZOS).save(
    f"{root}/assets/branding/splash_logo_ios.png", optimize=True
)
print(f"  {w3}x{h3} -> {w3 / 3:.1f}pt")
