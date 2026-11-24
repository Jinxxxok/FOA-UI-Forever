#!/usr/bin/env python3
"""
던전 세트 2 (0.5티) 연계 퀘스트 → FOA_UI/T05Data.lua

자료:
  AllTheThings (MIT) .contrib/.db/forever/dungeons & raids/0.5 - dungeon sets.lua
    직업별 강화 4단계(퀘스트 · 내야 하는 0티 장비 · 골드 · 받는 0.5티 장비) · 공통 연계 퀘스트(직업별 갈래 포함) · 필요 재료
  QuestieDB (GPL-3.0) 포에버 합본
    퀘스트 한글 이름 · 목표 글 · 주는 NPC 와 자리(포에버 지도 기준) · NPC 한글 이름
    (ATT 의 동부 역병지대 좌표는 옛 지도 기준이라 NPC 자리는 QuestieDB 를 쓴다)

사용: python3 -I gen_t05.py <ATT 0.5 파일> <QuestieDB 폴더> <출력 T05Data.lua>
"""
import os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quests"))
import questie_data
from lupa import lua51

ATT, QDB, OUT = sys.argv[1:4]
src = open(ATT, encoding="utf-8").read()

# ── ATT 파일을 그대로 실행 (도움 함수는 표를 돌려주는 흉내) ──
L = lua51.LuaRuntime(unpack_returned_tuples=True)
L.execute("""
os = nil; io = nil; dofile = nil; loadfile = nil; require = nil
local function auto() return setmetatable({}, { __index = function(_, k) return k end }) end
MAP = auto(); TIMELINE = auto(); ROOTS = auto()
setmetatable(_G, { __index = function(_, k) return k end })
function q(id, t) t = t or {}; t.questID = id; return t end
function i(id, t) t = t or {}; t.itemID = id; return t end
function objective(n, t) t = t or {}; t.objective = n; return t end
function cl(c, g) return { cls = c, groups = g } end
function n(h, g) return { header = h, groups = g } end
function ach(id, t) return { ach = id } end
function root(r, t) RESULT = t end
""")
L.execute(src)
R = L.globals().RESULT


