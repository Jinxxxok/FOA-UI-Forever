-- FOA UI · 현황 아이콘 (전문기술 · 무기 숙련 · 평판을 창을 열지 않고 둥근 아이콘으로)
--  · 전문기술 / 보조 기술 (요리 · 응급치료 · 낚시 · 독) / 자물쇠 따기: 아이콘 + 숙련 + 아래 진행 막대
--  · 모양: FOA 아이콘 칸 (둥근 모서리 · 얇은 테두리) · 전문 민트 / 무기 파랑 / 평판 단계 색 · 다 올리면 금색
--  · 묶음 사이엔 넓은 틈과 가는 세로 선
--  · 무기 숙련 · 방어: 자동이면 써 본 무기 중 아직 다 안 올린 것 4개까지
--  · 평판: 자동이면 추적 중인 평판 + 이번 접속에서 오른 평판
--  · 설정 "일반 → 현황 아이콘 고르기" 에서 하나씩 켜고 끄기 (캐릭터별 · 고른 것이 자동보다 먼저)
--  숙련이 오르면 아이콘이 톡 튀고 "+1" 이 떠오른다. 마우스를 올리면 자세히.
--  위치: FOA 편집 모드 "현황 아이콘"

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Tracker")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local ICON, GAP, GROUP_GAP, ROW_GAP = 28, 7, 19, 10   -- 아이콘 · 칸 사이 · 묶음 사이 · 줄 사이
local CHIP_H = ICON + 19                                 -- 아이콘 + 막대 + 숫자
local PER_ROW = 12                                       -- 한 줄 폭 (아이콘 수 기준)
local GOLD = { 0.890, 0.753, 0.478 }                     -- 다 올림 (FOA gold)
local KIND_RGB = {
	prof = { 0.435, 0.827, 0.604 },     -- 전문기술 · 보조 기술: 민트
	weapon = { 0.498, 0.659, 1.000 },   -- 무기 숙련 · 방어: 강철 파랑
}

-- 이름 → 아이콘 (그 기술을 배우는 주문의 아이콘. 이름은 게임 언어 그대로라 한국어 · 영어 다 맞는다)
local PROF_SPELLS = { 2259, 2018, 7411, 4036, 2366, 2108, 2575, 8613, 3908, 2550, 3273, 7620, 1804, 2842 }
local WEAPON_SPELLS = { 196, 197, 264, 266, 198, 199, 200, 201, 202, 227, 15590, 1180, 2567, 5011, 5009, 203, 204 }

local function SpellInfo(id)
	local name, icon
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, i = pcall(C_Spell.GetSpellInfo, id)
		if ok and i then name, icon = i.name, i.iconID end
	end
	if not name and GetSpellInfo then
		local ok, n, _, ic = pcall(GetSpellInfo, id)
		if ok then name, icon = n, ic end
	end
	return name, icon
end

local ICONS, KIND
local function BuildIcons()
	if ICONS then return end
	ICONS, KIND = {}, {}
	for _, id in ipairs(PROF_SPELLS) do
		local n, ic = SpellInfo(id)
		if n then ICONS[n] = ic; KIND[n] = "prof" end
	end
	for _, id in ipairs(WEAPON_SPELLS) do
		local n, ic = SpellInfo(id)
		if n then ICONS[n] = ic; KIND[n] = "weapon" end
	end
end

local function Section(h)
	h = h or ""
	if h:find("전문") or h:find("Profession") then return "prof" end
	if h:find("보조") or h:find("Secondary") then return "prof" end
	if h:find("무기") or h:find("Weapon") then return "weapon" end
	return "other"
end

-- 기술 번호 → 아이콘 주문 · 종류 (포에버 C_SkillInfo 는 기술 번호를 준다)
local SKILL_SPELL = {
	[171] = 2259, [164] = 2018, [333] = 7411, [202] = 4036, [182] = 2366, [165] = 2108, [186] = 2575, [393] = 8613,
	[197] = 3908, [185] = 2550, [129] = 3273, [356] = 7620, [633] = 1804, [40] = 2842,
	[173] = 1180, [43] = 201, [55] = 202, [44] = 196, [172] = 197, [54] = 198, [160] = 199, [229] = 200, [136] = 227,
	[162] = 203, [473] = 15590, [45] = 264, [46] = 266, [226] = 5011, [176] = 2567, [228] = 5009, [95] = 204,
}
local PROF_ORDER = { 171, 164, 333, 202, 182, 165, 186, 393, 197, 185, 129, 356, 633, 40 }
local WEAPON_ORDER = { 173, 43, 55, 44, 172, 54, 160, 229, 136, 162, 473, 45, 46, 226, 176, 228, 3014, 95 }
local PROF_ID, WEAPON_ID = {}, {}
for _, id in ipairs(PROF_ORDER) do PROF_ID[id] = true end
for _, id in ipairs(WEAPON_ORDER) do WEAPON_ID[id] = true end
-- 기술 분류 번호: 6 무기 · 9 보조 기술 · 11 전문기술
local CAT_KIND = { [6] = "weapon", [9] = "prof", [11] = "prof" }

local function SkillIcon(id, name)
	local sp = id and SKILL_SPELL[id]
	if sp then
		local _, ic = SpellInfo(sp)
		if ic then return ic end
	end
	BuildIcons()
	return name and ICONS[name]
end

local function AddSkill(out, seen, kind, name, rank, max, mod, id, icon)
	if not name or seen[name] or (max or 0) < 1 then return end
	seen[name] = true
	out[#out + 1] = { key = "s:" .. name, name = name, rank = rank or 0, max = max, mod = mod or 0, kind = kind,
		icon = icon or SkillIcon(id, name), skillID = id }
end

