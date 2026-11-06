#!/usr/bin/env python3
"""
포에버 던전 퀘스트 (FOA_UI/DungeonQuests.lua)
자료: AllTheThings (MIT License) db/Camelot/Categories/Instances.lua
던전(inst) 아래 퀘스트: 필요 레벨 · 진영 · 직업 · 시작 NPC / 위치 · 선행 퀘스트 · 보상 아이템 · 드랍으로 시작하는 퀘스트
사용: python3 -I gen_dquests.py <Instances.lua> <출력.lua>
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import att_parse

t = open(sys.argv[1], encoding="utf-8-sig").read()
root = att_parse.parse(t, "Instances")

def body(node):
    if isinstance(node, tuple) and node[0] == "call":
        a = node[2]
        return a[-1] if a and isinstance(a[-1], dict) else None
def kids(node):
    if isinstance(node, list): return node
    if not (isinstance(node, tuple) and node[0] == "call"): return []
    a = node[2]
    if a and isinstance(a[-1], list): return a[-1]
    b = body(node)
    if b is None: return []
    return (b.get("g") or []) + (b.get("__arr") or [])

def ints(v):
    return [int(x) for x in (v or []) if isinstance(x, int)]

out = {}   # inst -> {qid: row}
def quests_in(node, inst, acc):
    for k in kids(node):
        if not (isinstance(k, tuple) and k[0] == "call"): continue
        if k[1] == "inst": continue
        if k[1] == "q" and k[2] and isinstance(k[2][0], int):
            qid = k[2][0]; b = body(k) or {}
            if b.get("u") or qid in acc: continue
            lvl = b.get("lvl") or 0
            if isinstance(lvl, list): lvl = lvl[0]
            mp, x, y = 0, 0, 0
            co = b.get("coords")
            if isinstance(co, dict):
                for cm, v in co.items():
                    if isinstance(cm, int) and isinstance(v, list) and v and isinstance(v[0], list):
                        mp, x, y = cm, v[0][0], v[0][1]; break
            rew = []
            for c in kids(k):
                if isinstance(c, tuple) and c[0] == "call":
                    if c[1] == "s" and len(c[2]) >= 2 and isinstance(c[2][1], int): rew.append(c[2][1])
                    elif c[1] == "i" and c[2] and isinstance(c[2][0], int): rew.append(c[2][0])
            npc = (ints(b.get("qgs")) or [0])[0]
            drop = 0 if npc else (ints(b.get("crs")) or [0])[0]
            acc[qid] = (qid, int(lvl or 0), int(b.get("r") or 0), mp, x, y, npc, ints(b.get("sourceQuests")), rew, ints(b.get("c")), drop,
                        1 if b.get("repeatable") else 0)
            continue
        quests_in(k, inst, acc)

def walk(node):
    for k in kids(node):
        if isinstance(k, tuple) and k[0] == "call" and k[1] == "inst" and k[2] and isinstance(k[2][0], int):
            acc = out.setdefault(k[2][0], {})
            quests_in(k, k[2][0], acc)
            walk(k)
        else:
            walk(k)
walk(root)

with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 포에버 던전 퀘스트 (자동 생성: tools/quests/gen_dquests.py)\n")
    f.write("-- 자료: AllTheThings (MIT License) db/Camelot · https://github.com/ATTWoWAddon/AllTheThings\n")
    f.write("-- [던전 inst] = { { 퀘스트, 필요레벨, 진영(1호드 2얼라), 지도, x, y, 주는NPC, 선행{}, 보상{}, 직업{}, 드랍NPC(아이템으로 시작), 반복 }, ... }\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\nns.DUNGEON_QUESTS = {\n")
    n = 0
    for inst in sorted(out):
        rows = sorted(out[inst].values(), key=lambda r: (r[1], r[0]))
        if not rows: continue
        f.write("\t[%d] = {\n" % inst)
        for r in rows:
            n += 1
            f.write("\t\t{%d,%d,%d,%d,%g,%g,%d,{%s},{%s},{%s},%d,%d},\n" % (r[0], r[1], r[2], r[3], r[4], r[5], r[6],
                    ",".join(map(str, r[7])), ",".join(map(str, r[8])), ",".join(map(str, r[9])), r[10], r[11]))
        f.write("\t},\n")
    f.write("}\n")
print(len(out), "instances", n, "quests")
