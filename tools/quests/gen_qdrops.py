#!/usr/bin/env python3
"""
퀘스트 아이템이 나오는 몹 (FOA_UI/QuestDrops.lua)
자료: AllTheThings (MIT License) db/Camelot/Categories/Zones.lua · Instances.lua

포에버(클래식) 몹 툴팁에는 "밀림 치료제 1/7" 같은 줍기 목표 줄이 안 나와서,
이름표에 퀘스트 표시를 띄우려면 "어느 몹이 그 퀘스트 아이템을 떨구는지" 자료가 필요하다.
  · 퀘스트 목표 아이템: q() 의 cost {"i", 아이템, 개수} · qo() 의 providers {"i", 아이템}
  · 그 아이템이 나오는 몹: qo() 의 crs · 아이템 항목 i(아이템, {crs=…}) · n(몹) 아래 놓인 아이템
결과: ns.QUEST_DROP_NPC = { [몹] = { 아이템, … } } (퀘스트 목표 아이템만)

사용: python3 -I gen_qdrops.py <Zones.lua> <Instances.lua> <출력.lua>
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import att_parse

roots = [att_parse.parse(open(sys.argv[1], encoding="utf-8-sig").read(), "Zones"),
         att_parse.parse(open(sys.argv[2], encoding="utf-8-sig").read(), "Instances")]


def args(node):
    return node[2] if isinstance(node, tuple) and node[0] == "call" else []


def resolve(node):
    a = args(node)
    if not a: return []
    last = a[-1]
    if isinstance(last, dict): return [last]
    if isinstance(last, tuple) and last[0] == "call" and last[1].endswith("ResolveQuestData"):
        d = last[2][0] if last[2] and isinstance(last[2][0], dict) else {}
        common = {k: v for k, v in d.items() if k not in ("aqd", "hqd")}
        out = []
        for key in ("aqd", "hqd"):
            if isinstance(d.get(key), dict):
                b = dict(common); b.update(d[key]); out.append(b)
        return out or [common]
    return []


def kids_of(b):
    return (b.get("g") or []) + (b.get("__arr") or []) if isinstance(b, dict) else []


def ints(v):
    return [int(x) for x in (v or []) if isinstance(x, int) and x > 0]


obj_items = set()   # 퀘스트 목표 아이템
item_npcs = {}      # 아이템 → {몹}


def add(item, npcs):
    if npcs: item_npcs.setdefault(item, set()).update(npcs)


def walk(node, src):
    if isinstance(node, list):
        for k in node: walk(k, src)
        return
    if not (isinstance(node, tuple) and node[0] == "call"):
        return
    name, a = node[1], args(node)
    nid = a[0] if a and isinstance(a[0], int) else None
    bodies = resolve(node)
    if name == "n" and nid and nid > 0:
        src = nid
    elif name == "e":
        b = bodies[0] if bodies else {}
        boss = b.get("npcID") if isinstance(b.get("npcID"), int) else None
        crs = ints(b.get("crs"))
        src = boss or (crs[0] if crs else src)
    elif name == "i" and nid:
        b = bodies[0] if bodies else {}
        crs = ints(b.get("crs"))
        add(nid, crs or ([src] if src else []))
    elif name == "q" and nid:
        for b in bodies:
            cost = b.get("cost")
            for c in (cost if isinstance(cost, list) else []):
                if isinstance(c, list) and len(c) >= 2 and c[0] == "i" and isinstance(c[1], int):
                    obj_items.add(c[1])
            for k in kids_of(b):
                if isinstance(k, tuple) and k[0] == "call" and k[1] == "qo":
                    qb = (resolve(k) or [{}])[0]
                    crs = ints(qb.get("crs"))
                    for p in qb.get("providers") or []:
                        if isinstance(p, list) and len(p) == 2 and p[0] == "i" and isinstance(p[1], int):
                            obj_items.add(p[1])
                            add(p[1], crs)
    for b in bodies[:1]:
        for k in kids_of(b): walk(k, src)
    if not bodies and a and isinstance(a[-1], list):
        walk(a[-1], src)


for r in roots:
    walk(r, None)

npc_items = {}
for it in sorted(obj_items):
    npcs = item_npcs.get(it)
    if not npcs or len(npcs) > 60:   # 너무 흔한 아이템(몹 60종 넘게)은 이름 비교로 충분
        continue
    for n in npcs:
        npc_items.setdefault(n, []).append(it)

with open(sys.argv[3], "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 퀘스트 아이템이 나오는 몹 (자동 생성: tools/quests/gen_qdrops.py)\n")
    f.write("-- 자료: AllTheThings (MIT License) db/Camelot · https://github.com/ATTWoWAddon/AllTheThings\n")
    f.write("-- [몹] = { 퀘스트 목표 아이템, ... } · 이름표 줍기 퀘스트 표시용 (포에버 몹 툴팁에 줍기 목표 줄이 없어서)\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\n")
    f.write("ns.QUEST_DROP_NPC = {\n")
    for n in sorted(npc_items):
        f.write("[%d]={%s},\n" % (n, ",".join(str(x) for x in sorted(npc_items[n]))))
    f.write("}\n")
print("objective items", len(obj_items), "with sources", sum(1 for i in obj_items if i in item_npcs), "npcs", len(npc_items))
