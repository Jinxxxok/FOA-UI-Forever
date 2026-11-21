#!/usr/bin/env python3
"""
제작 장비 제조법은 어디서 나오나 (상인 · 드랍 · 퀘스트 · 상자 · 훈련사) → FOA_UI/RecipeSources.lua
 BIS 툴팁에 "제조법은 상인이 팔지 않아요" 만 나오던 것을 실제 출처로 채운다.

 자료
  · QuestieDB (GPL-3.0) 포에버 합본: 제조법 아이템의 상인 · 드랍 NPC · 상자 · 퀘스트 보상 · 가르치는 주문
      (합본 만들기: tools/quests/questie_export.py)
  · AllTheThings (MIT): profession db (제조법 아이템 → 주문) · 수집기 원본(포에버 아이템 · 주문 이름, 주문 → 전문기술)
      · 평판 조건(minReputation)
  · FOA_UI/ForeverCrafts.lua (제작 장비 → 주문) · ProfessionTrainers.lua (훈련사가 가르치는 주문) · RecipeVendors.lua

 사용: python3 -I gen_sources.py <QuestieDB 폴더> <ATT 폴더> <FOA_UI 폴더> <출력.lua>
"""
import os, re, sys, glob, json
from collections import Counter
from lupa import lua51

qdb, att, foa, out = sys.argv[1:5]
HARV = os.path.join(att, ".contrib", "Harvesters", "Database Harvester", "Raw - Forever")


def rt():
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    L.execute("os = nil; io = nil; dofile = nil; loadfile = nil; require = nil")
    return L


def py(v):
    if v is None or isinstance(v, (int, float, str, bool)):
        return v
    try:
        ks = list(v.keys())
    except AttributeError:
        return v
    if ks and all(isinstance(k, int) for k in ks) and sorted(ks) == list(range(1, len(ks) + 1)):
        return [py(v[k]) for k in range(1, len(ks) + 1)]
    return {k: py(v[k]) for k in ks}


comb = os.path.join(qdb, "src", "corrections", "Forever", "combined")
L = rt()
ITEMS = L.execute(open(os.path.join(comb, "foreverItemDB.lua"), encoding="utf-8").read())
NPCS = L.execute(open(os.path.join(comb, "foreverNpcDB.lua"), encoding="utf-8").read())
OBJS = L.execute(open(os.path.join(comb, "foreverObjectDB.lua"), encoding="utf-8").read())
QUESTS = L.execute(open(os.path.join(comb, "foreverQuestDB.lua"), encoding="utf-8").read())

# 지역 번호 → 지도 번호
zsrc = open(os.path.join(qdb, "support", "Forever", "Zones", "areaIdToUiMapId.lua"), encoding="utf-8").read()
AREA = {}
for marker in ("ZoneDB.private.areaIdToUiMapId = [[", "ZoneDB.private.areaIdToUiMapIdOverride = [["):
    i = zsrc.find(marker)
    if i < 0:
        continue
    j = zsrc.find("]]", i)
    t = rt().execute(zsrc[i + len(marker):j])
    for k in t.keys():
        if marker.endswith("Override = [[") or int(k) not in AREA:
            AREA[int(k)] = int(t[k])


def harv(name):
    d = {}
    for line in open(os.path.join(HARV, name), encoding="utf-8-sig"):
        if "@@@" in line:
            a, b = line.rstrip("\n").split("@@@", 1)
            if a.isdigit():
                d[int(a)] = b
    return d


ITEM_NAME = harv("Items.txt")
for k in ITEMS.keys():          # 수집기에 없는 옛 아이템 이름은 Questie 에서
    row = ITEMS[k]
    if row is not None and row[1] and int(k) not in ITEM_NAME:
        ITEM_NAME[int(k)] = row[1]
SPELL_NAME = harv("SpellNames.txt")
SPELL_SKILL = {k: int(v) for k, v in harv("Recipes.txt").items() if v.isdigit()}

