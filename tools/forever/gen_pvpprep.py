#!/usr/bin/env python3
"""
포에버 전장 준비물 → FOA_UI/PvPPrep.lua (BIS 판 준비물 탭의 "전장 장비" · "전장 소모품")

 자료 (AllTheThings, MIT License · 포에버 1.60.1 게임 자료에서 뽑은 것)
  · .contrib/.db/forever/pvp/premier gear.lua : 프리미어 PvP 세트(파란 · 영웅) · 칸별 명예 + 전장 표식 값 · 강화 인장 · 망토 · 목걸이
  · db/Camelot/Categories/Zones.lua            : 명예 상인(계급 보상) — 상급 연맹/호드 휘장 · 전투 물약 · 전투 깃발
  · .contrib/.db/forever/pvp/battlegrounds/*.lua : 전장 보급관 장신구 · 전장 전용 붕대 · 음식
  · .contrib/.db/forever/.config/exports/ItemDB.lua : 착용 칸(inventoryType)으로 칸을 정한다
 계급 조건(인장 · 보상)은 블리자드 공지 "How PvP Progression in World of Warcraft: Forever Works" 표를 따른다.
 물약 · 도구 고르기는 FOA 정리 (아이템 번호는 위 자료로 포에버에 있는지 확인)

 사용: python3 -I gen_pvpprep.py <ATT 폴더> <출력 PvPPrep.lua>
"""
import os, re, sys

att, out = sys.argv[1:3]
contrib = os.path.join(att, ".contrib", ".db", "forever")

db = {}
for m in re.finditer(r'\[(\d+)\]=\{([^\n]*)\},?\n', open(os.path.join(contrib, ".config", "exports", "ItemDB.lua"), encoding="utf-8").read()):
    db[int(m.group(1))] = dict((k, v.strip('"')) for k, v in re.findall(r'(\w+)=("(?:[^"\\]|\\.)*"|[^,]+)', m.group(2)))


def inv(i):
    return int(db.get(i, {}).get("inventoryType", 0) or 0)


INV2SLOT = {1: 1, 3: 3, 5: 5, 20: 5, 10: 10, 7: 7, 8: 8, 9: 9, 6: 6}
SLOT_ORDER = [1, 3, 5, 10, 7, 8, 9, 6]  # 머리 어깨 가슴 손 다리 발 손목 허리
MARK = {"20558": "WSG", "20559": "AB", "20560": "AV", "274895": "DI"}
# 강화 인장 계급 조건 (블리자드 공지: 8 손목 · 허리 / 9 발 / 10 손 / 12 다리 · 어깨 / 13 가슴 · 머리)
SEAL_RANK = {9: 8, 6: 8, 8: 9, 10: 10, 7: 12, 3: 12, 5: 13, 1: 13}
SEAL_NAME = {"Belt": 6, "Chest": 5, "Feet": 8, "Hands": 10, "Head": 1, "Legs": 7, "Shoulder": 3, "Wrist": 9}

txt = open(os.path.join(contrib, "pvp", "premier gear.lua"), encoding="utf-8").read()
lines = txt.split("\n")
fac, cls, kind, setname = None, None, None, None
sets = {}          # fac → cls → [ {name, rare={slot:id}, epic={slot:id}} ]
cost = {}          # slot → (mark, n, honor)
seals = {}         # slot → (id, honor)
misc = {}
i = 0
while i < len(lines):
    ln = lines[i]
    if "FACTION_HEADER_ALLIANCE" in ln: fac = "A"
    if "FACTION_HEADER_HORDE" in ln: fac = "H"
    m = re.search(r'cl\((\w+),', ln)
    if m: cls = m.group(1)
    m = re.search(r'-- (Epic|Rare) set: (.+)$', ln)
    if m:
        kind = m.group(1).lower()
        base = re.sub(r"^(Field Marshal's|Warlord's|Lieutenant Commander's|Champion's) ", "", m.group(2).strip())
        L = sets.setdefault(fac, {}).setdefault(cls, [])
        cur = next((s for s in L if s["name"] == base), None)
        if not cur:
            cur = {"name": base, "rare": {}, "epic": {}}
            L.append(cur)
        setname = cur
    m = re.search(r'i\((\d+)\)?,?\s*\{?\s*-- (.+)$', ln)
    if m:
        iid, nm = int(m.group(1)), m.group(2).strip()
        blk = "\n".join(lines[i:i + 5])
        cm = re.search(r'\{ "i", (\d+), (\d+) \},[^\n]*\n\s*\{ "c", 1792, (\d+) \}', blk) if "{" in ln.split("--")[0] else None
        hm = re.match(r'\s*cost = \{\s*\{ "c", 1792, (\d+) \}', "\n".join(lines[i + 1:i + 3])) if "{" in ln.split("--")[0] else None
        sm = re.search(r"Emboldened (\w+) Seal", nm)
        if sm and hm:
            seals[SEAL_NAME[sm.group(1)]] = (iid, int(hm.group(1)))
        elif "Sergeant's Cape" in nm or "Sergeant's Cloak" in nm:
            misc.setdefault("cloak", {}).setdefault(fac, []).append(iid)
            if cm: misc["cloakCost"] = (MARK[cm.group(1)], int(cm.group(2)), int(cm.group(3)))
        elif "Sergeant's Insignia" in nm:
            misc.setdefault("neck", {})[fac] = iid
            if cm: misc["neckCost"] = (MARK[cm.group(1)], int(cm.group(2)), int(cm.group(3)))
        elif cls and setname and kind and inv(iid) in INV2SLOT:
            slot = INV2SLOT[inv(iid)]
            setname[kind][slot] = iid
            if kind == "rare" and cm:
                c = (MARK[cm.group(1)], int(cm.group(2)), int(cm.group(3)))
                if slot in cost and cost[slot] != c:
                    print("값이 다른 칸", slot, cost[slot], c, nm)
                cost.setdefault(slot, c)
    i += 1