def py(v):
    if v is None or isinstance(v, (int, float, str, bool)):
        return v
    keys = list(v.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [py(v[k]) for k in range(1, len(keys) + 1)]
    return {k: py(v[k]) for k in keys}


root = py(R)
root = root.get("groups") if isinstance(root, dict) else root   # root(ROOTS.Instances, n(0.5 세트, { … }))

# 목표 개수는 주석에만 있다 ("objective(1, {	-- 0/25 Ogre Warbeads" 다음 줄 provider = { "i", 21982 })
COUNT = {}
for m in re.finditer(r'objective\(\d+,\s*\{\s*--\s*0/(\d+)[^\n]*\n\s*providers?\s*=\s*\{\s*\{?\s*"i",\s*(\d+)', src):
    COUNT[int(m.group(2))] = int(m.group(1))

Q, N, O, AREA = questie_data.load(QDB)


def lookup(kind):
    out = {}
    L2 = lua51.LuaRuntime(unpack_returned_tuples=True)
    for path in (os.path.join(QDB, "l10n", "Forever", kind, "koKR.lua"),
                 os.path.join(QDB, "l10n", "Forever", "traces", kind, "koKR.lua")):
        if not os.path.exists(path):
            continue
        s = open(path, encoding="utf-8").read()
        a, b = s.find("[[return {"), s.rfind("}]]")
        t = L2.execute(s[a + 2:b + 1])
        for k in t.keys():
            out[int(k)] = py(t[k])
    return out


KQ, KN, KI = lookup("lookupQuests"), lookup("lookupNpcs"), lookup("lookupItems")
npcs = L.execute(open(os.path.join(QDB, "src", "corrections", "Forever", "combined", "foreverNpcDB.lua"), encoding="utf-8").read())

CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"]
UP_NAME = {"An Earnest Proposition": 1, "Just Compensation": 2, "Anthion's Parting Words": 3, "Saving the Best for Last": 4}
# 공통 줄 순서 (영어 이름 · 같은 칸이면 묶음)
ORDER = [
    ("up", 1),
    ("A Supernatural Device",), ("The Ectoplasmic Distiller",), ("Hunting for Ectoplasm",), ("A Portable Power Source",),
    ("A Shifty Merchant",), ("Return to Deliana", "Return to Mokvar"),
    ("up", 2),
    ("In Search of Anthion",), ("Dead Man's Plea",), ("Proof of Life",), ("Anthion's Strange Request",), ("Anthion's Old Friend",),
    ("Falrin's Vendetta",), ("The Instigator's Enchantment",), ("The Challenge",),
    ("up", 3),
    ("Bodley's Unfortunate Fate",), ("Three Kings of Flame",), ("Components of Importance",),
    ("The Left Piece of Lord Valthalak's Amulet",), ("I See Alcaz Island In Your Future...",), ("More Components of Importance",),
    ("The Right Piece of Lord Valthalak's Amulet",), ("Final Preparations",), ("Mea Culpa, Lord Valthalak",), ("Return to Bodley",),
    ("Back to the Beginning",),
    ("up", 4),
]


# 포에버 새 퀘스트(얼라이언스 주술사 · 호드 성기사 갈래 97xxx)는 QuestieDB 에 이름이 없다 → ATT 주석 이름
ATT_NAME = {}
for m in re.finditer(r'q\((\d+)[^\n]*?--\s*([^\[\n]+?)\s*(?:\[|$)', src, re.M):
    ATT_NAME.setdefault(int(m.group(1)), m.group(2).strip())


def qname(qid):
    r = Q.get(qid)
    return (r[0] if r and r[0] else None) or ATT_NAME.get(qid)


def items_of(node):
    """{ 아이템 = 개수 } : cost + 목표 provider"""
    out = {}
    for c in (node.get("cost") or []):
        if isinstance(c, list) and c and c[0] == "i":
            out[int(c[1])] = int(c[2] if len(c) > 2 else 1)
    for g in (node.get("groups") or []):
        if isinstance(g, dict) and "objective" in g:
            prov = g.get("provider")
            provs = [prov] if prov else (g.get("providers") or [])
            for p in provs:
                if isinstance(p, list) and p and p[0] == "i":
                    out[int(p[1])] = COUNT.get(int(p[1]), out.get(int(p[1]), 1))
    return out


def gold_of(node):
    for c in (node.get("cost") or []):
        if isinstance(c, list) and c and c[0] == "g":
            return int(c[1])
    return 0


def rewards_of(node):
    return [int(g["itemID"]) for g in (node.get("groups") or []) if isinstance(g, dict) and "itemID" in g and "objective" not in g]


def variants(entry):
    """ATT 항목 → [(퀘스트, 진영 0/1/2, 합친 정보)]"""
    out = []
    if "allianceQuestData" in entry or "hordeQuestData" in entry:
        for key, fac in (("allianceQuestData", 2), ("hordeQuestData", 1)):
            sub = entry.get(key)
            if not isinstance(sub, dict):
                continue
            merged = dict(entry)
            merged.pop("allianceQuestData", None); merged.pop("hordeQuestData", None)
            for k, v in sub.items():
                if k in ("cost", "groups") and k in merged and isinstance(v, list):
                    merged[k] = list(merged[k]) + v
                else:
                    merged[k] = v
            out.append((int(sub["questID"]), fac, merged))
    elif "questID" in entry:
        races = entry.get("races")
        fac = 2 if races == "ALLIANCE_ONLY" else (1 if races == "HORDE_ONLY" else 0)
        out.append((int(entry["questID"]), fac, entry))
    return out


# ── 직업별 강화 4단계 ──
CLS = {}
SHARED = []
for block in root:
    if not isinstance(block, dict):
        continue
    if block.get("cls"):
        c = block["cls"]
        ups = CLS.setdefault(c, {})
        for e in block["groups"] or []:
            for qid, fac, node in variants(e):
                u = UP_NAME.get(qname(qid))
                if not u:
                    print("모르는 직업 퀘스트", c, qid, qname(qid)); continue
                d = ups.setdefault(u, {"q": {}, "cost": {}, "gold": 0, "reward": [], "giver": {}})
                d["q"][fac] = qid
                d["cost"][fac] = items_of(node)   # 진영마다 재료가 다르다 (얼라: 여명의 설원 혈액 견본 · 호드: 실리시드 독 견본)
                d["gold"] = d["gold"] or gold_of(node)
                d["reward"] = d["reward"] or rewards_of(node)
                d["giver"][fac] = node.get("qg")
    elif block.get("header") == "QUESTS":
        for e in block["groups"] or []:
            SHARED.extend(variants(e))

# ── 포에버 실제 강화 퀘스트: 시즌 오브 디스커버리식 84147~84210 (델리아나 230319 · 모크바르 230317) ──
#  ATT 포에버 자료는 옛 클래식 번호(8905~9013)라 그대로 쓰면 끝낸 퀘스트를 못 알아본다.
#  QuestieDB 포에버 기록(traces)에 델리아나 230319 가 84147~84154 를 주고받는 게 남아 있다 · 직업은 QuestieDB SoD 보정 파일
SOD_RANGE = {(1, 2): range(84147, 84155), (1, 1): range(84155, 84163), (2, 2): range(84163, 84171), (2, 1): range(84171, 84179),
             (3, 2): range(84179, 84187), (3, 1): range(84187, 84195), (4, 2): range(84195, 84203), (4, 1): range(84203, 84211)}
sod_src = open(os.path.join(QDB, "src", "corrections", "Sod", "sodQuestFixes.lua"), encoding="utf-8").read()
SOD_CLS = {}
# 블록마다 (다음 항목으로 넘어가 읽지 않게) · 블록에 직업이 없으면(84150 등) QuestieDB 합본의 직업 비트
for m in re.finditer(r"\[(84[12]\d\d)\] = \{[^\n]*\n(.*?)\n        \},", sod_src, re.S):
    c = re.search(r"requiredClasses\] = classIDs\.(\w+)", m.group(2))
    if c:
        SOD_CLS[int(m.group(1))] = c.group(1)
BIT = {1: "WARRIOR", 2: "PALADIN", 4: "HUNTER", 8: "ROGUE", 16: "PRIEST", 64: "SHAMAN", 128: "MAGE", 256: "WARLOCK", 1024: "DRUID"}
for qid in range(84147, 84211):
    r = Q.get(qid)
    if qid not in SOD_CLS and r and r[6] in BIT:
        SOD_CLS[qid] = BIT[r[6]]
SOD = {}
for (u, fac), rng in SOD_RANGE.items():
    for qid in rng:
        c = SOD_CLS.get(qid)
        if c:   # QuestieDB 합본에 빠진 번호(84207 등)도 SoD 보정 파일에 직업이 있으면 쓴다
            SOD[(c, u, fac)] = qid
print("SoD 강화 퀘스트", len(SOD))

# 보상: 포에버는 특성별로 고르는 새 0.5티 (226xxx) · 직업마다 묶음 1~4개 (8부위씩) · 맨 끝 이름 없는 묶음(Wrists · Waist …)은 안 줌
ITEMDB = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(ATT))), ".config", "exports", "ItemDB.lua")
TOKEN = {"DRUID": "Feralheart", "HUNTER": "Beastmaster", "MAGE": "Sorcerer", "PALADIN": "Soulforge", "PRIEST": "Virtuous",
         "ROGUE": "Darkmantle", "SHAMAN": "Five Thunders", "WARLOCK": "Deathmist", "WARRIOR": "Heroism"}
