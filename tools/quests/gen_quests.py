#!/usr/bin/env python3
"""
포에버 퀘스트 시작 위치 자료 만들기 (FOA_UI/QuestDB.lua)

자료 출처: AllTheThings (MIT License, https://github.com/ATTWoWAddon/AllTheThings)
  db/Camelot/Categories/Zones.lua  (WoW Forever 1.60.x)

Lua 를 실행하지 않고 글자로만 읽는다 (생성자 호출 · 표 · 숫자 · 문자열만 있는 형식).
사용:  python3 -I gen_quests.py <Zones.lua 경로> <출력 QuestDB.lua>
"""
import sys, re

src = open(sys.argv[1], encoding="utf-8-sig").read()
start = src.index("categories.Zones=") + len("categories.Zones=")
s = src
n = len(s)
pos = start

NUM = re.compile(r"-?(?:0x[0-9a-fA-F]+|\d+(?:\.\d*)?(?:[eE][-+]?\d+)?|\.\d+)")
NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*")

def ws():
    global pos
    while pos < n:
        c = s[pos]
        if c in " \t\r\n":
            pos += 1
        elif s.startswith("--", pos):
            e = s.find("\n", pos)
            pos = n if e < 0 else e + 1
        else:
            break

def string():
    global pos
    q = s[pos]; pos += 1
    out = []
    while s[pos] != q:
        if s[pos] == "\\":
            out.append(s[pos:pos + 2]); pos += 2
        else:
            out.append(s[pos]); pos += 1
    pos += 1
    return "".join(out)

def value():
    global pos
    ws()
    c = s[pos]
    if c == "{":
        return table()
    if c == "(":                                  # (function(t) ... end)({...}) 같은 즉시 호출
        pos += 1
        inner = value(); ws(); pos += 1; ws()
        if pos < n and s[pos] == "(":
            pos += 1; args = []; ws()
            while s[pos] != ")":
                args.append(value()); ws()
                if s[pos] == ",":
                    pos += 1; ws()
            pos += 1
            for a in args:
                if isinstance(a, (dict, list)):
                    return a
        return inner
    if c in "\"'":
        return string()
    if s.startswith("[[", pos):
        e = s.index("]]", pos); v = s[pos + 2:e]; pos = e + 2; return v
    m = NUM.match(s, pos)
    if m and (c.isdigit() or c in "-."):
        pos = m.end(); t = m.group(0)
        return int(t, 16) if "x" in t.lower() else (float(t) if any(ch in t for ch in ".eE") and "x" not in t.lower() else int(t))
    if s.startswith("function", pos):           # 함수 본문은 건너뛴다
        depth = 0
        while True:
            m = re.compile(r"\b(function|if|do|end|repeat|until)\b").search(s, pos)
            w = m.group(1); pos = m.end()
            if w in ("function", "if", "do", "repeat"):
                depth += 1
            elif w in ("end", "until"):
                depth -= 1
                if depth == 0:
                    return ("fn",)
    m = NAME.match(s, pos)
    if m:
        name = m.group(0); pos = m.end(); ws()
        if name in ("true", "false", "nil"):
            return {"true": True, "false": False, "nil": None}[name]
        if pos < n and s[pos] == "(":            # 생성자 호출: kind(id, {...})
            pos += 1
            args = []
            ws()
            while s[pos] != ")":
                args.append(value()); ws()
                if s[pos] == ",":
                    pos += 1; ws()
            pos += 1
            return ("call", name, args)
        if pos < n and s[pos] == "{":            # f{...}
            return ("call", name, [table()])
        return ("ref", name)
    raise ValueError("unexpected at %d: %r" % (pos, s[pos:pos + 40]))

def table():
    global pos
    pos += 1
    arr, d = [], {}
    while True:
        ws()
        if s[pos] == "}":
            pos += 1; break
        if s[pos] == "[":
            pos += 1; k = value(); ws(); pos += 1; ws(); pos += 1   # [k]=
            d[k] = value()
        else:
            m = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)").match(s, pos)
            if m:
                pos = m.end(); d[m.group(1)] = value()
            else:
                arr.append(value())
        ws()
        if s[pos] in ",;":
            pos += 1
    if d:
        if arr:
            d["__arr"] = arr
        return d
    return arr

KIND = {"q": "quest"}
root = value()

