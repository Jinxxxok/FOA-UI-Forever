"""아케인 미니맵 텍스처 만들기 (MMSigilOuter / MMSigilInner / MMCorner / MMPointer / MMMaskSoft)

쓰는 법:
  python3 gen_minimap.py <FOA_UI/Media/Textures 폴더> <noto-sans-runic woff2 경로>

  룬 글꼴: npm pack @fontsource/noto-sans-runic → files/noto-sans-runic-runic-400-normal.woff2 (OFL)
  글꼴은 텍스처 안에 그림으로만 들어가고 애드온에는 포함하지 않는다.

모든 텍스처는 32비트 무압축 TGA (왼쪽 아래 원점) — 기존 FOA 텍스처와 같은 형식.
마법진 · 포인터는 흰색으로 그린다 (게임에서 금색으로 칠하고 ADD 로 겹친다).
모서리 장식은 금색 그라데이션을 그대로 굽는다.
"""
import base64
import io
import math
import struct
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

OUT = sys.argv[1].rstrip("/")
RUNIC = base64.b64encode(open(sys.argv[2], "rb").read()).decode()


def write_tga(img, path):
    img = img.convert("RGBA")
    w, h = img.size
    hdr = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    px = img.tobytes("raw", "BGRA")
    rows = [px[i * w * 4:(i + 1) * w * 4] for i in range(h)]
    with open(path, "wb") as f:
        f.write(hdr + b"".join(reversed(rows)))
    print("wrote", path, w, h)


def render(page, svg, size):
    html = (
        "<html><head><style>"
        "@font-face{font-family:Runic;src:url(data:font/woff2;base64," + RUNIC + ")}"
        "html,body{margin:0;background:transparent}"
        "</style></head><body>" + svg + "</body></html>"
    )
    page.set_viewport_size({"width": size, "height": size})
    page.set_content(html)
    page.evaluate("document.fonts.ready.then(() => true)")
    page.wait_for_timeout(250)
    png = page.screenshot(omit_background=True, clip={"x": 0, "y": 0, "width": size, "height": size})
    return Image.open(io.BytesIO(png))


C = 256  # 512 텍스처 가운데


def P(r, deg, cx=C, cy=C):
    a = math.radians(deg - 90)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def f(n):
    return "%.2f" % n


GLOW = (
    '<filter id="g" x="-10%" y="-10%" width="120%" height="120%">'
    '<feGaussianBlur stdDeviation="2.4" result="b"/>'
    '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
)

RUNES = "ᚠᚢᚦᚨᚱᚲᚷᚹ᛫ᚺᚾᛁᛃᛇᛈᛉᛊ᛫ᛏᛒᛖᛗᛚᛜᛞᛟ᛫" * 3


def sigil_outer():
    sq = lambda off: " ".join(f(P(206, d + off)[0]) + "," + f(P(206, d + off)[1]) for d in (0, 90, 180, 270))
    vtx = "".join(
        '<circle cx="%s" cy="%s" r="5"/>' % (f(P(206, i * 45)[0]), f(P(206, i * 45)[1])) for i in range(8)
    )
    dots = "".join(
        '<circle cx="%s" cy="%s" r="2"/>' % (f(P(206, i * 45)[0]), f(P(206, i * 45)[1])) for i in range(8)
    )
    return (
        '<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">'
        "<defs>" + GLOW +
        '<path id="rp" d="M34 256 a222 222 0 1 1 444 0 a222 222 0 1 1 -444 0"/></defs>'
        '<g filter="url(#g)" fill="none" stroke="#fff">'
        '<circle cx="256" cy="256" r="236" stroke-width="1.9"/>'
        '<circle cx="256" cy="256" r="231" stroke-width="0.9" stroke-opacity="0.7"/>'
        '<circle cx="256" cy="256" r="212" stroke-width="1.5"/>'
        '<polygon points="' + sq(0) + '" stroke-width="1.5" stroke-opacity="0.85"/>'
        '<polygon points="' + sq(45) + '" stroke-width="1.5" stroke-opacity="0.85"/>'
        '<g stroke-width="1.3">' + vtx + "</g></g>"
        '<g filter="url(#g)" fill="#fff">'
        '<text font-family="Runic" font-size="13" letter-spacing="1">'
        '<textPath href="#rp" textLength="1390" lengthAdjust="spacing">' + RUNES + "</textPath></text>"
        + dots + "</g></svg>"
    )


