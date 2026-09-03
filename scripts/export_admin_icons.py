"""Export vewo_admin app icons for iOS and Android from a 1024 master PNG."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MASTER = ROOT / "vewo_admin" / "assets" / "admin_app_icon_1024.png"
IOS_OUT = ROOT / "vewo_admin" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
ANDROID_RES = ROOT / "vewo_admin" / "android" / "app" / "src" / "main" / "res"

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

ANDROID_SIZES: dict[str, int] = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def square_master(src: Image.Image) -> Image.Image:
    img = src.convert("RGB")
    w, h = img.size
    if w == h == 1024:
        return img
    side = max(w, h, 1024)
    # Sample navy from top-left corner for padding.
    bg = img.getpixel((0, 0))
    canvas = Image.new("RGB", (side, side), bg)
    ox = (side - w) // 2
    oy = (side - h) // 2
    canvas.paste(img, (ox, oy))
    if side != 1024:
        canvas = canvas.resize((1024, 1024), Image.Resampling.LANCZOS)
    return canvas


def export_ios(master: Image.Image, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for filename, (w, h) in IOS_SIZES.items():
        icon = master if (w, h) == (1024, 1024) else master.resize((w, h), Image.Resampling.LANCZOS)
        icon.save(out_dir / filename, format="PNG", optimize=True)
        print(f"iOS  {filename} ({w}x{h})")


def export_android(master: Image.Image, res_dir: Path) -> None:
    for folder, size in ANDROID_SIZES.items():
        out_dir = res_dir / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        icon = master.resize((size, size), Image.Resampling.LANCZOS)
        icon.save(out_dir / "ic_launcher.png", format="PNG", optimize=True)
        print(f"Android {folder}/ic_launcher.png ({size}x{size})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, help="Optional source PNG (defaults to master path)")
    parser.add_argument("--master", type=Path, default=DEFAULT_MASTER)
    args = parser.parse_args()

    source = args.source or args.master
    if not source.exists():
        raise SystemExit(f"Source icon not found: {source}")

    master = square_master(Image.open(source))
    args.master.parent.mkdir(parents=True, exist_ok=True)
    master.save(args.master, format="PNG", optimize=True)
    print(f"Master: {args.master} ({args.master.stat().st_size} bytes)")

    export_ios(master, IOS_OUT)
    export_android(master, ANDROID_RES)


if __name__ == "__main__":
    main()