-- 기술 목록 읽기 (캐릭터 창 "기술" 탭과 같은 자료)
--  포에버: C_SkillInfo (번호 · 표) · 오리지널식: GetSkillLineInfo · 본섭: GetProfessions (전문기술만)
local function Skills()
	local out, seen = {}, {}
	local SI = C_SkillInfo
	if SI and SI.GetSkillLineInfo then
		local sec = "other"
		local n = SI.GetNumSkillLines and SI.GetNumSkillLines() or 0
		for i = 1, n do
			local ok, d = pcall(SI.GetSkillLineInfo, i)
			if ok and type(d) == "table" then
				if d.isHeader then
					sec = Section(d.name)
				elseif (d.parentSkillLineID or 0) == 0 then
					local id = d.skillID
					local kind = (WEAPON_ID[id] and "weapon") or (PROF_ID[id] and "prof") or CAT_KIND[d.skillLineCategoryID]
						or (sec ~= "other" and sec) or nil
					if kind then AddSkill(out, seen, kind, d.name, d.rank, d.maxRank, d.modifier, id) end
				end
			end
		end
		-- 기술 창에서 접어 둔 묶음 안의 기술은 위 목록에 안 나와서 번호로 한 번 더 찾는다
		if SI.GetSkillLineInfoByID then
			for _, grp in ipairs({ { PROF_ORDER, "prof" }, { WEAPON_ORDER, "weapon" } }) do
				for _, id in ipairs(grp[1]) do
					local ok, d = pcall(SI.GetSkillLineInfoByID, id)
					if ok and type(d) == "table" and not d.isHeader and (d.rank or 0) > 0 then
						AddSkill(out, seen, grp[2], d.name, d.rank, d.maxRank, d.modifier, id)
					end
				end
			end
		end
		if #out > 0 then return out end
	end
	if GetNumSkillLines and GetSkillLineInfo then
		BuildIcons()
		local sec = "other"
		for i = 1, GetNumSkillLines() do
			local name, header, _, rank, _, mod, max = GetSkillLineInfo(i)
			if header then
				sec = Section(name)
			elseif name and (max or 0) > 1 then
				local kind = (sec ~= "other" and sec) or KIND[name]
				if kind then AddSkill(out, seen, kind, name, rank, max, mod, nil, ICONS[name]) end
			end
		end
		if #out > 0 then return out end
	end
	if GetProfessions and GetProfessionInfo then
		local t = { GetProfessions() }
		for i = 1, 6 do
			local idx = t[i]
			if idx then
				local ok, name, icon, rank, max, _, _, line, mod = pcall(GetProfessionInfo, idx)
				if ok and name then AddSkill(out, seen, "prof", name, rank, max, mod, line, icon) end
			end
		end
	end
	return out
end

-- 평판 (추적 중 + 이번 접속에서 오른 것)
local STANDING_RGB = {
	[1] = { 1.000, 0.420, 0.369 }, [2] = { 1.000, 0.420, 0.369 }, [3] = { 1.000, 0.718, 0.353 }, [4] = { 0.910, 0.824, 0.478 },
	[5] = { 0.435, 0.827, 0.604 }, [6] = { 0.310, 0.765, 0.631 }, [7] = { 0.361, 0.784, 0.839 }, [8] = { 0.498, 0.659, 1.000 },
}

local function FactionByID(id)
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, d = pcall(C_Reputation.GetFactionDataByID, id)
		if ok and d and d.name then
			return { id = id, name = d.name, standing = d.reaction, min = d.currentReactionThreshold, max = d.nextReactionThreshold, val = d.currentStanding }
		end
	end
	if GetFactionInfoByID then
		local ok, name, _, standing, bmin, bmax, val = pcall(GetFactionInfoByID, id)
		if ok and name then return { id = id, name = name, standing = standing, min = bmin, max = bmax, val = val } end
	end
end