GENERIC = {"Wrists", "Waist", "Shoulders", "Legs", "Helm", "Gloves", "Boots", "Chest"}
UP_SLOTS = {1: [9], 2: [6, 10], 3: [8, 7, 3], 4: [1, 5]}
idb = open(ITEMDB, encoding="utf-8").read()
SETITEMS = {c: [] for c in TOKEN}
for m in re.finditer(r'^\[(\d+)\]=\{([^\n]*)\}', idb, re.M):
    iid = int(m.group(1))
    if not (226700 <= iid <= 227100):
        continue
    nm = re.search(r'name="([^"]*)"', m.group(2))
    it = re.search(r'inventoryType=(\d+)', m.group(2))
    if not (nm and it):
        continue
    for c, tok in TOKEN.items():
        if tok in nm.group(1):
            inv = int(it.group(1))
            SETITEMS[c].append((iid, 5 if inv == 20 else inv, nm.group(1)))
BLOCKS = {}
for c, lst in SETITEMS.items():
    lst.sort()
    blocks = [lst[i:i + 8] for i in range(0, len(lst), 8)]
    keep = []
    for b in blocks:
        words = {w for _, _, n in b for w in n.replace("of The Five Thunders", "").replace("of Heroism", "").split() if w in GENERIC}
        if len(words) >= 6:
            continue   # 이름 없는 묶음
        keep.append({inv: iid for iid, inv, _ in b})
    BLOCKS[c] = keep
print("보상 묶음", {c: len(b) for c, b in BLOCKS.items()})

# 공통 줄: 영어 이름 → 변형들
by_name = {}
for qid, fac, node in SHARED:
    by_name.setdefault(qname(qid), []).append((qid, fac, node))