# 제작 장비 (ForeverCrafts.lua): { 아이템, 전문기술(1대장 2가죽 3재봉 4기계 5마부), 주문, 숙련 }
CRAFT_SKILL = {1: 164, 2: 165, 3: 197, 4: 202, 5: 333}
crafts = {}
for m in re.finditer(r"\{(\d+),(\d+),(\d+),(\d+)\}", open(os.path.join(foa, "ForeverCrafts.lua"), encoding="utf-8").read()):
    it, p, sp, tr = map(int, m.groups())
    crafts[sp] = (it, CRAFT_SKILL.get(p), tr)

# 훈련사가 가르치는 주문
trainer = set()
src = open(os.path.join(foa, "ProfessionTrainers.lua"), encoding="utf-8").read()
for m in re.finditer(r",\{([0-9,]*)\},\"", src):     # 각 훈련사 줄의 제조법 { 주문, 숙련, ... } (영어 이름 바로 앞)
    nums = [int(x) for x in m.group(1).split(",") if x]
    trainer.update(nums[0::2])

# 이미 상인 자료가 있는 제조법 (RecipeVendors.lua) → 상인은 그쪽을 쓴다
vend_known = {}
for m in re.finditer(r"\[(\d+)\] = \{ \"[^\"]+\", (\d+),", open(os.path.join(foa, "RecipeVendors.lua"), encoding="utf-8").read()):
    vend_known[int(m.group(1))] = int(m.group(2))

# 제조법 아이템 → 주문
RECIPE_SUB = {1: 165, 2: 197, 3: 202, 4: 164, 5: 185, 6: 171, 7: 129, 8: 333, 9: 356}
teach = {}      # 아이템 → 주문
for k in ITEMS.keys():
    row = ITEMS[k]
    if row[12] == 9 and row[16]:
        teach[int(k)] = int(row[16])
for f in glob.glob(os.path.join(att, ".contrib", ".db", "forever", "profession db", "*.lua")):
    for m in re.finditer(r"^i\((\d+),\s*(\d+)(?:,[^)]*)?\);", open(f, encoding="utf-8").read(), re.M):
        it, sp = int(m.group(1)), int(m.group(2))
        if it > 0:
            teach.setdefault(it, sp)
for it, sp in vend_known.items():
    teach.setdefault(it, sp)
# 이름으로 잇기: "도안: 무법자의 목장식" ↔ 주문 "무법자의 목장식" (같은 전문기술 안에서만)
PFX = ("Pattern: ", "Plans: ", "Schematic: ", "Formula: ", "Recipe: ", "Manual: ", "Design: ")
by_name = {}
for sp, (it, sk, tr) in crafts.items():
    nm = SPELL_NAME.get(sp)
    if nm:
        by_name.setdefault((nm, sk), []).append(sp)
named = 0
for it, nm in ITEM_NAME.items():
    if it in teach:
        continue
    for p in PFX:
        if nm.startswith(p):
            base = nm[len(p):]
            row = ITEMS[it]
            sk = RECIPE_SUB.get(row[13]) if row else None
            cands = []
            for (n2, sk2), sps in by_name.items():
                if n2 == base and (sk is None or sk2 == sk):
                    cands += sps
            if len(cands) == 1:
                teach[it] = cands[0]
                named += 1
            break
# 이름을 모르는 새 주문(시즌 · 포에버 번호): 제조법 아이템 번호가 만든 아이템 + 1 이고 이름이 "도안: …" 이면 잇는다
taken = set(teach)
have = set(teach.values())
for sp, (it, sk, tr) in crafts.items():
    if sp in have:
        continue
    r = it + 1
    nm = ITEM_NAME.get(r)
    if r in taken or not nm or not nm.startswith(PFX):
        continue
    base = nm.split(": ", 1)[1]
    cn = ITEM_NAME.get(it) or SPELL_NAME.get(sp)
    row = ITEMS[r]
    sk2 = RECIPE_SUB.get(row[13]) if row is not None else None
    if (cn is None or cn == base) and (sk2 is None or sk2 == sk):
        teach[r] = sp
        named += 1
