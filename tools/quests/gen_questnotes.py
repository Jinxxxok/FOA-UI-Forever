#!/usr/bin/env python3
"""
포에버 퀘스트 메모 자료 만들기 (FOA_UI/QuestNotes.lua)
  · 호위 퀘스트 · NPC 지키기 퀘스트 (목표 글로 판단) + 호위 목적지
  · 돌아다니는 퀘스트 NPC 의 동선 (순찰 경로)
  · 여러 자리 중 한 곳에 나타나는 퀘스트 NPC 의 출현 자리

자료: QuestieDB (GPL-3.0, https://github.com/Questie/QuestieDB) 포에버 합본
      퀘스트 목표 글 · 완료 지점(triggerEnd) · NPC 출현 자리(spawns) · 순찰 경로(waypoints)
지도에 찍는 퀘스트 · 주는 NPC 는 FOA_UI/QuestDB.lua 에 있는 것만.

사용:  python3 -I gen_questnotes.py <QuestieDB 폴더> <QuestDB.lua> <출력 QuestNotes.lua>
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import questie_data  # noqa: E402

qdb_dir, questdb_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
Q, N, O, area = questie_data.load(qdb_dir)

# NPC 출현 자리 · 순찰 경로 (questie_data.load 는 이름 · 출현 자리만 읽어서 따로)
L = questie_data._rt()
npc_t = L.execute(open(os.path.join(qdb_dir, "src", "corrections", "Forever", "combined", "foreverNpcDB.lua"),
                       encoding="utf-8").read())


def by_zone(v):
    """{지역: …} · lua 에서 1..n 이 연속이면 list 로 와서 다시 dict 로"""
    if not v:
        return {}
    if isinstance(v, list):
        return {i + 1: x for i, x in enumerate(v)}
    return v


WP, SP = {}, {}
for k in npc_t.keys():
    row = npc_t[k]
    w = by_zone(questie_data._py(row[8]))
    s = by_zone(questie_data._py(row[7]))
    if w:
        WP[int(k)] = w
    if s:
        SP[int(k)] = s

# QuestDB.lua: 퀘스트 → 지도 · 자리 · 주는 NPC
giver_of, spot_of = {}, {}
for line in open(questdb_path, encoding="utf-8"):
    if not line.startswith("{"):
        continue
    try:
        v = L.eval(line.rstrip().rstrip(","))
        qid, pos, g = int(v[1]), questie_data._py(v[2]), v[14]
    except Exception:
        continue
    giver_of[qid] = int(g or 0)
    if isinstance(pos, list) and len(pos) >= 3:
        spot_of[qid] = (int(pos[0]), float(pos[1]), float(pos[2]))
givers = {g for g in giver_of.values() if g}


def ui_map(zone):
    return area.get(int(zone))


# ---------------------------------------------------------------------------
# 호위 · NPC 지키기
# ---------------------------------------------------------------------------
def texts(r):
    o = r[7]
    o = " ".join(x for x in o if isinstance(x, str)) if isinstance(o, list) else (o if isinstance(o, str) else "")
    t = r[8][0] if isinstance(r[8], list) and r[8] and isinstance(r[8][0], str) else ""
    return o, t


ESCORT = re.compile(r"\bescort|\baccompany|\bthe way back\b|help [\w' \"-]+? (?:escape|get back|to the road|find)"
                    r"|\blead [\w' ]+? (?:to|safely|out)|safely through|\bon the way\b|until (?:she|he) (?:returns|reach)"
                    r"|as (?:she|he) searches|\bget back to\b", re.I)
GUARDING = re.compile(r"\b[Pp]rotect (?!the Frontier)[A-Z][\w']+|\b[Dd]efend (?:[A-Z][\w']+|the)|\b[Pp]rotect (?:the )?[a-z]+ (?:caravan|refugees|shipment)")
NOT_ESCORT = {35, 37, 46, 52, 71, 128, 129, 2378, 2479, 5307, 5624, 6187, 9664, 9665, 98233}   # 경비병 이름("Guard Thomas") · 탑 이름 · 공격 퀘스트 등
FORCE = {4966: 2, 667: 2, 1651: 2, 3382: 2, 5713: 2, 4901: 1, 660: 1, 731: 1}      # 1 호위 · 2 지키기 (손으로 확인)

escort = {}
for qid in giver_of:
    r = Q.get(qid)
    if not r or qid in NOT_ESCORT:
        continue
    o, t = texts(r)
    s = o + " | " + t
    kind = FORCE.get(qid)
    if not kind:
        if ESCORT.search(s):
            kind = 1
        elif GUARDING.search(s):
            kind = 2
    if not kind:
        continue
    dest = None
    te = r[8]
    if isinstance(te, list) and len(te) > 1:
        zones = by_zone(te[1]) if not isinstance(te[1], dict) else te[1]
        for z, pts in (zones or {}).items():
            m = ui_map(z)
            if m and pts and isinstance(pts[0], list) and len(pts[0]) >= 2:
                dest = (m, round(pts[0][0], 1), round(pts[0][1], 1))
                break
    party = 1 if (r[22] or 0) & 2 else 0   # questFlags 2: 시작할 때 파티원도 함께 받음
    escort[qid] = (kind, dest, party)


# ---------------------------------------------------------------------------
# 돌아다니는 NPC 동선 · 여러 출현 자리
# ---------------------------------------------------------------------------
def simplify(pts, tol):
    """Douglas-Peucker"""
    if len(pts) < 3:
        return pts
    a, b = pts[0], pts[-1]
    dx, dy = b[0] - a[0], b[1] - a[1]
    dd = dx * dx + dy * dy
    far, idx = -1, 0
    for i in range(1, len(pts) - 1):
        p = pts[i]
        if dd == 0:
            d = math.hypot(p[0] - a[0], p[1] - a[1])
        else:
            t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / dd))
            d = math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy))
        if d > far:
            far, idx = d, i
    if far <= tol:
        return [a, b]
    return simplify(pts[:idx + 1], tol)[:-1] + simplify(pts[idx:], tol)


def as_paths(v):
    """경로 하나 [[x,y],…] 또는 여러 개 [[[x,y],…],…] → 여러 개"""
    if not v:
        return []
    if isinstance(v[0], list) and v[0] and isinstance(v[0][0], (int, float)):
        return [v]
    return [p for p in v if isinstance(p, list) and p and isinstance(p[0], list)]


def extent(pts):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return math.hypot(max(xs) - min(xs), max(ys) - min(ys))


ROAM_MIN = 2.0      # 경로가 이만큼(지도 0~100 기준)은 퍼져 있어야 "돌아다니는 NPC" (제자리 서성임은 빼고)
roam = {}
for g in sorted(givers):
    w = WP.get(g)
    if not w:
        continue
    maps = {}
    for z, v in w.items():
        m = ui_map(z)
        if not m:
            continue
        for p in as_paths(v):
            pts = [(float(x[0]), float(x[1])) for x in p if isinstance(x, list) and len(x) >= 2 and x[0] >= 0]
            if len(pts) < 3 or extent(pts) < ROAM_MIN:
                continue
            s = simplify(pts, 0.25)
            if len(s) > 80:
                s = simplify(pts, 0.6)
            maps.setdefault(m, []).append(s)
    if maps:
        roam[g] = maps

spawns = {}
for g in sorted(givers):
    if g in roam:
        continue
    s = SP.get(g)
    if not s:
        continue
    for z, pts in s.items():
        m = ui_map(z)
        pts = [(float(p[0]), float(p[1])) for p in (pts or []) if isinstance(p, list) and len(p) >= 2 and isinstance(p[0], (int, float)) and p[0] >= 0]
        if m and len(pts) >= 2 and extent(pts) >= 2.0:
            # 너무 가까운 자리는 하나로
            keep = []
            for p in pts:
                if all(math.hypot(p[0] - k[0], p[1] - k[1]) > 0.8 for k in keep):
                    keep.append(p)
            if len(keep) >= 2:
                spawns.setdefault(g, {})[m] = keep[:12]


# ---------------------------------------------------------------------------
# 쓰기
# ---------------------------------------------------------------------------
def f1(v):
    s = ("%.1f" % v).rstrip("0").rstrip(".")
    return s or "0"


out = []
out.append("-- FOA UI · 포에버 퀘스트 메모 (자동 생성: tools/quests/gen_questnotes.py) · GPL-3.0-or-later")
out.append("-- 자료: QuestieDB (GPL-3.0) 포에버 합본 · https://github.com/Questie/QuestieDB")
out.append("--  ESCORT[퀘스트] = { 종류(1 호위 · 2 NPC 지키기), 목적지 지도, x, y, 파티원도 함께(1) }  (목적지를 모르면 지도 0)")
out.append("--  ROAM[NPC] = { [지도] = { {x,y,x,y,…}, … } }  돌아다니는 퀘스트 NPC 의 동선 (0~100)")
out.append("--  SPAWNS[NPC] = { [지도] = {x,y,x,y,…} }  여러 자리 중 한 곳에 나타나는 퀘스트 NPC")
out.append("local _, ns = ...")
out.append("local b = select(4, GetBuildInfo()) or 0")
out.append("if not (b >= 16001 and b < 20000) then return end")
out.append("ns.QUEST_NOTES = {")
out.append("ESCORT = {")
for qid in sorted(escort):
    kind, dest, party = escort[qid]
    if dest:
        out.append("[%d]={%d,%d,%s,%s,%d}," % (qid, kind, dest[0], f1(dest[1]), f1(dest[2]), party))
    else:
        out.append("[%d]={%d,0,0,0,%d}," % (qid, kind, party))
out.append("},")
out.append("ROAM = {")
for g in sorted(roam):
    parts = []
    for m in sorted(roam[g]):
        paths = ",".join("{" + ",".join(f1(c) for p in path for c in p) + "}" for path in roam[g][m])
        parts.append("[%d]={%s}" % (m, paths))
    out.append("[%d]={%s}, -- %s" % (g, ",".join(parts), N.get(g, {}).get("name", "")))
out.append("},")
out.append("SPAWNS = {")
for g in sorted(spawns):
    parts = []
    for m in sorted(spawns[g]):
        parts.append("[%d]={%s}" % (m, ",".join(f1(c) for p in spawns[g][m] for c in p)))
    out.append("[%d]={%s}, -- %s" % (g, ",".join(parts), N.get(g, {}).get("name", "")))
out.append("},")
out.append("}")
open(out_path, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("escort", len(escort), "(호위 %d · 지키기 %d · 목적지 %d)" % (
    sum(1 for v in escort.values() if v[0] == 1), sum(1 for v in escort.values() if v[0] == 2),
    sum(1 for v in escort.values() if v[1])), "roam", len(roam), "spawns", len(spawns))