quests = {}
def walk(node):
    if isinstance(node, tuple) and node[0] == "call":
        name, args = node[1], node[2]
        body = args[-1] if args and isinstance(args[-1], dict) else None
        if name == "q" and args and isinstance(args[0], int) and body is not None:
            quests.setdefault(args[0], body)
        if body is not None:
            for ch in body.get("g", []) or []:
                walk(ch)
            for ch in body.get("__arr", []) or []:
                walk(ch)
        for a in args:
            if isinstance(a, list):
                for ch in a:
                    walk(ch)
    elif isinstance(node, list):
        for ch in node:
            walk(ch)
    elif isinstance(node, dict):
        for ch in node.get("g", []) or []:
            walk(ch)

walk(root)

def ilist(v):
    return [int(x) for x in v] if isinstance(v, list) else []

# 선행 퀘스트 빠진 것 (손으로 바로잡음 · 2026-11)
#  207 커즌의 수수께끼: 제2의 반란(203) + 나쁜 약(204) 둘 다 끝내야 (QuestieDB 포에버 자료 대조)
#  95786 남부해안의 지인(수사 니메츠 · 가라앉은 도시 얼라 시작): 니메츠가 "트롤 전설"을 연구하는 친구에게 보내는 퀘스트라
#        트롤 전설 석판 퀘스트(207) 다음 (퀘스트 글 + 게임에서 203 · 204 전에는 니메츠가 아무것도 안 줌 확인)
#  94992 구조 대작전(길 잃은 말): 휠러의 달아난 말들(94618)에서 먹이를 준 그 말이 주는 퀘스트 (wowf.io: 94618 보고 = 길 잃은 말)
#  수습생 클레어(강물터 · 햇살숲 아래 동굴 안): 흉측한 주술(95642) + 무차별 소탕(95643) → 우두머리 머리(95562) → 섬뜩한 발견(94884)
#        (forever-xp 퀘스트 줄기 자료 · 섬뜩한 발견은 흉측한 주술에서 채운 수정 촉매로 시작)
#  하사관 리프탄(강물터 30.7 49.1 · 황혼의 장막 앞): 지식의 조각(94879 · 애쉬 앰버홀) → 서부 전선(94886 · 디마르 브랜트, 보고 = 리프탄)
#        → 리프탄의 퀘스트 셋(94888 · 94889 · 96015) → 그놈의 머리(94890: 94888+94889) → 팔홀드에 소식(94891) → 황혼의 위협(94894)
#        (게임에서 서부 전선 전에는 리프탄이 아무것도 안 줌 확인 · forever-xp 퀘스트 줄기 자료)
PRE_FIX = {207: [204, 203], 95786: [207], 94992: [94618], 95562: [95642, 95643], 94884: [95562],
           94886: [94879], 94888: [94886], 94889: [94886], 96015: [94886], 94890: [94888, 94889], 94894: [94891],
           # 팔홀드 성채 (게임에서 햇살숲을 구해라 보고 전엔 수사 로울리가 아무것도 안 줌 확인 · forever-xp 퀘스트 줄기)
           #  디마르 브랜트: 햇살숲을 구해라(94877) → 현장으로(95329)
           #  수사 로울리: 94877 → 압박 붕대(96081) → 의사의 조수(96082) → 성직자의 격리(96083, 보고 = 로울랜드 수녀)
           #  로울랜드 수녀: → 물에 뭔가 있다(96084) → 상류 오염(96085) · 따로 종탑의 박쥐(95603) → 빛을 지켜라(95613) → 추모(95615)
           95329: [94877], 96081: [94877], 96082: [96081], 96083: [96082], 96084: [96083], 96085: [96084],
           95613: [95603], 95615: [95613]}

# ---------------------------------------------------------------------------
# QuestieDB 포에버 합본 (GPL-3.0, 있으면): 선행 퀘스트 · 택일 · 연결 퀘스트 · 조건 · 보고 NPC
#  포에버 실제 플레이 기록(약 91만 세션)으로 확인한 선행 관계(traces)가 들어 있어서 ATT 보다 정확하다
#  사용: gen_quests.py <Zones.lua> <출력> <QuestieDB 폴더>   (먼저 questie_export.py 로 합본을 만든다)
# ---------------------------------------------------------------------------
QQ = QN = QO = QA = None
if len(sys.argv) > 3:
    sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
    import questie_data
    QQ, QN, QO, QA = questie_data.load(sys.argv[3])

def part(v, i):
    if isinstance(v, list): return v[i - 1] if len(v) >= i else None
    if isinstance(v, dict): return v.get(i)
    return None

def ids(v):
    if isinstance(v, list): return [int(x) for x in v if isinstance(x, (int, float))]
    if isinstance(v, dict): return [int(x) for x in v.values() if isinstance(x, (int, float))]
    return []

