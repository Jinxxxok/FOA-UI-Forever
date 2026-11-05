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

rows, skipped = [], {"nocoord": 0, "u": 0, "removed": 0, "event": 0}
for qid in sorted(quests):
    q = quests[qid]
    if "u" in q: skipped["u"] += 1; continue
    if "rwp" in q: skipped["removed"] += 1; continue
    if "e" in q: skipped["event"] += 1; continue
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
    rows.append((qid, pts[:3], int(q.get("lvl", 1) or 1), int(q.get("r", 0) or 0), ilist(q.get("races")),
                 ilist(q.get("c")), ilist(q.get("sourceQuests")), ilist(q.get("altQuests")),
                 int(q.get("requireSkill", 0) or 0), rep, int(q.get("awp", 0) or 0), flags, item,
                 giver[0] if giver else 0))

L = lambda xs: "{" + ",".join(str(x) for x in xs) + "}"
with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 포에버 퀘스트 시작 위치 (자동 생성: tools/quests/gen_quests.py)\n")
    f.write("-- 자료: AllTheThings (MIT License) db/Camelot · https://github.com/ATTWoWAddon/AllTheThings\n")
    f.write("-- { 퀘스트ID, {지도,x,y,...}, 필요레벨, 진영(1호드 2얼라), 종족{}, 직업{}, 선행{}, 택일{}, 전문기술, 평판{}, 추가패치, 표시(1반복 2연결), 시작아이템, 주는NPC }\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\nns.QUEST_DB = {\n")
    for r in rows:
        p = []
        for (m, x, y) in r[1]:
            p += [m, round(x, 1), round(y, 1)]
        f.write("{%d,%s,%d,%d,%s,%s,%s,%s,%d,%s,%d,%d,%d,%d},\n" % (
            r[0], L(p), r[2], r[3], L(r[4]), L(r[5]), L(r[6]), L(r[7]), r[8], L(r[9]), r[10], r[11], r[12], r[13]))
    f.write("}\n")
print("quests:", len(quests), "written:", len(rows), "skipped:", skipped)
