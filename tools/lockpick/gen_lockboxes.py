"""자물쇠 따기 연습 사물함 자리 → FOA_UI/Lockboxes.lua

자료: QuestieDB (GPL-3.0 · https://github.com/Questie/QuestieDB) 포에버 합본 물체 자리 · 한국어 이름(l10n)
필요 숙련도: 대략 값 (Warcraft Tavern 포에버 자물쇠 따기 안내 기준 · 정확한 값은 게임 안 툴팁)
사용: python3 -I gen_lockboxes.py <QuestieDB 폴더> <출력 Lockboxes.lua>
      (먼저 ../quests/questie_export.py 로 합본을 만든다)
"""
import os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quests"))
import questie_data

qdb, out = sys.argv[1], sys.argv[2]
Q, N, O, area = questie_data.load(qdb)

# 연습 사물함 (찌그러진 · 흠뻑 젖은 · 움푹 파인 · 이끼투성이 · 붉은) · 대략 필요 숙련도
REQ = {179486: 110, 179487: 70, 179488: 110, 179489: 70, 179490: 150, 179491: 175,
       179492: 175, 179493: 175, 179494: 225, 179496: 225, 179497: 225, 179498: 280}

ko = {}
for era in ("TBC", "Classic", "Forever"):   # 뒤에 읽는 값(포에버)이 우선
    p = os.path.join(qdb, "l10n", era, "lookupObjects", "koKR.lua")
    for m in re.finditer(r'\[(\d+)\]\s*=\s*"([^"]*)"', open(p, encoding="utf-8").read()):
        if int(m.group(1)) in REQ:
            ko[int(m.group(1))] = m.group(2)

lines = ["-- FOA UI · 자물쇠 따기 연습 사물함 자리 (자동 생성 · tools/lockpick/gen_lockboxes.py)",
         "-- 자료: QuestieDB (GPL-3.0) 포에버 물체 자리 · 한국어 이름 / 필요 숙련도는 대략 값",
         "-- [물체] = { 이름, 필요 숙련도(대략), 영어 이름, { [지도] = { x, y, x, y, ... } } }  (자리 = 생길 수 있는 곳 · 한 번에 몇 개만 생긴다)",
         "local _, ns = ...",
         "local b = select(4, GetBuildInfo()) or 0",
         "if not (b >= 16001 and b < 20000) then return end",
         "ns.LOCKBOXES = {"]
total = 0
for oid in sorted(REQ):
    o = O.get(oid)
    if not o:
        continue
    maps = {}
    for zid, pts in (o["spawns"] or {}).items():
        mid = area.get(int(zid))
        if not mid:
            continue
        for p in pts:
            if p and len(p) >= 2 and p[0] > 0:
                maps.setdefault(mid, []).append((p[0], p[1]))
    if not maps:
        continue
    parts = []
    for mid in sorted(maps):
        xs = ",".join("%.1f,%.1f" % (x, y) for x, y in maps[mid])
        parts.append("[%d]={%s}" % (mid, xs))
        total += len(maps[mid])
    lines.append('\t[%d] = { "%s", %d, "%s", { %s } },' % (oid, ko.get(oid, o["name"]), REQ[oid], o["name"], ", ".join(parts)))
lines.append("}")
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("boxes", len(lines) - 8, "spots", total)
