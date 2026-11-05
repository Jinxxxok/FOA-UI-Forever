#!/usr/bin/env python3
"""
포에버 전문기술 빠른 레벨링 경로 → FOA_UI/ProfessionRoutes.lua
 자료: wowf.io 전문 기술 · 빠른 레벨링 (routes.json 으로 받아 둔 것)
"""
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
def q(s): return '"' + s.replace('"', '\\"') + '"'
out = ["-- FOA UI · 포에버 전문기술 빠른 레벨링 경로 (자동 생성 · tools/professions/gen_routes.py)",
       "-- 자료: wowf.io 전문 기술 · 빠른 레벨링 (재료 수는 그 구간 전체 합계, 출시 후 바뀔 수 있음)",
       "-- { 숙련 시작, 끝, 제작, 횟수, { { 재료, 수, 구하는 곳 } }, 제조법 얻는 곳 }",
       "local _, ns = ...", "ns.PROF_ROUTES = {"]
for prof, steps in d.items():
    out.append("\t[%s] = {" % q(prof))
    for s in steps:
        mats = ", ".join("{ %s, %d, %s }" % (q(m[0]), m[1], q(m[2])) for m in s[4])
        out.append("\t\t{ %d, %d, %s, %d, { %s }, %s }," % (s[0], s[1], q(s[2]), s[3], mats, q(s[5])))
    out.append("\t},")
out.append("}")
open(sys.argv[2], "w", encoding="utf-8").write("\n".join(out) + "\n")
