#!/usr/bin/env python3
"""Generate FlatBill high-conversion comparison promo posters (EN + ZH) and 15s 9:16 vertical reel (<20MB)."""
from __future__ import annotations

import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "build" / "raw_screens"
SHOT_ROOT = Path("/Users/wang/OPC/media/20261125-flatbill/appstore")
RELEASE_DIR = ROOT / "release"

FONT_EN_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_EN_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def font(size: int, bold: bool = True, cn: bool = False) -> ImageFont.FreeTypeFont:
    if cn and Path(FONT_CN).exists():
        try:
            return ImageFont.truetype(FONT_CN, size=size, index=2 if bold else 0)
        except Exception:
            return ImageFont.truetype(FONT_CN, size=size, index=0)
    path = FONT_EN_BOLD if bold else FONT_EN_REG
    if Path(path).exists():
        return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def paste_phone(canvas: Image.Image, img_path: Path, box: tuple[int, int, int, int], radius: int = 34) -> None:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    draw = ImageDraw.Draw(canvas)
    pad = 10
    draw.rounded_rectangle([x0 - pad, y0 - pad, x1 + pad, y1 + pad], radius=radius + pad, fill=(10, 14, 20))
    shot = Image.open(img_path).convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=radius, fill=255)
    canvas.paste(shot, (x0, y0), mask)


