# 전문기술 주문 → 만들어지는 아이템 (SkillLineAbility · SpellEffect 효과 24)
import wdc5, json, sys, collections
SKILLS = {164, 165, 171, 197, 202, 333, 185, 129, 186, 356, 182, 393}
sla = wdc5.parse(open("F_SkillLineAbility.db2", "rb").read())
spells = {}
for rid, v, p in sla:
    if v[3] in SKILLS: spells[v[4]] = v[3]
item = {}
for rid, v, p in wdc5.parse(open("F_SpellEffect.db2", "rb").read()):
    if p in spells and v[3] == 24 and v[10] and p not in item: item[p] = v[10]
icon = {}
for rid, v, p in wdc5.parse(open("F_SpellMisc.db2", "rb").read()):
    if p in spells and p not in icon: icon[p] = v[10]
c = collections.Counter(spells[s] for s in item)
print("spells", len(spells), "with item", len(item), c)
noitem = [s for s in spells if s not in item]
ic = collections.Counter(icon.get(s) for s in noitem)
print("no item", len(noitem), ic.most_common(8))
print("icon of 10518", icon.get(10518), "2149", icon.get(2149))
json.dump({"item": item, "icon": {s: icon.get(s, 0) for s in noitem}, "skill": spells}, open("craftitems.json", "w"))

# CraftItems.lua 쓰기 (FOA_UI 에 넣는 파일)
lines = ["-- FOA UI · 포에버 전문기술 주문 → 만들어지는 아이템 (자동 생성 · tools/crafts/gen_craftitems.py)",
         "-- 자료: 게임 파일 (SkillLineAbility · SpellEffect 효과 24) · 내 컴퓨터에 깔린 포에버에서 직접 읽음",
         "-- 제조법 주문은 아이콘이 비어 있어서(와우 로고) 만들어지는 아이템의 그림 · 툴팁을 보여 주는 데 쓴다",
         "local _, ns = ...",
         "local b = select(4, GetBuildInfo()) or 0",
         "if not (b >= 16001 and b < 20000) then return end",
         "ns.CRAFT_ITEM = {"]
row = []
for s in sorted(item):
    row.append("[%d]=%d," % (s, item[s]))
    if len(row) == 10:
        lines.append("".join(row)); row = []
if row: lines.append("".join(row))
lines.append("}")
open(sys.argv[1] if len(sys.argv) > 1 else "CraftItems.lua", "w", encoding="utf-8").write("\n".join(lines) + "\n")