def spot_of(table, eid, near):
    spawns = (table.get(eid) or {}).get("spawns") or {}
    best = None
    items = spawns.items() if isinstance(spawns, dict) else enumerate(spawns, 1)
    for area, pts in items:
        m = QA.get(int(area))
        if not m or not isinstance(pts, list): continue
        for p in pts:
            if not isinstance(p, list) or len(p) < 2: continue
            x, y = float(p[0]), float(p[1])
            if x <= 0 or y <= 0: continue          # -1,-1 = 던전 안
            d = (x - near[1]) ** 2 + (y - near[2]) ** 2 if (near and near[0] == m) else 1e9
            if best is None or d < best[0]: best = (d, m, x, y)
    return best[1:] if best else None

# 연결 퀘스트 목적지 (Questie: 목적지 퀘스트 쪽에 breadcrumbs 목록)
crumb_to = {}
if QQ:
    for tq, r in QQ.items():
        for b in ids(r[27]): crumb_to.setdefault(b, set()).add(tq)
        bf = r[26]
        if isinstance(bf, (int, float)) and bf: crumb_to.setdefault(tq, set()).add(int(bf))

stat = {"pre": 0, "ender": 0, "ender_same": 0, "skill": 0, "crumb": 0, "alt": 0}
rows, skipped = [], {"nocoord": 0, "u": 0, "removed": 0, "event": 0}
for qid in sorted(quests):
    q = quests[qid]
    if "u" in q: skipped["u"] += 1; continue
    if "rwp" in q: skipped["removed"] += 1; continue
    if "e" in q or q.get("isYearly"): skipped["event"] += 1; continue
    co = q.get("coords")
    pts = []
    if isinstance(co, dict):
        for m, lst in co.items():
            if isinstance(m, int) and isinstance(lst, list):
                for p in lst:
                    if isinstance(p, list) and len(p) >= 2:
                        pts.append((m, float(p[0]), float(p[1])))
    if not pts:
        skipped["nocoord"] += 1; continue
    rep = q.get("minReputation")
    rep = ilist(rep)[:2] if isinstance(rep, list) and len(rep) >= 2 else []
    flags = (1 if (q.get("repeatable") or q.get("isDaily")) else 0) | (2 if q.get("isBreadcrumb") else 0)
    item = 0
    for p in q.get("providers", []) or []:
        if isinstance(p, list) and len(p) >= 2 and p[0] == "i":
            item = int(p[1]); break
    giver = ilist(q.get("qgs"))[:1]
    pre = ilist(q.get("sourceQuests"))
    need = int(q.get("sqreq", 0) or 0)
    alt = ilist(q.get("altQuests"))
    skill = int(q.get("requireSkill", 0) or 0)
    rank = int(q.get("learnedAt", 0) or 0) if skill else 0
    nxt = ilist(q.get("nextQuests")) if q.get("isBreadcrumb") else []
    maxlvl, ender = 0, None
    qq = QQ.get(qid) if QQ else None
    lockQ, lockS = [], []
    if qq:
        grp, sgl = ids(qq[11]), ids(qq[12])
        if grp or sgl:
            # Questie: 묶음(모두) + 하나만(그중 하나) → 선행 목록 · 필요한 수
            newpre = grp + [x for x in sgl if x not in grp]
            newneed = 0 if not sgl or (len(sgl) == 1) else len(grp) + 1
            if sorted(newpre) != sorted(pre) or newneed != need: stat["pre"] += 1
            pre, need = newpre, newneed
        else:
            for p in PRE_FIX.get(qid, []):
                if p not in pre: pre.append(p)
        for a in ids(qq[15]):
            if a not in alt: alt.append(a); stat["alt"] += 1
        rs = qq[17]
        if isinstance(rs, list) and rs and rs[0]:
            if not skill: skill = int(rs[0]); stat["skill"] += 1
            if len(rs) > 1 and rs[1]: rank = max(rank, int(rs[1]))
        if qid in crumb_to:
            for t in sorted(crumb_to[qid]):
                if t not in nxt: nxt.append(t)
            stat["crumb"] += 1
        spl = qq[29]
        if isinstance(spl, (int, float)) and spl < 0: lockS.append(int(-spl))
        for d in ids(qq[35]) if isinstance(qq[35], list) else ([int(qq[35])] if isinstance(qq[35], (int, float)) and qq[35] else []):
            lockQ.append(d)
        ml = qq[31]
        if isinstance(ml, (int, float)) and ml: maxlvl = int(ml)
        # 보고 NPC: 받은 NPC 와 같으면 0, 다르면 {지도, x, y, NPC}
        fb = qq[2]
        cre, obj = ids(part(fb, 1)), ids(part(fb, 2))
        g0 = giver[0] if giver else 0
        if g0 and g0 in cre:
            ender = 0; stat["ender_same"] += 1
        else:
            near = pts[0] if pts else None
            for c in cre:
                sp = spot_of(QN, c, near)
                if sp: ender = [sp[0], round(sp[1], 1), round(sp[2], 1), c]; break
            if ender is None:
                for o in obj:
                    sp = spot_of(QO, o, near)
                    if sp: ender = [sp[0], round(sp[1], 1), round(sp[2], 1), 0]; break
            if ender is None and cre: ender = [0, 0, 0, cre[0]]
            if ender is not None: stat["ender"] += 1
        if not rep:
            mr = qq[18]
            if isinstance(mr, list) and len(mr) >= 2 and mr[0]: rep = [int(mr[0]), int(mr[1])]
    else:
        for p in PRE_FIX.get(qid, []):
            if p not in pre: pre.append(p)
    if nxt: flags |= 2
    # 조건 더 (없으면 안 씀): {전문기술 숙련도, 연결 퀘스트의 목적지{}, 선행 중 몇 개면 되는지, 평판 이하{}, 이 퀘스트를 깨면 잠김{}, 이 주문을 알면 잠김{}, 최고 레벨}
    lc = q.get("lc")
    if isinstance(lc, list):
        for i in range(1, len(lc) - 1, 2):
            if lc[i] == "questID" and int(lc[i + 1]) not in lockQ: lockQ.append(int(lc[i + 1]))
            elif lc[i] == "spellID" and int(lc[i + 1]) not in lockS: lockS.append(int(lc[i + 1]))
    mrep = q.get("maxReputation")
    mrep = [int(mrep[0]), int(mrep[1])] if isinstance(mrep, list) and len(mrep) >= 2 else []
    if not mrep and qq:
        mx = qq[19]
        if isinstance(mx, list) and len(mx) >= 2 and mx[0]: mrep = [int(mx[0]), int(mx[1])]
    extra = [rank if skill else 0, nxt, need, mrep, lockQ, lockS, maxlvl]
    while extra and extra[-1] in (0, []): extra.pop()
    rows.append((qid, pts[:3], int(q.get("lvl", 1) or 1), int(q.get("r", 0) or 0), ilist(q.get("races")),
                 ilist(q.get("c")), pre, alt,
                 skill, rep, int(q.get("awp", 0) or 0), flags, item,
                 giver[0] if giver else 0, extra, ender))

