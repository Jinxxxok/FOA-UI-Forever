#!/usr/bin/env python3
"""
포에버 지도 틀 바로잡기
  포에버는 몇몇 지도의 그림 범위(지도 경계)를 바꿨다: 1412 멀고어 · 1423 동부 역병지대 · 1433 붉은마루 산맥 · 1453 스톰윈드(항구 포함).
  자료(AllTheThings 등)에 옛 지도 기준 좌표가 섞여 있으면 그 지도에서 표시가 엉뚱한 곳에 찍힌다.
  forever_frame_fixes.json 의 (지도, 옛 x, 옛 y) 와 정확히 같은 좌표만 새 좌표로 바꾼다.
  새 좌표 = 지도 경계 변환식으로 계산한 값 · 옛 좌표 판정은 그 자리 NPC 의 포에버 위치와 대조해 확인한 것만 표에 넣었다.

  자료를 다시 만든 뒤(gen_*.py) 이 스크립트를 한 번 돌린다.
사용: python3 -I apply_frame_fixes.py <FOA_UI 폴더>
"""
import sys, os, re, json

here = os.path.dirname(os.path.abspath(__file__))
data = json.load(open(os.path.join(here, "forever_frame_fixes.json"), encoding="utf-8"))
FIX = {(int(m), float(x), float(y)): (nx, ny) for m, x, y, nx, ny in data["fixes"]}
MAPS = "|".join(sorted({str(m) for m, _, _ in FIX}))
PAT = re.compile(r"(?<![\d.])(" + MAPS + r")(\s*,\s*)(\d+(?:\.\d+)?)(\s*,\s*)(\d+(?:\.\d+)?)(?![\d.])")
FILES = ["DungeonQuests.lua", "DungeonQuestNotes.lua", "QuestDB.lua", "ForeverQuestRewards.lua", "RecipeVendors.lua",
         "FlightDB.lua", "Map.lua"]


def fmt(v):
    return ("%.1f" % v).rstrip("0").rstrip(".") if v != int(v) else "%d" % v


root = sys.argv[1]
total = 0
for name in FILES:
    path = os.path.join(root, name)
    if not os.path.exists(path):
        continue
    src = open(path, encoding="utf-8").read()
    n = 0

    def rep(m):
        global n
        key = (int(m.group(1)), float(m.group(3)), float(m.group(5)))
        if key not in FIX:
            return m.group(0)
        n += 1
        nx, ny = FIX[key]
        return m.group(1) + m.group(2) + fmt(nx) + m.group(4) + fmt(ny)

    out = PAT.sub(rep, src)
    if n:
        open(path, "w", encoding="utf-8").write(out)
    print("%-26s %d" % (name, n))
    total += n
print("total", total)
