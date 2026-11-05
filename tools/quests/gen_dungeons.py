#!/usr/bin/env python3
"""
포에버 던전 보스별 전리품 (자료: AllTheThings MIT, db/Camelot/Categories/Instances.lua)
사용: python3 -I gen_dungeons.py <Instances.lua> [출력.json]
"""
import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import att_parse

t = open(sys.argv[1], encoding="utf-8-sig").read()
root = att_parse.parse(t, "Instances")

def body(node):
    if isinstance(node, tuple) and node[0] == "call":
        a = node[2]
        return a[-1] if a and isinstance(a[-1], dict) else None
def kids(node):
    if not (isinstance(node, tuple) and node[0] == "call"):
        return []
    a = node[2]
    if a and isinstance(a[-1], list):
        return a[-1]
    b = body(node)
    if b is None:
        return []
    return (b.get("g") or []) + (b.get("__arr") or [])

def items_of(node):
    out = []
    def rec(x):
        if isinstance(x, tuple) and x[0] == "call":
            nm, a = x[1], x[2]
            b = body(x) or {}
            if nm == "s" and len(a) >= 2 and isinstance(a[1], int):
                if "u" not in b: out.append(a[1])
            elif nm == "i" and a and isinstance(a[0], int):
                if "u" not in b: out.append(a[0])
            if nm not in ("q", "qo"):
                for c in kids(x): rec(c)
    for c in kids(node): rec(c)
    seen, res = set(), []
    for i in out:
        if i not in seen: seen.add(i); res.append(i)
    return res

dungeons = []
def boss_list(container):
    bosses = []
    for c in kids(container):
        if not (isinstance(c, tuple) and c[0] == "call"): continue
        nm, a = c[1], c[2]
        b = body(c) or {}
        if nm == "e" and a and isinstance(a[0], int):
            crs = b.get("crs") or ([b["npcID"]] if b.get("npcID") else [])
            its = items_of(c)
            if its: bosses.append({"enc": a[0], "npc": crs[0] if crs else 0, "items": its})
        elif nm == "n" and a and isinstance(a[0], int):
            its = items_of(c)
            if its:
                desc = b.get("description") or ""
                bosses.append({"npc": a[0], "items": its, "rare": 1 if "Rare" in desc else 0})
    return bosses

def walk(node):
    if not (isinstance(node, tuple) and node[0] == "call"):
        if isinstance(node, list):
            for c in node: walk(c)
        return
    if node[1] == "inst":
        a = node[2]; b = body(node) or {}
        if "u" in b: return
        co = b.get("coords") or {}
        entr = None
        for m, lst in (co.items() if isinstance(co, dict) else []):
            if lst: entr = [m, lst[0][0], lst[0][1]]; break
        base = {"inst": a[0], "lvl": b.get("lvl"), "map": b.get("mapID"), "raid": 1 if b.get("isRaid") else 0, "entr": entr}
        top = boss_list(node)
        if top:
            d = dict(base); d["wing"] = 0; d["bosses"] = top; dungeons.append(d)
        for c in kids(node):        # 날개(헤더)마다 따로: 붉은십자군 · 혈투의 전장 · 스트라솔름 등
            if isinstance(c, tuple) and c[0] == "call" and c[1] == "h":
                bb = boss_list(c)
                hb = body(c) or {}
                if bb and c[2][0] not in (-45, -46, -63, -56):
                    d = dict(base); d["wing"] = c[2][0]; d["lvl"] = hb.get("lvl", base["lvl"]); d["bosses"] = bb; dungeons.append(d)
                elif bb and c[2][0] == -46:   # 희귀 몹
                    for x in bb: x["rare"] = 1
                    tgt = [d for d in dungeons if d["inst"] == a[0]]
                    if tgt: tgt[-1]["bosses"] += bb
                    else:
                        d = dict(base); d["wing"] = 0; d["bosses"] = bb; dungeons.append(d)
        return
    for c in kids(node): walk(c)
walk(root)
for d in dungeons:
    print(d["inst"], d["wing"], d["lvl"], d["map"], d["entr"], [(x.get("enc"), x["npc"], len(x["items"]), x.get("rare", 0)) for x in d["bosses"]])
if len(sys.argv) > 2:
    json.dump(dungeons, open(sys.argv[2], "w"), ensure_ascii=False)
