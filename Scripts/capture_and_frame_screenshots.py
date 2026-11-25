#!/usr/bin/env python3
"""Boot iOS Simulators, capture real FlatBill native UI screenshots (EN + ZH),
and frame them into App Store 6.5" iPhone (1284x2778) and 13" iPad (2064x2752) showcases."""
from __future__ import annotations

import subprocess
import time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DERIVED = ROOT / "build" / "SimDerived"
RAW_DIR = ROOT / "build" / "raw_screens"
OUT_ROOT = Path("/Users/wang/OPC/media/20261125-flatbill/appstore")

IPHONE_UDID = "763788AE-549A-4E0A-8D30-128A44F000E9"  # iPhone 18 Pro Max
IPAD_UDID = "578123F2-ECF5-49A3-AF3B-08157D9471AD"    # iPad Pro 13-inch (M5)
BUNDLE_ID = "com.yanghe.flatbill"

FONT_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_CN_FALLBACK = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_EN = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def load_font(size: int, bold: bool = True, cn: bool = False) -> ImageFont.FreeTypeFont:
    if cn:
        if Path(FONT_CN).exists():
            try:
                return ImageFont.truetype(FONT_CN, size=size, index=2 if bold else 0)
            except Exception:
                return ImageFont.truetype(FONT_CN, size=size, index=0)
        return ImageFont.truetype(FONT_CN_FALLBACK, size=size, index=0)
    if Path(FONT_EN).exists():
        return ImageFont.truetype(FONT_EN, size=size)
    return ImageFont.truetype(FONT_CN, size=size, index=2 if bold else 0)


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=check, capture_output=True, text=True)


def build_sim_app() -> Path:
    print("[1/4] Building FlatBill for iOS Simulator...")
    subprocess.run([
        "xcodebuild",
        "-project", str(ROOT / "FlatBill.xcodeproj"),
        "-scheme", "FlatBill",
        "-configuration", "Debug",
        "-destination", f"platform=iOS Simulator,id={IPHONE_UDID}",
        "-derivedDataPath", str(DERIVED),
        "CODE_SIGNING_ALLOWED=NO",
        "build",
    ], check=True)
    app_path = DERIVED / "Build" / "Products" / "Debug-iphonesimulator" / "FlatBill.app"
    if not app_path.exists():
        raise RuntimeError(f"Built app not found at {app_path}")
    return app_path


def capture_device_screens(udid: str, app_path: Path, device_tag: str, screens: list[str], langs: list[str]) -> dict[tuple[str, str], Path]:
    print(f"[2/4] Booting simulator {device_tag} ({udid})...")
    run(["xcrun", "simctl", "boot", udid], check=False)
    run(["xcrun", "simctl", "bootstatus", udid, "-b"])
    run(["xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100", "--wifiBars", "3", "--cellularBars", "4"], check=False)
    run(["xcrun", "simctl", "uninstall", udid, BUNDLE_ID], check=False)
    run(["xcrun", "simctl", "install", udid, str(app_path)])

    captured: dict[tuple[str, str], Path] = {}
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    for lang in langs:
        # Reset app container between languages so starter samples match language cleanly
        run(["xcrun", "simctl", "uninstall", udid, BUNDLE_ID], check=False)
        run(["xcrun", "simctl", "install", udid, str(app_path)])
        for screen in screens:
            run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
            time.sleep(0.4)
            run(["xcrun", "simctl", "launch", udid, BUNDLE_ID, "-ui_lang", lang, "-ui_demo_screen", screen])
            out_png = RAW_DIR / f"{device_tag}_{lang}_{screen}.png"
            for attempt in range(4):
                time.sleep(2.4 if attempt == 0 else 1.4)
                run(["xcrun", "simctl", "io", udid, "screenshot", str(out_png)])
                if out_png.stat().st_size > 40_000:
                    break
            captured[(lang, screen)] = out_png
            print(f"  ✓ Captured {out_png.name} ({out_png.stat().st_size // 1024} KB)")

    run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
    run(["xcrun", "simctl", "shutdown", udid], check=False)
    return captured


