#!/usr/bin/env python3
"""
던전 희귀몹 · 특수 몹 · 상자 전리품 → FOA_UI/ForeverLootExtra.lua
 자료: wowf.io 던전 안내의 전리품 표 (보스가 아닌 출처, 장비만) · 2026-11-10 수집 → rares_wowf.json
 [슬러그, 영문 이름, 한글 이름, [장비 아이템]]
 희귀 표시(1)는 클래식에서 희귀 정예였던 몹, 나머지(2)는 특수 몹 · 소환 · 상자
사용: python3 -I gen_rares.py rares_wowf.json ForeverLootExtra.lua
"""
import sys, json
src = json.load(open(sys.argv[1], encoding="utf-8"))
KEY = {
 "ruins-of-lordaeron": "lordaeron", "deadmines": "deadmines", "wailing-caverns": "wailing", "shadowfang-keep": "shadowfang",
 "stockade": "stockade", "razorfen-kraul": "kraul", "gnomeregan": "gnomeregan", "scarlet-monastery-graveyard": "sm_gy",
 "scarlet-monastery-library": "sm_lib", "scarlet-monastery-armory": "sm_arm", "scarlet-monastery-cathedral": "sm_cath",
 "zul-farrak": "zulfarrak", "maraudon": "maraudon", "sunken-temple": "sunken", "dire-maul-east": "dm_east",
 "dire-maul-west": "dm_west", "dire-maul-north": "dm_north", "blackrock-depths": "brd", "lower-blackrock-spire": "lbrs",
 "upper-blackrock-spire": "ubrs", "stratholme-main-gate": "strat_live", "stratholme-service-gate": "strat_ud",
 "scholomance": "scholo", "blackfathom-deeps": "blackfathom", "uldaman": "uldaman", "razorfen-downs": "downs",
}
RARE = {"Miner Johnson", "Deviate Faerie Dragon", "Deathsworn Captain", "Bruegal Ironknuckle", "Razorfen Spearhide",
 "Blind Hunter", "Earthcaller Halmgar", "Dark Iron Ambassador", "Techbot", "Azshir the Sleepless", "Fallen Champion",
 "Ironspine", "Zerillis", "Dustwraith", "Meshlok the Harvester", "Verek", "Panzor the Invincible", "Spirestone Butcher",
 "Spirestone Battle Lord", "Spirestone Lord Magus", "Crystal Fang", "Bannok Grimaxe", "Ghok Bashguud",
 "Jed Runewatcher", "Lordaeron Captain"}
NPC = {"Azshir the Sleepless": 6490, "Fallen Champion": 6488, "Ironspine": 6489}
by = {}
for slug, en, ko, items in src:
    k = KEY.get(slug)
    if not k or not items: continue
    by.setdefault(k, []).append((en, ko, items))
def q(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write("-- FOA UI · 던전 희귀몹 · 특수 몹 · 상자 전리품 (자동 생성 · tools/dungeons/gen_rares.py)\n")
    f.write("-- 자료: wowf.io 던전 안내 전리품 표 (보스 외 출처 · 장비만) · ForeverLoot 에 합친다 (같은 이름 보스면 아이템만 더함)\n")
    f.write("-- [던전] = { { 한글 이름, { 아이템 }, NPC 번호(0 = 모름), 1 희귀 / 2 특수 몹 · 상자, 영문 이름 }, ... }\n")
    f.write("local _, ns = ...\nns.FOREVER_LOOT_EXTRA = {\n")
    for k in sorted(by):
        f.write("\t%s = {\n" % k)
        for en, ko, items in by[k]:
            f.write("\t\t{ %s, { %s }, %d, %d, %s },\n" % (q(ko), ", ".join(map(str, items)), NPC.get(en, 0), 1 if en in RARE else 2, q(en)))
        f.write("\t},\n")
    f.write("}\n\n")
    f.write('''-- 합치기: 같은 영문 이름의 보스가 있으면 빠진 아이템만 더하고, 없으면 희귀 · 선택 칸으로 붙인다
do
	local L = ns.FOREVER_LOOT
	for _, d in ipairs(L and L.list or {}) do
		local extra = ns.FOREVER_LOOT_EXTRA[d.key]
		if extra and d.bosses then
			for _, e in ipairs(extra) do
				local hit
				for _, b in ipairs(d.bosses) do
					if b[5] == e[5] or (e[3] ~= 0 and b[3] == e[3]) then hit = b break end
				end
				if hit then
					local have = {}
					for _, id in ipairs(hit[2]) do have[id] = true end
					for _, id in ipairs(e[2]) do if not have[id] then table.insert(hit[2], id) end end
				else
					table.insert(d.bosses, { e[1], e[2], e[3], e[4], e[5] })
				end
			end
		end
	end
end
''')
print(sum(len(v) for v in by.values()), "sources")