def sigil_inner():
    ticks = ""
    for i in range(120):
        a, b = P(192, i * 3), P(199 if i % 5 == 0 else 196, i * 3)
        ticks += "M%s %sL%s %s" % (f(a[0]), f(a[1]), f(b[0]), f(b[1]))
    return (
        '<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">'
        "<defs>" + GLOW + "</defs>"
        '<g filter="url(#g)" fill="none" stroke="#fff">'
        '<path d="' + ticks + '" stroke-width="1.3" stroke-opacity="0.85"/>'
        '<circle cx="256" cy="256" r="186" stroke-width="1.5" stroke-dasharray="2 6"/>'
        '<circle cx="256" cy="256" r="202" stroke-width="0.9" stroke-opacity="0.6"/>'
        "</g></svg>"
    )


def corner():
    # 시안의 왼쪽 위 모서리 장식 (모서리 꼭짓점 = 0,0 · 지도 쪽이 +x · +y). 보이는 범위 -14..70
    return (
        '<svg width="128" height="128" viewBox="-14 -14 84 84" xmlns="http://www.w3.org/2000/svg">'
        "<defs>"
        '<linearGradient id="gd" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0" stop-color="#FFF0C2"/><stop offset="0.35" stop-color="#D9AE5E"/>'
        '<stop offset="0.6" stop-color="#9A6D2C"/><stop offset="1" stop-color="#F3D692"/></linearGradient>'
        '<filter id="h" x="-30%" y="-30%" width="160%" height="160%">'
        '<feGaussianBlur in="SourceAlpha" stdDeviation="1.1" result="a"/>'
        '<feFlood flood-color="#000" flood-opacity="0.75"/><feComposite in2="a" operator="in" result="s"/>'
        '<feMerge><feMergeNode in="s"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
        "</defs>"
        '<g filter="url(#h)">'
        '<path d="M0 66 V7 Q0 0 7 0 H66" fill="none" stroke="url(#gd)" stroke-width="3" stroke-linecap="round"/>'
        '<path d="M6 60 V11 Q6 6 11 6 H60" fill="none" stroke="url(#gd)" stroke-width="1" stroke-opacity="0.8"/>'
        '<path d="M30 0 L34 -7 L38 0 Z M0 30 L-7 34 L0 38 Z" fill="url(#gd)"/>'
        '<path d="M14 -2 C20 -11 31 -11 35 -4 M-2 14 C-11 20 -11 31 -4 35" fill="none" stroke="url(#gd)" stroke-width="1.2"/>'
        '<circle cx="66" cy="0" r="2.4" fill="url(#gd)"/><circle cx="0" cy="66" r="2.4" fill="url(#gd)"/>'
        "</g></svg>"
    )


def pointer():
    return (
        '<svg width="32" height="32" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">'
        '<defs><filter id="g" x="-50%" y="-50%" width="200%" height="200%">'
        '<feGaussianBlur stdDeviation="1.6" result="b"/>'
        '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>'
        '<path d="M9 10 L23 10 L16 21 Z" fill="#fff" filter="url(#g)"/></svg>'
    )


def soft_mask(size=256, feather=16):
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            d = min(x + 0.5, y + 0.5, size - x - 0.5, size - y - 0.5)
            t = max(0.0, min(1.0, d / feather))
            a = t * t * (3 - 2 * t)
            px[x, y] = (255, 255, 255, int(a * 255 + 0.5))
    return img


with sync_playwright() as p:
    b = p.chromium.launch()
    page = b.new_page(device_scale_factor=1)
    write_tga(render(page, sigil_outer(), 512), OUT + "/MMSigilOuter.tga")
    write_tga(render(page, sigil_inner(), 512), OUT + "/MMSigilInner.tga")
    write_tga(render(page, corner(), 128), OUT + "/MMCorner.tga")
    write_tga(render(page, pointer(), 32), OUT + "/MMPointer.tga")
    b.close()
write_tga(soft_mask(), OUT + "/MMMaskSoft.tga")