recipes_of = {}
for it, sp in teach.items():
    if sp in crafts:
        recipes_of.setdefault(sp, []).append(it)

# 평판 조건 (ATT: minReputation={진영, 값})
rep = {}
for f in glob.glob(os.path.join(att, "db", "*", "Categories", "*.lua")):
    if "/Camelot/" not in f and "/Vanilla/" not in f and "/TBC/" not in f:
        continue
    txt = open(f, encoding="utf-8", errors="ignore").read()
    for m in re.finditer(r"itemID=(\d+)[^)]{0,300}?minReputation=\{(\d+),(\d+)\}", txt):
        it = int(m.group(1))
        if it not in rep or "/Camelot/" in f:
            rep[it] = (int(m.group(2)), int(m.group(3)))
    for m in re.finditer(r"\bi\((\d+),\{[^)]{0,300}?minReputation=\{(\d+),(\d+)\}", txt):
        it = int(m.group(1))
        if it not in rep or "/Camelot/" in f:
            rep[it] = (int(m.group(2)), int(m.group(3)))


def zmap(t):
    """지역 → 좌표 목록 (lua 표를 그대로 dict 로: 지역 번호가 1,2,3.. 이어도 목록으로 바뀌지 않게)"""
    if t is None:
        return {}
    return {int(k): (py(t[k]) or []) for k in t.keys()}


# ATT 컴파일 자료에서 제조법 아이템이 놓인 자리: 던전(inst) · 지역(m) · 몹(n / crs) · 퀘스트(q) · 월드 드랍
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quests"))
import att_parse
ATT_CTX = {}


def att_walk(node, ctx):
    if isinstance(node, list):
        for c in node:
            att_walk(c, ctx)
        return
    if isinstance(node, dict):
        for k in ("g", "__arr"):
            if k in node:
                att_walk(node[k], ctx)
        return
    if not (isinstance(node, tuple) and node[0] == "call"):
        return
    nm, a = node[1], node[2]
    b = a[-1] if a and isinstance(a[-1], dict) else {}
    c = dict(ctx)
    if nm == "inst":
        mp = b.get("maps")
        c["map"] = mp[0] if isinstance(mp, list) and mp else c.get("map")
        c["inst"] = 1
        c["npcs"] = None
    elif nm == "m" and a and isinstance(a[0], int):
        c["map"] = a[0]
        c["npcs"] = None
    elif nm in ("n", "h", "e") and a and isinstance(a[0], int):
        if nm == "n" and a[0] > 0:
            c["npcs"] = [a[0]]
        elif isinstance(b.get("crs"), list):
            c["npcs"] = [x for x in b["crs"] if isinstance(x, int)]
        if nm == "n" and a[0] < 0:
            c["hdr"] = a[0]
    elif nm == "q" and a and isinstance(a[0], int):
        c["quest"] = a[0]
    if nm in ("r", "i") and a:
        iid = int(b.get("itemID", 0) or 0) if nm == "r" else (a[0] if isinstance(a[0], int) else 0)
        if iid and iid not in ATT_CTX:
            cc = dict(c)
            # 상인이 파는 것: 값(cost) · 수량 한정(isLimited) 이 붙어 있다
            if b.get("cost") is not None or b.get("isLimited"):
                cc["vendor"] = 1
            ATT_CTX[iid] = cc
    kids = a[-1] if a and isinstance(a[-1], list) else (b.get("g") or []) + (b.get("__arr") or [])
    att_walk(kids, c)


