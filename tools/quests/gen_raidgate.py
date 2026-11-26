#!/usr/bin/env python3
"""
공격대 전리품이 있어야 끝낼 수 있는 퀘스트 → FOA_UI/DungeonQuestNotes.lua 의 QUEST_RAID_GATE 묶음
 자료: QuestieDB 포에버 (GPL-3.0 · https://github.com/Questie/QuestieDB) data/Forever/*.lua
  - 퀘스트 목표 아이템이 공격대 몹(화산 심장부 · 검은날개 둥지 · 줄구룹 · 안퀴라즈 폐허/사원 · 낙스라마스 · 오닉시아)에게서만
    나오거나, 처치 목표가 공격대 몹이면 그 공격대가 필요하다
  - 선행 퀘스트가 막혀 있으면 뒤 퀘스트도 막힌다
  - 대상: 퀘스트 보상 장비(ForeverQuestRewards.lua)를 주는 퀘스트
  예) 9023 완벽한 독 (파라드의 연발 석궁 등): 대사제 베녹시스(줄구룹) · 쿠린낙스(안퀴라즈 폐허) 독주머니
사용: python3 -I gen_raidgate.py <QuestieDB 폴더> <FOA_UI 폴더>
"""
import os
import re
import sys
from lupa import lua51

RAID = {  # 지역 번호 → (FOA 키, 한글 이름)
    2717: ("mc", "화산 심장부"), 2677: ("bwl", "검은날개 둥지"), 1977: ("zg", "줄구룹"),
    3429: ("aq20", "안퀴라즈 폐허"), 3428: ("aq40", "안퀴라즈 사원"), 3456: ("naxx", "낙스라마스"),
    2159: ("onyxia", "오닉시아의 둥지"),
}


def load(path, var):
    src = open(path, encoding="utf-8").read()
    m = re.search(r"QuestieDB\.%s = \[\[(.*?)\]\]" % var, src, re.S)
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    L.execute("os = nil; io = nil; dofile = nil; loadfile = nil; require = nil")
    return L.execute(m.group(1))


def seq(v):
    if v is None:
        return []
    try:
        return [v[k] for k in sorted(v.keys())]
    except AttributeError:
        return []


def main(qdb, foa):
    d = os.path.join(qdb, "data", "Forever")
    Q = load(os.path.join(d, "foreverQuestDB.lua"), "questData")
    I = load(os.path.join(d, "foreverItemDB.lua"), "itemData")
    N = load(os.path.join(d, "foreverNpcDB.lua"), "npcData")
    O = load(os.path.join(d, "foreverObjectDB.lua"), "objectData")

    def npc_raid(n):
        r = N[n]
        return RAID.get(r[9]) if r is not None else None

    def obj_raid(o):
        r = O[o]
        return RAID.get(r[5]) if r is not None else None

    def item_raids(it, depth=0):
        """아이템이 공격대에서만 나오면 그 공격대들 (다른 곳에서도 나오면 None)"""
        r = I[it]
        if r is None or depth > 3:
            return None
        if seq(r[14]):                      # 상인
            return None
        raids, any_src = set(), False
        for n in seq(r[2]):
            any_src = True
            x = npc_raid(n)
            if not x:
                return None
            raids.add(x)
        for o in seq(r[3]):
            any_src = True
            x = obj_raid(o)
            if not x:
                return None
            raids.add(x)
        for c in seq(r[4]):                 # 상자 · 꾸러미에서
            any_src = True
            x = item_raids(c, depth + 1)
            if not x:
                return None
            raids |= x
        return raids if any_src and raids else None

    memo = {}

    def gate(q, depth=0):
        if q in memo:
            return memo[q]
        memo[q] = None
        r = Q[q]
        if r is None or depth > 20:
            return None
        raids = set()
        obj = r[10]
        if obj is not None:
            parts = seq(obj)
            # 1 처치 목표 · 3 아이템 목표
            for e in seq(obj[1]) if obj[1] is not None else []:
                x = npc_raid(seq(e)[0]) if seq(e) else None
                if x:
                    raids.add(x)
            for e in seq(obj[3]) if obj[3] is not None else []:
                s = seq(e)
                x = item_raids(s[0]) if s else None
                if x:
                    raids |= x
        for p in seq(r[12]) + seq(r[13]):    # 선행 (모두 · 하나)
            x = gate(p, depth + 1)
            if x:
                raids |= x
        memo[q] = raids or None
        return memo[q]

    rew = open(os.path.join(foa, "ForeverQuestRewards.lua"), encoding="utf-8").read()
    qids = sorted({int(m.group(1)) for m in re.finditer(r"^\{\d+,(\d+),", rew, re.M)})
    out = {}
    for q in qids:
        g = gate(q)
        if g:
            out[q] = g
    lines = ["ns.QUEST_RAID_GATE = {",
             "\t-- [자동 생성 · tools/quests/gen_raidgate.py] 공격대 전리품이 있어야 끝나는 퀘스트 (QuestieDB 포에버)",
             "\t--  { FOA 키, … } · 그 공격대가 포에버에 열려 있지 않으면 BIS 후보 · 퀘스트 보상 목록에서 뺀다"]
    for q in sorted(out):
        keys = sorted({k for k, _ in out[q]})
        names = " · ".join(sorted({n for _, n in out[q]}))
        title = Q[q][1]
        lines.append('\t[%d] = { %s },  -- %s (%s)' % (q, ", ".join('"%s"' % k for k in keys), title, names))
    lines.append("}")
    block = "\n".join(lines)
    path = os.path.join(foa, "DungeonQuestNotes.lua")
    src = open(path, encoding="utf-8").read()
    pat = re.compile(r"ns\.QUEST_RAID_GATE = \{.*?\n\}", re.S)
    src = pat.sub(lambda _: block, src) if pat.search(src) else src.rstrip("\n") + "\n" + block + "\n"
    open(path, "w", encoding="utf-8").write(src)
    print(len(qids), "quests ·", len(out), "raid-gated")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
