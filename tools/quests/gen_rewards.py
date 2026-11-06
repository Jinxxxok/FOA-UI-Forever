#!/usr/bin/env python3
"""
포에버 퀘스트 보상 장비 (FOA_UI/ForeverQuestRewards.lua)
자료: AllTheThings (MIT License) db/Camelot/Categories/Zones.lua
퀘스트 바로 아래(g)의 아이템 i(아이템) · s(소스, 아이템) = 보상. 장비인지는 게임 안에서 착용 부위로 거른다.
사용: python3 -I gen_rewards.py <Zones.lua> <출력.lua>
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import att_parse

t = open(sys.argv[1], encoding="utf-8-sig").read()
root = att_parse.parse(t, "Zones")

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

out = {}
def rec(x):
    if isinstance(x, list):
        for y in x: rec(y)
        return
    if not (isinstance(x, tuple) and x[0] == "call"):
        return
    if x[1] == "q" and x[2] and isinstance(x[2][0], int):
        qid = x[2][0]; b = body(x) or {}
        if not b.get("repeatable"):
            lvl = b.get("lvl") or 0
            if isinstance(lvl, list): lvl = lvl[0]
            fac = b.get("r") or 0
            cls = b.get("c") or []
            npc = (b.get("qgs") or [0])[0]
            mp, xx, yy = 0, 0, 0
            co = b.get("coords")
            if isinstance(co, dict):
                for k, v in co.items():
                    if isinstance(k, int) and isinstance(v, list) and v and isinstance(v[0], list):
                        mp, xx, yy = k, v[0][0], v[0][1]; break
            for k in kids(x):
                iid = None
                if isinstance(k, tuple) and k[0] == "call":
                    if k[1] == "i" and k[2] and isinstance(k[2][0], int): iid = k[2][0]
                    elif k[1] == "s" and len(k[2]) >= 2 and isinstance(k[2][1], int): iid = k[2][1]   # s(소스ID, 아이템ID, {...}) = 장비 보상
                if iid:
                    if iid not in out or (lvl and lvl < out[iid][2]):
                        out[iid] = (iid, qid, int(lvl or 0), int(fac), mp, xx, yy, int(npc or 0), [int(c) for c in cls if isinstance(c, int)])
    for k in kids(x): rec(k)
rec(root)

with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 포에버 퀘스트 보상 아이템 (자동 생성: tools/quests/gen_rewards.py)\n")
    f.write("-- 자료: AllTheThings (MIT License) db/Camelot · https://github.com/ATTWoWAddon/AllTheThings\n")
    f.write("-- { 아이템, 퀘스트, 필요레벨, 진영(1호드 2얼라), 지도, x, y, 주는NPC, 직업{} }\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\nns.FOREVER_QREWARDS = {\n")
    for iid in sorted(out):
        e = out[iid]
        f.write("{%d,%d,%d,%d,%d,%g,%g,%d,{%s}},\n" % (e[0], e[1], e[2], e[3], e[4], e[5], e[6], e[7], ",".join(map(str, e[8]))))
    f.write("}\n")
print(len(out), "items")
