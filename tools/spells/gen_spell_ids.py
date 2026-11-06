#!/usr/bin/env python3
"""
배울 기술 툴팁용 주문 번호 (FOA_UI/ClassSpellIDs.lua)
 내 컴퓨터의 포에버 게임 파일(CASC)에서 직접 읽는다 (tools/mapreveal 의 casc.py · wdc5.py)
  · SkillLineAbility(1266278): 직업 비트(ClassMask)로 그 직업이 배우는 주문
  · SpellMisc(1003144): 주문 아이콘 파일 번호 · SpellLevels(1140079): 배우는 레벨
  · ClassSpells.lua 의 { 레벨, 이름, 단계, 아이콘 } → 같은 아이콘 + 같은 레벨인 그 직업 주문
사용: python3 gen_spell_ids.py <ClassSpells.lua> <출력.lua>  (casc 폴더에서, names_f.pkl · F_*.db2 준비)
"""
import os, re, sys, pickle, collections
import wdc5
from jenkins import namehash
nm = pickle.load(open("names_f.pkl", "rb"))
sla = wdc5.parse(open("F_SkillLineAbility.db2", "rb").read())
misc, lv = {}, {}
for rid, v, p in wdc5.parse(open("F_SpellMisc.db2", "rb").read()): misc.setdefault(p, v[10])
for rid, v, p in wdc5.parse(open("F_SpellLevels.db2", "rb").read()): lv.setdefault(p, (v[3], v[4]))
BIT = {"WARRIOR": 1, "PALADIN": 2, "HUNTER": 4, "ROGUE": 8, "PRIEST": 16, "SHAMAN": 64, "MAGE": 128, "WARLOCK": 256, "DRUID": 1024}
byClass = collections.defaultdict(set)
for rid, v, p in sla:
    for c, b in BIT.items():
        if v[6] & b: byClass[c].add(v[4])
cs = open(sys.argv[1], encoding="utf-8").read()
cur, out = None, collections.OrderedDict()
for line in cs.splitlines():
    m = re.match(r"\s*([A-Z]+) = \{", line)
    if m: cur = m.group(1); out[cur] = []; continue
    m = re.match(r'\s*\{ (\d+), "([^"]+)", (\d+), "([^"]+)", \d+ \},', line)
    if not (m and cur): continue
    L, name, icon = int(m.group(1)), m.group(2), m.group(4)
    fd = nm.get(namehash("interface/icons/%s.blp" % icon.lower()))
    cands = [s for s in byClass[cur] if misc.get(s) == fd]
    exact = [s for s in cands if L in lv.get(s, (0, 0))]
    pick = sorted(exact or (cands if len(cands) == 1 else []))
    if pick: out[cur].append((L, name, pick[0]))
with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write("local _, ns = ...\nlocal b = select(4, GetBuildInfo()) or 0\nif not (b >= 16001 and b < 20000) then return end\nns.CLASS_SPELL_IDS = {\n")
    for c, rows in out.items():
        f.write("\t%s = {\n" % c)
        for L, name, sid in rows: f.write('\t\t["%d:%s"] = %d,\n' % (L, name, sid))
        f.write("\t},\n")
    f.write("}\n")