def draw_rounded_paste(canvas: Image.Image, shot: Image.Image, box: tuple[int, int, int, int], radius: int, bezel_color=(16, 22, 30)) -> None:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    resized = shot.convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(canvas)
    pad = int(w * 0.022)
    draw.rounded_rectangle([x0 - pad, y0 - pad, x1 + pad, y1 + pad], radius=radius + pad, fill=bezel_color)
    mask = Image.new("L", (w, h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([0, 0, w, h], radius=radius, fill=255)
    canvas.paste(resized, (x0, y0), mask)


def compose_store_slide(
    raw_png: Path,
    out_png: Path,
    target_size: tuple[int, int],
    badge: str,
    title: str,
    subtitle: str,
    dark_bg: bool,
    is_cn: bool,
) -> None:
    W, H = target_size
    bg = (21, 28, 38) if dark_bg else (247, 245, 240)
    ink = (255, 255, 255) if dark_bg else (21, 28, 38)
    sub_ink = (202, 210, 222) if dark_bg else (92, 102, 115)
    accent = (217, 107, 22)

    canvas = Image.new("RGB", (W, H), bg)
    draw = ImageDraw.Draw(canvas)

    f_badge = load_font(int(W * 0.030), bold=True, cn=is_cn)
    f_title = load_font(int(W * 0.064), bold=True, cn=is_cn)
    f_sub = load_font(int(W * 0.034), bold=False, cn=is_cn)

    tb = draw.textbbox((0, 0), badge, font=f_badge)
    bw, bh = tb[2] - tb[0], tb[3] - tb[1]
    px, py = int(W * 0.042), int(H * 0.012)
    pill_h = bh + py * 2
    pill_x0 = (W - bw - px * 2) // 2
    pill_y0 = int(H * 0.040)
    draw.rounded_rectangle([pill_x0, pill_y0, pill_x0 + bw + px * 2, pill_y0 + pill_h], radius=pill_h // 2, fill=accent)
    draw.text((pill_x0 + px - tb[0], pill_y0 + py - tb[1]), badge, font=f_badge, fill=(255, 255, 255))

    ty = pill_y0 + pill_h + int(H * 0.024)
    for line in title.split("\n"):
        lb = draw.textbbox((0, 0), line, font=f_title)
        lw = lb[2] - lb[0]
        draw.text(((W - lw) // 2 - lb[0], ty - lb[1]), line, font=f_title, fill=ink)
        ty += (lb[3] - lb[1]) + int(H * 0.014)

    sy = ty + int(H * 0.008)
    sb = draw.textbbox((0, 0), subtitle, font=f_sub)
    sw = sb[2] - sb[0]
    draw.text(((W - sw) // 2 - sb[0], sy - sb[1]), subtitle, font=f_sub, fill=sub_ink)

    shot = Image.open(raw_png)
    shot_aspect = shot.width / shot.height
    frame_top = sy + (sb[3] - sb[1]) + int(H * 0.034)
    avail_h = H - frame_top - int(H * 0.034)
    avail_w = int(W * 0.80)
    if avail_w / avail_h > shot_aspect:
        fh = avail_h
        fw = int(fh * shot_aspect)
    else:
        fw = avail_w
        fh = int(fw / shot_aspect)
    fx0 = (W - fw) // 2
    fy0 = frame_top
    draw_rounded_paste(canvas, shot, (fx0, fy0, fx0 + fw, fy0 + fh), radius=int(fw * 0.085))

    out_png.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_png, "PNG")


def main() -> None:
    app_path = build_sim_app()
    screens = ["home", "preview", "editor", "clients", "paywall"]
    langs = ["en", "zh"]

    iphone_raw = capture_device_screens(IPHONE_UDID, app_path, "iphone65", screens, langs)
    ipad_raw = capture_device_screens(IPAD_UDID, app_path, "ipad13", screens, langs)

    copy_en = {
        "home": ("ZERO LOGIN · 100% OFFLINE", "Quotes & Invoices\nRight at the Job Site", "1-tap clone & swap client · 0% card fees", True),
        "preview": ("4 EXECUTIVE PDF THEMES", "Crisp Branded PDFs\nwith Paid Stamp", "Print Zelle/Venmo notes · Page-2 job photos", False),
        "editor": ("BUILT FOR REPEAT JOBS", "Insert Price Book\n& Sign on Screen", "Auto-draft guard · Convert quote to invoice", True),
        "clients": ("CLIENT & BALANCE TRACKER", "Every Customer &\nUnpaid Balance Clear", "1-tap repeat estimates · Offline JSON backup", False),
        "paywall": ("PAY ONCE · OWN FOREVER", "Skip $220/yr Apps.\nPay $19.99 Once.", "3 free PDFs monthly · Optional lifetime unlock", True),
    }
    copy_zh = {
        "home": ("免登录 · 100% 离线", "现场 15 秒出单\n报价单与收款发票", "一键复制换客户 · 零平台抽成手续费", True),
        "preview": ("4 套专业 PDF 单据模板", "带抬头 Logo 与印章\n微信一键发高清 PDF", "自定义收款说明 · 施工图自动排附页不挡字", False),
        "editor": ("常用价目库一键插入", "现场签字验收\n报价单秒转正式发票", "防误滑丢稿保护 · 自动算税费与优惠", True),
        "clients": ("客户与尾款一目了然", "谁已结清谁欠尾款\n打开手机瞬间看清", "老客户一键复开新单 · 本地 JSON 备份", False),
        "paywall": ("告别高价年卡订阅", "买断终身拥有\n永不被年费绑架", "每月送 3 张免费导出 · 可选一次买断终身用", True),
    }

    print("[3/4] Compositing EN & CN App Store screenshots (6.5\" iPhone + 13\" iPad)...")
    for idx, sc in enumerate(screens, start=1):
        for lang, locale_dir, copy_map, is_cn in [
            ("en", "en-US", copy_en, False),
            ("zh", "zh-Hans", copy_zh, True),
        ]:
            badge, title, sub, dark = copy_map[sc]
            compose_store_slide(
                iphone_raw[(lang, sc)],
                OUT_ROOT / locale_dir / "iphone65" / f"{idx:02d}_{sc}.png",
                (1284, 2778),
                badge, title, sub, dark, is_cn,
            )
            compose_store_slide(
                ipad_raw[(lang, sc)],
                OUT_ROOT / locale_dir / "ipad13" / f"{idx:02d}_{sc}.png",
                (2064, 2752),
                badge, title, sub, dark, is_cn,
            )

    print(f"[4/4] Done! Framed App Store screenshots saved in {OUT_ROOT}")


if __name__ == "__main__":
    main()
