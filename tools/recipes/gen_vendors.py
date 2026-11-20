#!/usr/bin/env python3
"""
제조법 파는 상인 (상인 · 위치 · 값) → FOA_UI/RecipeVendors.lua
 자료: AllTheThings (MIT) db/Camelot/Categories/Zones.lua · ExpansionFeatures.lua (상인 n · 좌표 · 파는 아이템 i · cost)
 사용: python3 -I gen_vendors.py <Zones.lua,ExpansionFeatures.lua> <profession db 폴더> <출력.lua>  (그 뒤 tools/maps/apply_frame_fixes.py)
       .contrib/.db/forever/profession db/*.lua (제조법 아이템 → 주문)
"""
import sys, os, re, glob, json
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quests"))
import att_parse
zones, profdir, out = sys.argv[1], sys.argv[2], sys.argv[3]
PROF = {"alchemy": "연금술", "blacksmithing": "대장기술", "enchanting": "마법부여", "engineering": "기계공학", "first aid": "응급치료",
        "leatherworking": "가죽세공", "tailoring": "재봉술"}
recipe = {}
for f in glob.glob(os.path.join(profdir, "*.lua")):
    p = PROF.get(os.path.basename(f)[:-4])
    if not p: continue
    # 심화 과정 전용 제조법은 뒤에 인자가 더 붙는다: i(15740, 19066, nil, TRIBAL_LEATHERWORKING);
    #  (예전엔 이 줄을 못 읽어서 전통 · 용비늘 · 원소 등 심화 과정 도안을 파는 상인이 모두 빠졌다)
    for m in re.finditer(r"^i\((\d+),\s*(\d+)(?:,[^)]*)?\);", open(f, encoding="utf-8").read(), re.M):
        it = int(m.group(1))
        if it > 0: recipe[it] = (p, int(m.group(2)))
# 상인이 있는 분류 파일 (쉼표로 여러 개): Zones.lua 에 더해 ExpansionFeatures.lua (포에버 전문기술 평판 상인 · 가죽세공인 등)
roots = []
for zp in zones.split(","):
    key = os.path.basename(zp)[:-4]
    roots.append(att_parse.parse(open(zp, encoding="utf-8-sig").read(), key))
def body(node):
    a = node[2]
    return a[-1] if a and isinstance(a[-1], dict) else None
def kids(node):
    if not (isinstance(node, tuple) and node[0] == "call"): return []
    a = node[2]
    if a and isinstance(a[-1], list): return a[-1]
    b = body(node)
    if b is None: return []
    return (b.get("g") or []) + (b.get("__arr") or [])
vend = {}
learned = {}
def walk(node, mapctx=None):
    if isinstance(node, list):
        for c in node: walk(c, mapctx)
        return
    if not (isinstance(node, tuple) and node[0] == "call"): return
    nm, a = node[1], node[2]
    b = body(node) or {}
    if nm == "m" and a and isinstance(a[0], int): mapctx = a[0]
    if nm == "n" and a and isinstance(a[0], int) and a[0] > 0:
        co = b.get("coords") or b.get("coord")
        pts = []
        if isinstance(co, dict):
            for mm, lst in co.items():
                for p in (lst if isinstance(lst, list) else []):
                    if isinstance(p, list) and len(p) >= 2: pts.append((mm, p[0], p[1]))
        for c in kids(node):
            if isinstance(c, tuple) and c[0] == "call" and c[1] in ("i", "r") and c[2] and isinstance(c[2][0], int):
                cb = body(c) or {}
                iid = c[2][0] if c[1] == "i" else int(cb.get("itemID", 0) or 0)
                if c[1] == "r" and iid and iid not in recipe:
                    sk = {171: "연금술", 164: "대장기술", 333: "마법부여", 202: "기계공학", 129: "응급치료", 165: "가죽세공", 197: "재봉술", 185: "요리",
                          # 심화 과정 (가죽세공 용비늘 · 원소 · 전통 / 대장기술 방어구 · 무기 · 대가 / 기계공학 노움 · 고블린)
                          10656: "가죽세공", 10658: "가죽세공", 10660: "가죽세공", 9787: "대장기술", 9788: "대장기술",
                          17039: "대장기술", 17040: "대장기술", 17041: "대장기술", 20219: "기계공학", 20222: "기계공학"}.get(int(cb.get("requireSkill", 0) or 0))
                    if sk: recipe[iid] = (sk, c[2][0])
                if iid in recipe:
                    learned[iid] = int(cb.get("learnedAt", 0) or 0)
                    cost = cb.get("cost")
                    cs = []
                    for x in (cost if isinstance(cost, list) else []):
                        if isinstance(x, list) and len(x) >= 2:
                            if x[0] == "g": cs.append(("g", int(x[1]), 0))
                            elif x[0] == "i": cs.append(("i", int(x[1]), int(x[2]) if len(x) > 2 else 1))
                    vend.setdefault(iid, []).append((a[0], pts[:1], cs, int(b.get("r", 0) or 0), 1 if cb.get("isLimited") else 0))
    for c in kids(node): walk(c, mapctx)
for root in roots: walk(root)
def q(s): return '"' + s + '"'
lines = ["-- FOA UI · 제조법 파는 상인 (자동 생성 · tools/recipes/gen_vendors.py)",
         "-- 자료: AllTheThings (MIT License) · 상인 NPC · 위치 · 값(골드 또는 교환 아이템)",
         "-- [제조법 아이템] = { 전문기술, 배우는 주문, 필요 숙련, { { 상인 NPC, 지도, x, y, 진영(1호드 2얼라 0공통), 골드(동), 교환 아이템, 수, [1 = 수량 한정] } ... } }",
         "local _, ns = ...", "local b = select(4, GetBuildInfo()) or 0", "if not (b >= 16001 and b < 20000) then return end", "ns.RECIPE_VENDORS = {"]
n = 0
for iid in sorted(vend):
    p, sp = recipe[iid]
    vs = []
    for (npc, pts, cs, r, lim) in vend[iid][:4]:
        mm, x, y = (pts[0] if pts else (0, 0, 0))
        g = sum(c[1] for c in cs if c[0] == "g")
        ex = [c for c in cs if c[0] == "i"]
        vs.append(("{ %d, %d, %.1f, %.1f, %d, %d, %d, %d" % (npc, mm, x, y, r, g, ex[0][1] if ex else 0, ex[0][2] if ex else 0)) + (", 1 }" if lim else " }"))
    lines.append("\t[%d] = { %s, %d, %d, { %s } }," % (iid, q(p), sp, learned.get(iid, 0), ", ".join(vs)))
    n += 1
lines.append("}")
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("recipes", len(recipe), "with vendor", n)
