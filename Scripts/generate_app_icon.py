#!/usr/bin/env python3
"""Generate crisp 1024x1024 AppIcon and LaunchBg Assets.xcassets for FlatBill."""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Resources" / "Assets.xcassets"


def draw_icon(out_png: Path) -> None:
    S = 1024
    img = Image.new("RGB", (S, S), (21, 28, 38))  # Deep Slate #151C26
    draw = ImageDraw.Draw(img)

    # Subtle radial-like vignette layers
    for i in range(18):
        inset = i * 14
        shade = (
            min(255, 21 + i),
            min(255, 28 + i),
            min(255, 38 + int(i * 1.2)),
        )
        draw.rounded_rectangle([inset, inset, S - inset, S - inset], radius=220, outline=shade, width=16)

    # Subtle blueprint grid lines in background
    grid_color = (34, 45, 62)
    for g in range(96, S, 96):
        draw.line([(g, 0), (g, S)], fill=grid_color, width=2)
        draw.line([(0, g), (S, g)], fill=grid_color, width=2)

    # Drop shadow behind invoice card
    draw.rounded_rectangle([226, 174, 796, 864], radius=58, fill=(10, 14, 20))

    # Crisp Paper Invoice Sheet
    card = [206, 148, 778, 842]
    draw.rounded_rectangle(card, radius=54, fill=(248, 246, 240))

    # Construction Safety Amber Header Banner on Invoice Sheet
    draw.rounded_rectangle([206, 148, 778, 320], radius=54, fill=(217, 107, 22))
    draw.rectangle([206, 260, 778, 320], fill=(217, 107, 22))

    # Header bold title bars ("FLATBILL / INV")
    draw.rounded_rectangle([258, 200, 500, 242], radius=16, fill=(255, 255, 255))
    draw.rounded_rectangle([258, 258, 410, 284], radius=12, fill=(255, 232, 210))
    # Right currency emblem in header
    try:
        font_big = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 104)
    except Exception:
        font_big = ImageFont.load_default()
    draw.text((642, 174), "$", font=font_big, fill=(255, 255, 255))

    # Crisp invoice table line items
    line_y = [382, 466, 550]
    for idx, y in enumerate(line_y):
        draw.rounded_rectangle([258, y, 560 - (idx * 30), y + 32], radius=14, fill=(40, 52, 68))
        draw.rounded_rectangle([626, y, 724, y + 32], radius=14, fill=(116, 128, 145))
        draw.line([(258, y + 54), (724, y + 54)], fill=(224, 219, 208), width=4)

    # Total bar at bottom of paper
    draw.rounded_rectangle([258, 650, 724, 738], radius=22, fill=(235, 231, 221))
    draw.rounded_rectangle([286, 680, 444, 710], radius=12, fill=(21, 28, 38))
    draw.rounded_rectangle([540, 676, 696, 714], radius=14, fill=(217, 107, 22))

    # Emerald Paid / Verified Stamp Badge (bottom-right overlapping sheet)
    cx, cy, r = 746, 756, 134
    draw.ellipse([cx - r - 12, cy - r - 12, cx + r + 12, cy + r + 12], fill=(21, 28, 38))
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(21, 128, 61))
    # Thick white checkmark
    pts = [(cx - 56, cy + 4), (cx - 14, cy + 46), (cx + 64, cy - 42)]
    draw.line(pts, fill=(255, 255, 255), width=28, joint="curve")
    for px, py in pts:
        draw.ellipse([px - 14, py - 14, px + 14, py + 14], fill=(255, 255, 255))

    out_png.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_png, "PNG")


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))

    icon_dir = ASSETS / "AppIcon.appiconset"
    icon_dir.mkdir(parents=True, exist_ok=True)
    icon_png = icon_dir / "AppIcon-1024.png"
    draw_icon(icon_png)
    (icon_dir / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))

    launch_dir = ASSETS / "LaunchBg.colorset"
    launch_dir.mkdir(parents=True, exist_ok=True)
    (launch_dir / "Contents.json").write_text(json.dumps({
        "colors": [{
            "color": {
                "color-space": "srgb",
                "components": {"alpha": "1.000", "blue": "0.941", "green": "0.961", "red": "0.969"},
            },
            "idiom": "universal",
        }],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))

    # Also copy icon to docs/icon.png for landing page
    docs_icon = ROOT / "docs" / "icon.png"
    docs_icon.parent.mkdir(parents=True, exist_ok=True)
    Image.open(icon_png).resize((512, 512), Image.Resampling.LANCZOS).save(docs_icon, "PNG")
    print(f"✓ Generated {icon_png} and {docs_icon}")


if __name__ == "__main__":
    main()