-------------------------------------------------------------------------------
-- 평판 그림: 진영마다 그 진영을 떠올리게 하는 아이콘
--  도시 = 마법사 순간이동 아이콘 · 상인 마을 = 지역 그림 · 그 밖엔 상징 물건
--  진영 번호 → 이름 낱말 → 묶음(스팀휘들 · 얼라이언스 · 호드) 순으로 찾고, 없으면 첫 글자 칸
--  후보를 여러 개 두고 게임에 실제로 있는 그림만 쓴다 (GetFileIDFromPath 로 확인)
-------------------------------------------------------------------------------
local REP_ICON_ID = {
	[72] = { "Spell_Arcane_TeleportStormWind", "INV_Misc_Tournaments_banner_Human" },
	[47] = { "Spell_Arcane_TeleportIronForge" },
	[69] = { "Spell_Arcane_TeleportDarnassus" },
	[54] = { "INV_Misc_Tournaments_banner_Gnome", "Achievement_Character_Gnome_Male", "INV_Gizmo_01" },
	[930] = { "Spell_Arcane_TeleportExodar" },
	[76] = { "Spell_Arcane_TeleportOrgrimmar" },
	[81] = { "Spell_Arcane_TeleportThunderBluff" },
	[68] = { "Spell_Arcane_TeleportUnderCity" },
	[530] = { "INV_Misc_Tournaments_banner_Troll", "Achievement_Character_Troll_Male" },
	[911] = { "Spell_Arcane_TeleportSilvermoon" },
	[21] = { "Achievement_Zone_Stranglethorn_01", "INV_Misc_Bandana_03" },
	[369] = { "Achievement_Zone_Tanaris_01", "INV_Misc_Coin_02" },
	[470] = { "Achievement_Zone_Barrens_01", "INV_Misc_Coin_01" },
	[577] = { "Achievement_Zone_Winterspring", "INV_Misc_Coin_01" },
	[909] = { "INV_Misc_Ticket_Darkmoon_01" },
	[1090] = { "Achievement_Reputation_KirinTor", "Spell_Arcane_TeleportDalaran" },
	[609] = { "Achievement_Zone_Silithus_01", "Spell_Nature_Regeneration" },
	[529] = { "INV_Jewelry_Talisman_07", "Achievement_Reputation_ArgentCrusader" },
	[576] = { "Achievement_Reputation_timbermaw" },
	[59] = { "INV_Ingot_Thorium" },
	[270] = { "INV_Bijou_Red" },
	[749] = { "Spell_Frost_SummonWaterElemental_2" },
	[910] = { "INV_Misc_Head_Dragon_Bronze" },
	[809] = { "INV_Misc_Book_11" },
	[589] = { "Ability_Mount_WhiteTiger" },
	[890] = { "INV_BannerPVP_02" },
	[730] = { "INV_Jewelry_StormPikeTrinket_01" },
	[729] = { "INV_Jewelry_FrostwolfTrinket_01" },
	[509] = { "INV_BannerPVP_02" },
	[510] = { "INV_BannerPVP_01" },
	[889] = { "INV_BannerPVP_01" },
	[92] = { "INV_Misc_Head_Centaur_01" },
	[93] = { "INV_Misc_Head_Centaur_01" },
	[349] = { "Ability_Stealth" },
	[70] = { "INV_Misc_Note_06" },
	[471] = { "Ability_Mount_Gryphon_01" },
	[87] = { "INV_Misc_Bandana_03" },
}
-- 이름 낱말 (한국어 · 영어) → 같은 그림 · 포에버에만 있는 진영도 이걸로 잡는다
local REP_ICON_WORD = {
	{ "스톰윈드", 72 }, { "Stormwind", 72 }, { "아이언포지", 47 }, { "Ironforge", 47 }, { "다르나서스", 69 }, { "Darnassus", 69 },
	{ "놈리건", 54 }, { "Gnomeregan", 54 }, { "엑소다르", 930 }, { "Exodar", 930 }, { "오그리마", 76 }, { "Orgrimmar", 76 },
	{ "썬더 블러프", 81 }, { "Thunder Bluff", 81 }, { "언더시티", 68 }, { "Undercity", 68 }, { "검은창", 530 }, { "Darkspear", 530 },
	{ "실버문", 911 }, { "Silvermoon", 911 }, { "무법항", 21 }, { "Booty Bay", 21 }, { "가젯잔", 369 }, { "Gadgetzan", 369 },
	{ "톱니항", 470 }, { "Ratchet", 470 }, { "눈망루", 577 }, { "Everlook", 577 }, { "다크문", 909 }, { "Darkmoon", 909 },
	{ "키린 토", 1090 }, { "Kirin Tor", 1090 }, { "세나리온", 609 }, { "Cenarion", 609 }, { "은빛 여명", 529 }, { "Argent Dawn", 529 },
	{ "나무구렁", 576 }, { "Timbermaw", 576 }, { "토륨", 59 }, { "Thorium", 59 }, { "잔달라", 270 }, { "Zandalar", 270 },
	{ "히드락시안", 749 }, { "Hydraxian", 749 }, { "놀즈도르무", 910 }, { "Nozdormu", 910 }, { "쉔드랄라", 809 }, { "Shen'dralar", 809 },
	{ "Wintersaber", 589 }, { "은빛날개", 890 }, { "Silverwing", 890 }, { "스톰파이크", 730 }, { "Stormpike", 730 },
	{ "서리늑대", 729 }, { "Frostwolf", 729 }, { "아라소르", 509 }, { "Arathor", 509 }, { "Defilers", 510 }, { "전쟁노래", 889 }, { "Warsong", 889 },
	{ "켄타우로스", 92 }, { "Centaur", 92 }, { "라벤홀트", 349 }, { "Ravenholdt", 349 }, { "Syndicate", 70 },
	{ "와일드해머", 471 }, { "Wildhammer", 471 }, { "해적", 87 }, { "Bloodsail", 87 },
}
local REP_ICON_THEME = {   -- 그 밖의 진영: 이름에 든 낱말로 분위기 맞추기
	{ "마법", { "Spell_Holy_MagicalSentry", "Spell_Arcane_ArcaneResilience" } }, { "Arcan", { "Spell_Holy_MagicalSentry" } },
	{ "상업", { "INV_Misc_Coin_02" } }, { "Commerce", { "INV_Misc_Coin_02" } }, { "무역", { "INV_Misc_Coin_02" } },
	{ "드루이드", { "Ability_Druid_CatForm", "Spell_Nature_Regeneration" } }, { "Druid", { "Ability_Druid_CatForm" } },
	{ "화약", { "INV_Misc_Bomb_04" } }, { "Powder", { "INV_Misc_Bomb_04" } }, { "기계", { "Trade_Engineering" } },
	{ "학자", { "INV_Misc_Book_09" } }, { "서고", { "INV_Misc_Book_09" } },
}
local REP_ICON_GROUP = {   -- 묶음 이름 → 그 묶음 공통 그림
	{ "스팀휘들", { "INV_Misc_Coin_01" } }, { "Steamwheedle", { "INV_Misc_Coin_01" } },
	{ "얼라이언스", { "INV_BannerPVP_02" } }, { "Alliance", { "INV_BannerPVP_02" } },
	{ "호드", { "INV_BannerPVP_01" } }, { "Horde", { "INV_BannerPVP_01" } },
}

local iconCache = {}
local function IconFile(name)
	local v = iconCache[name]
	if v == nil then
		local path = "Interface\\Icons\\" .. name
		v = path
		if GetFileIDFromPath then
			local ok, id = pcall(GetFileIDFromPath, path)
			v = (ok and type(id) == "number" and id > 0) and id or false
		end
		iconCache[name] = v
	end
	return v or nil