# ── NPC 자리 (QuestieDB 포에버 · 첫 자리) ──
NPCS = {}
def npc(nid):
    if not nid:
        return
    nid = int(nid)
    if nid in NPCS:
        return
    r = npcs[nid]
    m, x, y = 0, -1, -1
    if r is not None and r[7]:
        sp = r[7]
        # 이 NPC 의 지역(zoneID) 자리 먼저 · 지역 번호 없이 들어 있는 자리(포에버 새 NPC 의 [1])는 뒤로
        keys = sorted(sp.keys(), key=lambda a: (0 if a == r[9] else (2 if a not in AREA else 1)))
        for a in keys:
            pts = sp[a]
            if pts and pts[1]:
                m = AREA.get(int(a), int(a)) if a else 0
                x, y = float(pts[1][1]), float(pts[1][2])
                if x > 0:
                    break
    ko = KN.get(nid)
    name = (ko[0] if isinstance(ko, list) else ko) if ko else (r[1] if r is not None else str(nid))
    NPCS[nid] = (name, m or 0, round(x, 1), round(y, 1))


def ender_of(qid):
    r = Q.get(qid)
    fin = r and r[2]
    lst = (fin[0] if isinstance(fin, list) else (fin or {}).get(1)) if fin else None
    e = lst[0] if lst else None
    if e:
        e = FOREVER_NPC.get(int(e), int(e))
        npc(e)
    return int(e) if e else 0


FOREVER_NPC = {16013: 230319, 16012: 230317}   # 포에버에서 실제로 퀘스트를 주고받는 델리아나 · 모크바르 (QuestieDB 기록)


def giver_of(qid, node):
    g = node.get("qg")
    if not g:
        r = Q.get(qid)
        st = r and r[1]
        lst = (st[0] if isinstance(st, list) else (st or {}).get(1)) if st else None
        g = lst[0] if lst else None
    if g:
        g = FOREVER_NPC.get(int(g), int(g))
        npc(g)
    return int(g) if g else 0


KO_BY_EN = {}
for _qid, _v in KQ.items():
    _en = qname(_qid)
    if _en and isinstance(_v, list) and _v and _en not in KO_BY_EN:
        KO_BY_EN[_en] = _v


def ko_quest(qid):
    v = KQ.get(qid)
    if not v:
        # 포에버 새 갈래(97xxx)는 같은 영어 이름 퀘스트의 한글 제목만 (목표 글은 다른 직업 장비 이름이라 안 쓴다)
        alt = KO_BY_EN.get(qname(qid))
        return (alt[0] if alt else (qname(qid) or str(qid))), ""
    title = v[0] if isinstance(v, list) else v
    obj = ""
    if isinstance(v, list) and len(v) > 1 and v[1]:
        o = v[1]
        obj = " ".join(x for x in (o if isinstance(o, list) else [o]) if isinstance(x, str))
    return title, obj


def q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


QTXT = {}
steps = []
for key in ORDER:
    if key[0] == "up":
        steps.append("\t\t{ up = %d },\n" % key[1])
        continue
    vs = []
    for nm in key:
        vs.extend(by_name.get(nm, []))
    if not vs:
        print("!! 공통 퀘스트 없음", key); continue
    parts = []
    for qid, fac, node in sorted(vs, key=lambda x: x[0]):
        giver = giver_of(qid, node)
        QTXT[qid] = ko_quest(qid)
        cls = node.get("classes")
        its = items_of(node)
        gold = gold_of(node)
        f = ["q = %d" % qid, "fac = %d" % fac, "npc = %d" % giver]
        e = ender_of(qid)
        if e and e != giver:
            f.append("e = %d" % e)
        if cls:
            f.append("cls = { %s }" % ", ".join(q(c) for c in cls))
        if its:
            f.append("items = { %s }" % ", ".join("{ %d, %d }" % (k, v) for k, v in its.items()))
        if gold:
            f.append("gold = %d" % gold)
        parts.append("{ " + ", ".join(f) + " }")
    steps.append("\t\t{ %s },\n" % ", ".join(parts))

