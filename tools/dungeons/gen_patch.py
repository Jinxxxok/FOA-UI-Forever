#!/usr/bin/env python3
"""
포에버 던전 전리품 보강 → FOA_UI/ForeverLootPatch.lua
 ForeverLoot(만들어 둔 자료) 위에 덮는 보강분:
  1) AllTheThings 최신 원본(.contrib/.db/forever/dungeons & raids/*.lua)의 보스별 전리품 중 빠진 아이템 · 바뀐 NPC 번호 · 빠진 보스
  2) 1.60.1 새 던전(알카즈 · 검은아귀 · 구체자) 중 ATT 에 전리품이 비어 있는 보스 = 공개 전리품 표(wowf.io · wowtbc.gg) 이름 → 아이템 번호(Wago ItemSearchName · Item 표)
  3) 새 던전 일반 몹 전리품 (ATT ZONE_DROPS)
사용: python3 -I gen_patch.py att_bosses.json adds.json ForeverLootPatch.lua
"""
import sys, json
att = json.load(open(sys.argv[1], encoding="utf-8"))
adds = json.load(open(sys.argv[2], encoding="utf-8"))
P = {}   # key -> list of entries
def put(key, npc, en, items, kind=0, ko=None, before=None, old=None):
    P.setdefault(key, []).append(dict(npc=npc, en=en, items=items, kind=kind, ko=ko, before=before, old=old))

# 1) 있는 보스에 빠진 아이템 (NPC 번호로 맞춘다)
for key, m in adds.items():
    for npc, items in m.items():
        put(key, int(npc), None, items)

# 1-b) 바뀐 · 빠진 보스 (ATT 원본 기준)
A = lambda f, n: att[f]["bosses"][str(n)]["items"]
put("alcaz", 255391, "Overseer Wrex", A("alcaz prison.lua", 255391))                       # 감독관 렉스 (예전 자료엔 NPC · 전리품 없음)
put("uldaman", 7228, "Ironaya", A("uldaman.lua", 7228), 0, "아이로나야", before=7023)
put("strat_live", 10813, "Balnazzar", A("stratholme.lua", 10813), old=10812)               # 시체는 발나자르(10813) · 예전엔 달로한(10812)
put("sunken", 8443, "Avatar of Hakkar", A("the temple of atal'hakkar.lua", 8443), old=8440)
put("sunken", 8580, "Atal'alarion", A("the temple of atal'hakkar.lua", 8580), 2, "아탈알라리온", before=5710)
put("drowned", 273738, "Primeval Elemental", [274611, 274612])
put("drowned", 260202, "Deathless Marrow", A("the drowned city.lua", 260202), 2)
put("drowned", 264172, "Umbra", A("the drowned city.lua", 264172), 1)
put("blackfathom", 12876, "Baron Aquanis", A("blackfathom deeps.lua", 12876), 2, "남작 아쿠아니스")
put("lbrs", 10263, "Burning Felguard", A("blackrock spire.lua", 10263), 2)
for n, en in ((9027, "Gorosh the Dervish"), (9028, "Grizzle"), (9029, "Eviscerator"), (9030, "Ok'thor the Breaker"),
              (9031, "Anub'shiah"), (9032, "Hedrum the Creeper"), (16059, "Theldren")):
    put("brd", n, en, A("blackrock depths.lua", n), 2)

# 2) 새 던전: 공개 전리품 표 (보스 순서는 ForeverLoot 그대로)
put("shapers", 253201, "Titanosaur", [280009, 280010, 280011])
put("shapers", 253214, "Ravasaur Hunters", [280012, 280013, 280014])
put("shapers", 261812, "Thunderhoof", [280018, 280019, 280020])
put("shapers", 261813, "Venomridge", [280015, 280016, 280017])
put("shapers", 262127, "Direhorn Matriarch", [280021, 280022, 280045])
put("shapers", 261974, "Cinder", [280028, 280029])
put("shapers", 262297, "Snowtalon", [280026, 280027])
put("shapers", 262081, "Bolt", [280031, 280032])
put("shapers", 272561, "Vitrix", [280026, 280027, 280028, 280031, 280032])
put("shapers", 261809, "Nanaya", [280023, 280024, 280025, 273128])
put("blackmaw", 247207, "Blackmaw Behemoth", [280065, 280066, 280067])
put("blackmaw", 0, "Gortek the Apprentice", [280077, 280078], 1)