# ATT 에서 빠진 칸 (게임 아이템 자료 ItemDB 에는 있음): 호드 사냥꾼 파란 머리
FIX = {("H", "HUNTER", "Pursuit", 1): 272491}
for (f, c, n, slot), iid in FIX.items():
    s = next(x for x in sets[f][c] if x["name"] == n)
    if slot not in s["rare"]:
        assert inv(iid) == 1 and db[iid]["name"].startswith("Premier"), iid
        s["rare"][slot] = iid
for f in sets:
    for c in sets[f]:
        for s in sets[f][c]:
            for k in ("rare", "epic"):
                if len(s[k]) != 8: print("칸이 모자람", f, c, s["name"], k, sorted(s[k]))

# 명예 상인(계급 보상): 상급 휘장 · 전투 물약
zones = open(os.path.join(att, "db", "Camelot", "Categories", "Zones.lua"), encoding="utf-8-sig").read()
gi = re.search(r'i\(274445,\{[^}]*cost=\{\{"c",1792,(\d+)\}', zones)
trinket_honor = int(gi.group(1)) if gi else 0
for need in (18839, 18841, 274445):
    if not re.search(r'i\(%d,' % need, zones):
        print("명예 상인에 없음", need)

# 전장 보급관 장신구 (레벨별로 여러 번호 · 게임에서 내 레벨에 맞는 것을 고른다)
BG_TRINKETS = [
    ("DI", "A", [271903, 271905]), ("DI", "A", [271904, 271906]),
    ("DI", "H", [272059, 272061]), ("DI", "H", [272060, 272062]),
    ("AB", "A", [20071, 21117, 21118, 21119]), ("AB", "H", [20072, 21115, 21116, 21120]),
    ("WSG", "", [21567, 21568]), ("WSG", "", [21565, 21566]),
]
bgtxt = "".join(open(os.path.join(contrib, "pvp", "battlegrounds", f), encoding="utf-8").read()
                for f in os.listdir(os.path.join(contrib, "pvp", "battlegrounds")))
for _, _, ids in BG_TRINKETS:
    for x in ids:
        assert "i(%d)" % x in bgtxt, x
        assert inv(x) == 12, (x, inv(x))

# 물약 · 붕대 · 도구 (FOA 정리 · 포에버에 있는 번호인지 확인)
#  { 아이템, 이유, 대상 } 대상: all · mana(마나 쓰는 직업) · melee(근접 · 마나 없는 직업) · 직업 이름
POTIONS = [
    (5634, "기절 · 감속 면역 30초", "all"),
    (20008, "기절 · 감속 풀기 + 5초 면역", "all"),
    (3387, "물리 면역 6초", "all"),
    (2459, "이동 속도 50% · 깃발 운반", "all"),
    (9030, "마법 · 저주 · 독 · 질병 풀기", "all"),
    (13446, "생명력 회복", "all"),
    (18839, "명예 상인 · 계급 5", "all"),
    (18841, "명예 상인 · 계급 5", "mana"),
    (13444, "마나 회복", "mana"),
    (13455, "방어도 +2000 · 2분", "melee"),
    (11951, "생명력 회복 · 물약과 따로", "all"),
    (11952, "생명력 · 마나 회복 · 물약과 따로", "mana"),
]
SUPPLY = [
    (14530, "붕대 · 응급치료 225", "all"),
    (272058, "검은창 섬 안에서만 · 평판 우호", "all"),
    (272055, "검은창 섬 안에서만 · 평판 우호", "all"),
    (19307, "알터랙 계곡 안에서만", "all"),
]
ENGI = [  # 기계공학 있을 때
    (15993, "3초 기절 · 기계공학 260", "eng"),
    (10646, "광역 피해 · 나도 맞음", "eng"),
    (10720, "10초 그물 · 210", "eng"),
    (7189, "20초 이동 속도", "eng"),
]
NOENG = [  # 기계공학 없을 때: 포에버 SAF-T · EZ-Thro (기계공학 없이 쓴다고 알려졌지만 확인 전)
    (260805, "3초 기절 · 기계공학 제작품", "noeng"),
    (260816, "기절 · 기계공학 제작품", "noeng"),
    (260828, "이동 속도 · 기계공학 제작품", "noeng"),
    (15993, "3초 기절 · 기계공학 260", "noeng"),
]
CLASS = [
    (7676, "기력 회복", "ROGUE"), (3776, "이동 속도 감소 독", "ROGUE"), (9186, "시전 속도 감소 독", "ROGUE"),
    (13442, "분노 + 힘", "WARRIOR"), (9206, "힘", "WARRIOR"), (13452, "민첩 · 치명타", "WARRIOR"),
    (13452, "민첩 · 치명타", "HUNTER"), (13452, "민첩 · 치명타", "DRUID"),
    (12662, "마나 회복 (물약과 따로)", "mana"), (20520, "마나 회복 (물약과 따로)", "mana"),
]
names = {}
for line in open(os.path.join(att, ".contrib", "Harvesters", "Database Harvester", "Raw - Forever", "Items.txt"), encoding="utf-8-sig"):
    if "@@@" in line:
        a, b = line.rstrip("\n").split("@@@", 1)
        if a.isdigit(): names[int(a)] = b
