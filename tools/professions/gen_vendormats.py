#!/usr/bin/env python3
"""
상인에게 살 수 있는 제작 재료 (실타래 · 약병 · 염료 · 소금 · 융해촉진제 · 양념 · 독 재료 …) → FOA_UI/VendorMatsData.lua

자료:
  QuestieDB 포에버 합본 (GPL-3.0 · https://github.com/Questie/QuestieDB)
    아이템마다 파는 상인(vendors) · 상인 자리 · 진영 · 한글 이름(l10n/Forever koKR)
  cMaNGOS classic-db (GPL-3.0 · https://github.com/cmangos/classic-db) Full_DB
    item_template 의 구입 가격(BuyPrice · BuyCount = 한 번에 사는 개수) · 아이템 종류
    npc_vendor 의 maxcount (0 보다 크면 수량 한정 상인)
  가격은 클래식 1.12 기준 · 게임 안에서 상인 창을 열면 실제 가격으로 바꿔 기억한다 (VendorMats.lua)

고르는 기준: 포에버 자료에 파는 상인이 있고
  · 클래식 자료(cMaNGOS)나 포에버 자료(QuestieDB)에서 종류가 "직업용품"(7)인 아이템
  · 또는 아래 EXTRA (장작나무 · 별목재 · 단풍나무 씨앗 · 가시덩굴 씨앗 · 부싯돌 · 큰지렁이 등 제작에 쓰는 것)
  · 포에버 새 아이템(클래식 자료에 없음)은 상인이 둘 이상일 때만 (가격은 게임 안에서 기억)

사용: python3 -I gen_vendormats.py <QuestieDB 폴더> <ClassicDB .sql> <출력 VendorMatsData.lua>
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quests"))
import questie_data
from lupa import lua51

QDB, SQL, OUT = sys.argv[1:4]
EXTRA = {4470, 4471, 11291, 17034, 17035, 2665, 6530}
SKIP = {232454, 232455, 232456, 232457}   # 휘장(화폐처럼 쓰는 것)


def tuples(line):
    body = line[line.index("VALUES") + 6:].strip().rstrip(";")
    i, n, out = 0, len(body), []
    while i < n:
        if body[i] != "(":
            i += 1
            continue
        j, cur, buf, inq = i + 1, [], "", False
        while j < n:
            c = body[j]
            if inq:
                if c == "\\":
                    buf += body[j:j + 2]; j += 2; continue
                if c == "'":
                    inq = False
                buf += c
            elif c == "'":
                inq = True; buf += c
            elif c == ",":
                cur.append(buf); buf = ""
            elif c == ")":
                cur.append(buf); break
            else:
                buf += c
            j += 1
        out.append(cur)
        i = j + 1
    return out


price, cls, limited, sold = {}, {}, set(), set()
for line in open(SQL, encoding="utf-8", errors="replace"):
    if line.startswith("INSERT INTO `item_template`"):
        for t in tuples(line):
            e = int(t[0])
            cls[e] = int(t[1])
            price[e] = (int(t[8]), max(1, int(t[7])))   # (BuyPrice, BuyCount)
    elif line.startswith("INSERT INTO `npc_vendor`"):
        for t in tuples(line):
            sold.add(int(t[1]))
            if int(t[2]) > 0:
                limited.add((int(t[0]), int(t[1])))

_, _, _, AREA = questie_data.load(QDB)
L = lua51.LuaRuntime(unpack_returned_tuples=True)
L.execute("os = nil; io = nil; dofile = nil; loadfile = nil; require = nil")
comb = os.path.join(QDB, "src", "corrections", "Forever", "combined")
items = L.execute(open(os.path.join(comb, "foreverItemDB.lua"), encoding="utf-8").read())
npcs = L.execute(open(os.path.join(comb, "foreverNpcDB.lua"), encoding="utf-8").read())


def l10n(kind):
    out = {}
    L2 = lua51.LuaRuntime()
    L2.execute("GetLocale = function() return 'koKR' end; l10n = {}")
    for path in (os.path.join(QDB, "l10n", "Forever", kind, "koKR.lua"),
                 os.path.join(QDB, "l10n", "Forever", "traces", kind, "koKR.lua")):
        if not os.path.exists(path):
            continue
        src = open(path, encoding="utf-8").read()
        # 파일 모양: if GetLocale() ~= "koKR" then return end ... l10n.xxx = { [id] = ... }  →  표만 꺼낸다
        i = src.find("{", src.find("="))
        while i >= 0 and not src[i:i + 200].lstrip("{ \n\t").startswith("["):
            i = src.find("{", i + 1)
        t = L2.execute("return " + src[i:src.rfind("}") + 1])
        for k in t.keys():
            v = t[k]
            name = v if isinstance(v, str) else (v[1] if v is not None else None)
            if isinstance(name, str) and name:
                out[int(k)] = name
    return out


KO_ITEM, KO_NPC = l10n("lookupItems"), l10n("lookupNpcs")
FAC = {"A": 2, "H": 1, "AH": 0}

npc_out = {}
def npc_row(nid):
    if nid in npc_out:
        return npc_out[nid]
    r = npcs[nid]
    row = None
    if r is not None and r[13] in FAC:
        sp = r[7]
        for area in (sp.keys() if sp else []):
            m = AREA.get(int(area))
            pts = sp[area]
            if not m or not pts or not pts[1]:
                continue
            x, y = float(pts[1][1]), float(pts[1][2])
            if x <= 0 or y <= 0:
                continue
            row = (FAC[r[13]], m, round(x, 1), round(y, 1), KO_NPC.get(nid) or r[1])
            break
    npc_out[nid] = row
    return row


out = {}
for k in items.keys():
    iid = int(k)
    r = items[k]
    if iid in SKIP or not r[14]:
        continue
    vend = [int(v) for v in r[14].values()]
    qcls = r[12]
    if not (iid in EXTRA or cls.get(iid) == 7 or (qcls == 7 and iid not in cls)):
        continue
    if iid not in cls and len(vend) < 2:
        continue
    lst = []
    for v in sorted(set(vend)):
        if npc_row(v):
            lst.append(-v if (v, iid) in limited else v)
    if not lst:
        continue
    # 클래식에서 상인이 안 팔던 아이템(포에버에서 새로 상인에게 생긴 것)은 클래식 가격표 값이 실제 구입 가격이 아니다 → 0 (게임 안에서 기억)
    p, c = price.get(iid, (0, 1)) if iid in sold else (0, 1)
    out[iid] = (p, c, KO_ITEM.get(iid) or r[1], lst)


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


used = {abs(v) for _, _, _, l in out.values() for v in l}
with open(OUT, "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 상인에게 살 수 있는 제작 재료 (자동 생성 · tools/professions/gen_vendormats.py)\n")
    f.write("-- 자료: QuestieDB 포에버 합본 (GPL-3.0) 파는 상인 · 자리 · 한글 이름 / cMaNGOS classic-db (GPL-3.0) 구입 가격 · 수량 한정\n")
    f.write("--  가격은 클래식 1.12 기준 (게임 안에서 상인 창을 열면 실제 가격으로 바꿔 기억)\n")
    f.write("-- items[아이템] = { 가격(동), 한 번에 사는 개수, 한글 이름, { 상인 NPC (음수 = 수량 한정) } }\n")
    f.write("-- npcs[NPC] = { 진영(0 둘 다 · 1 호드 · 2 얼라이언스), 지도, x, y, 이름 }\n")
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\n")
    f.write("ns.VENDOR_MATS = {\n\titems = {\n")
    for iid in sorted(out):
        p, c, name, lst = out[iid]
        f.write("\t\t[%d] = { %d, %d, %s, { %s } },\n" % (iid, p, c, q(name), ", ".join(map(str, lst))))
    f.write("\t},\n\tnpcs = {\n")
    for nid in sorted(used):
        fac, m, x, y, name = npc_out[nid]
        f.write("\t\t[%d] = { %d, %d, %s, %s, %s },\n" % (nid, fac, m, ("%g" % x), ("%g" % y), q(name)))
    f.write("\t},\n}\n")
print(len(out), "items", len(used), "npcs")
print("가격 없음:", sorted((i, out[i][2]) for i in out if not out[i][0]))