# 3) 새 던전 일반 몹 전리품 (예전 출처 자료(2026-11-10)에 없는 1.60.1 새 아이템)
TRASH = {
    "alcaz": [t["item"] for t in att["alcaz prison.lua"]["trash"]],
    "dalaran": [t["item"] for t in att["city of dalaran.lua"]["trash"]],
    "excavation": [t["item"] for t in att["excavation site - wetlands.lua"]["trash"]],
    "thanes": [t["item"] for t in att["hall of thanes.lua"]["trash"]],
    "kroldok": [t["item"] for t in att["krol'dok stronghold.lua"]["trash"]],
    "lordaeron": [t["item"] for t in att["ruins of lordaeron.lua"]["trash"]],
    "blackmaw": [287032, 287034, 287028, 287036],
    "shapers": [287037],
}
for key, items in TRASH.items():
    put(key, 0, "Trash", items, 3, "일반 몹")

def lua_s(s): return "nil" if s is None else '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
L = ["-- FOA UI · 포에버 던전 전리품 보강 (자동 생성 · tools/dungeons/gen_patch.py)",
     "-- 자료: AllTheThings (MIT) 최신 원본 .contrib/.db/forever (2026-11-17) · 새 던전 빈 보스 = wowf.io · wowtbc.gg 전리품 표 + Wago 아이템 표",
     "-- [던전] = { { NPC, 영문 이름, { 아이템 }, 종류(0 보스 · 1 희귀 · 2 선택 · 3 일반 몹), 한글 이름, 앞에 넣을 NPC, 예전 NPC } }",
     "--  같은 NPC(또는 예전 NPC · 같은 영문 이름) 보스가 있으면 빠진 아이템만 더하고 NPC 번호를 채운다 · 없으면 새 줄로",
     "local _, ns = ...", "ns.FOREVER_LOOT_PATCH = {"]
for key in sorted(P):
    L.append("\t%s = {" % key)
    for e in P[key]:
        L.append("\t\t{ %d, %s, { %s }, %d, %s, %s, %s }," % (e["npc"], lua_s(e["en"]), ", ".join(map(str, e["items"])), e["kind"], lua_s(e["ko"]),
                 e["before"] or "nil", e["old"] or "nil"))
    L.append("\t},")
L.append("}")
L.append(r'''
-- 덮기: ForeverLootExtra 합친 다음, 던전 화면이 자료를 읽기 전에
do
	local L = ns.FOREVER_LOOT
	for _, d in ipairs(L and L.list or {}) do
		local patch = ns.FOREVER_LOOT_PATCH[d.key]
		if patch and d.bosses then
			for _, e in ipairs(patch) do
				local npc, en, items, kind, ko, before, old = e[1], e[2], e[3], e[4], e[5], e[6], e[7]
				local hit
				for _, b in ipairs(d.bosses) do
					if (npc ~= 0 and b[3] == npc) or (old and b[3] == old) or (en and (b[5] == en or b[1] == en) and (kind ~= 3 or b[4] == 3)) then hit = b break end
				end
				if hit then
					if npc ~= 0 and (hit[3] == 0 or hit[3] == old) then hit[3] = npc end
					local have = {}
					for _, id in ipairs(hit[2]) do have[id] = true end
					for _, id in ipairs(items) do if not have[id] then table.insert(hit[2], id); have[id] = true end end
				else
					local copy = {}
					for i, id in ipairs(items) do copy[i] = id end
					local row = { ko or en or "?", copy, npc, kind or 0, en or "" }
					local at
					if before then for i, b in ipairs(d.bosses) do if b[3] == before then at = i break end end end
					if at then table.insert(d.bosses, at, row) else table.insert(d.bosses, row) end
				end
			end
		end
	end
end
''')
open(sys.argv[3], "w", encoding="utf-8").write("\n".join(L))
print({k: len(v) for k, v in P.items()})
