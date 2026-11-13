#!/usr/bin/env python3
"""
FOA 지도 아이콘: 탈것 전문가 (NpcMount)
다른 FOA 아이콘(Lucide 선 아이콘)과 같은 규칙: 24칸 · 선 굵기 2 · 둥근 끝 → 64 / 42(_q) / 32(_s, 선 2.25) 흰색 알파 TGA
Lucide 에 말 아이콘이 없어서 같은 규칙으로 새로 그림 (NpcMount.svg)
사용: python3 gen_icon_mount.py <FOA_UI/Media/Icons>
"""
import sys, os, io, cairosvg
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
svg = open(os.path.join(here, "NpcMount.svg"), encoding="utf-8").read()
out = sys.argv[1]
for sz, suf, sw in ((64, "", 2), (42, "_q", 2), (32, "_s", 2.25)):
    s = svg.replace('stroke-width="2"', 'stroke-width="%s"' % sw).encode()
    im = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=s, output_width=sz, output_height=sz))).convert("RGBA")
    o = Image.new("RGBA", (sz, sz), (255, 255, 255, 0))
    o.putalpha(im.getchannel("A"))
    o.save(os.path.join(out, "NpcMount%s.tga" % suf))
