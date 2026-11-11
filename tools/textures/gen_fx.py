"""효과용 텍스처 (Sparkle: 네 갈래 반짝임) — 흰색, 게임에서 색을 입혀 ADD 로 겹친다

쓰는 법: python3 gen_fx.py <FOA_UI/Media/Textures 폴더>
"""
import io
import struct
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

OUT = sys.argv[1].rstrip("/")


def write_tga(img, path):
    img = img.convert("RGBA")
    w, h = img.size
    hdr = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    px = img.tobytes("raw", "BGRA")
    rows = [px[i * w * 4:(i + 1) * w * 4] for i in range(h)]
    with open(path, "wb") as f:
        f.write(hdr + b"".join(reversed(rows)))
    print("wrote", path, w, h)


SPARKLE = (
    '<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">'
    "<defs>"
    '<radialGradient id="c" cx="32" cy="32" r="14" gradientUnits="userSpaceOnUse">'
    '<stop offset="0" stop-color="#fff" stop-opacity="0.9"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>'
    '<filter id="g" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1.6" result="b"/>'
    '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
    "</defs>"
    '<circle cx="32" cy="32" r="14" fill="url(#c)"/>'
    '<path filter="url(#g)" fill="#fff" d="M32 3 L34.6 29.4 L61 32 L34.6 34.6 L32 61 L29.4 34.6 L3 32 L29.4 29.4 Z"/>'
    '<path fill="#fff" fill-opacity="0.7" d="M32 16 L33.4 30.6 L48 32 L33.4 33.4 L32 48 L30.6 33.4 L16 32 L30.6 30.6 Z" transform="rotate(45 32 32)"/>'
    "</svg>"
)

with sync_playwright() as p:
    b = p.chromium.launch()
    page = b.new_page(device_scale_factor=1)
    page.set_viewport_size({"width": 64, "height": 64})
    page.set_content("<html><body style='margin:0;background:transparent'>" + SPARKLE + "</body></html>")
    png = page.screenshot(omit_background=True, clip={"x": 0, "y": 0, "width": 64, "height": 64})
    write_tga(Image.open(io.BytesIO(png)), OUT + "/Sparkle.tga")
    b.close()