L = lambda xs: "{" + ",".join(str(x) for x in xs) + "}"
with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 포에버 퀘스트 (자동 생성: tools/quests/gen_quests.py) · GPL-3.0-or-later\n")
    f.write("-- 자료: AllTheThings (MIT License) db/Camelot · https://github.com/ATTWoWAddon/AllTheThings\n")
    f.write("--       QuestieDB (GPL-3.0) 포에버 합본: 선행 · 택일 · 연결 · 조건 · 보고 NPC · https://github.com/Questie/QuestieDB\n")
    f.write("-- { 퀘스트ID, {지도,x,y,...}, 필요레벨, 진영(1호드 2얼라), 종족{}, 직업{}, 선행{}, 택일{}, 전문기술, 평판{}, 추가패치, 표시(1반복 2연결), 시작아이템, 주는NPC, [조건 더], [보고] }\n")
    f.write("-- [조건 더] = { 전문기술 숙련도, 연결 퀘스트 목적지{}, 선행 중 필요한 수(0=모두), 평판 이하{세력,값}, 깨면 잠기는 퀘스트{}, 알면 잠기는 주문{}, 최고 레벨 } (없으면 false)\n")
    f.write("-- [보고] = 0 (받은 NPC 에게) · {지도, x, y, NPC} (다른 NPC · 물체면 NPC 0) · 없으면 모름\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\nns.QUEST_DB = {\n")
    for r in rows:
        p = []
        for (m, x, y) in r[1]:
            p += [m, round(x, 1), round(y, 1)]
        ex = ""
        if r[14]:
            ex = "," + "{" + ",".join(L(v) if isinstance(v, list) else str(v) for v in r[14]) + "}"
        if r[15] is not None:
            if not ex: ex = ",false"
            ex += ",0" if r[15] == 0 else "," + L(r[15])
        f.write("{%d,%s,%d,%d,%s,%s,%s,%s,%d,%s,%d,%d,%d,%d%s},\n" % (
            r[0], L(p), r[2], r[3], L(r[4]), L(r[5]), L(r[6]), L(r[7]), r[8], L(r[9]), r[10], r[11], r[12], r[13], ex))
    f.write("}\n")
print("quests:", len(quests), "written:", len(rows), "skipped:", skipped)
if QQ: print("questie:", stat)
