#!/usr/bin/env python3
"""
전장 퀘스트 → FOA_UI/QuestBG.lua (QuestDB.lua 와 같은 줄 형식 · 불러올 때 ns.QUEST_DB 뒤에 붙인다)

 QuestDB.lua 는 ATT Zones.lua 만 읽어서 PvP 분류(전장) 퀘스트가 빠져 있었다.
 자료
  · AllTheThings (MIT) db/Camelot/Categories/PVP.lua: 포에버에 있는 전장 퀘스트 · 주는 NPC 자리(coords) ·
      레벨 · 진영 · 반복 · 선행 · 택일 · 평판 조건 · 어느 전장인지
  · QuestieDB (GPL-3.0) 포에버 합본: 자리가 없을 때 주는 NPC 의 자리 · 보고 NPC · 최고 레벨

 사용: python3 -I gen_bgquests.py <ATT 폴더> <QuestieDB 폴더> <출력 QuestBG.lua>
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import att_parse
import questie_data

att, qdb, out = sys.argv[1:4]
txt = open(os.path.join(att, "db", "Camelot", "Categories", "PVP.lua"), encoding="utf-8-sig").read()
key = re.search(r"categories\.(\w+)=", txt).group(1)
tree = att_parse.parse(txt, key)
Q, N, O, AREA = questie_data.load(qdb)

BG = {1459: "AV", 1460: "WSG", 1461: "AB", 2524: "DI"}


def body(a):
    return a[-1] if a and isinstance(a[-1], dict) else {}


def kids(node):
    a = node[2]
    b = body(a)
    if a and isinstance(a[-1], list):
        return a[-1]
    return (b.get("g") or []) + (b.get("__arr") or [])


found = {}


def walk(node, ctx):
    if isinstance(node, list):
        for c in node:
            walk(c, ctx)
        return
    if isinstance(node, dict):
        for k in ("g", "__arr"):
            if k in node:
                walk(node[k], ctx)
        return
    if not (isinstance(node, tuple) and node[0] == "call"):
        return
    nm, a = node[1], node[2]
    b = body(a)
    c = dict(ctx)
    if nm == "m" and a and isinstance(a[0], int):
        c["map"] = a[0]
    if nm == "q" and a and isinstance(a[0], int) and c.get("map") in BG:
        found.setdefault(a[0], (BG[c["map"]], b))
    walk(kids(node), c)


walk(tree, {})


def lst(v):
    if v is None:
        return []
    return v if isinstance(v, list) else [v]


def npc_points(npcs, limit=6):
    pts = []
    for n in npcs:
        sp = (N.get(n) or {}).get("spawns") or {}
        if isinstance(sp, list):
            sp = {i + 1: v for i, v in enumerate(sp)}
        for z, ps in sp.items():
            um = AREA.get(int(z))
            for p in (ps or []):
                if um and p and p[0] is not None and p[0] >= 0:
                    pts.append((um, round(float(p[0]), 1), round(float(p[1]), 1)))
                    if len(pts) >= limit:
                        return pts
    return pts


def fmt(v):
    if isinstance(v, float):
        s = ("%.1f" % v).rstrip("0").rstrip(".")
        return s
    return str(v)


rows, tags = [], {}
skipped = []
for qid, (bg, b) in sorted(found.items()):
    if b.get("u"):
        skipped.append((qid, "u"))
        continue
    qrow = Q.get(qid)
    pts = []
    co = b.get("coords") or b.get("coord")
    if isinstance(co, dict):
        for m, ps in co.items():
            for p in (ps if isinstance(ps, list) else []):
                if isinstance(p, list) and len(p) >= 2:
                    pts.append((int(m), round(float(p[0]), 1), round(float(p[1]), 1)))
    qgs = [x for x in lst(b.get("qgs")) if isinstance(x, int)]
    if not pts and qrow:
        sb = qrow[1]
        npcs = sb[0] if isinstance(sb, list) and sb and sb[0] else []
        pts = npc_points(npcs or qgs)
    if not pts:
        skipped.append((qid, "no spot"))
        continue
    lv = b.get("lvl")
    req = (lv[0] if isinstance(lv, list) else lv) or (qrow and qrow[3]) or 1
    maxlv = (lv[1] if isinstance(lv, list) and len(lv) > 1 else 0) or (qrow and qrow[31]) or 0
    fac = int(b.get("r") or 0)
    pre = [x for x in lst(b.get("sourceQuests")) if isinstance(x, int)]
    alt = [x for x in lst(b.get("altQuests")) if isinstance(x, int)]
    flags = (1 if b.get("repeatable") else 0) | (2 if b.get("isBreadcrumb") else 0)
    rep = []
    mr = b.get("minReputation")
    if isinstance(mr, list) and len(mr) >= 2:
        rep = [mr[0], mr[1]]
    extra = False
    xr = b.get("maxReputation")
    if maxlv or (isinstance(xr, list) and len(xr) >= 2):
        extra = "{0,false,0,%s,false,false,%d}" % (("{%d,%d}" % (xr[0], xr[1])) if isinstance(xr, list) and len(xr) >= 2 else "false", maxlv)
    giver = qgs[0] if qgs else 0
    # 보고: Questie finishedBy NPC (받은 NPC 와 같으면 0)
    turn = "nil"
    if qrow and isinstance(qrow[2], list) and qrow[2] and qrow[2][0]:
        en = qrow[2][0][0]
        if en == giver:
            turn = "0"
        else:
            tp = npc_points([en], 1)
            if tp:
                turn = "{%d,%s,%s,%d}" % (tp[0][0], fmt(tp[0][1]), fmt(tp[0][2]), en)
    flat = ",".join("%d,%s,%s" % (m, fmt(x), fmt(y)) for m, x, y in pts)
    row = "{%d,{%s},%d,%d,{},{},{%s},{%s},0,{%s},0,%d,0,%d,%s%s}" % (
        qid, flat, req, fac, ",".join(map(str, pre)), ",".join(map(str, alt)),
        ",".join(map(str, rep)), flags, giver, extra if extra else "false", ("," + turn) if turn != "nil" else "")
    rows.append(row)
    tags[qid] = bg

with open(out, "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 포에버 전장 퀘스트 (자동 생성: tools/quests/gen_bgquests.py) · GPL-3.0-or-later\n")
    f.write("-- 자료: AllTheThings (MIT License) db/Camelot PVP · QuestieDB (GPL-3.0) 포에버 합본 (자리가 없을 때 · 보고 NPC)\n")
    f.write("-- 줄 형식은 QuestDB.lua 와 같다. 불러올 때 ns.QUEST_DB 뒤에 붙이고, ns.QUEST_BG[퀘스트] = 전장 (AV 알터랙 · WSG 전쟁노래 · AB 아라시 · DI 검은창 섬)\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\n")
    f.write("local rows = {\n")
    for r in rows:
        f.write(r + ",\n")
    f.write("}\n")
    f.write("ns.QUEST_BG = {\n")
    items = sorted(tags.items())
    for i in range(0, len(items), 10):
        f.write("\t" + " ".join("[%d]=\"%s\"," % (q, t) for q, t in items[i:i + 10]) + "\n")
    f.write("}\n")
    f.write("ns.QUEST_DB = ns.QUEST_DB or {}\n")
    f.write("local have = {}\nfor _, r in ipairs(ns.QUEST_DB) do have[r[1]] = true end\n")
    f.write("for _, r in ipairs(rows) do if not have[r[1]] then ns.QUEST_DB[#ns.QUEST_DB + 1] = r end end\n")

from collections import Counter
print("quests", len(rows), Counter(tags.values()), "skipped", len(skipped), skipped[:10])