end

local function FirstIcon(list)
	for _, n in ipairs(list or {}) do
		local v = IconFile(n)
		if v then return v end
	end
end

local function FindWord(tbl, name)
	if not name then return end
	for _, w in ipairs(tbl) do
		if name:find(w[1], 1, true) then return w[2] end
	end
end

M.repGroup = {}   -- 진영 번호 → 평판 창 묶음 이름 (FactionRows 가 채움)
local function RepIcon(id, name, group)
	local v = id and FirstIcon(REP_ICON_ID[id])
	if v then return v end
	local wid = FindWord(REP_ICON_WORD, name)
	v = wid and FirstIcon(REP_ICON_ID[wid])
	if v then return v end
	v = FirstIcon(FindWord(REP_ICON_THEME, name))
	if v then return v end
	return FirstIcon(FindWord(REP_ICON_GROUP, group or (id and M.repGroup[id])))
end

local function Watched()
	if C_Reputation and C_Reputation.GetWatchedFactionData then
		local ok, d = pcall(C_Reputation.GetWatchedFactionData)
		if ok and d and d.factionID and d.factionID > 0 then return FactionByID(d.factionID) end
	end
	if GetWatchedFactionInfo then
		local name, standing, bmin, bmax, val, id = GetWatchedFactionInfo()
		if name then return { id = id, name = name, standing = standing, min = bmin, max = bmax, val = val } end
	end
end

local function FactionIDByName(name)
	if not name then return end
	local n = (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetNumFactions()) or (GetNumFactions and GetNumFactions()) or 0
	for i = 1, n do
		local fname, fid
		if C_Reputation and C_Reputation.GetFactionDataByIndex then
			local d = C_Reputation.GetFactionDataByIndex(i)
			fname, fid = d and d.name, d and d.factionID
		elseif GetFactionInfo then
			local r = { GetFactionInfo(i) }
			fname, fid = r[1], r[14]
		end
		if fname == name then return fid end
	end
end

-------------------------------------------------------------------------------
-- 직접 고르기 (캐릭터별 InkUICharDB.trackerPick)
--  [키] = 숫자(고정 · 고른 차례) / false(빼기) / 없음(자동)
--  키: 기술 "s:이름" · 평판 "f:진영번호" (번호를 못 얻으면 "r:이름")
-------------------------------------------------------------------------------
local function Picks(make)
	local c = Ink.cdb
	if not c then return {} end
	if make and type(c.trackerPick) ~= "table" then c.trackerPick = {} end
	return c.trackerPick or {}
end

local function Pick(key)
	local v = Picks()[key]
	if v == nil then return nil end
	return v and true or false
end

local function RepKey(f) return f.id and ("f:" .. f.id) or ("r:" .. (f.name or "?")) end

-- 직접 고른 묶음 (무기 · 평판): 하나라도 고르면 그 묶음은 "고른 것만" 보인다
--  자동(덜 올린 무기 · 추적 중 · 방금 오른 평판)은 아무것도 안 골랐을 때만
--  (다 올려서 자동으로 숨었던 무기가 레벨업 뒤 다시 튀어나오지 않게)
local function RepManual()
	for k, v in pairs(Picks()) do
		if v ~= nil and (k:find("^f:") or k:find("^r:")) then return true end
	end
	return false
end

local function WeaponManual(skills)
	for _, sk in ipairs(skills) do
		if sk.kind == "weapon" and Pick(sk.key) ~= nil then return true end
	end
	return false
end

local function RepEntry(f)
	f.icon = f.icon or RepIcon(f.id, f.name)
	f.key = "r:" .. f.name
	f.pick = RepKey(f)
	f.kind = "rep"
	f.rank = (f.val or 0) - (f.min or 0)
	f.max = math.max(1, (f.max or 1) - (f.min or 0))
	return f
end

