-- FOA UI · 포에버 던전 전리품 보강 (자동 생성 · tools/dungeons/gen_patch.py)
-- 자료: AllTheThings (MIT) 최신 원본 .contrib/.db/forever (2026-11-17) · 새 던전 빈 보스 = wowf.io · wowtbc.gg 전리품 표 + Wago 아이템 표
-- [던전] = { { NPC, 영문 이름, { 아이템 }, 종류(0 보스 · 1 희귀 · 2 선택 · 3 일반 몹), 한글 이름, 앞에 넣을 NPC, 예전 NPC } }
--  같은 NPC(또는 예전 NPC · 같은 영문 이름) 보스가 있으면 빠진 아이템만 더하고 NPC 번호를 채운다 · 없으면 새 줄로
local _, ns = ...
ns.FOREVER_LOOT_PATCH = {
	alcaz = {
		{ 255391, "Overseer Wrex", { 276732, 276733, 276734 }, 0, nil, nil, nil },
		{ 0, "Trash", { 287017, 287018, 287020, 287019, 287021, 287025, 287023, 287024, 287022 }, 3, "일반 몹", nil, nil },
	},
	blackfathom = {
		{ 4831, nil, { 252798 }, 0, nil, nil, nil },
		{ 6243, nil, { 273141 }, 0, nil, nil, nil },
		{ 12876, "Baron Aquanis", { 16782 }, 2, "남작 아쿠아니스", nil, nil },
	},
	blackmaw = {
		{ 247207, "Blackmaw Behemoth", { 280065, 280066, 280067 }, 0, nil, nil, nil },
		{ 0, "Gortek the Apprentice", { 280077, 280078 }, 1, nil, nil, nil },
		{ 0, "Trash", { 287032, 287034, 287028, 287036 }, 3, "일반 몹", nil, nil },
	},
	brd = {
		{ 9025, nil, { 11813 }, 0, nil, nil, nil },
		{ 10096, nil, { 11610 }, 0, nil, nil, nil },
		{ 9024, nil, { 11207 }, 0, nil, nil, nil },
		{ 9543, nil, { 11612 }, 0, nil, nil, nil },
		{ 9499, nil, { 18653 }, 0, nil, nil, nil },
		{ 9938, nil, { 22208, 22400, 22395 }, 0, nil, nil, nil },
		{ 9027, "Gorosh the Dervish", { 11726 }, 2, nil, nil, nil },
		{ 9028, "Grizzle", { 11610, 11722, 11702, 11703 }, 2, nil, nil, nil },
		{ 9029, "Eviscerator", { 11686, 11679, 11730, 11685 }, 2, nil, nil, nil },
		{ 9030, "Ok'thor the Breaker", { 11662, 11824, 11665, 11728 }, 2, nil, nil, nil },
		{ 9031, "Anub'shiah", { 11678, 11677, 11731, 11675 }, 2, nil, nil, nil },
		{ 9032, "Hedrum the Creeper", { 11635, 11729, 11634, 11633 }, 2, nil, nil, nil },
		{ 16059, "Theldren", { 22047, 22305, 22317, 22318, 22330 }, 2, nil, nil, nil },
	},
	dalaran = {
		{ 246017, nil, { 273099 }, 0, nil, nil, nil },
		{ 246020, nil, { 273103 }, 0, nil, nil, nil },
		{ 0, "Trash", { 286992, 286991, 286994, 286988, 286987, 286989 }, 3, "일반 몹", nil, nil },
	},
	deadmines = {
		{ 643, nil, { 273092, 210178 }, 0, nil, nil, nil },
		{ 645, nil, { 8490, 273102 }, 0, nil, nil, nil },
	},
	dm_east = {
		{ 14354, nil, { 18267 }, 0, nil, nil, nil },
	},
	downs = {
		{ 7356, nil, { 274380 }, 0, nil, nil, nil },
		{ 7357, nil, { 252843 }, 0, nil, nil, nil },
		{ 8567, nil, { 274385 }, 0, nil, nil, nil },
		{ 7358, nil, { 274381 }, 0, nil, nil, nil },
	},
	drowned = {
		{ 258924, nil, { 274613 }, 0, nil, nil, nil },
		{ 273738, "Primeval Elemental", { 274611, 274612 }, 0, nil, nil, nil },
		{ 260202, "Deathless Marrow", { 274606, 274614, 274607 }, 2, nil, nil, nil },
		{ 264172, "Umbra", { 286662, 286658 }, 1, nil, nil, nil },
	},
	excavation = {
		{ 260325, nil, { 273106 }, 0, nil, nil, nil },
		{ 260326, nil, { 273097 }, 0, nil, nil, nil },
		{ 0, "Trash", { 286983, 287068, 286985 }, 3, "일반 몹", nil, nil },
	},
	gnomeregan = {
		{ 6229, nil, { 274049 }, 0, nil, nil, nil },
		{ 7800, nil, { 4415, 4413, 6716, 4411, 6672, 7742, 7560, 7561, 4416, 7192, 4417, 4408, 4412, 4414, 4410, 4409 }, 0, nil, nil, nil },
	},
	kroldok = {
		{ 258966, nil, { 273101 }, 0, nil, nil, nil },
		{ 0, "Trash", { 287007, 287008, 287009, 287011, 287012, 287013, 287014, 287015, 287016, 267137, 267138 }, 3, "일반 몹", nil, nil },
	},
	lbrs = {
		{ 10596, nil, { 249521 }, 0, nil, nil, nil },
		{ 9736, nil, { 12835 }, 0, nil, nil, nil },
		{ 9596, nil, { 12838 }, 0, nil, nil, nil },
		{ 10263, "Burning Felguard", { 13181, 13182 }, 2, nil, nil, nil },
	},
	lordaeron = {
		{ 0, "Trash", { 268535, 286981, 286978, 286979, 286980, 286977 }, 3, "일반 몹", nil, nil },
	},
	scholo = {
		{ 10508, nil, { 13521 }, 0, nil, nil, nil },
		{ 1853, nil, { 14514, 13501 }, 0, nil, nil, nil },
	},
	shadowfang = {
		{ 3886, nil, { 273096 }, 0, nil, nil, nil },
		{ 4278, nil, { 273105 }, 0, nil, nil, nil },
	},
	shapers = {
		{ 253201, "Titanosaur", { 280009, 280010, 280011 }, 0, nil, nil, nil },
		{ 253214, "Ravasaur Hunters", { 280012, 280013, 280014 }, 0, nil, nil, nil },
		{ 261812, "Thunderhoof", { 280018, 280019, 280020 }, 0, nil, nil, nil },
		{ 261813, "Venomridge", { 280015, 280016, 280017 }, 0, nil, nil, nil },
		{ 262127, "Direhorn Matriarch", { 280021, 280022, 280045 }, 0, nil, nil, nil },
		{ 261974, "Cinder", { 280028, 280029 }, 0, nil, nil, nil },
		{ 262297, "Snowtalon", { 280026, 280027 }, 0, nil, nil, nil },
		{ 262081, "Bolt", { 280031, 280032 }, 0, nil, nil, nil },
		{ 272561, "Vitrix", { 280026, 280027, 280028, 280031, 280032 }, 0, nil, nil, nil },
		{ 261809, "Nanaya", { 280023, 280024, 280025, 273128 }, 0, nil, nil, nil },
		{ 0, "Trash", { 287037 }, 3, "일반 몹", nil, nil },
	},
	sm_arm = {
		{ 6575, nil, { 255730 }, 0, nil, nil, nil },
	},
	sm_lib = {
		{ 3974, nil, { 273109 }, 0, nil, nil, nil },
	},
	strat_live = {
		{ 10558, nil, { 13379 }, 0, nil, nil, nil },
		{ 11120, nil, { 12827 }, 0, nil, nil, nil },
		{ 10997, nil, { 12839 }, 0, nil, nil, nil },
		{ 10811, nil, { 22897 }, 0, nil, nil, nil },
		{ 10813, "Balnazzar", { 13250, 14512, 13520, 13348, 18717, 13360, 13353, 13359, 18718, 12103, 18720, 13358, 13369, 16725 }, 0, nil, nil, 10812 },
	},
	strat_ud = {
		{ 10438, nil, { 12833 }, 0, nil, nil, nil },
		{ 10440, nil, { 13335 }, 0, nil, nil, nil },
		{ 11121, nil, { 12830 }, 0, nil, nil, nil },
	},
	sunken = {
		{ 8443, "Avatar of Hakkar", { 10663, 10844, 10838, 10843, 12462, 10845, 10842, 10846 }, 0, nil, nil, 8440 },
		{ 8580, "Atal'alarion", { 22444, 10799, 10800, 10798, 252871 }, 2, "아탈알라리온", 5710, nil },
	},
	thanes = {
		{ 0, "Trash", { 275893, 275892 }, 3, "일반 몹", nil, nil },
	},
	ubrs = {
		{ 9816, nil, { 249520, 23320 }, 0, nil, nil, nil },
		{ 10264, nil, { 18657 }, 0, nil, nil, nil },
		{ 10899, nil, { 12834, 12728, 12837 }, 0, nil, nil, nil },
		{ 10339, nil, { 13522 }, 0, nil, nil, nil },
		{ 10430, nil, { 24101 }, 0, nil, nil, nil },
		{ 10363, nil, { 15730, 13519 }, 0, nil, nil, nil },
	},
	uldaman = {
		{ 7023, nil, { 274485, 274428, 274430, 274425 }, 0, nil, nil, nil },
		{ 7206, nil, { 274431 }, 0, nil, nil, nil },
		{ 2748, nil, { 274432 }, 0, nil, nil, nil },
		{ 7228, "Ironaya", { 9408, 9409, 9407, 274484 }, 0, "아이로나야", 7023, nil },
	},
	wailing = {
		{ 3671, nil, { 273098 }, 0, nil, nil, nil },
		{ 3673, nil, { 273087 }, 0, nil, nil, nil },
	},
	zulfarrak = {
		{ 7795, nil, { 274652, 274651, 274653 }, 0, nil, nil, nil },
		{ 7273, nil, { 274657 }, 0, nil, nil, nil },
		{ 7272, nil, { 274638, 274639, 274641 }, 0, nil, nil, nil },
		{ 7271, nil, { 274642 }, 0, nil, nil, nil },
		{ 7796, nil, { 274643, 274644, 274645 }, 0, nil, nil, nil },
		{ 10082, nil, { 274658 }, 0, nil, nil, nil },
		{ 10080, nil, { 274659, 274660 }, 0, nil, nil, nil },
		{ 7604, nil, { 274646, 274647, 274648 }, 0, nil, nil, nil },
		{ 7797, nil, { 274655 }, 0, nil, nil, nil },
	},
}

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
