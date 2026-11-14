"""QuestieDB 포에버 합본 자료 읽기 (GPL-3.0 · https://github.com/Questie/QuestieDB)

QuestieDB 의 tools/export-forever.lua 로 만든 합본(src/corrections/Forever/combined/*.lua)과
지역 번호 표(support/Forever/Zones/areaIdToUiMapId.lua)를 읽어 파이썬 값으로 돌려준다.
합본 만들기: python3 -I questie_export.py <QuestieDB 폴더>
"""
import os
from lupa import lua51


def _rt():
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    # 자료 파일만 읽는다 (파일 · 셸 기능 끔)
    L.execute("os = nil; io = nil; dofile = nil; loadfile = nil; require = nil")
    return L


def _py(v):
    """lua 표 → dict/list (1..n 이 연속이면 list)"""
    if v is None or isinstance(v, (int, float, str, bool)):
        return v
    try:
        keys = list(v.keys())
    except AttributeError:
        return v
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [_py(v[k]) for k in range(1, len(keys) + 1)]
    return {k: _py(v[k]) for k in keys}


def _load_table(path):
    L = _rt()
    src = open(path, encoding="utf-8").read()
    t = L.execute(src)
    return t


def load(qdb):
    comb = os.path.join(qdb, "src", "corrections", "Forever", "combined")
    quests = _load_table(os.path.join(comb, "foreverQuestDB.lua"))
    npcs = _load_table(os.path.join(comb, "foreverNpcDB.lua"))
    objs = _load_table(os.path.join(comb, "foreverObjectDB.lua"))
    # 지역 번호 → 지도 번호
    zsrc = open(os.path.join(qdb, "support", "Forever", "Zones", "areaIdToUiMapId.lua"), encoding="utf-8").read()
    L = _rt()
    area = {}
    for marker in ("ZoneDB.private.areaIdToUiMapId = [[", "ZoneDB.private.areaIdToUiMapIdOverride = [["):
        i = zsrc.find(marker)
        if i < 0:
            continue
        j = zsrc.find("]]", i)
        t = L.execute(zsrc[i + len(marker):j])
        for k in t.keys():
            if marker.endswith("Override = [[") or k not in area:
                area[int(k)] = int(t[k])
    Q = {}
    for k in quests.keys():
        row = quests[k]
        Q[int(k)] = [_py(row[i]) for i in range(1, 37)]   # 자리 번호 = questKeys (1부터) → 파이썬 0부터
    N = {}
    for k in npcs.keys():
        row = npcs[k]
        N[int(k)] = {"name": row[1], "spawns": _py(row[7]) or {}}
    O = {}
    for k in objs.keys():
        row = objs[k]
        O[int(k)] = {"name": row[1], "spawns": _py(row[4]) or {}}
    return Q, N, O, area