cls_out = []
for c in CLASSES:
    ups = CLS.get(c, {})
    rows = []
    for u in (1, 2, 3, 4):
        d = ups.get(u)
        if not d:
            print("!! 직업 단계 없음", c, u); continue
        for fac, qid in d["q"].items():
            QTXT[qid] = ko_quest(qid)
        # 강화 퀘스트 NPC: 진영별로 다르다 (델리아나 · 모크바르 · 안시온) → ATT qg, 없으면 QuestieDB 시작 NPC
        givers = {}
        for fac, qid in d["q"].items():
            givers[fac] = giver_of(qid, {"qg": d["giver"].get(fac)})
        def pick(t, fac):
            return t.get(fac, t.get(0))
        def costs(fac):
            c = pick(d["cost"], fac) or {}
            return ", ".join("{ %d, %d }" % (k, v) for k, v in c.items())
        enders = {fac: ender_of(qid) for fac, qid in d["q"].items()}
        # 포에버 번호: SoD 84xxx (얼라 주술사 · 호드 성기사는 ATT 의 97xxx 그대로)
        qA0, qH0 = pick(d["q"], 2) or 0, pick(d["q"], 1) or 0
        qA = SOD.get((c, u, 2), qA0) if qA0 < 90000 else qA0
        qH = SOD.get((c, u, 1), qH0) if qH0 < 90000 else qH0
        for fq, oq in ((qA, qA0), (qH, qH0)):
            if fq != oq:
                QTXT[fq] = QTXT.get(oq) or ko_quest(oq)   # 같은 직업 · 진영의 옛 퀘스트 한글 제목 · 목표
        # 주는 NPC: 델리아나 230319 · 모크바르 230317 / 안시온의 작별 인사는 안시온이 주고 델리아나 · 모크바르에게 보고
        nA, nH = (16016, 16016) if u == 3 else (230319, 230317)
        eA, eH = 230319, 230317
        for x in (nA, nH, eA, eH):
            npc(x)
        rw = []
        for b in BLOCKS.get(c, []):
            rw.append("{ " + ", ".join(str(b[inv]) for inv in UP_SLOTS[u] if inv in b) + " }")
        rows.append("\t\t\t[%d] = { A = %d, H = %d, A0 = %d, H0 = %d, nA = %d, nH = %d, eA = %d, eH = %d, costA = { %s }, costH = { %s }, gold = %d, reward = { %s }, old = { %s } },\n" % (
            u, qA, qH, qA0, qH0, nA, nH, eA, eH, costs(2), costs(1), d["gold"], ", ".join(rw), ", ".join(map(str, d["reward"]))))
    cls_out.append("\t\t%s = {\n%s\t\t},\n" % (c, "".join(rows)))

# 아이템 한글 이름 (게임이 아직 모를 때 대신)
item_ids = set()
for c in CLS.values():
    for d in c.values():
        for cc in d["cost"].values():
            item_ids.update(cc.keys())
        item_ids.update(d["reward"])
for _, _, node in SHARED:
    item_ids.update(items_of(node).keys())

with open(OUT, "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 던전 세트 2 (0.5티) 연계 퀘스트 (자동 생성 · tools/forever/gen_t05.py)\n")
    f.write("-- 자료: AllTheThings (MIT) 포에버 0.5 세트 (단계 · 내야 하는 장비 · 재료) · 포에버 아이템 표(226xxx 특성별 보상)\n")
    f.write("--       강화 퀘스트 번호 = QuestieDB 포에버 기록의 SoD식 84147~84210 (델리아나 230319 · 모크바르 230317)\n")
    f.write("--       QuestieDB (GPL-3.0) 포에버 합본 (퀘스트 한글 이름 · 목표 · 주는 NPC · 자리)\n")
    f.write("-- chain = 순서대로 · { up = n } 은 직업별 강화 단계 · 한 칸에 여러 개면 진영(fac 1 호드 · 2 얼라이언스 · 0 둘 다) / 직업(cls)으로 고른다\n")
    f.write("-- class[직업][단계] = { A/H 포에버 퀘스트(SoD식 84xxx · 97xxx), A0/H0 옛 클래식 번호, nA/nH 주는 NPC, eA/eH 보고 NPC,\n--   costA/costH = { {0티 장비 · 재료, 개수} }, gold(동), reward = { {특성 묶음 1 장비}, {묶음 2} … } (포에버 226xxx · 골라 받음), old = 옛 0.5티 }\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\n")
    f.write("ns.T05 = {\n\tchain = {\n")
    f.write("".join(steps))
    f.write("\t},\n\tclass = {\n")
    f.write("".join(cls_out))
    f.write("\t},\n\tquest = {\n")
    for qid in sorted(QTXT):
        t, o = QTXT[qid]
        f.write("\t\t[%d] = { %s, %s },\n" % (qid, q(t), q(o)))
    f.write("\t},\n\tnpc = {\n")
    for nid in sorted(NPCS):
        name, m, x, y = NPCS[nid]
        f.write("\t\t[%d] = { %s, %d, %g, %g },\n" % (nid, q(name), m, x, y))
    f.write("\t},\n\titem = {\n")
    for iid in sorted(item_ids):
        ko = KI.get(iid)
        if ko:
            f.write("\t\t[%d] = %s,\n" % (iid, q(ko if isinstance(ko, str) else ko[0])))
    f.write("\t},\n}\n")
print("steps", len(steps), "classes", len(cls_out), "quests", len(QTXT), "npcs", len(NPCS), "items", len(item_ids))
