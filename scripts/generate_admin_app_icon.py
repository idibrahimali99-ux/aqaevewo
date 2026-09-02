"""Add user admin badge overlay to the original AQAR TOWN icon (logo unchanged)."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MAIN_ICON = (
    ROOT
    / "real_estate_iraq"
    / "ios"
    / "Runner"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "Icon-App-1024x1024@1x.png"
)
BADGE_ICON = ROOT / "vewo_admin" / "assets" / "admin_badge_overlay.png"
DEFAULT_OUT = ROOT / "vewo_admin" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
PREVIEW_OUT = ROOT / "docs" / "admin-icon-preview.png"

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


def _add_badge(base: Image.Image, badge: Image.Image) -> Image.Image:
    img = base.convert("RGBA").copy()
    size = img.width
    s = size / 1024

    badge_size = int(300 * s)
    badge_resized = badge.convert("RGBA").resize((badge_size, badge_size), Image.Resampling.LANCZOS)

    margin = int(28 * s)
    x = size - badge_size - margin
    y = size - badge_size - margin

    img.alpha_composite(badge_resized, (x, y))
    return img


def render_icon(size: int, master_1024: Image.Image, badge_1024: Image.Image) -> Image.Image:
    if size == 1024:
        base = master_1024
        badge = badge_1024
    else:
        base = master_1024.resize((size, size), Image.Resampling.LANCZOS)
        badge = badge_1024.resize((size, size), Image.Resampling.LANCZOS)
    return _add_badge(base, badge)


def write_all_sizes(master_1024: Image.Image, badge_source: Image.Image, out_dir: Path) -> None:
    badge_1024 = badge_source.convert("RGBA")
    out_dir.mkdir(parents=True, exist_ok=True)
    for filename, (w, h) in IOS_SIZES.items():
        icon = render_icon(w, master_1024, badge_1024)
        icon.save(out_dir / filename, format="PNG", optimize=True)
        print(f"Wrote {out_dir / filename} ({w}x{h})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    if not MAIN_ICON.exists():
        raise SystemExit(f"Main icon not found: {MAIN_ICON}")
    if not BADGE_ICON.exists():
        raise SystemExit(f"Badge icon not found: {BADGE_ICON}")

    master = Image.open(MAIN_ICON).convert("RGBA")
    badge = Image.open(BADGE_ICON).convert("RGBA")

    if args.apply:
        write_all_sizes(master, badge, DEFAULT_OUT)
    else:
        PREVIEW_OUT.parent.mkdir(parents=True, exist_ok=True)
        preview = render_icon(1024, master, badge)
        preview.save(PREVIEW_OUT, format="PNG", optimize=True)
        print(f"Preview: {PREVIEW_OUT}")


if __name__ == "__main__":
    main()
