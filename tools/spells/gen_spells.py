#!/usr/bin/env python3
"""
포에버 직업 기술 (레벨별 배우는 기술) → FOA_UI/ClassSpells.lua
 자료: wowf.io 스킬북 (직업별 페이지를 레벨|이름|단계|아이콘|표시 줄로 받아 둔 *.txt)
 특성으로 얻는 기술(단계 없는 것 중 특성 아이콘과 같은 것)은 뺀다 (TalentData.lua 참고)
사용: python3 -I gen_spells.py <txt 폴더> <TalentData.lua> <출력 ClassSpells.lua>
"""
import sys, os, re
src, talent_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
talent = open(talent_path, encoding="utf-8").read()
# 클래스별 특성 아이콘 중 최대 1단계짜리(능력 특성)
tal = {}
cur = None
for line in talent.splitlines():
    m = re.search(r'\["([A-Z]+):', line)
    if m: cur = m.group(1)
    m = re.search(r'\{\s*\d+,\s*\d+,\s*(\d+),\s*\d+,\s*\d+,\s*"[^"]*",\s*"([^"]+)"', line)
    if m and cur and m.group(1) == "1":
        tal.setdefault(cur, set()).add(m.group(2))
PET_SKILLS = {"할퀴기", "포효", "급강하", "야수 겁주기", "강인한 체력", "무쇠 가죽"}
CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"]
def q(s): return '"' + s.replace('"', '\\"') + '"'
lines = ["-- FOA UI · 포에버 직업 기술 (자동 생성 · tools/spells/gen_spells.py)",
         "-- 자료: wowf.io 스킬북 (출시 후 바뀔 수 있음 · 직업 상급자 창을 한 번 열면 그 자료가 우선)",
         "-- { 레벨, 이름, 단계(0 = 단계 없음), 아이콘 이름, 표시(1 신규 2 변경) }",
         "local _, ns = ...", "local b = select(4, GetBuildInfo()) or 0", "if not (b >= 16001 and b < 20000) then return end",
         "ns.CLASS_SPELLS = {"]
for c in CLASSES:
    p = os.path.join(src, c + ".txt")
    if not os.path.exists(p): continue
    rows, seen = [], set()
    for l in open(p, encoding="utf-8"):
        f = l.strip().split("|")
        if len(f) != 5 or not f[0].isdigit(): continue
        lvl, name, rank, icon, flag = int(f[0]), f[1].strip(), f[2].strip(), f[3].strip().replace(".jpg", ""), f[4].strip()
        r = int(rank) if rank.isdigit() else 0
        if r == 0 and icon in tal.get(c, ()):  # 특성 능력
            continue
        if c == "HUNTER" and name in PET_SKILLS:  # 야수 조련으로 배우는 소환수 기술
            continue
        key = (name, r)
        if key in seen: continue
        seen.add(key)
        rows.append((lvl, name, r, icon, 1 if flag == "NEW" else (2 if flag == "CHANGED" else 0)))
    # 같은 기술의 단계 레벨이 거꾸로면(자료 오류) 뒤 단계 레벨을 앞 단계 이상으로
    rows.sort(key=lambda x: (x[1], x[2]))
    fixed, last = [], {}
    for (lvl, name, r, icon, fl) in rows:
        if r > 0 and name in last and lvl < last[name]: lvl = last[name]
        last[name] = lvl
        fixed.append((lvl, name, r, icon, fl))
    fixed.sort(key=lambda x: (x[0], x[1], x[2]))
    lines.append("\t%s = {" % c)
    for (lvl, name, r, icon, fl) in fixed:
        lines.append("\t\t{ %d, %s, %d, %s, %d }," % (lvl, q(name), r, q(icon), fl))
    lines.append("\t},")
    print(c, len(fixed))
lines.append("}")
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
