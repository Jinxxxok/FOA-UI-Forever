#!/usr/bin/env python3
"""
던전 퀘스트 중 전문기술이 있어야 받는 퀘스트 → FOA_UI/DungeonQuestNotes.lua 의 자동 생성 블록
 자료: QuestieDB (GPL-3.0) 포에버 합본 requiredSkill { 기술, 숙련 } · AllTheThings 던전 퀘스트의 requireSkill 과 대조
 (두 자료가 같은 전문기술을 말할 때만 넣는다 · 숙련은 QuestieDB 값)

 사용: python3 -I gen_dqskill.py <QuestieDB 폴더> <FOA_UI 폴더>
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import questie_data

qdb, foa = sys.argv[1:3]
Q, _, _, _ = questie_data.load(qdb)
dq = open(os.path.join(foa, "DungeonQuests.lua"), encoding="utf-8").read()
ids = set(int(x) for x in re.findall(r"\{(\d+),\d+,\d,", dq))
# ATT 쪽 표 (gen_dquests.py 가 쓴 ns.DUNGEON_QUEST_SKILL 이 있으면 대조용) · 9788 방어구 제작 등 전문화는 대장기술(164)로 본다
SPEC_BASE = {9788: 164, 9787: 164, 17039: 164, 17040: 164, 17041: 164, 10656: 165, 10658: 165, 10660: 165, 20219: 202, 20222: 202}
att = {}
m = re.search(r"ns\.DUNGEON_QUEST_SKILL_ATT = \{([^}]*)\}", dq)
if m:
    for q, s in re.findall(r"\[(\d+)\]=(\d+)", m.group(1)):
        att[int(q)] = SPEC_BASE.get(int(s), int(s))
out = {}
for q in sorted(ids):
    r = Q.get(q)
    rs = r and r[17]
    if isinstance(rs, list) and len(rs) >= 2 and rs[0]:
        if att and q in att and att[q] != rs[0]:
            print("자료가 다름", q, rs, att[q])
            continue
        out[q] = (int(rs[0]), int(rs[1] or 0))
block = ("\t-- [자동 생성 · tools/quests/gen_dqskill.py] 전문기술이 있어야 받는 퀘스트 { 기술 번호, 숙련 } (QuestieDB 포에버 · AllTheThings 대조)\n"
         "\t--  164 대장기술 · 165 가죽세공 · 171 연금술 · 186 채광 · 197 재봉술 · 202 기계공학 · 333 마법부여\n")
notes_path = os.path.join(foa, "DungeonQuestNotes.lua")
notes = open(notes_path, encoding="utf-8").read()
tbl = "ns.DUNGEON_QUEST_SKILL = {\n" + block + "".join("\t[%d] = { %d, %d },\n" % (q, s, l) for q, (s, l) in out.items()) + "}\n"
if "ns.DUNGEON_QUEST_SKILL = {" in notes:
    notes = re.sub(r"ns\.DUNGEON_QUEST_SKILL = \{.*?\n\}\n", lambda _: tbl, notes, flags=re.S)
else:
    notes = notes.rstrip("\n") + "\n" + tbl
open(notes_path, "w", encoding="utf-8").write(notes)
print(len(out), "quests", out)