local function Reps()
	local out, seen = {}, {}
	local function add(f)
		if not f or not f.name then return end
		local k = RepKey(f)
		if seen[k] then return end
		seen[k] = true
		out[#out + 1] = RepEntry(f)
	end
	-- 고정한 평판 먼저 (고른 차례대로)
	local pins = {}
	for k, v in pairs(Picks()) do
		if type(v) == "number" then
			local id = tonumber(k:match("^f:(%d+)$"))
			local name = not id and k:match("^r:(.+)$")
			if id or name then pins[#pins + 1] = { id = id, name = name, n = v } end
		end
	end
	table.sort(pins, function(a, b) return a.n < b.n end)
	for _, p in ipairs(pins) do
		local id = p.id or FactionIDByName(p.name)
		if id then add(FactionByID(id)) end
	end
	-- 자동: 추적 중 + 이번 접속에서 오른 것 (뺀 것은 건너뜀 · 자동은 3개까지)
	if Ink.db.trackerReps ~= false and not RepManual() then
		local auto = {}
		local w = Watched()
		if w then auto[#auto + 1] = w end
		for _, id in ipairs(M.recentRep or {}) do auto[#auto + 1] = FactionByID(id) end
		local n = 0
		for _, f in ipairs(auto) do
			if f and f.name and n < 3 and Pick(RepKey(f)) == nil and not seen[RepKey(f)] then
				add(f)
				n = n + 1
			end
		end
	end
	return out
end

-- 평판 창의 모든 진영 (접힌 묶음은 잠깐 펼쳐 읽고 다시 접어 둔다)
local function FactionRows()
	local CR = C_Reputation
	local useC = CR and CR.GetFactionDataByIndex and true or false
	local function num()
		if useC and CR.GetNumFactions then return CR.GetNumFactions() or 0 end
		return GetNumFactions and GetNumFactions() or 0
	end
	local function info(i)
		if useC then
			local d = CR.GetFactionDataByIndex(i)
			if not d then return end
			return { name = d.name, header = d.isHeader, collapsed = d.isCollapsed, hasRep = d.isHeaderWithRep, id = d.factionID,
				standing = d.reaction, min = d.currentReactionThreshold, max = d.nextReactionThreshold, val = d.currentStanding }
		elseif GetFactionInfo then
			local name, _, standing, bmin, bmax, val, _, _, isHeader, isCollapsed, hasRep, _, _, fid = GetFactionInfo(i)
			if not name then return end
			return { name = name, header = isHeader, collapsed = isCollapsed, hasRep = hasRep, id = fid,
				standing = standing, min = bmin, max = bmax, val = val }
		end
	end
	local expand = (useC and CR.ExpandFactionHeader) or ExpandFactionHeader
	local collapse = (useC and CR.CollapseFactionHeader) or CollapseFactionHeader
	local opened = {}
	if expand then
		local i, guard = 1, 0
		while i <= num() and guard < 400 do
			guard = guard + 1
			local d = info(i)
			if d and d.header and d.collapsed and d.name then
				if pcall(expand, i) then opened[d.name] = true end
			end
			i = i + 1
		end
	end
	local rows, grp = {}, nil
	for i = 1, num() do
		local d = info(i)
		if d and d.name then
			if d.header and not d.hasRep then grp = d.name end
			d.group = grp
			if d.id then M.repGroup[d.id] = grp end
			rows[#rows + 1] = d
		end
	end
	-- 펼쳤던 묶음은 뒤에서부터 다시 접는다 (앞 번호가 밀리지 않게)
	if collapse and next(opened) then
		for i = num(), 1, -1 do
			local d = info(i)
			if d and d.header and not d.collapsed and opened[d.name] then pcall(collapse, i) end
		end
	end
	return rows
end

-------------------------------------------------------------------------------
-- 아이콘 칩 (FOA 아이콘 칸: 둥근 모서리 + 얇은 테두리 · 아래 가는 진행 막대 + 숫자)
--  전문기술 = 민트 · 무기 = 파랑 · 평판 = 평판 단계 색 · 다 올리면 금색 테두리와 은은한 빛
-------------------------------------------------------------------------------
local function FirstChar(name)
	return (name or "?"):match("^[%z\1-\127\194-\244][\128-\191]*") or "?"
end

local function NewChip(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(ICON, CHIP_H)
	-- 아이콘 칸
	b.ic = CreateFrame("Frame", nil, b)
	b.ic:SetSize(ICON, ICON)
	b.ic:SetPoint("TOP")
	b.icon = b.ic:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.skin = Ink:IconSkin(b.ic, b.icon, true)
	b.skin.bg:SetVertexColor(0.035, 0.040, 0.052, 0.86)
	-- 글자 칸 (평판 · 아이콘 없는 기술): 단계 색을 옅게 깐 바탕 + 굵은 첫 글자
	b.wash = Ink:Round(b.ic, "BORDER", true)
	b.wash:SetPoint("TOPLEFT", 1, -1)
	b.wash:SetPoint("BOTTOMRIGHT", -1, 1)
	b.letter = Ink:Text(b.skin.top, F.bold, 13, C.text, "CENTER")
	b.letter:SetPoint("CENTER", b.ic, "CENTER", 0, 0)
	-- 위쪽 은은한 윤기 (아이콘이 납작해 보이지 않게)
	b.sheen = b.skin.top:CreateTexture(nil, "ARTWORK")
	b.sheen:SetPoint("TOPLEFT", b.ic, "TOPLEFT", 4, -2)
	b.sheen:SetPoint("TOPRIGHT", b.ic, "TOPRIGHT", -4, -2)
	b.sheen:SetHeight(ICON * 0.42)
	b.sheen:SetTexture(Ink.tex.white)
	if b.sheen.SetGradient and CreateColor then
		pcall(b.sheen.SetGradient, b.sheen, "VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.07))
	else
		b.sheen:SetVertexColor(1, 1, 1, 0.035)
	end
	-- 빛 (다 올림 · 오를 때 번쩍)
	b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -7)
	b.glow:SetTexture(Ink.tex.glow)
	b.glow:SetPoint("TOPLEFT", b.ic, "TOPLEFT", -11, 11)
	b.glow:SetPoint("BOTTOMRIGHT", b.ic, "BOTTOMRIGHT", 11, -11)
	b.glow:SetBlendMode("ADD")
	b.glow:SetAlpha(0)
	-- 진행 막대 (아이콘 폭 · 2점 · 둥근 끝 대신 1점 안쪽으로 들여 깔끔하게)
	b.track = b:CreateTexture(nil, "ARTWORK")
	b.track:SetTexture(Ink.tex.white)
	b.track:SetHeight(2)
	b.track:SetPoint("TOPLEFT", b.ic, "BOTTOMLEFT", 2, -4)
	b.track:SetPoint("TOPRIGHT", b.ic, "BOTTOMRIGHT", -2, -4)
	b.track:SetVertexColor(1, 1, 1, 0.09)
	b.fill = b:CreateTexture(nil, "OVERLAY")
	b.fill:SetTexture(Ink.tex.white)
	b.fill:SetHeight(2)
	b.fill:SetPoint("LEFT", b.track, "LEFT")
	b.tip = b:CreateTexture(nil, "OVERLAY", nil, 1)   -- 막대 끝 밝은 점
	b.tip:SetTexture(Ink.tex.white)
	b.tip:SetSize(2, 2)
	b.tip:SetPoint("RIGHT", b.fill, "RIGHT")
	b.num = Ink:Text(b, F.numR, 10, C.soft, "CENTER")
	b.num:SetPoint("TOP", b.track, "BOTTOM", 0, -3)
	-- 오를 때: 톡 튀기 + 빛 번쩍 + "+1" 떠오르기
	b.pop = b.ic:CreateAnimationGroup()
	local s1 = b.pop:CreateAnimation("Scale")
	s1:SetScaleFrom(1, 1); s1:SetScaleTo(1.16, 1.16); s1:SetDuration(0.12); s1:SetOrder(1); s1:SetSmoothing("OUT")
	local s2 = b.pop:CreateAnimation("Scale")
	s2:SetScaleFrom(1.16, 1.16); s2:SetScaleTo(1, 1); s2:SetDuration(0.26); s2:SetOrder(2); s2:SetSmoothing("IN")
	b.flash = b.glow:CreateAnimationGroup()
	local g1 = b.flash:CreateAnimation("Alpha"); g1:SetFromAlpha(0); g1:SetToAlpha(0.7); g1:SetDuration(0.14); g1:SetOrder(1)
	local g2 = b.flash:CreateAnimation("Alpha"); g2:SetFromAlpha(0.7); g2:SetToAlpha(0); g2:SetDuration(0.9); g2:SetOrder(2); g2:SetSmoothing("OUT")
	b.flash:SetScript("OnFinished", function() b.glow:SetAlpha(b.restGlow or 0) end)
	b.plus = Ink:Text(b, F.latinB, 11, KIND_RGB.prof, "CENTER", "OVERLAY")
	b.plus:SetPoint("BOTTOM", b.ic, "TOP", 0, 1)
	b.plus:SetAlpha(0)
	b.float = b.plus:CreateAnimationGroup()
	local fa = b.float:CreateAnimation("Alpha"); fa:SetFromAlpha(1); fa:SetToAlpha(0); fa:SetDuration(1.2); fa:SetSmoothing("IN")
	local ft = b.float:CreateAnimation("Translation"); ft:SetOffset(0, 14); ft:SetDuration(1.2); ft:SetSmoothing("OUT")
	b:SetScript("OnEnter", function(self)
		self.hot = true
		if self.entry then M:Paint(self, self.entry) end
		M:Tip(self)
	end)
	b:SetScript("OnLeave", function(self)
		self.hot = nil
		if self.entry then M:Paint(self, self.entry) end
		GameTooltip:Hide()
	end)
	return b
end

function M:Paint(b, e)
	b.entry = e
	local p = math.max(0, math.min(1, (e.rank or 0) / math.max(1, e.max or 1)))
	local maxed = (e.rank or 0) >= (e.max or 1)
	local col = e.kind == "rep" and (STANDING_RGB[e.standing or 4] or GOLD) or (KIND_RGB[e.kind] or KIND_RGB.prof)
	local useLetter = not e.icon
	if useLetter then
		b.icon:Hide()
		b.wash:SetVertexColor(col[1], col[2], col[3], 0.16)
		b.wash:Show()
		b.letter:SetText(FirstChar(e.name))
		b.letter:SetTextColor(col[1], col[2], col[3])
		b.letter:Show()
	else
		b.wash:Hide()
		b.letter:Hide()
		b.icon:SetTexture(e.icon)
		b.icon:Show()
	end
	-- 테두리: 평소 옅게 · 평판은 단계 색 · 다 올리면 금색 · 마우스 올리면 밝게
	local bd = b.skin.border
	if maxed and e.kind ~= "rep" then
		bd:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], b.hot and 1 or 0.78)
	elseif e.kind == "rep" then
		bd:SetVertexColor(col[1], col[2], col[3], b.hot and 0.9 or 0.45)
	else
		bd:SetVertexColor(1, 1, 1, b.hot and 0.42 or 0.13)
	end
	-- 막대 · 숫자
	local fc = (maxed and e.kind ~= "rep") and GOLD or col
	b.fill:SetVertexColor(fc[1], fc[2], fc[3], 0.95)
	b.fill:SetWidth(math.max(0.01, (ICON - 4) * p))
	b.fill:SetShown(p > 0)
	b.tip:SetVertexColor(math.min(1, fc[1] + 0.35), math.min(1, fc[2] + 0.35), math.min(1, fc[3] + 0.35), 1)
	b.tip:SetShown(p > 0.04 and p < 1)
	if e.kind == "rep" then
		b.num:SetText(math.floor(p * 100 + 0.5) .. "%")
		b.num:SetTextColor(col[1], col[2], col[3])
	else
		b.num:SetText(tostring(e.rank or 0))
		local nc = maxed and GOLD or (b.hot and C.text or C.soft)
		b.num:SetTextColor(nc[1], nc[2], nc[3])
	end
	-- 다 올린 것은 금빛이 은은하게 남는다
	b.restGlow = (maxed and e.kind ~= "rep") and 0.16 or 0
	b.glow:SetVertexColor(fc[1], fc[2], fc[3])
	if not (b.flash and b.flash:IsPlaying()) then b.glow:SetAlpha(b.restGlow) end
	b.plus:SetTextColor(col[1], col[2], col[3])
end

local KIND_LABEL = { prof = "숙련", weapon = "무기 숙련" }

function M:Tip(b)
	local e = b.entry
	if not e then return end
	GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
	GameTooltip:AddLine(e.name, 1, 1, 1)
	local g = { 0.56, 0.58, 0.61 }
	if e.kind == "rep" then
		local col = STANDING_RGB[e.standing or 4] or GOLD
		GameTooltip:AddDoubleLine(_G["FACTION_STANDING_LABEL" .. (e.standing or 4)] or "", e.rank .. " / " .. e.max, col[1], col[2], col[3], 1, 1, 1)
		if e.rank < e.max then GameTooltip:AddLine("다음 단계까지 " .. (e.max - e.rank), g[1], g[2], g[3]) end
	else
		local col = KIND_RGB[e.kind] or KIND_RGB.prof
		GameTooltip:AddDoubleLine(KIND_LABEL[e.kind] or "숙련", e.rank .. " / " .. e.max, col[1], col[2], col[3], 1, 1, 1)
		if (e.mod or 0) ~= 0 then GameTooltip:AddDoubleLine("장비 · 효과", (e.mod > 0 and "+" or "") .. e.mod, g[1], g[2], g[3], 0.55, 0.9, 0.55) end
		if e.rank >= e.max then
			GameTooltip:AddLine(e.kind == "weapon" and "지금 레벨에선 최대예요 · 레벨이 오르면 다시 올라요"
				or "최대예요 · 상급자에게 다음 단계를 배우면 더 올라요", GOLD[1], GOLD[2], GOLD[3], true)
		elseif e.kind == "weapon" then
			GameTooltip:AddLine("이 무기로 싸우면 올라요 (레벨 × 5 까지) · 남은 " .. (e.max - e.rank), g[1], g[2], g[3], true)
		else
			GameTooltip:AddLine("최대까지 " .. (e.max - e.rank), g[1], g[2], g[3])
		end
	end
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- 다시 그리기
-------------------------------------------------------------------------------
function M:Collect()
	local list = {}
	local skills = Skills()
	for _, s in ipairs(skills) do
		s.pick = s.key
		if s.kind == "prof" and Pick(s.key) ~= false then list[#list + 1] = s end
	end
	local autoW, n = Ink.db.trackerWeapons ~= false and not WeaponManual(skills), 0
	for _, s in ipairs(skills) do
		if s.kind == "weapon" then
			local p = Pick(s.key)
			if p == true then
				list[#list + 1] = s
			elseif p == nil and autoW and s.rank > 1 and s.rank < s.max and n < 4 then   -- 1 = 한 번도 안 쓴 무기
				list[#list + 1] = s
				n = n + 1
			end
		end
	end
	for _, r in ipairs(Reps()) do list[#list + 1] = r end
	return list
end

-- 지금 현황 아이콘에 떠 있는 것 (설정 칩 색칠용 · 바뀌면 다시 셈)
function M:Shown()
	if not self.shown then
		local set = {}
		local ok, list = pcall(self.Collect, self)
		if ok then for _, e in ipairs(list) do set[e.pick or e.key] = true end end
		self.shown = set
	end
	return self.shown
end

local STANDING_SHORT = function(st) return _G["FACTION_STANDING_LABEL" .. (st or 4)] or "" end

-- 설정 칩 목록: sec = "prof" / "weapon" / "rep"
function M:PickItems(sec)
	local out = {}
	if sec == "rep" then
		for _, d in ipairs(FactionRows()) do
			if d.header and not d.hasRep then
				out[#out + 1] = { header = true, name = d.name }
			else
				local rank = (d.val or 0) - (d.min or 0)
				local span = math.max(1, (d.max or 1) - (d.min or 0))
				out[#out + 1] = { key = RepKey(d), kind = "rep", name = d.name, letter = FirstChar(d.name), icon = RepIcon(d.id, d.name, d.group),
					rgb = STANDING_RGB[d.standing or 4] or GOLD, sub = STANDING_SHORT(d.standing), rank = rank, max = span, standing = d.standing }
			end
		end
		-- 빈 묶음 제목은 뺀다
		local clean = {}
		for i, it in ipairs(out) do
			local nextIt = out[i + 1]
			if not (it.header and (not nextIt or nextIt.header)) then clean[#clean + 1] = it end
		end
		return clean
	end
	for _, s in ipairs(Skills()) do
		if s.kind == sec then
			out[#out + 1] = { key = s.key, kind = s.kind, name = s.name, icon = s.icon, letter = FirstChar(s.name), rgb = KIND_RGB[s.kind], sub = s.rank .. "/" .. s.max,
				rank = s.rank, max = s.max, mod = s.mod, maxed = s.rank >= s.max }
		end
	end
	return out
end

-- 칩 하나의 상태: 떠 있나, 직접 고른 값 (true 고정 / false 뺌 / nil 자동)
function M:IsManual(kind)
	if kind == "rep" then return RepManual() end
	if kind == "weapon" then return WeaponManual(Skills()) end
	return false
end

-- 칩 하나의 상태: 떠 있나 · 직접 고른 값 (true 고정 / false 뺌 / nil 자동) · 그 묶음이 "고른 것만" 상태인가
function M:PickState(key, kind)
	return self:Shown()[key] and true or false, Pick(key), self:IsManual(kind)
end

function M:TogglePick(key, kind)
	local t = Picks(true)
	local function nextSeq()
		local top = 0
		for _, v in pairs(t) do if type(v) == "number" and v > top then top = v end end
		return top + 1
	end
	-- 무기 · 평판을 처음 고르는 순간: 지금 자동으로 떠 있는 것은 고정해서 그대로 남긴다 (화면이 갑자기 비지 않게)
	if kind ~= "prof" and not self:IsManual(kind) then
		for _, e in ipairs(self:Collect()) do
			local k = e.pick or e.key
			if e.kind == kind and k ~= key and t[k] == nil then t[k] = nextSeq() end
		end
	end
	if self:Shown()[key] then
		t[key] = false
	elseif kind == "prof" then
		t[key] = nil
	else
		t[key] = nextSeq()
	end
	self.shown = nil
	pcall(self.Update, self)
end

-- 기술 키 → 종류 (배운 기술 목록 · 없으면 이름표)
local function SkillKind(key, cache)
	if cache[key] == nil then
		BuildIcons()
		cache[key] = KIND[key:sub(3)] or false
		for _, s in ipairs(cache.list or {}) do if s.key == key then cache[key] = s.kind end end
	end
	return cache[key]
end

local function InSec(key, sec, cache)
	if sec == "rep" then return key:find("^f:") or key:find("^r:") end
	return key:find("^s:") and SkillKind(key, cache) == sec
end

function M:PickChanged(sec)
	local cache = { list = Skills() }
	for k, v in pairs(Picks()) do
		if v ~= nil and InSec(k, sec, cache) then return true end
	end
	return false
end

function M:ClearPicks(sec)
	local t = Picks()
	local cache = { list = Skills() }
	local drop = {}
	for k in pairs(t) do if InSec(k, sec, cache) then drop[#drop + 1] = k end end
	for _, k in ipairs(drop) do t[k] = nil end
	self.shown = nil
	pcall(self.Update, self)
end

-- 묶음(전문기술 · 무기 · 평판) 사이엔 넓은 틈 + 가는 세로 선 · 폭이 넘치면 아래 줄로
function M:Update()
	local list = self.Collect and self:Collect() or {}
	local set = {}
	for _, e in ipairs(list) do set[e.pick or e.key] = true end
	self.shown = set
	local f = self.frame
	if not f then return end
	self.last = self.last or {}
	f.divs = f.divs or {}
	local maxW = PER_ROW * (ICON + GAP) - GAP
	local x, row, right, nd, prevKind = 0, 0, 0, 0, nil
	for i, e in ipairs(list) do
		local b = f.chips[i] or NewChip(f)
		f.chips[i] = b
		if prevKind and e.kind ~= prevKind then
			if x - GAP + GROUP_GAP + ICON > maxW then
				x, row = 0, row + 1
			else
				nd = nd + 1
				local d = f.divs[nd]
				if not d then
					d = f:CreateTexture(nil, "ARTWORK")
					d:SetTexture(Ink.tex.white)
					d:SetSize(1, ICON - 10)
					f.divs[nd] = d
				end
				d:SetVertexColor(1, 1, 1, 0.12)
				d:ClearAllPoints()
				d:SetPoint("TOP", f, "TOPLEFT", x - GAP + GROUP_GAP / 2, -(row * (CHIP_H + ROW_GAP) + 5))
				d:Show()
				x = x - GAP + GROUP_GAP
			end
		elseif x > 0 and x + ICON > maxW then
			x, row = 0, row + 1
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", x, -row * (CHIP_H + ROW_GAP))
		self:Paint(b, e)
		b:Show()
		right = math.max(right, x + ICON)
		x = x + ICON + GAP
		prevKind = e.kind
		local prev = self.last[e.key]
		if prev and e.rank > prev and e.kind ~= "rep" then
			b.plus:SetText("+" .. (e.rank - prev))
			b.pop:Stop(); b.pop:Play()
			b.flash:Stop(); b.flash:Play()
			b.float:Stop(); b.float:Play()
		end
		self.last[e.key] = e.rank
	end
	for i = #list + 1, #f.chips do f.chips[i]:Hide() end
	for i = nd + 1, #f.divs do f.divs[i]:Hide() end
	f:SetWidth(math.max(ICON, right))
	f:SetHeight((row + 1) * CHIP_H + row * ROW_GAP)
end

function M:Init()
	if Ink.db.tracker == false then return end
	local f = CreateFrame("Frame", "FOATracker", Ink.root)
	f:SetSize(ICON, CHIP_H)
	f:SetFrameStrata("LOW")
	f.chips = {}
	self.frame = f
	Ink:Movable("tracker", "현황 아이콘", f, "left", 60, 16, 300, CHIP_H)
	self.recentRep = {}

	-- 오리지널식 기술 목록: 접힌 묶음이 있으면 목록에 안 나와서 한 번 펼쳐 둔다 (포에버는 번호로 찾아서 필요 없음)
	if not C_SkillInfo and ExpandSkillHeader then pcall(ExpandSkillHeader, 0) end

	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "UPDATE_FACTION",
		"CHAT_MSG_COMBAT_FACTION_CHANGE", "LEARNED_SPELL_IN_TAB", "TRADE_SKILL_UPDATE" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	local queued
	e:SetScript("OnEvent", function(_, ev, msg)
		if ev == "CHAT_MSG_COMBAT_FACTION_CHANGE" and type(msg) == "string" then
			-- "스톰윈드에 대한 평판이 25만큼 올랐습니다." 같은 글에서 진영 이름을 찾는다
			local n = (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetNumFactions()) or (GetNumFactions and GetNumFactions()) or 0
			for i = 1, n do
				local fname, fid
				if C_Reputation and C_Reputation.GetFactionDataByIndex then
					local d = C_Reputation.GetFactionDataByIndex(i)
					fname, fid = d and d.name, d and d.factionID
				elseif GetFactionInfo then
					local r = { GetFactionInfo(i) }
					fname, fid = r[1], r[14]
				end
				if fname and fid and msg:find(fname, 1, true) then
					for k, v in ipairs(M.recentRep) do if v == fid then table.remove(M.recentRep, k) break end end
					table.insert(M.recentRep, 1, fid)
					while #M.recentRep > 3 do table.remove(M.recentRep) end
					break
				end
			end
		end
		if queued then return end
		queued = true
		C_Timer.After(0.4, function()
			queued = nil
			local ok, err = pcall(M.Update, M)
			if not ok then Ink:LogError("Tracker: " .. tostring(err)) end
		end)
	end)
	C_Timer.After(2, function() pcall(M.Update, M) end)
	-- 평판 창 묶음 이름을 한 번 읽어 둔다 (묶음 공통 그림용)
	C_Timer.After(4, function()
		pcall(FactionRows)
		pcall(M.Update, M)
	end)
end

M.FactionIDByName = FactionIDByName
