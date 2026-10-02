"""Derive the Android notification (status bar) icon from icon_monochrome.png (#14).

Outputs android/app/src/main/res/drawable-{m,h,xh,xxh,xxxh}dpi/ic_stat_notify.png.

The status bar draws only the alpha channel (everything becomes white), so the
coloured launcher icon would show up as a white square. Use the white silhouette
of the bubble (the Android 13 themed icon) cropped to its content and fitted into
the 24dp icon with 1dp of padding (22dp live area, Material guidelines).

Usage: python tool/make_notification_icon.py .
"""
import sys

from PIL import Image

root = sys.argv[1]
src = Image.open(f"{root}/assets/branding/icon_monochrome.png").convert("RGBA")
alpha = src.getchannel("A")
bbox = alpha.point(lambda a: 255 if a > 8 else 0).getbbox()
print("silhouette bbox", bbox)
alpha = alpha.crop(bbox)
w, h = alpha.size

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
ICON_DP = 24
LIVE_DP = 22

for name, scale in DENSITIES.items():
    size = round(ICON_DP * scale)
    live = LIVE_DP * scale
    s = live / max(w, h)
    sw, sh = max(1, round(w * s)), max(1, round(h * s))
    scaled = alpha.resize((sw, sh), Image.LANCZOS)
    out_alpha = Image.new("L", (size, size), 0)
    out_alpha.paste(scaled, ((size - sw) // 2, (size - sh) // 2))
    white = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    white.putalpha(out_alpha)
    path = f"{root}/android/app/src/main/res/drawable-{name}/ic_stat_notify.png"
    white.save(path, optimize=True)
    print(f"  {name}: {size}px (content {sw}x{sh}) -> {path}")
