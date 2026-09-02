"""Generate distinct iOS app icons for vewo_admin (AQAR TOWN Admin)."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "vewo_admin" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

GOLD = (246, 182, 12)
GOLD_DARK = (212, 160, 0)
NAVY_TOP = (26, 26, 34)
NAVY_BOTTOM = (45, 45, 58)
ADMIN_RED = (198, 40, 40)
WHITE = (255, 255, 255)

IOS_SIZES: dict[str, tuple[int, int]] = {
    "Icon-App-20x20@1x.png": (20, 20),
    "Icon-App-20x20@2x.png": (40, 40),
    "Icon-App-20x20@3x.png": (60, 60),
    "Icon-App-29x29@1x.png": (29, 29),
    "Icon-App-29x29@2x.png": (58, 58),
    "Icon-App-29x29@3x.png": (87, 87),
    "Icon-App-40x40@1x.png": (40, 40),
    "Icon-App-40x40@2x.png": (80, 80),
    "Icon-App-40x40@3x.png": (120, 120),
    "Icon-App-60x60@2x.png": (120, 120),
    "Icon-App-60x60@3x.png": (180, 180),
    "Icon-App-76x76@1x.png": (76, 76),
    "Icon-App-76x76@2x.png": (152, 152),
    "Icon-App-83.5x83.5@2x.png": (167, 167),
    "Icon-App-1024x1024@1x.png": (1024, 1024),
}


def _lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def _gradient(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        r = _lerp(NAVY_TOP[0], NAVY_BOTTOM[0], t)
        g = _lerp(NAVY_TOP[1], NAVY_BOTTOM[1], t)
        b = _lerp(NAVY_TOP[2], NAVY_BOTTOM[2], t)
        for x in range(size):
            px[x, y] = (r, g, b, 255)
    return img


def _rounded_mask(size: int, radius: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def _draw_house(draw: ImageDraw.ImageDraw, cx: float, cy: float, scale: float) -> None:
    roof_h = 72 * scale
    body_w = 130 * scale
    body_h = 95 * scale
    left = cx - body_w / 2
    top = cy - body_h / 2
    draw.polygon(
        [
            (cx, top - roof_h),
            (left - 18 * scale, top + 8 * scale),
            (left + body_w + 18 * scale, top + 8 * scale),
        ],
        fill=GOLD,
    )
    draw.rounded_rectangle(
        (left, top, left + body_w, top + body_h),
        radius=10 * scale,
        fill=GOLD_DARK,
    )
    door_w = 34 * scale
    door_h = 52 * scale
    draw.rounded_rectangle(
        (
            cx - door_w / 2,
            top + body_h - door_h,
            cx + door_w / 2,
            top + body_h,
        ),
        radius=6 * scale,
        fill=NAVY_TOP,
    )
    win = 24 * scale
    for wx in (left + 22 * scale, left + body_w - 22 * scale - win):
        draw.rounded_rectangle(
            (wx, top + 24 * scale, wx + win, top + 24 * scale + win),
            radius=4 * scale,
            fill=WHITE,
        )


def _draw_pin(draw: ImageDraw.ImageDraw, cx: float, cy: float, scale: float) -> None:
    r = 22 * scale
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GOLD)
    draw.ellipse((cx - 8 * scale, cy - 8 * scale, cx + 8 * scale, cy + 8 * scale), fill=NAVY_TOP)
    draw.polygon(
        [
            (cx, cy + r + 26 * scale),
            (cx - 16 * scale, cy + 8 * scale),
            (cx + 16 * scale, cy + 8 * scale),
        ],
        fill=GOLD,
    )


def _draw_shield(draw: ImageDraw.ImageDraw, size: int) -> None:
    s = size / 1024
    x = size * 0.72
    y = size * 0.12
    w = 150 * s
    h = 180 * s
    draw.rounded_rectangle((x, y, x + w, y + h * 0.55), radius=18 * s, fill=ADMIN_RED)
    draw.polygon(
        [
            (x, y + h * 0.45),
            (x + w / 2, y + h),
            (x + w, y + h * 0.45),
        ],
        fill=ADMIN_RED,
    )
    try:
        font = ImageFont.truetype("arialbd.ttf", max(int(34 * s), 8))
    except OSError:
        font = ImageFont.load_default()
    draw.text((x + w * 0.18, y + h * 0.16), "A", fill=WHITE, font=font)


def _draw_admin_banner(draw: ImageDraw.ImageDraw, size: int) -> None:
    s = size / 1024
    banner_h = 190 * s
    y0 = size - banner_h
    draw.rectangle((0, y0, size, size), fill=ADMIN_RED)
    draw.rectangle((0, y0, size, y0 + 8 * s), fill=GOLD)
    try:
        font = ImageFont.truetype("arialbd.ttf", max(int(78 * s), 10))
    except OSError:
        font = ImageFont.load_default()
    text = "ADMIN"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(
        ((size - tw) / 2, y0 + (banner_h - th) / 2 - 6 * s),
        text,
        fill=WHITE,
        font=font,
    )


def render_icon(size: int) -> Image.Image:
    img = _gradient(size)
    mask = _rounded_mask(size, size * 0.223)
    img.putalpha(mask)
    draw = ImageDraw.Draw(img)
    s = size / 1024

    ring = 10 * s
    draw.rounded_rectangle(
        (ring, ring, size - ring, size - ring),
        radius=size * 0.19,
        outline=GOLD,
        width=max(int(6 * s), 1),
    )

    _draw_house(draw, size * 0.5, size * 0.43, s * 2.35)
    _draw_pin(draw, size * 0.5, size * 0.66, s * 1.8)
    if size >= 120:
        _draw_shield(draw, size)
    if size >= 80:
        _draw_admin_banner(draw, size)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    master = render_icon(1024)
    for filename, (w, h) in IOS_SIZES.items():
        icon = master.resize((w, h), Image.Resampling.LANCZOS) if (w, h) != (1024, 1024) else master
        icon.save(OUT / filename, format="PNG", optimize=True)
        print(f"Wrote {filename} ({w}x{h})")
    print("Done.")


if __name__ == "__main__":
    main()
