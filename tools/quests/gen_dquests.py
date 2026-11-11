#!/usr/bin/env python3
"""
포에버 던전 퀘스트 (FOA_UI/DungeonQuests.lua)
자료: AllTheThings (MIT License) db/Camelot/Categories/Instances.lua · Zones.lua
던전(inst) 아래 퀘스트: 필요 레벨 · 진영 · 직업 · 시작 NPC / 위치 · 선행 퀘스트 · 보상 아이템 · 드랍으로 시작하는 퀘스트

퀘스트에 좌표가 없으면 아래 순서로 채운다 (지어내지 않고 자료에 있는 것만):
  1) 주는 NPC 의 좌표 (다른 퀘스트 · NPC 항목에 적힌 같은 NPC 자리)
  2) 아이템으로 시작하면: 그 아이템이 나오는 보스 / 몹 (보스 = e(npcID) 아래, 몹 = 던전 일반 드랍)
     + 아이템을 들고 가서 보고하는 곳 = 이 퀘스트를 선행으로 하는 다음 퀘스트의 NPC 자리
  3) 그래도 없으면 "던전 안 NPC" / "던전 안 물체" 로 표시
진영마다 다른 퀘스트(ResolveQuestData)는 얼라 · 호드 두 줄로 나눈다.

사용: python3 -I gen_dquests.py <Instances.lua> <Zones.lua> <출력.lua>
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import att_parse

inst_root = att_parse.parse(open(sys.argv[1], encoding="utf-8-sig").read(), "Instances")
zone_root = att_parse.parse(open(sys.argv[2], encoding="utf-8-sig").read(), "Zones")

def args(node):
    return node[2] if isinstance(node, tuple) and node[0] == "call" else []

def resolve(node):
    """q(id, _.ResolveQuestData({aqd=..., hqd=..., 공통...})) → [(진영, body)]"""
    a = args(node)
    if not a: return []
    last = a[-1]
    if isinstance(last, dict): return [(None, last)]
    if isinstance(last, tuple) and last[0] == "call" and last[1].endswith("ResolveQuestData"):
        d = last[2][0] if last[2] and isinstance(last[2][0], dict) else {}
        common = {k: v for k, v in d.items() if k not in ("aqd", "hqd")}
        out = []
        for key, r in (("aqd", 2), ("hqd", 1)):
            if isinstance(d.get(key), dict):
                b = dict(common); b.update(d[key]); b["r"] = r
                out.append((r, b))
        return out or [(None, common)]
    return []

def body(node):
    a = args(node)
    return a[-1] if a and isinstance(a[-1], dict) else None

def kids(node):
    if isinstance(node, list): return node
    a = args(node)
    if not a: return []
    if isinstance(a[-1], list): return a[-1]
    b = body(node)
    if b is None:
        rs = resolve(node)
        b = rs[0][1] if rs else None
    if b is None: return []
    return (b.get("g") or []) + (b.get("__arr") or [])

def ints(v):
    return [int(x) for x in (v or []) if isinstance(x, int)]

def first_coord(co):
    if isinstance(co, dict):
        for cm, v in co.items():
            if isinstance(cm, int) and isinstance(v, list) and v and isinstance(v[0], list):
                return (cm, v[0][0], v[0][1])

# ---------------------------------------------------------------------------
# 색인: NPC 자리 · 아이템이 나오는 곳 · 퀘스트 전체
# ---------------------------------------------------------------------------
npc_at = {}      # npc → (지도, x, y)
item_src = {}    # 아이템 → 보스/몹 npc (-1 = 던전 일반 몹)
all_q = {}       # 퀘스트 → [(진영, body)]
followers = {}   # 퀘스트 → 이 퀘스트를 선행으로 하는 퀘스트들

def index(node, src):
    if isinstance(node, tuple) and node[0] == "call":
        name, a = node[1], args(node)
        nid = a[0] if a and isinstance(a[0], int) else None
        b = body(node) or {}
        c = first_coord(b.get("coords"))
        if name == "n" and nid:
            if c: npc_at.setdefault(nid, c)
            src = nid
        elif name == "e":
            boss = b.get("npcID") if isinstance(b.get("npcID"), int) else None
            crs = ints(b.get("crs"))
            boss = boss or (crs[0] if crs else None)
            if boss:
                if c: npc_at.setdefault(boss, c)
                src = boss
        elif name == "h" and nid == -63:      # 던전 일반 드랍
            src = -1
        elif name == "i" and nid:
            crs = ints(b.get("crs"))
            s = crs[0] if crs else src
            if s: item_src.setdefault(nid, s)
        elif name == "q" and nid:
            rs = resolve(node)
            all_q.setdefault(nid, []).extend(rs)
            for _, qb in rs:
                qc = first_coord(qb.get("coords"))
                if qc:
                    for g in ints(qb.get("qgs")): npc_at.setdefault(g, qc)
                for sq in ints(qb.get("sourceQuests")):
                    followers.setdefault(sq, set()).add(nid)
    for k in kids(node):
        index(k, src)

index(zone_root, None)
index(inst_root, None)

def next_stop(qid, faction, item):
    """아이템을 들고 가서 보고하는 곳: 이 퀘스트 다음 퀘스트의 NPC 자리 (그 아이템을 받는 퀘스트 우선)"""
    best = None
    for f in sorted(followers.get(qid, ())):
        for r, b in all_q.get(f, []):
            if faction and r and r != faction: continue
            if faction and b.get("r") and b.get("r") != faction: continue
            c = first_coord(b.get("coords"))
            if not c: continue
            npc = (ints(b.get("qgs")) or [0])[0]
            score = 2 if item and item in ints(b.get("qis")) else 1
            if not best or score > best[0]:
                best = (score, c, npc)
    return best

# ---------------------------------------------------------------------------
# 던전 퀘스트
# ---------------------------------------------------------------------------
KIND_GIVER, KIND_TURNIN, KIND_INSIDE_NPC, KIND_INSIDE_OBJ, KIND_DROP = 0, 1, 2, 3, 4
INSIDE_GIVER = {1142}
out = {}
stats = {"total": 0, "coords": 0, "npc": 0, "turnin": 0, "inside_npc": 0, "inside_obj": 0, "drop": 0, "none": 0}

def row(qid, qb, faction):
    lvl = qb.get("lvl") or 0
    if isinstance(lvl, list): lvl = lvl[0]
    r = faction or int(qb.get("r") or 0)
    npc = (ints(qb.get("qgs")) or [0])[0]
    providers = [p for p in (qb.get("providers") or []) if isinstance(p, list) and len(p) == 2]
    if not npc:
        npc = next((p[1] for p in providers if p[0] == "n" and isinstance(p[1], int)), 0)
    obj = next((p[1] for p in providers if p[0] == "o" and isinstance(p[1], int)), 0)
    item = (ints(qb.get("qss")) or [0])[0]
    drop = 0 if npc else (ints(qb.get("crs")) or [0])[0]
    if item and not drop and not npc:
        drop = item_src.get(item, 0)
    mp, x, y, kind, turnin = 0, 0, 0, KIND_GIVER, 0
    c = first_coord(qb.get("coords"))
    if c:
        (mp, x, y), kind = c, KIND_GIVER
        stats["coords"] += 1
    elif npc and npc in npc_at:
        (mp, x, y), kind = npc_at[npc], KIND_GIVER
        stats["npc"] += 1
    else:
        nx = next_stop(qid, r, item) if (item or obj or not npc) else None
        if nx:
            (_, (mp, x, y), turnin), kind = nx, KIND_TURNIN
            stats["turnin"] += 1
        elif npc:
            kind = KIND_INSIDE_NPC; stats["inside_npc"] += 1
        elif obj:
            kind = KIND_INSIDE_OBJ; stats["inside_obj"] += 1
        elif item or drop:
            kind = KIND_DROP; stats["drop"] += 1
        else:
            stats["none"] += 1
    # 자료의 좌표가 시작 NPC 가 아니라 보고하는 NPC 자리인 퀘스트 → 던전 안 NPC 로 (안내는 DungeonQuestNotes.lua)
    #  1142 꺼져가는 생명의 불씨: 다르나서스 69.4, 67.6 = 트레샬라(보고) · 헤랄라스는 가시덩굴 우리 안 (워크래프트 태번 포에버 공략)
    if qid in INSIDE_GIVER:
        mp, x, y, kind, turnin = 0, 0, 0, KIND_INSIDE_NPC, 0
    rew = []
    return [qid, int(lvl or 0), r, mp, x, y, npc, ints(qb.get("sourceQuests")), rew, ints(qb.get("c")), drop,
            1 if qb.get("repeatable") else 0, item, kind, turnin]

def quests_in(node, acc):
    for k in kids(node):
        if not (isinstance(k, tuple) and k[0] == "call"): continue
        if k[1] == "inst": continue
        if k[1] == "q" and k[2] and isinstance(k[2][0], int):
            qid = k[2][0]
            rs = resolve(k)
            for faction, qb in rs:
                if qb.get("u"): continue
                key = (qid, faction or int(qb.get("r") or 0)) if len(rs) > 1 else (qid, 0)
                if key in acc: continue
                stats["total"] += 1
                r = row(qid, qb, faction)
                for c in kids(k):
                    if isinstance(c, tuple) and c[0] == "call":
                        if c[1] == "s" and len(c[2]) >= 2 and isinstance(c[2][1], int): r[8].append(c[2][1])
                        elif c[1] == "i" and c[2] and isinstance(c[2][0], int): r[8].append(c[2][0])
                acc[key] = r
            continue
        quests_in(k, acc)

def walk(node):
    for k in kids(node):
        if isinstance(k, tuple) and k[0] == "call" and k[1] == "inst" and k[2] and isinstance(k[2][0], int):
            acc = out.setdefault(k[2][0], {})
            quests_in(k, acc)
            walk(k)
        else:
            walk(k)
walk(inst_root)

with open(sys.argv[3], "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 포에버 던전 퀘스트 (자동 생성: tools/quests/gen_dquests.py)\n")
    f.write("-- 자료: AllTheThings (MIT License) db/Camelot · https://github.com/ATTWoWAddon/AllTheThings\n")
    f.write("-- [던전 inst] = { { 퀘스트, 필요레벨, 진영(1호드 2얼라), 지도, x, y, 주는NPC, 선행{}, 보상{}, 직업{}, 드랍NPC(-1 던전 몹), 반복,\n")
    f.write("--                   시작 아이템, 위치 종류(0 주는 곳 · 1 보고하는 곳 · 2 던전 안 NPC · 3 던전 안 물체 · 4 던전 드랍), 보고 NPC }, ... }\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\nns.DUNGEON_QUESTS = {\n")
    n = 0
    for inst in sorted(out):
        rows = sorted(out[inst].values(), key=lambda r: (r[1], r[0], r[2]))
        if not rows: continue
        f.write("\t[%d] = {\n" % inst)
        for r in rows:
            n += 1
            f.write("\t\t{%d,%d,%d,%d,%g,%g,%d,{%s},{%s},{%s},%d,%d,%d,%d,%d},\n" % (r[0], r[1], r[2], r[3], r[4], r[5], r[6],
                    ",".join(map(str, r[7])), ",".join(map(str, r[8])), ",".join(map(str, r[9])), r[10], r[11], r[12], r[13], r[14]))
        f.write("\t},\n")
    f.write("}\n")
    # 다른 퀘스트로 안내만 하는 연결 퀘스트 (선택: 안 해도 다음 퀘스트를 받을 수 있다)
    crumbs = sorted(q for q, rs in all_q.items() if any(b.get("isBreadcrumb") for _, b in rs) and any(q in v for v in [set(r[0] for r in out[i].values()) for i in out]))
    f.write("-- 연결 퀘스트 (다른 NPC 에게 안내만 함 · 선택): 선행 목록에 있어도 안 해도 된다\n")
    f.write("ns.DUNGEON_BREADCRUMB = {%s}\n" % ",".join("[%d]=true" % q for q in crumbs))
print(len(out), "instances", n, "quests", stats)