for ver in ("Camelot", "Vanilla"):
    for cat, key in (("Instances", "Instances"), ("Zones", "Zones"), ("WorldDrops", "WorldDrops"), ("ExpansionFeatures", "ExpansionFeatures")):
        fp = os.path.join(att, "db", ver, "Categories", cat + ".lua")
        if not os.path.exists(fp):
            continue
        try:
            tree = att_parse.parse(open(fp, encoding="utf-8-sig").read(), key)
        except Exception as ex:
            print("ATT parse fail", ver, cat, ex)
            continue
        before = len(ATT_CTX)
        att_walk(tree, {"cat": cat})
        print("ATT", ver, cat, len(ATT_CTX) - before)


def npc_spot(n):
    row = NPCS[n]
    if row is None:
        return None
    sp = zmap(row[7])
    zone = row[9]
    best = None
    for z, pts in sp.items():
        um = AREA.get(int(z))
        if not um:
            continue
        cnt = len(pts) if isinstance(pts, list) else 0
        if best is None or cnt > best[3]:
            p = pts[0] if pts else [-1, -1]
            best = (um, p[0], p[1], cnt)
    if best is None and zone:
        um = AREA.get(int(zone))
        if um:
            best = (um, -1, -1, 0)
    return best


def fac(n):
    row = NPCS[n]
    f = row and row[13]
    return 0 if f in (None, "AH") else (1 if f == "H" else 2)


def lvl(n):
    row = NPCS[n]
    if not row:
        return 0, 0
    return int(row[4] or 0), int(row[5] or 0)


def obj_spot(o):
    row = OBJS[o]
    if row is None:
        return None
    sp = zmap(row[4])
    best = None
    for z, pts in sp.items():
        um = AREA.get(int(z))
        if um and (best is None or len(pts) > best[3]):
            p = pts[0] if pts else [-1, -1]
            best = (um, p[0], p[1], len(pts))
    return best


def r1(v):
    return -1 if v is None or v < 0 else round(float(v), 1)


DROP_LIST_MAX = 4      # 이보다 많은 몹이 떨구면 "여러 몹 (월드 드랍)"
rows = {}
stat = Counter()
for sp, (it, sk, tr) in sorted(crafts.items()):
    recs = recipes_of.get(sp, [])
    e = {}
    if sp in trainer:
        e["t"] = 1
    if not recs:
        if not e:
            stat["no recipe item"] += 1
            continue
        rows[sp] = e
        stat["trainer"] += 1
        continue
    rec = recs[0]
    # 출처가 있는 제조법 아이템을 고른다 (같은 주문을 가르치는 아이템이 여럿일 때)
    def has_src(r):
        row = ITEMS[r]
        return row is not None and any(row[i] for i in (2, 3, 6, 14))
    for r in recs:
        if has_src(r):
            rec = r
            break
    e["r"] = rec
    row = ITEMS[rec]
    if rec in rep:
        e["rep"] = rep[rec]
    if row is not None:
        vend = py(row[14]) or []
        drops = py(row[2]) or []
        objs = py(row[3]) or []
        qs = py(row[6]) or []
        ids = py(row[4]) or []
        if ids:
            e["i"] = ids[:3]
        if vend and rec not in vend_known:
            vl = []
            for n in vend:
                s = npc_spot(n)
                if s:
                    vl.append([n, s[0], r1(s[1]), r1(s[2]), fac(n)])
            if vl:
                e["v"] = vl
        elif rec in vend_known:
            e["vk"] = 1
        if drops:
            if len(drops) <= DROP_LIST_MAX:
                dl = []
                for n in drops:
                    s = npc_spot(n)
                    lo, hi = lvl(n)
                    dl.append([n, s[0] if s else 0, lo, hi])
                e["d"] = dl
            else:
                zc = Counter()
                los, his = [], []
                for n in drops:
                    s = npc_spot(n)
                    if s:
                        zc[s[0]] += 1
                    lo, hi = lvl(n)
                    if lo:
                        los.append(lo)
                        his.append(hi)
                los.sort(); his.sort()
                # 몹 레벨 범위: 아주 동떨어진 몇 마리는 빼고 (가운데 80%)
                k = len(los) // 10
                lo = los[k] if los else 0
                hi = his[-1 - k] if his else 0
                e["w"] = [len(drops), lo, hi, [z for z, _ in zc.most_common(3)]]
        if objs:
            ol = []
            for o in objs[:3]:
                s = obj_spot(o)
                ol.append([o, s[0] if s else 0])
            e["o"] = ol
        if qs:
            e["q"] = qs[:3]
    # Questie 에 출처가 없으면 ATT 맥락으로 (던전 보스 · 일반 몹 · 지역 · 월드 드랍 · 퀘스트)
    if not any(k in e for k in ("v", "vk", "d", "w", "o", "q", "i")):
        c = ATT_CTX.get(rec)
        if c:
            if c.get("cat") == "WorldDrops":
                e["w"] = [0, 0, 0, []]
            elif c.get("quest"):
                e["q"] = [c["quest"]]
            elif c.get("npcs") and c.get("vendor"):
                vl = []
                for n in c["npcs"][:3]:
                    sp_ = npc_spot(n)
                    vl.append([n, (sp_[0] if sp_ else (c.get("map") or 0)), r1(sp_[1]) if sp_ else -1, r1(sp_[2]) if sp_ else -1, fac(n)])
                e["v"] = vl
            elif c.get("npcs"):
                dl = []
                for n in c["npcs"][:DROP_LIST_MAX]:
                    sp_ = npc_spot(n)
                    lo, hi = lvl(n)
                    dl.append([n, (c.get("map") or (sp_[0] if sp_ else 0)), lo, hi])
                e["d"] = dl
                if len(c["npcs"]) > DROP_LIST_MAX:
                    e["dn"] = len(c["npcs"])
            elif c.get("map"):
                e["z"] = [c["map"], 1 if c.get("inst") else 0]
            e["att"] = 1
    kinds = [k for k in ("t", "v", "vk", "d", "w", "o", "q", "i", "z") if k in e]
    stat["+".join(kinds) or "unknown"] += 1
    rows[sp] = e