for lst in (POTIONS, SUPPLY, ENGI, NOENG, CLASS):
    for x, _, _ in lst:
        assert x in names, x


def lua_set(s):
    rare = ", ".join("[%d] = %d" % (k, s["rare"][k]) for k in SLOT_ORDER if k in s["rare"])
    epic = ", ".join("[%d] = %d" % (k, s["epic"][k]) for k in SLOT_ORDER if k in s["epic"])
    return '{ name = "%s", rare = { %s }, epic = { %s } }' % (s["name"], rare, epic)


def lst(L):
    return ", ".join('{ %d, "%s", "%s" }' % (a, b, c) for a, b, c in L)


o = []
o.append("-- FOA UI · 포에버 전장 준비물 (자동 생성: tools/forever/gen_pvpprep.py) · GPL-3.0-or-later")
o.append("-- 자료: AllTheThings (MIT License) 포에버 1.60.1 — 프리미어 PvP 세트 · 명예 + 전장 표식 값 · 강화 인장 · 명예 상인 · 전장 보급관")
o.append("--       계급 조건: 블리자드 공지 \"How PvP Progression in World of Warcraft: Forever Works\" · 물약 · 도구 고르기: FOA 정리")
o.append("local _, ns = ...")
o.append("local b = select(4, GetBuildInfo()) or 0")
o.append("if not (b >= 16001 and b < 20000) then return end")
o.append("ns.PVP_PREP = {")
o.append('\thonor = 1792,')
o.append('\tmarks = { WSG = 20558, AB = 20559, AV = 20560, DI = 274895 },')
o.append("\t-- 프리미어 파란 세트 칸 순서 · 칸마다 { 표식, 개수, 명예 } · 영웅 강화 인장 { 아이템, 명예, 계급 }")
o.append("\tslots = { %s }," % ", ".join(str(s) for s in SLOT_ORDER))
o.append("\tcost = { %s }," % ", ".join('[%d] = { "%s", %d, %d }' % (s, *cost[s]) for s in SLOT_ORDER))
o.append("\tseal = { %s }," % ", ".join("[%d] = { %d, %d, %d }" % (s, seals[s][0], seals[s][1], SEAL_RANK[s]) for s in SLOT_ORDER))
o.append("\tsets = {")
for f in ("A", "H"):
    o.append("\t\t%s = {" % f)
    for c in sorted(sets[f]):
        o.append("\t\t\t%s = { %s }," % (c, ", ".join(lua_set(s) for s in sets[f][c])))
    o.append("\t\t},")
o.append("\t},")
cc = misc["cloakCost"]; nc = misc["neckCost"]
o.append('\tcloak = { A = { %s }, H = { %s }, cost = { "%s", %d, %d }, rank = 3 },' % (
    ", ".join(map(str, misc["cloak"]["A"])), ", ".join(map(str, misc["cloak"]["H"])), *cc))
o.append('\tneck = { A = %d, H = %d, cost = { "%s", %d, %d }, rank = 4 },' % (misc["neck"]["A"], misc["neck"]["H"], *nc))
o.append("\ttrinket = { A = 274445, H = 274444, honor = %d, rank = 2 }," % trinket_honor)
o.append("\t-- 무기 (계급 14): 한손 · 원거리 검은창 섬 표식 10 + 명예 12,000 · 방패 · 보조 10 + 10,500 · 양손 알터랙 표식 20 + 22,500")
o.append("\tbgTrinkets = { %s }," % ", ".join('{ "%s", "%s", { %s } }' % (bg, f, ", ".join(map(str, ids))) for bg, f, ids in BG_TRINKETS))
o.append("\tpotions = { %s }," % lst(POTIONS))
o.append("\tsupply = { %s }," % lst(SUPPLY))
o.append("\tengi = { %s }," % lst(ENGI))
o.append("\tnoeng = { %s }," % lst(NOENG))
o.append("\tclass = { %s }," % lst(CLASS))
o.append("}")
open(out, "w", encoding="utf-8").write("\n".join(o) + "\n")
print("sets", {f: {c: len(v) for c, v in sets[f].items()} for f in sets}, "cost", cost, "seals", len(seals), "trinket honor", trinket_honor, misc)