def build_en_compare_card() -> Path:
    W, H = 1080, 1350
    img = Image.new("RGB", (W, H), (21, 28, 38))
    draw = ImageDraw.Draw(img)

    # Top pill
    f_pill = font(26, bold=True)
    pill = "TIRED OF $220/YR INVOICE SUBSCRIPTIONS?"
    pb = draw.textbbox((0, 0), pill, font=f_pill)
    pw = pb[2] - pb[0]
    draw.rounded_rectangle([(W - pw) // 2 - 26, 46, (W + pw) // 2 + 26, 98], radius=26, fill=(217, 107, 22))
    draw.text(((W - pw) // 2, 58), pill, font=f_pill, fill=(255, 255, 255))

    # Headline
    f_h1 = font(56, bold=True)
    lines = ["Same Job-Site PDF Invoices.", "1/10th the Price. Own Forever."]
    y = 122
    for ln in lines:
        b = draw.textbbox((0, 0), ln, font=f_h1)
        draw.text(((W - (b[2] - b[0])) // 2, y), ln, font=f_h1, fill=(255, 255, 255))
        y += 68

    # Comparison split cards
    cy0, cy1 = 278, 650
    # Left card: Expensive Apps
    draw.rounded_rectangle([46, cy0, 520, cy1], radius=22, fill=(32, 41, 55), outline=(70, 82, 102), width=2)
    draw.text((74, cy0 + 24), "TYPICAL INVOICE APPS", font=font(22, True), fill=(185, 194, 208))
    draw.text((74, cy0 + 60), "$220 - $360 / yr", font=font(44, True), fill=(248, 113, 113))
    draw.line([(74, cy0 + 86), (430, cy0 + 86)], fill=(239, 68, 68), width=5)

    bad_pts = [
        "x  $8-$9/week auto-renew traps",
        "x  Paywall blocks sharing after work",
        "x  3.3% card fees & forced KYC",
        "x  Zero cheap lifetime option",
    ]
    by = cy0 + 132
    for pt in bad_pts:
        draw.text((74, by), pt, font=font(23, False), fill=(210, 216, 226))
        by += 54

    # Right card: FlatBill
    draw.rounded_rectangle([560, cy0, 1034, cy1], radius=22, fill=(38, 30, 22), outline=(217, 107, 22), width=3)
    draw.text((588, cy0 + 24), "FLATBILL (iPhone & iPad)", font=font(22, True), fill=(255, 173, 102))
    draw.text((588, cy0 + 60), "$19.99 ONCE", font=font(46, True), fill=(255, 255, 255))

    good_pts = [
        "+  3 Free PDFs/mo (no login)",
        "+  1-Tap Clone & Swap Client",
        "+  0% Fees (Zelle / Venmo / Cash)",
        "+  Clean Page-2 Job Photos",
    ]
    gy = cy0 + 132
    for pt in good_pts:
        draw.text((588, gy), pt, font=font(23, True), fill=(134, 239, 172))
        gy += 54

    # Real iOS Screenshots Side-by-Side at Bottom
    home_raw = RAW_DIR / "iphone65_en_home.png"
    prev_raw = RAW_DIR / "iphone65_en_preview.png"
    if home_raw.exists() and prev_raw.exists():
        paste_phone(img, home_raw, (95, 690, 485, 1300), radius=34)
        paste_phone(img, prev_raw, (595, 690, 985, 1300), radius=34)

    out = RELEASE_DIR / "compare_card_en_1080x1350.png"
    RELEASE_DIR.mkdir(parents=True, exist_ok=True)
    img.save(out, "PNG")
    print(f"✓ Saved {out} ({out.stat().st_size // 1024} KB)")
    return out


def build_zh_compare_card() -> Path:
    W, H = 1080, 1440  # 3:4 Xiaohongshu cover
    img = Image.new("RGB", (W, H), (247, 245, 240))
    draw = ImageDraw.Draw(img)

    # Top dark header slab
    draw.rectangle([0, 0, W, 380], fill=(21, 28, 38))
    draw.rectangle([0, 372, W, 382], fill=(217, 107, 22))

    badge = "受够了年费 ¥268–¥598 的报价单软件"
    fb = font(30, True, cn=True)
    bb = draw.textbbox((0, 0), badge, font=fb)
    bw = bb[2] - bb[0]
    draw.rounded_rectangle([(W - bw) // 2 - 28, 44, (W + bw) // 2 + 28, 104], radius=30, fill=(217, 107, 22))
    draw.text(((W - bw) // 2, 58), badge, font=fb, fill=(255, 255, 255))

    fh = font(64, True, cn=True)
    for idx, ln in enumerate(["15 秒离线出 PDF 单据", "一次买断 · 永不续费"]):
        b = draw.textbbox((0, 0), ln, font=fh)
        draw.text(((W - (b[2] - b[0])) // 2, 136 + idx * 86), ln, font=fh, fill=(255, 255, 255))

    sub = "免登录 · 一键复制老单换客户 · 施工图排附页不挡字 · 0抽成"
    fs = font(28, False, cn=True)
    sb = draw.textbbox((0, 0), sub, font=fs)
    draw.text(((W - (sb[2] - sb[0])) // 2, 316), sub, font=fs, fill=(210, 216, 226))

    # Price bar
    draw.rounded_rectangle([46, 412, 518, 560], radius=20, fill=(255, 255, 255), outline=(229, 225, 216), width=2)
    draw.text((76, 434), "常见订阅制报价/开单软件", font=font(24, False, cn=True), fill=(100, 110, 124))
    draw.text((76, 478), "¥268 - ¥598 / 年", font=font(44, True, cn=True), fill=(200, 30, 30))

    draw.rounded_rectangle([562, 412, 1034, 560], radius=20, fill=(253, 241, 229), outline=(217, 107, 22), width=3)
    draw.text((592, 434), "FlatBill 离线买断版", font=font(24, True, cn=True), fill=(217, 107, 22))
    draw.text((592, 478), "每月3单免费 / ¥68终身", font=font(38, True, cn=True), fill=(21, 28, 38))

    home_zh = RAW_DIR / "iphone65_zh_home.png"
    prev_zh = RAW_DIR / "iphone65_zh_preview.png"
    if home_zh.exists() and prev_zh.exists():
        paste_phone(img, home_zh, (88, 602, 492, 1384), radius=34)
        paste_phone(img, prev_zh, (588, 602, 992, 1384), radius=34)

    out = RELEASE_DIR / "compare_card_zh_3x4.png"
    img.save(out, "PNG")
    print(f"✓ Saved {out} ({out.stat().st_size // 1024} KB)")
    return out


def build_15s_promo_video(compare_en: Path) -> Path:
    slides = [
        compare_en,
        SHOT_ROOT / "en-US" / "iphone65" / "01_home.png",
        SHOT_ROOT / "en-US" / "iphone65" / "02_preview.png",
        SHOT_ROOT / "en-US" / "iphone65" / "03_editor.png",
        SHOT_ROOT / "en-US" / "iphone65" / "05_paywall.png",
    ]
    tmp_dir = ROOT / "build" / "promo_frames"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    norm_paths: list[Path] = []
    for idx, src in enumerate(slides):
        im = Image.open(src).convert("RGB")
        # Fit cleanly inside 1080x1920 dark slate canvas
        canvas = Image.new("RGB", (1080, 1920), (21, 28, 38))
        scale = min(1080 / im.width, 1920 / im.height)
        nw, nh = int(im.width * scale), int(im.height * scale)
        resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas.paste(resized, ((1080 - nw) // 2, (1920 - nh) // 2))
        p = tmp_dir / f"slide_{idx:02d}.png"
        canvas.save(p, "PNG")
        norm_paths.append(p)

    out_mp4 = RELEASE_DIR / "promo_15s_en_9x16.mp4"
    # 5 slides x 3.0s each with crisp 0.35s fade transitions -> ~13.6s vertical H.264 MP4
    ffmpeg = "/Users/wang/.local/bin/ffmpeg"
    inputs = []
    for p in norm_paths:
        inputs.extend(["-loop", "1", "-t", "3.0", "-i", str(p)])
    filter_complex = (
        "[0:v]fps=30,format=yuv420p[v0];"
        "[1:v]fps=30,format=yuv420p[v1];"
        "[2:v]fps=30,format=yuv420p[v2];"
        "[3:v]fps=30,format=yuv420p[v3];"
        "[4:v]fps=30,format=yuv420p[v4];"
        "[v0][v1]xfade=transition=fade:duration=0.35:offset=2.65[x01];"
        "[x01][v2]xfade=transition=fade:duration=0.35:offset=5.30[x02];"
        "[x02][v3]xfade=transition=fade:duration=0.35:offset=7.95[x03];"
        "[x03][v4]xfade=transition=fade:duration=0.35:offset=10.60,format=yuv420p[vout]"
    )
    subprocess.run([
        ffmpeg, "-y",
        *inputs,
        "-filter_complex", filter_complex,
        "-map", "[vout]",
        "-c:v", "libx264", "-crf", "23", "-preset", "medium", "-movflags", "+faststart",
        str(out_mp4),
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    size_mb = out_mp4.stat().st_size / (1024 * 1024)
    print(f"✓ Generated {out_mp4} ({size_mb:.2f} MB)")
    return out_mp4


def main() -> None:
    en_card = build_en_compare_card()
    build_zh_compare_card()
    build_15s_promo_video(en_card)


if __name__ == "__main__":
    main()