def lua(v):
    if isinstance(v, list):
        return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, tuple):
        return lua(list(v))
    if isinstance(v, float):
        s = ("%.1f" % v).rstrip("0").rstrip(".")
        return s
    return str(v)


with open(out, "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 제작 장비 제조법 출처 (자동 생성 · tools/recipes/gen_sources.py)\n")
    f.write("-- 자료: QuestieDB (GPL-3.0) 포에버 합본 · AllTheThings (MIT) · FOA 제작 · 훈련사 자료\n")
    f.write("-- [주문] = { r = 제조법 아이템, t = 훈련사, vk = RecipeVendors.lua 에 상인 있음, v = { {상인, 지도, x, y, 진영} },\n")
    f.write("--   d = { {몹, 지도, 최저 레벨, 최고 레벨} }, w = { 떨구는 몹 수, 레벨 낮음, 높음, {지도...} } (여러 몹 · 월드 드랍),\n")
    f.write("--   dn = 떨구는 보스 · 몹 수(d 보다 많을 때), o = { {상자, 지도} }, i = { 들어 있는 아이템 }, q = { 퀘스트 },\n")
    f.write("--   z = { 지도, 던전이면 1 } (그 지역 · 던전 어디서나), rep = { 평판 진영, 값 } }   r 만 있으면 아직 출처가 안 밝혀진 제조법\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\n")
    f.write("ns.RECIPE_SRC = {\n")
    for sp in sorted(rows):
        e = rows[sp]
        parts = []
        for k in ("r", "t", "vk", "v", "d", "dn", "w", "o", "i", "q", "z", "rep"):
            if k in e:
                parts.append("%s=%s" % (k, lua(e[k])))
        f.write("\t[%d] = { %s },\n" % (sp, ", ".join(parts)))
    f.write("}\n")

print("crafts", len(crafts), "rows", len(rows), "name-matched", named)
for k, v in stat.most_common():
    print("  %-20s %d" % (k, v))
