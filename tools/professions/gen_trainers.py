#!/usr/bin/env python3
"""
포에버 전문기술 훈련사 자료 → FOA_UI/ProfessionTrainers.lua

자료: AllTheThings (MIT License) db/Camelot/Categories/Zones.lua
  지역마다 prof(기술번호, { n(NPC, {coords, r=진영, g={ r(단계 주문, {rank=단계, lvl=레벨, learnedAt=숙련}), r(제조법, {learnedAt=숙련}) ... }) })
  → 훈련사마다: 자리 · 진영 · 가르치는 단계(초급 1 · 수습 2 · 숙련 3 · 전문 4) · 가르치는 제조법(주문 번호 · 필요 숙련)
  + 영어 이름(선택): QuestieDB 포에버 합본 (GPL-3.0) · 게임이 아직 NPC 이름을 모를 때만 씀
사용: python3 -I gen_trainers.py <Zones.lua> <Instances.lua> <출력 ProfessionTrainers.lua> [QuestieDB 폴더]
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quests"))
import att_parse

roots = [att_parse.parse(open(sys.argv[1], encoding="utf-8-sig").read(), "Zones"),
         att_parse.parse(open(sys.argv[2], encoding="utf-8-sig").read(), "Instances")]
OUT = sys.argv[3]
NAMES = {}
EXTRA = {}   # 보조 훈련사 (QuestieDB 직함으로): [기술] = [(npc, 진영, 지도, x, y, 최고 단계, 이름)]
if len(sys.argv) > 4:
    import questie_data
    from lupa import lua51
    _, QN, _, QA = questie_data.load(sys.argv[4])
    NAMES = {k: v["name"] for k, v in QN.items() if v.get("name")}
    # 직함 → 기술 · 가르치는 최고 단계 (포에버: 숙련 이하는 도시마다 · 채집 훈련사는 시작 지역 밖이면 모든 단계)
    TITLE = {"Journeyman Leatherworker": (165, 2), "Journeyman Blacksmith": (164, 2), "Journeyman Tailor": (197, 2),
             "Journeyman Alchemist": (171, 2), "Journeyman Engineer": (202, 2), "Journeyman Enchanter": (333, 2),
             "Herbalism Trainer": (182, 4), "Mining Trainer": (186, 4), "Skinning Trainer": (393, 4),
             "Junior Herbalism Trainer": (182, 1), "Junior Mining Trainer": (186, 1), "Junior Skinning Trainer": (393, 1),
             "Cooking Trainer": (185, 2), "Fishing Trainer": (356, 2), "First Aid Trainer": (129, 2)}
    L51 = lua51.LuaRuntime()
    L51.execute("os = nil; io = nil")
    t = L51.execute(open(os.path.join(sys.argv[4], "src", "corrections", "Forever", "combined", "foreverNpcDB.lua"), encoding="utf-8").read())
    for k in t.keys():
        r = t[k]
        sub = r[14]
        if sub not in TITLE: continue
        prof, mx = TITLE[sub]
        fac = {"A": 2, "H": 1}.get(r[13], 0)
        sp = r[7]
        if not sp: continue
        for area in sp.keys():
            m = QA.get(int(area))
            pts = sp[area]
            if not m or not pts or not pts[1]: continue
            x, y = float(pts[1][1]), float(pts[1][2])
            if x <= 0: continue
            EXTRA.setdefault(prof, []).append((int(k), fac, m, round(x, 1), round(y, 1), mx, r[1].replace('"', "'")))
            break

def body_of(node):
    args = node[2]
    return args[-1] if args and isinstance(args[-1], dict) else None

def children(body):
    out = []
    if not isinstance(body, dict): return out
    for k in ("g", "__arr"):
        v = body.get(k)
        if isinstance(v, list): out += v
    return out

def ints(v):
    return [int(x) for x in v] if isinstance(v, list) else []

trainers = {}   # npc -> dict

def collect_recipes(node, out):
    """훈련사 아래 (머리글 · 묶음 포함) r(...) 를 모두"""
    if isinstance(node, tuple) and node[0] == "call":
        name, args = node[1], node[2]
        b = body_of(node)
        if name == "r" and args and isinstance(args[0], int):
            out.append((args[0], b or {}))
        for ch in children(b):
            collect_recipes(ch, out)
        for a in args:
            if isinstance(a, list):
                for ch in a: collect_recipes(ch, out)
    elif isinstance(node, list):
        for ch in node: collect_recipes(ch, out)

def spots_of(co):
    spots = []
    if isinstance(co, dict):
        for m, lst in co.items():
            if isinstance(m, int) and m >= 1000 and isinstance(lst, list):   # 옛 지도 번호(1000 미만)는 뺀다
                for p in lst:
                    if isinstance(p, list) and len(p) >= 2: spots.append((m, float(p[0]), float(p[1])))
    return spots

def walk(node, prof=None, inst=None):
    if isinstance(node, tuple) and node[0] == "call":
        name, args = node[1], node[2]
        b = body_of(node)
        if name == "prof" and args and isinstance(args[0], int):
            prof = args[0]
        if name == "inst" and isinstance(b, dict):
            inst = spots_of(b.get("coords")) or inst
        if name == "n" and prof and args and isinstance(args[0], int) and isinstance(b, dict):
            npc = args[0]
            spots = spots_of(b.get("coords"))
            inside = 0
            if not spots and inst:
                spots, inside = inst, 1        # 던전 안 훈련사: 던전 입구 자리
            recs = []
            for ch in children(b): collect_recipes(ch, recs)
            if spots and recs:
                t = trainers.setdefault((prof, npc), {"prof": prof, "npc": npc, "fac": int(b.get("r", 0) or 0), "spots": spots, "ranks": {}, "recipes": {}, "inside": inside})
                for sid, rb in recs:
                    la = int(rb.get("learnedAt", 0) or 0)
                    if rb.get("rank"):
                        t["ranks"][int(rb["rank"])] = (sid, int(rb.get("lvl", 0) or 0), la)
                    elif not rb.get("u"):
                        t["recipes"][sid] = la
            return
        for ch in children(b): walk(ch, prof, inst)
        for a in args:
            if isinstance(a, list):
                for ch in a: walk(ch, prof, inst)
    elif isinstance(node, list):
        for ch in node: walk(ch, prof, inst)
    elif isinstance(node, dict):
        for ch in children(node): walk(ch, prof, inst)

for root in roots: walk(root)

L = lambda xs: "{" + ",".join(str(x) for x in xs) + "}"
by_prof = {}
for (prof, npc), t in sorted(trainers.items()):
    by_prof.setdefault(prof, []).append(t)
with open(OUT, "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 포에버 전문기술 훈련사 (자동 생성 · tools/professions/gen_trainers.py)\n")
    f.write("-- 자료: AllTheThings (MIT License) db/Camelot · https://github.com/ATTWoWAddon/AllTheThings\n")
    f.write("--       NPC 영어 이름: QuestieDB (GPL-3.0) · 게임이 NPC 이름을 아직 모를 때만\n")
    f.write("-- [기술 번호] = { { NPC, 진영(0 공통 1 호드 2 얼라), {지도,x,y,...}, 단계{ [단계]={주문, 레벨, 숙련} }, 제조법{ 주문, 숙련, 주문, 숙련, ... }, 영어 이름, [던전 안이면 1] } }\n")
    f.write("--  단계: 1 초급 · 2 수습 · 3 숙련 · 4 전문 (게임 이름 · NPC 칭호는 한 칸 위)\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\nns.PROF_TRAINERS = {\n")
    for prof in sorted(by_prof):
        f.write("\t[%d] = {\n" % prof)
        for t in by_prof[prof]:
            sp = []
            for (m, x, y) in t["spots"][:2]: sp += [m, round(x, 1), round(y, 1)]
            rk = ",".join("[%d]={%d,%d,%d}" % (r, v[0], v[1], v[2]) for r, v in sorted(t["ranks"].items()))
            rc = []
            for sid, la in sorted(t["recipes"].items(), key=lambda kv: (kv[1], kv[0])): rc += [sid, la]
            nm = NAMES.get(t["npc"], "").replace("\\", "").replace('"', "'")
            f.write("\t\t{%d,%d,%s,{%s},%s,\"%s\"%s},\n" % (t["npc"], t["fac"], L(sp), rk, L(rc), nm, ",1" if t["inside"] else ""))
        f.write("\t},\n")
    f.write("}\n")
    if EXTRA:
        f.write("-- 보조 훈련사 (QuestieDB 포에버 합본 · GPL-3.0 · NPC 직함으로 고름): [기술] = { {NPC, 진영, 지도, x, y, 가르치는 최고 단계, 영어 이름} }\n")
        f.write("ns.PROF_TRAINERS_EXTRA = {\n")
        main = {(p_, n_) for (p_, n_) in trainers}
        for prof in sorted(EXTRA):
            f.write("\t[%d] = {\n" % prof)
            for e in sorted(EXTRA[prof]):
                if (prof, e[0]) in main: continue
                f.write('\t\t{%d,%d,%d,%s,%s,%d,"%s"},\n' % e)
            f.write("\t},\n")
        f.write("}\n")
import collections
cnt = collections.Counter()
for (prof, npc), t in trainers.items():
    for r in t["ranks"]: cnt[(prof, r)] += 1
print("trainers:", len(trainers), "profs:", sorted(by_prof))
for prof in sorted(by_prof):
    print(prof, [ (r, cnt[(prof, r)]) for r in (1,2,3,4) ], "recipes max", max((len(t["recipes"]) for t in by_prof[prof]), default=0))
