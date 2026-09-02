"""Generate all iOS AppIcon sizes from a 1024x1024 master PNG."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MASTER = ROOT / "vewo_admin" / "assets" / "admin_app_icon_1024.png"
DEFAULT_OUT = ROOT / "vewo_admin" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

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


def export_icons(master_path: Path, out_dir: Path) -> None:
    master = Image.open(master_path).convert("RGB")
    if master.size != (1024, 1024):
        master = master.resize((1024, 1024), Image.Resampling.LANCZOS)
    out_dir.mkdir(parents=True, exist_ok=True)
    for filename, (w, h) in IOS_SIZES.items():
        icon = master if (w, h) == (1024, 1024) else master.resize((w, h), Image.Resampling.LANCZOS)
        icon.save(out_dir / filename, format="PNG", optimize=True)
        print(f"Wrote {filename} ({w}x{h})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--master", type=Path, default=DEFAULT_MASTER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    if not args.master.exists():
        raise SystemExit(f"Master icon not found: {args.master}")
    export_icons(args.master, args.out)


if __name__ == "__main__":
    main()
