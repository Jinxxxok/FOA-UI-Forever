-- FOA UI · 전문기술 안내 (포에버 · 전문기술 창 옆)
--  · 지금 숙련 구간에 만들 것 (wowf.io 빠른 레벨링 경로) + 남은 횟수 · 재료(가방에 있는 수) · 예상 재료비(경매장 가격)
--  · 내가 아는 제조법 중 지금 숙련이 오르는 것 (주황 · 노랑)
--  · 다음 구간들 · 훈련사에게 배울 제조법(훈련사 창을 한 번 열면 비용까지)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Professions")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local FOREVER = (function() local b = select(4, GetBuildInfo()) or 0 return b >= 16001 and b < 20000 end)()
local W, ROW = 296, 30
local ORANGE = { 1, 0.5, 0.25 }
local YELLOW = { 1, 0.86, 0.3 }
local GREEN = { 0.44, 0.83, 0.6 }
local GOLD = { 1, 0.82, 0.38 }
local DIFF_C = { [0] = ORANGE, [1] = YELLOW, [2] = GREEN }
local DIFF_T = { optimal = 0, medium = 1, easy = 2, trivial = 3 }

local function Money(c)
	local A = Ink.modules.AHPrice
	if A and A.Money then return A.Money(c) end
	return tostring(c or 0)
end

-------------------------------------------------------------------------------
-- 지금 열린 전문기술: 이름 · 숙련 · 아는 제조법
-------------------------------------------------------------------------------
-- 숙련을 기술 목록(캐릭터 창 기술 탭)에서 이름으로 찾기: 포에버 전문기술 창은 GetTradeSkillLine 숙련이 0으로 올 때가 있다
local function SkillByName(name)
	if not name then return end
	if GetNumSkillLines and GetSkillLineInfo then
		for i = 1, GetNumSkillLines() do
			local n, header, _, rank, _, _, max = GetSkillLineInfo(i)
			if n and not header and (n == name or name:find(n, 1, true) or n:find(name, 1, true)) and (max or 0) > 0 then return rank, max end
		end
	end
	if GetProfessions and GetProfessionInfo then
		local list = { GetProfessions() }
		for i = 1, 6 do
			local idx = list[i]
			if idx then
				local n, _, rank, max = GetProfessionInfo(idx)
				if n and (n == name or name:find(n, 1, true) or n:find(name, 1, true)) and (max or 0) > 0 then return rank, max end
			end
		end
	end
end

local function ProfInfoRaw()
	if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and _G.ProfessionsFrame and _G.ProfessionsFrame:IsShown() then
		local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
		if not (ok and info and info.professionName) then ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo) end
		if ok and info and info.professionName then
			local base = (select(2, pcall(C_TradeSkillUI.GetBaseProfessionInfo)) or {}).professionName
			return base or info.professionName, info.skillLevel or 0, info.maxSkillLevel or 0, "modern"
		end
	end
	if _G.CraftFrame and _G.CraftFrame:IsShown() and GetCraftDisplaySkillLine then
		local name, rank, max = GetCraftDisplaySkillLine()
		if name then return name, rank or 0, max or 0, "craft" end
	end
	if GetTradeSkillLine then
		local name, rank, max = GetTradeSkillLine()
		if name and name ~= "UNKNOWN" then return name, rank or 0, max or 0, "classic" end
	end
end
local function ProfInfo()
	local name, rank, max, kind = ProfInfoRaw()
	-- 전문기술 창 첫 화면(기술 목록)은 이름이 빈 글자로 온다: 빈 이름은 아무 기술에나 걸리므로(find("")) 없는 걸로
	if type(name) ~= "string" or name == "" or name == "UNKNOWN" then return nil, 0, 0, kind end
	if name and ((rank or 0) == 0 or (max or 0) == 0) then
		local r2, m2 = SkillByName(name)
		if r2 then rank, max = r2, m2 end
	end
	return name, rank, max, kind
end

-- 아는 제조법 { name, icon, diff(0~3), avail, reagents = { {name, need, have, itemID} } }
local function KnownRecipes(kind)
	local out = {}
	if kind == "modern" then
		local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
		for _, id in ipairs(ok and ids or {}) do
			local ok2, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
			if ok2 and info and info.learned and not info.isDummyRecipe then
				local r = { name = info.name, icon = info.icon, diff = info.relativeDifficulty or 3, avail = info.numAvailable or 0, id = id, reagents = {} }
				if C_TradeSkillUI.GetRecipeItemLink then local okL, l = pcall(C_TradeSkillUI.GetRecipeItemLink, id); if okL and type(l) == "string" then r.link = l end end
				local ok3, sch = pcall(C_TradeSkillUI.GetRecipeSchematic, id, false)
				for _, slot in ipairs(ok3 and sch and sch.reagentSlotSchematics or {}) do
					local rg = slot.reagents and slot.reagents[1]
					if rg and rg.itemID and (slot.reagentType == nil or slot.reagentType == 1) then
						local nm = C_Item.GetItemNameByID and C_Item.GetItemNameByID(rg.itemID)
						r.reagents[#r.reagents + 1] = { name = nm, need = slot.quantityRequired or 1, have = C_Item.GetItemCount and C_Item.GetItemCount(rg.itemID, true) or 0, itemID = rg.itemID }
					end
				end
				out[#out + 1] = r
			end
		end
	elseif kind == "classic" and GetNumTradeSkills then
		for i = 1, GetNumTradeSkills() do
			local name, t, avail = GetTradeSkillInfo(i)
			if name and t ~= "header" and t ~= "subheader" then
				local r = { name = name, icon = GetTradeSkillIcon and GetTradeSkillIcon(i), diff = DIFF_T[t] or 3, avail = avail or 0, reagents = {} }
				if GetTradeSkillItemLink then local okL, l = pcall(GetTradeSkillItemLink, i); if okL and type(l) == "string" then r.link = l end end
				for j = 1, (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0) do
					local rn, _, need, have = GetTradeSkillReagentInfo(i, j)
					local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j)
					r.reagents[#r.reagents + 1] = { name = rn, need = need or 1, have = have or 0, itemID = link and tonumber(link:match("item:(%d+)")) }
				end
				out[#out + 1] = r
			end
		end
	elseif kind == "craft" and GetNumCrafts then
		for i = 1, GetNumCrafts() do
			local name, _, t, avail = GetCraftInfo(i)
			if name and t ~= "header" then
				local r = { name = name, icon = GetCraftIcon and GetCraftIcon(i), diff = DIFF_T[t] or 3, avail = avail or 0, reagents = {} }
				if GetCraftItemLink then local okL, l = pcall(GetCraftItemLink, i); if okL and type(l) == "string" then r.link = l end end
				for j = 1, (GetCraftNumReagents and GetCraftNumReagents(i) or 0) do
					local rn, _, need, have = GetCraftReagentInfo(i, j)
					local link = GetCraftReagentItemLink and GetCraftReagentItemLink(i, j)
					r.reagents[#r.reagents + 1] = { name = rn, need = need or 1, have = have or 0, itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil }
				end
				out[#out + 1] = r
			end
		end
	end
	return out
end

local function RouteFor(name)
	if not (ns.PROF_ROUTES and name) or name == "" then return end
	if ns.PROF_ROUTES[name] then return ns.PROF_ROUTES[name], name end
	for k, v in pairs(ns.PROF_ROUTES) do
		if name:find(k, 1, true) or k:find(name, 1, true) then return v, k end
	end
end

-- 가방(+은행) 개수. 재료 안내는 이름만 알고 있는 경우가 많아서:
--  이름 → 아이템 번호(캐시) → 개수, 안 되면 이름으로 묻고, 그래도 0이면 가방을 직접 훑어 이름이 같은 걸 센다
--  (포에버는 옛 GetItemCount 가 없어서 이름만으로는 늘 0 이 나왔다)
local function BagCountByName(name)
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return 0 end
	local n = 0
	for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
		for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
			local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
			if ok and info then
				local nm = info.itemName
				if not nm and info.itemID and C_Item.GetItemNameByID then nm = C_Item.GetItemNameByID(info.itemID) end
				if nm == name then n = n + (info.stackCount or 1) end
			end
		end
	end
	return n
end

local function Count(name, itemID)
	if not itemID and name and C_Item and C_Item.GetItemInfoInstant then
		local ok, id = pcall(C_Item.GetItemInfoInstant, name)
		if ok and type(id) == "number" then itemID = id end
	end
	if itemID and C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, itemID, true)
		if ok and n and n > 0 then return n end
	end
	if name and C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, name, true)
		if ok and type(n) == "number" and n > 0 then return n end
	end
	if name and GetItemCount then
		local ok, n = pcall(GetItemCount, name, true)
		if ok and type(n) == "number" and n > 0 then return n end
	end
	return name and BagCountByName(name) or 0
end

local function Price(name, itemID)
	if not ns.AHPrice then return end
	local p = itemID and ns.AHPrice(itemID) or nil
	if not p and name then p = ns.AHPrice(name) end
	return p
end

-------------------------------------------------------------------------------
-- 제조법 파는 상인 (RecipeVendors.lua): 만드는 것 이름(주문 이름) → 상인 목록
-------------------------------------------------------------------------------
local vendorIdx = {}
local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id); if ok and n then return n end end
	if GetSpellInfo then local n = GetSpellInfo(id); return n end
end
-- 그림: 제조법 주문은 게임 자료에 아이콘이 비어 있어서(와우 로고) 만들어지는 아이템 그림을 쓴다 (CraftItems.lua)
local TEMP_ICON = 136235
local waitItems = {}
local function ItemIcon(id)
	if not id then return end
	local ic
	if C_Item and C_Item.GetItemIconByID then local ok, v = pcall(C_Item.GetItemIconByID, id); if ok then ic = v end end
	if not ic and GetItemIcon then local ok, v = pcall(GetItemIcon, id); if ok then ic = v end end
	if not ic or ic == TEMP_ICON then
		-- 게임이 아직 모르는 아이템: 서버에 물어 두고, 받으면 패널을 다시 그린다
		waitItems[id] = true
		if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
		return nil
	end
	return ic
end
local function CraftItem(sid) return sid and ns.CRAFT_ITEM and ns.CRAFT_ITEM[sid] or nil end
-- 재료 이름: 게임이 아직 모르면 서버에 물어 두고(받으면 다시 그림) 그동안은 "…" (예전엔 "?")
local function RgName(rg)
	if rg.name and rg.name ~= "" then return rg.name end
	local n = rg.itemID and C_Item.GetItemNameByID and C_Item.GetItemNameByID(rg.itemID)
	if n and n ~= "" then rg.name = n; return n end
	if rg.itemID then
		waitItems[rg.itemID] = true
		if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, rg.itemID) end
	end
	return "…"
end
local function SpellIcon(sid)
	local st
	if C_Spell and C_Spell.GetSpellTexture then local ok, v = pcall(C_Spell.GetSpellTexture, sid); if ok then st = v end end
	if not st and GetSpellTexture then local ok, v = pcall(GetSpellTexture, sid); if ok then st = v end end
	if st and st ~= TEMP_ICON then return st end
end
local function CraftIcon(sid)
	if not sid then return end
	return ItemIcon(CraftItem(sid)) or SpellIcon(sid)
end
-- 만드는 것 이름(주문 이름) → 주문: 경로 자료는 이름만 있어서
local spellByName
local function CraftSpellByName(n)
	if not n then return end
	if not spellByName then
		spellByName = {}
		for sid in pairs(ns.CRAFT_ITEM or {}) do local nm = SpellName(sid); if nm and not spellByName[nm] then spellByName[nm] = sid end end
		for _, e in pairs(ns.RECIPE_VENDORS or {}) do local nm = SpellName(e[2]); if nm and not spellByName[nm] then spellByName[nm] = e[2] end end
	end
	return spellByName[n]
end
local function ItemByName(n)
	if not (n and C_Item and C_Item.GetItemInfoInstant) then return end
	local ok, id = pcall(C_Item.GetItemInfoInstant, n)
	if ok and type(id) == "number" then return id end
end
M.CraftItem, M.CraftIcon, M.CraftSpellByName = CraftItem, CraftIcon, CraftSpellByName

local function VendorIndex(prof)
	if vendorIdx[prof] then return vendorIdx[prof] end
	local idx = {}
	for item, e in pairs(ns.RECIPE_VENDORS or {}) do
		if prof and (e[1] == prof or prof:find(e[1], 1, true)) then
			local n = SpellName(e[2])
			if n then idx[n] = { item = item, spell = e[2], req = e[3], list = e[4] } end
		end
	end
	vendorIdx[prof] = idx
	return idx
end
local function MyFac()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	return f == "Horde" and 1 or (f == "Alliance" and 2 or 0)
end
-- 내 진영에서 살 수 있는 상인 하나 (같은 지역이면 우선)
local function PickVendor(v)
	if not v then return end
	local fac, best = MyFac(), nil
	local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	for _, x in ipairs(v.list) do
		if x[5] == 0 or x[5] == fac then
			if not best or (x[2] == here and best[2] ~= here) then best = x end
		end
	end
	return best
end
local function NpcName(id)
	local D = Ink.modules.Dungeon
	if D and D.BossName then return D.BossName({ npc = id, name = nil }) end
end
-- 늘 그 자리에 있지 않은 상인 (자료 좌표에 가도 없을 수 있다) · 제조법 상인 줄 · 툴팁에 한 줄 더
--  펙스밋(하이잘 산 데이건): 정해진 자리 여러 곳 중 한 곳에 40분쯤 나타났다가 2시간쯤 사라지는 상인 · 서버 층마다 따로
--  (wow-professions.com 포에버 · QuestieDB 포에버 자료에도 자리가 여러 개로 나온다)
ns.NPC_NOTE = ns.NPC_NOTE or {}
ns.NPC_NOTE[266901] = "떠돌이 상인 · 데이건 안 여러 자리에 40분쯤 나타났다가 2시간쯤 사라져요 · 서버 층마다 달라요"
local function VendorText(x)
	if not x then return end
	local who = NpcName(x[1]) or "상인"
	local zone = x[2] > 0 and C_Map.GetMapInfo and (C_Map.GetMapInfo(x[2]) or {}).name or nil
	local where = zone and string.format("%s %.0f, %.0f", zone, x[3], x[4]) or ""
	if x[9] == 1 then where = where .. (where ~= "" and " · " or "") .. "수량 한정" end   -- 팔리고 없으면 다시 채워질 때까지 기다려야 한다
	if ns.NPC_NOTE[x[1]] then where = where .. (where ~= "" and " · " or "") .. ns.NPC_NOTE[x[1]] end
	local price = ""
	if x[7] and x[7] > 0 then
		local iname = C_Item.GetItemNameByID and C_Item.GetItemNameByID(x[7])
		if not iname and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, x[7]) end
		price = (iname or ("아이템 #" .. x[7])) .. " " .. (x[8] or 1) .. "개와 교환"
	elseif x[6] and x[6] > 0 then
		price = Money(x[6])
	end
	return who, where, price
end
local function Waypoint(x)
	if not (x and x[2] and x[2] > 0) then return end
	if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(x[2]) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(x[2], x[3] / 100, x[4] / 100))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
		print(string.format("|cffFFF468FOA|r 지도에 %s 위치를 찍었어요 (%s)", x.label or "상인", (C_Map.GetMapInfo(x[2]) or {}).name or ""))
	end
end

M.PickVendor, M.VendorText, M.Waypoint = PickVendor, VendorText, Waypoint

-------------------------------------------------------------------------------
-- 훈련사 · 단계 (포에버: 초급 → 수습 → 숙련 → 전문, 단계마다 가르치는 훈련사가 따로 · 숙련 · 전문은 몇 명뿐)
--  자료: ProfessionTrainers.lua (AllTheThings 훈련사 · 단계 · 제조법 + QuestieDB 보조 훈련사) + 훈련사 창에서 읽은 것
-------------------------------------------------------------------------------
local PROF_ID = { ["가죽세공"] = 165, ["대장기술"] = 164, ["연금술"] = 171, ["재봉술"] = 197, ["기계공학"] = 202, ["마법부여"] = 333,
	["약초채집"] = 182, ["채광"] = 186, ["무두질"] = 393, ["요리"] = 185, ["낚시"] = 356, ["응급치료"] = 129 }
local RANK_NAME = { "초급", "수습", "숙련", "전문" }   -- 게임 전문기술 창 · 훈련사 창과 같은 이름
-- 단계 글자색: 아이템 등급색처럼 (초급 일반 · 수습 고급 · 숙련 희귀 · 전문 영웅) → 한눈에 어느 단계인지
local RANK_Q, RANK_FB = { 1, 2, 3, 4 }, { "E8E6E1", "1EFF00", "0070DD", "A335EE" }
local function RankHex(r)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[RANK_Q[r] or 1]
	if r > 1 and c and c.r then return string.format("%02X%02X%02X", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5)) end
	return RANK_FB[r] or "E8E6E1"
end
local function RankLabel(r) return "|cff" .. RankHex(r) .. (RANK_NAME[r] or "") .. "|r" end
local RANK_CAP = { 75, 150, 225, 300 }
local RANK_REQ = { { 5, 0 }, { 10, 50 }, { 20, 125 }, { 35, 200 } }   -- 단계마다 { 캐릭터 레벨, 숙련 }
-- 이름: 게임(전문기술 창 · 훈련사 창)은 초급 · 수습 · 숙련 · 전문 인데, NPC 칭호만 한 칸 위로 붙어 있다
--  (텔로니스 칭호 "전문 가죽세공인" 이 가르치는 건 "숙련 가죽세공" · 300까지는 드라크 스톤핸드의 "전문 가죽세공")
local SERVICE_NAME = { "초급", "수습", "숙련", "전문" }
local RANK_COST = { 10, 500, 5000, 50000 }   -- 기본 비용 (평판 할인 전 · 실제 값은 훈련사 창에서 본 것을 쓴다)
local PROF_NAME = {}
for k, v in pairs(PROF_ID) do PROF_NAME[v] = k end
M.PROF_ID, M.RANK_NAME, M.SERVICE_NAME, M.PROF_NAME = PROF_ID, RANK_NAME, SERVICE_NAME, PROF_NAME

-- 단계 배우는 비용: 훈련사 창에서 본 값 → 없으면 기본 값 (두 번째 값 = 본 적 있음)
local function RankCost(prof, r)
	local c = Ink.db.profRankCost and Ink.db.profRankCost[prof] and Ink.db.profRankCost[prof][r]
	if c then return c, true end
	local pn = PROF_NAME[prof]
	if pn then
		local want = SERVICE_NAME[r] .. " " .. pn
		for k, v in pairs(Ink.db.profTrainer or {}) do
			if k == pn or k:find(pn, 1, true) then
				for _, e in ipairs(v.list or {}) do if e[2] == want and e[6] then return e[6], true end end
			end
		end
	end
	return RANK_COST[r], false
end
M.RankCost = RankCost

-- 보조 기술의 숙련 · 전문 단계는 훈련사가 아니라 책 · 퀘스트 (진영 0 공통 1 호드 2 얼라)
local SECONDARY = {
	[185] = { [3] = { book = 16072, req = { 0, 125 }, who = { { 3955, 2, 1440, 49.5, 67.1, "Shandrina" }, { 12033, 1, 1443, 26.2, 69.7, "Wulan" } } },
		[4] = { quest = 6610, req = { 35, 225 }, who = { { 8125, 0, 1446, 52.6, 28.1, "Dirge Quikcleave" } } } },
	[356] = { [3] = { book = 16083, req = { 20, 125 }, who = { { 2626, 0, 1434, 27.4, 77.2, "Old Man Heming" } } },
		[4] = { quest = 6607, req = { 35, 225 }, who = { { 12919, 0, 1445, 58.6, 60.1, "Nat Pagle" } } } },
	[129] = { [3] = { book = 16084, req = { 0, 125 }, who = { { 2805, 2, 1417, 27.0, 58.8, "Deneb Walker" }, { 13476, 1, 1445, 36.5, 30.4, "Balai Lok'Wein" } } },
		[4] = { quest = 6624, req = { 35, 225 }, who = { { 12939, 2, 1445, 67.8, 49.0, "Doctor Gustaf VanHowzen" }, { 12920, 1, 1417, 73.4, 36.9, "Doctor Gregory Victor" } } } },
}
-- 찾기 어려운 훈련사 메모
local TRAINER_NOTE = { [11073] = "울다만 던전 안 · 전갈을 모두 잡아야 나타나요" }

local function ProfID(name)
	if not name or name == "" then return end
	if PROF_ID[name] then return PROF_ID[name] end
	for k, v in pairs(PROF_ID) do if name:find(k, 1, true) or k:find(name, 1, true) then return v end end
	if GetProfessions and GetProfessionInfo then
		for _, idx in ipairs({ GetProfessions() }) do
			local ok, n, _, _, _, _, _, line = pcall(GetProfessionInfo, idx)
			if ok and n == name and line then return line end
		end
	end
end
M.ProfID = ProfID
local function RankOfMax(max)
	if (max or 0) <= 75 then return 1 elseif max <= 150 then return 2 elseif max <= 225 then return 3 end
	return 4
end
M.RankOfMax = RankOfMax

-- NPC 이름: 게임이 아직 모르는 NPC 는 영어 이름 → 서버에 물어 두고 잠시 뒤 다시 그린다 (nameMiss)
local nameMiss
local function TrainerName(npc, en)
	local Q = Ink.modules.QuestMap
	local n = Q and Q.GiverName and Q:GiverName(npc)
	if not n then
		local s = Ink.db.npcSpot and Ink.db.npcSpot[npc]
		n = type(s) == "table" and s[4] or nil
	end
	if not n then nameMiss = true end
	return n or (en and en ~= "" and en) or "훈련사"
end
local function ZoneName(map) return map and map > 0 and C_Map.GetMapInfo and (C_Map.GetMapInfo(map) or {}).name or "" end
local function Dist(map, x, y)
	local Q = Ink.modules.QuestMap
	if Q and Q.DistTo then
		local ok, d = pcall(Q.DistTo, Q, { map = map, x = x / 100, y = y / 100, id = 5e6 })
		if ok and type(d) == "number" then return d end
	end
	return 5e6
end

-- 이 기술의 훈련사 목록 (내 진영) { npc, map, x, y, ranks = {[단계]=true}, recipes = {[주문]=숙련}, name, inside, learned }
local function Trainers(prof)
	local out, fac = {}, MyFac()
	for _, t in ipairs((ns.PROF_TRAINERS or {})[prof] or {}) do
		if t[2] == 0 or t[2] == fac then
			local rk = {}
			for r in pairs(t[4]) do rk[r] = true end
			local rc = {}
			local list = t[5]
			for i = 1, #list, 2 do rc[list[i]] = list[i + 1] end
			out[#out + 1] = { npc = t[1], map = t[3][1], x = t[3][2], y = t[3][3], ranks = rk, recipes = rc, en = t[6] or "", inside = t[7] == 1, rankData = t[4] }
		end
	end
	for _, t in ipairs((ns.PROF_TRAINERS_EXTRA or {})[prof] or {}) do
		if t[2] == 0 or t[2] == fac then
			local rk = {}
			for r = 1, t[6] do rk[r] = true end
			out[#out + 1] = { npc = t[1], map = t[3], x = t[4], y = t[5], ranks = rk, recipes = {}, en = t[7] or "", extra = true }
		end
	end
	-- 훈련사 창에서 직접 본 단계 · 자리 (계정 공용)
	local seen = Ink.db.profTrainerSeen and Ink.db.profTrainerSeen[prof]
	for npc, v in pairs(seen or {}) do
		local hit
		for _, t in ipairs(out) do if t.npc == npc then hit = t end end
		if not hit and v.map then
			hit = { npc = npc, map = v.map, x = v.x, y = v.y, ranks = {}, recipes = {}, en = v.name or "", learned = true }
			out[#out + 1] = hit
		end
		if hit then for r in pairs(v.ranks or {}) do hit.ranks[r] = true end end
	end
	return out
end
M.Trainers = Trainers

-- 단계 하나를 배우는 곳 (가까운 순) · 보조 기술은 책 · 퀘스트
--  다음 단계뿐 아니라 그 뒤 단계도: 200에서 "225 넘으면 어디로" 를 미리 볼 수 있게
function M.RankInfo(prof, nr)
	if not prof or not nr or nr < 1 or nr > 4 then return end
	local sec = SECONDARY[prof] and SECONDARY[prof][nr]
	local fac = MyFac()
	local spots = {}
	if sec then
		for _, w in ipairs(sec.who) do
			if w[2] == 0 or w[2] == fac then
				spots[#spots + 1] = { npc = w[1], map = w[3], x = w[4], y = w[5], en = w[6], d = Dist(w[3], w[4], w[5]) }
			end
		end
	else
		for _, t in ipairs(Trainers(prof)) do
			if t.ranks[nr] then
				-- 숙련 · 전문 단계는 확인된 훈련사(ATT · 직접 본 곳)를 먼저: 이름만 보고 짐작한 보조 훈련사는 뒤로
				t.d = Dist(t.map, t.x, t.y) + ((nr >= 3 and t.extra and not t.learned) and 1e7 or 0)
				spots[#spots + 1] = t
			end
		end
	end
	table.sort(spots, function(a, b) return a.d < b.d end)
	local req = (sec and sec.req) or RANK_REQ[nr]
	local cost, seen
	if not sec then cost, seen = RankCost(prof, nr) end
	-- 단계 주문 (그림 · 툴팁용): 훈련사 자료에서
	local rankSpell
	for _, t in ipairs((ns.PROF_TRAINERS or {})[prof] or {}) do
		if t[4][nr] then rankSpell = t[4][nr][1] break end
	end
	return { rank = nr, name = RankLabel(nr), plain = RANK_NAME[nr], cap = RANK_CAP[nr], lvl = req[1], skill = req[2], spots = spots, book = sec and sec.book, quest = sec and sec.quest,
		cost = cost, costSeen = seen, svc = (not sec and PROF_NAME[prof]) and (SERVICE_NAME[nr] .. " " .. PROF_NAME[prof]) or nil, spell = rankSpell }
end
-- 다음 단계를 배우는 곳
function M.NextRank(prof, max)
	local cur = RankOfMax(max)
	if cur >= 4 then return end
	return M.RankInfo(prof, cur + 1)
end
-- 지금 단계 뒤로 남은 단계 전부 (이미 배운 단계는 뺀다)
function M.Roadmap(prof, max)
	local out = {}
	for r = RankOfMax(max) + 1, 4 do
		local info = M.RankInfo(prof, r)
		if info then out[#out + 1] = info end
	end
	return out
end

-- 툴팁 줄 모양 (가독성: 한 줄엔 한 가지 · 길면 마디마다 줄바꿈)
--  "글" 회색 (첫 줄은 제목 · 흰색) · TipH("소제목") 빈 줄 + 금색 소제목 · TipKV(왼쪽, 오른쪽) 두 칸
--  TipT(글, 색) 색 있는 글 · TipHint("누르면 …") 맨 아래 흐린 안내 · TipGap() 빈 줄
local TIP_SOFT, TIP_DIM, TIP_HEAD, TIP_WHITE = { 0.78, 0.80, 0.83 }, { 0.50, 0.52, 0.56 }, { 0.89, 0.75, 0.48 }, { 0.96, 0.95, 0.92 }
local TIP_GOLD, TIP_GREEN, TIP_RED, TIP_MUTED = { 1, 0.82, 0.37 }, { 0.44, 0.83, 0.6 }, { 1, 0.42, 0.37 }, { 0.6, 0.62, 0.66 }
local function TipH(t) return { h = t } end
local function TipKV(l, r, lc, rc) return { l = l, r = r, lc = lc, rc = rc } end
local function TipT(t, c) return { t = t, c = c } end
local function TipHint(t) return { hint = t } end
local function TipGap() return { gap = true } end
local function Short(max, ...)   -- 앞 마디부터 이어 붙이다 넘치면 거기서 멈춘다 (목록 줄이 … 으로 잘리지 않게)
	local out
	for i = 1, select("#", ...) do
		local p = select(i, ...)
		if p and p ~= "" then
			local cand = out and (out .. " · " .. p) or p
			if out and Ink.DispLen(cand) > max then break end
			out = cand
		end
	end
	return out or ""
end

-------------------------------------------------------------------------------
-- 심화 과정 (ProfessionSpecs.lua): 가죽세공 · 대장기술 · 기계공학
-------------------------------------------------------------------------------
local function Knows(sid)
	if not sid then return false end
	if IsPlayerSpell then local ok, v = pcall(IsPlayerSpell, sid); if ok and v then return true end end
	if IsSpellKnown then local ok, v = pcall(IsSpellKnown, sid); if ok and v then return true end end
	return false
end
M.Knows = Knows
local function MyClass() local _, c = UnitClass("player"); return c or "" end
local function ClassName(c) return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c end
-- 심화 과정 훈련사인데 그 과정을 안 배웠으면 그 훈련사 제조법은 아직 못 배운다
local function SpecLocked(t)
	local need = t and (ns.PROF_SPEC_NPC or {})[t.npc]
	return need and not Knows(need) or false
end
local function IsSpecSpell(sid) return (ns.PROF_SPEC_SPELL or {})[sid] ~= nil end
-- 내 진영 NPC 하나 (가까운 곳 · 자리 자료가 없으면 맨 뒤)
local function PickWho(list)
	local fac, best = MyFac(), nil
	for _, w in ipairs(list or {}) do
		if w[2] == 0 or w[2] == fac then
			local has = (w[3] or 0) > 0
			local d = has and Dist(w[3], w[4], w[5]) or 9e9
			if not best or d < best.d then best = { npc = w[1], map = has and w[3] or nil, x = w[4], y = w[5], en = w[6] or "", d = d } end
		end
	end
	return best
end
local function WhoText(w)
	if not w then return "자리 정보 없음" end
	local n = TrainerName(w.npc, w.en)
	if w.map then return string.format("%s · %s %.0f, %.0f", n, ZoneName(w.map), w.x, w.y) end
	return n
end
local function WhoPin(w, label)
	if w and w.map then return { w.npc, w.map, w.x, w.y, label = label or "훈련사" } end
end
local function SpecName(s)
	local n = SpellName(s.spell)
	return (n and n ~= "") and n or s.name
end
-- 심화 과정마다 어울리는 글자색 (용비늘 = 붉은 용 · 원소 = 물빛 · 전통 = 숲 · 방어구 = 강철 · 무기 = 불꽃 · 노움 = 푸른 기계 · 고블린 = 주황 폭발)
local SPEC_HEX = { [10656] = "FF7A59", [10658] = "5BC8F5", [10660] = "9CD45E", [9788] = "B8C7D1", [9787] = "FFB45E",
	[17041] = "FF8F6B", [17040] = "FFD45E", [17039] = "8FD3FF", [20219] = "6FB8FF", [20222] = "FFA347" }
local function SpecNameC(s)
	local h = SPEC_HEX[s.spell]
	return h and ("|cff" .. h .. SpecName(s) .. "|r") or SpecName(s)
end
local function SpecShortC(s)
	local h = SPEC_HEX[s.spell]
	return h and ("|cff" .. h .. (s.short or s.name) .. "|r") or (s.short or s.name)
end
-- 직업 추천: 점수(2 추천 · 1 쓸 만함), 짧은 이유(목록 줄), 긴 설명(툴팁)
local function Fit(s, cls)
	local f = s.fit and (s.fit[cls] or s.fit.ALL)
	if f then return f[1], f[2], f[3] or f[2] end
	return 0
end
-- 직업 이름을 그 직업 색으로
local function ClassText(c) return "|cff" .. Ink.ClassHex(c) .. ClassName(c) .. "|r" end
local function ItemNameOf(it)
	local n
	if C_Item and C_Item.GetItemNameByID then local ok, v = pcall(C_Item.GetItemNameByID, it[1]); if ok and v and v ~= "" then n = v end end
	if not n and it[3] and it[3] > 0 then n = SpellName(it[3]) end
	if not n then ItemIcon(it[1]) end   -- 서버에 물어 두기 (받으면 다시 그린다)
	return n or it[4] or ("아이템 #" .. it[1])
end
-- 이 과정을 배우면 훈련사에게서 열리는 제조법 이름
local function SpecRecipes(prof, specSpell, cap)
	local out, seen = {}, {}
	for _, t in ipairs((ns.PROF_TRAINERS or {})[prof] or {}) do
		if (ns.PROF_SPEC_NPC or {})[t[1]] == specSpell then
			local list = t[5]
			for i = 1, #list, 2 do
				local sid = list[i]
				if not IsSpecSpell(sid) and not seen[sid] then
					seen[sid] = true
					local n = SpellName(sid)
					if n and n ~= "" then out[#out + 1] = { n, list[i + 1] } end
				end
			end
		end
	end
	table.sort(out, function(a, b) return a[2] < b[2] end)
	local names = {}
	for i = 1, math.min(cap or 8, #out) do names[i] = out[i][1] end
	return names, #out
end
-- 상태: { def, learned, best, bestSc, alt{}, lvlOK, skillOK, master = { 같은 모양 } }
local function SpecGroupState(def, skill, cls, lv)
	local st = { def = def, alt = {} }
	for _, s in ipairs(def.list) do
		if Knows(s.spell) then st.learned = s end
		local sc = Fit(s, cls)
		-- 직업과 상관없이 쓰임새로 고르는 기술(기계공학)은 '추천' 을 붙이지 않는다
		if not def.advice and sc > 0 and (not st.best or sc > st.bestSc) then st.best, st.bestSc = s, sc end
	end
	for _, s in ipairs(def.list) do
		if st.best and s ~= st.best and Fit(s, cls) >= st.bestSc then st.alt[#st.alt + 1] = s end
	end
	st.lvlOK, st.skillOK = lv >= (def.lvl or 0), (skill or 0) >= (def.skill or 0)
	return st
end
function M.SpecState(prof, skill)
	local def = (ns.PROF_SPECS or {})[prof]
	if not def then return end
	local cls, lv = MyClass(), UnitLevel("player") or 1
	local st = SpecGroupState(def, skill, cls, lv)
	if def.masters and st.learned and st.learned.spell == def.masters.need then
		st.master = SpecGroupState(def.masters, skill, cls, lv)
	end
	return st
end
-- 자리 두 줄: 이름(오른쪽 흰색) + 지역 · 좌표(오른쪽 흐리게)
local function WhoLines(t, label, w)
	if not w then t[#t + 1] = TipKV(label, "자리 정보 없음"); return end
	t[#t + 1] = TipKV(label, TrainerName(w.npc, w.en), TIP_SOFT, TIP_WHITE)
	if w.map then t[#t + 1] = TipKV(" ", string.format("%s  %.0f, %.0f", ZoneName(w.map), w.x, w.y), TIP_SOFT, TIP_MUTED) end
end
-- 툴팁 줄 · 누르면 찍을 곳 (퀘스트 시작 NPC 가 따로 있고 자리를 알면 그쪽 먼저)
-- 심화 과정 전 연계 퀘스트: 단계마다 끝냈는지(초록 "완료") · 아직이면 낼 재료 한 줄
local function QuestDone(qid)
	local f = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
	if not (f and qid) then return false end
	local ok, v = pcall(f, qid)
	return ok and v == true
end
local function QuestTitle(qid, fallback)
	local f = C_QuestLog and C_QuestLog.GetTitleForQuestID
	if f and qid then
		local ok, v = pcall(f, qid)
		if ok and type(v) == "string" and v ~= "" then return v end
	end
	return fallback
end
local function ChainLines(t, s)
	local fi = UnitFactionGroup("player") == "Horde" and 2 or 1
	t[#t + 1] = TipH("연계 순서")
	local nDone = 0
	for i, c in ipairs(s.chain) do
		local qid = c.q[fi]
		local done = QuestDone(qid)
		if done then nDone = nDone + 1 end
		local mark = done and "|cff6FD39A완료|r  " or ("|cffE3C07A" .. i .. "|r  ")
		t[#t + 1] = TipKV(mark .. QuestTitle(qid, c.name), c.get or " ", done and TIP_MUTED or TIP_WHITE, TIP_MUTED)
		if not done then
			local need
			if c.items then
				local parts = {}
				for _, it in ipairs(c.items) do parts[#parts + 1] = ItemNameOf(it) .. " " .. it[2] end
				need = table.concat(parts, " · ")
			elseif c.text then
				need = c.text[fi]
			end
			if need then t[#t + 1] = TipT(need, TIP_SOFT) end
		end
	end
	if nDone > 0 then t[#t + 1] = TipT(nDone .. " / " .. #s.chain .. " 끝냄", TIP_GREEN) end
	if s.chainNote then t[#t + 1] = TipT(s.chainNote, TIP_DIM) end
end

local function SpecTip(prof, s, def, isMaster, withSwitch)
	local cls = MyClass()
	local t = { SpecNameC(s) }
	t[#t + 1] = TipT(s.desc, TIP_WHITE)
	if s.sig then t[#t + 1] = s.sig end
	t[#t + 1] = TipH("조건")
	t[#t + 1] = TipKV(isMaster and "무기제작 · " .. (def.lvl or 0) .. "레벨" or ((def.lvl or 0) .. "레벨"), "숙련도 " .. (def.skill or 0), TIP_SOFT, TIP_WHITE)
	if def.one then t[#t + 1] = TipT(def.one, TIP_MUTED) end
	local st = s.start and PickWho(s.start)
	local w = PickWho(s.who)
	t[#t + 1] = TipH("배우는 법")
	if st then WhoLines(t, "|cffE3C07A1|r  퀘스트 시작", st) end
	WhoLines(t, st and "|cffE3C07A2|r  배우는 곳" or "배우는 곳", w)
	if s.how then t[#t + 1] = TipT(s.how, TIP_MUTED) end
	if s.chain then ChainLines(t, s) end
	if s.items then
		t[#t + 1] = TipH("가져갈 것")
		for _, it in ipairs(s.items) do
			local nm = ItemNameOf(it)
			local have = Count(nm, it[1])
			t[#t + 1] = TipKV(nm, (have > 0 and (have .. " / ") or "") .. it[2] .. "개", TIP_SOFT, have >= it[2] and TIP_GREEN or TIP_WHITE)
		end
	end
	if s.target then
		t[#t + 1] = TipH("대가 퀘스트")
		t[#t + 1] = s.target
	end
	local rec, n = SpecRecipes(prof, s.spell, 6)
	if #rec > 0 then
		t[#t + 1] = TipH("훈련사에게 열리는 제조법")
		for i = 1, #rec, 2 do t[#t + 1] = TipKV(rec[i], rec[i + 1] or " ", TIP_SOFT, TIP_SOFT) end
		if n > #rec then t[#t + 1] = TipT("외 " .. (n - #rec) .. "개", TIP_MUTED) end
	end
	local sc, _, long = Fit(s, cls)
	if s.fit and s.fit.ALL and not s.fit[cls] then
		if long then t[#t + 1] = TipH("쓰임새"); t[#t + 1] = long end
	elseif long then
		t[#t + 1] = TipH(ClassText(cls) .. (sc >= 2 and "  |cffFFD15F추천|r" or ""))
		t[#t + 1] = long
	end
	if withSwitch and def.switch then
		t[#t + 1] = TipH("나중에 바꾸려면")
		t[#t + 1] = TipT(def.switch, TIP_MUTED)
	end
	local pin = WhoPin(st, "퀘스트 시작") or WhoPin(w, "심화 과정 훈련사")
	if pin then t[#t + 1] = TipHint("누르면 지도에 " .. (WhoPin(st) and "퀘스트 시작 NPC" or "배우는 곳") .. " 표시") end
	return t, pin
end
-- 직업별 추천 전체 (툴팁 아래쪽): 직업 이름은 직업색 · 내 직업은 금색으로
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local function FitTable(def, t)
	t = t or {}
	if def.advice then t[#t + 1] = TipH("고르는 법"); t[#t + 1] = def.adviceLong or def.advice; return t end
	t[#t + 1] = TipH("직업별 추천")
	local me = MyClass()
	for _, c in ipairs(CLASS_ORDER) do
		local sc = 0
		for _, s in ipairs(def.list) do
			local v = Fit(s, c)
			if s.fit and s.fit[c] and v > sc then sc = v end
		end
		if sc > 0 then
			local names = {}
			for _, s in ipairs(def.list) do
				if s.fit and s.fit[c] and s.fit[c][1] == sc then names[#names + 1] = SpecShortC(s) end
			end
			local right = table.concat(names, " · ") .. (sc >= 2 and "" or "  (판매용)")
			t[#t + 1] = TipKV((c == me and "|cffFFD15F●|r " or "") .. ClassText(c), right, TIP_SOFT, c == me and TIP_GOLD or (sc >= 2 and TIP_WHITE or TIP_MUTED))
		end
	end
	t[#t + 1] = TipT("클래식 기준 일반론 · 포에버 패치로 바뀔 수 있어요", TIP_DIM)
	return t
end
-- 단계 하나의 툴팁: 조건 · 비용 · 배우는 곳(가까운 순 3곳) · 그 뒤 단계
local function RankTip(nx, title, later)
	local lv = UnitLevel("player") or 1
	local t = { title or (nx.name .. " 단계 · " .. nx.cap .. "까지") }
	t[#t + 1] = TipH("조건")
	t[#t + 1] = TipKV(lv < nx.lvl and ("|cffFF6B5E" .. nx.lvl .. "레벨|r") or (nx.lvl .. "레벨"), "숙련도 " .. nx.skill, TIP_SOFT, TIP_WHITE)
	local costT = M.RankCostText(nx)
	if nx.book then
		t[#t + 1] = TipT("훈련사가 아니라 책으로 배워요 (그 NPC 가 팔아요)", TIP_MUTED)
	elseif nx.quest then
		t[#t + 1] = TipT("훈련사가 아니라 퀘스트로 배워요", TIP_MUTED)
	elseif costT ~= "" then
		t[#t + 1] = TipKV("비용", (costT:gsub("%s+$", "")), TIP_SOFT, TIP_GOLD)
		if nx.cost and not nx.costSeen then t[#t + 1] = TipT("기본 값 · 평판이 높으면 싸져요", TIP_DIM) end
	end
	t[#t + 1] = TipH(nx.book and "책 파는 곳" or (nx.quest and "퀘스트 주는 곳" or "배우는 곳"))
	for k = 1, math.min(3, #nx.spots) do WhoLines(t, k == 1 and "가까운 곳" or "그 밖에", nx.spots[k]) end
	if #nx.spots == 0 then t[#t + 1] = TipT("자리 정보 없음", TIP_MUTED) end
	local sp = nx.spots[1]
	if sp and TRAINER_NOTE[sp.npc] then t[#t + 1] = TipT(TRAINER_NOTE[sp.npc], TIP_GOLD) end
	if nx.svc then t[#t + 1] = TipT("훈련사 창에서 '" .. nx.svc .. "' 배우기", TIP_MUTED) end
	if later and #later > 0 then
		t[#t + 1] = TipH("그 뒤 단계")
		for _, ri in ipairs(later) do
			local s2 = ri.spots[1]
			t[#t + 1] = TipKV(ri.name .. " · " .. ri.cap .. "까지", ri.lvl .. "레벨 · 숙련도 " .. ri.skill, TIP_WHITE, TIP_SOFT)
			t[#t + 1] = TipKV(" ", s2 and (TrainerName(s2.npc, s2.en) .. " · " .. ZoneName(s2.map)) or (ri.book and "책" or (ri.quest and "퀘스트" or "정보 없음")), TIP_SOFT, TIP_MUTED)
		end
	end
	if sp then t[#t + 1] = TipHint("누르면 지도에 표시") end
	return t
end
M.RankTip = RankTip
-- 심화 과정 한 묶음의 툴팁 (첫 화면 · 추천 줄): 과정마다 배우는 곳 + 직업별 추천
local function GroupTip(def, isMaster, pinName)
	local cls = MyClass()
	local t = { isMaster and "무기제작 대가 과정" or def.group }
	t[#t + 1] = TipT(string.format("%s%d레벨 · 숙련도 %d · %s", isMaster and "무기제작 · " or "", def.lvl or 0, def.skill or 0, def.one or ""), TIP_WHITE)
	t[#t + 1] = TipH("과정과 배우는 곳")
	for _, v in ipairs(def.list) do
		local w = PickWho(v.who)
		local rec = not def.advice and Fit(v, cls) >= 2
		t[#t + 1] = TipKV(SpecNameC(v) .. (rec and "  |cffFFD15F추천|r" or ""), w and TrainerName(w.npc, w.en) or "", TIP_WHITE, TIP_SOFT)
		t[#t + 1] = TipKV("   " .. (v.desc or ""), w and w.map and string.format("%s  %.0f, %.0f", ZoneName(w.map), w.x, w.y) or "", TIP_MUTED, TIP_MUTED)
	end
	FitTable(def, t)
	if pinName then t[#t + 1] = TipHint("누르면 지도에 " .. pinName .. " 위치\n전문기술 창을 열면 더 자세히 나와요") end
	return t
end
-- 상태 글 (오른쪽): 배움 · 지금 가능 · 모자란 조건
local function SpecReady(def, skill, lv)
	if lv < (def.lvl or 0) then return false, "|cffFF6B5E" .. def.lvl .. "레벨|r" end
	if (skill or 0) < (def.skill or 0) then return false, "숙련도 " .. def.skill end
	return true, "|cff6FD39A지금 가능|r"
end
M.SpecTip, M.FitTable = SpecTip, FitTable

-- 훈련사가 가르치는 제조법: [주문] = { 숙련, 훈련사들 }
local function TrainerRecipes(prof)
	local out = {}
	for _, t in ipairs(Trainers(prof)) do
		for sid, la in pairs(t.recipes) do
			local e = out[sid]
			if not e then e = { la = la, who = {} }; out[sid] = e end
			e.who[#e.who + 1] = t
		end
	end
	return out
end

-- 경로 자료의 "교관 · 10g" → 실제로 가르치는 훈련사 (가까운 곳 · 내 진영 · 심화 과정 훈련사는 배운 경우만)
local trCache, trByName = {}, {}
function M.ResetCache() trCache = {} end
local function TrainerRecipesC(prof)
	if not trCache[prof] then trCache[prof] = TrainerRecipes(prof) end
	return trCache[prof]
end
local function TrainerSpellByName(prof, n)
	trByName[prof] = trByName[prof] or {}
	local m = trByName[prof]
	if m[n] == nil then
		m[n] = false
		for sid in pairs(TrainerRecipesC(prof)) do if SpellName(sid) == n then m[n] = sid break end end
	end
	return m[n] or nil
end
function M.RouteTrainer(prof, craft, src)
	if not (prof and craft and type(src) == "string" and src:find("^교관")) then return end
	local recs = TrainerRecipesC(prof)
	local sid = CraftSpellByName(craft)
	if not (sid and recs[sid]) then sid = TrainerSpellByName(prof, craft) end
	local e = sid and recs[sid]
	if not e then return end
	local best
	for _, t in ipairs(e.who) do
		if not SpecLocked(t) then
			t.d = t.d or Dist(t.map, t.x, t.y)
			if not best or t.d < best.d then best = t end
		end
	end
	if not best then return end
	return best, src:match("·%s*(.+)$"), #e.who
end

-- 비용 글: 본 값이면 그대로, 기본 값이면 "약" · 책 · 퀘스트는 따로
function M.RankCostText(info)
	if not info then return "" end
	if info.book then return "책 구입" end
	if info.quest then return "퀘스트" end
	if not info.cost then return "" end
	return (info.costSeen and "" or "약 ") .. Money(info.cost)
end
function M.RankIcon(info)
	if not info then return 134400 end
	if info.book then return ItemIcon(info.book) or 133741 end
	return (info.spell and SpellIcon(info.spell)) or 134400
end

-- 기술 그림: 단계 주문 그림 (전문기술 아이콘)
local function ProfIcon(prof)
	for _, t in ipairs((ns.PROF_TRAINERS or {})[prof] or {}) do
		for r = 1, 4 do
			local d = t[4][r]
			local ic = d and SpellIcon(d[1])
			if ic then return ic end
		end
	end
	return 134400
end
-- 내가 배운 전문기술 { prof, name, rank, max } (주 기술 → 채집 → 보조 순)
local PROF_ORDER = { 165, 164, 171, 197, 202, 333, 182, 186, 393, 185, 356, 129 }
local function MyProfs()
	local out = {}
	for _, id in ipairs(PROF_ORDER) do
		local rank, max
		if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
			local ok, d = pcall(C_SkillInfo.GetSkillLineInfoByID, id)
			if ok and type(d) == "table" and not d.isHeader and (d.rank or 0) > 0 then rank, max = d.rank, d.maxRank end
		end
		if not rank then rank, max = SkillByName(PROF_NAME[id]) end
		if rank and (max or 0) > 0 then out[#out + 1] = { prof = id, name = PROF_NAME[id], rank = rank, max = max } end
	end
	return out
end
M.MyProfs = MyProfs

-- 한 줄 안내: "숙련 단계 (훈련사)", "텔로니스 · 다르나서스 65, 22"
function M.NextRankText(info)
	if not info then return end
	local s = info.spots[1]
	local how = info.book and "책" or (info.quest and "퀘스트" or "훈련사")
	local where = s and string.format("%s · %s %.0f, %.0f%s", TrainerName(s.npc, s.en), ZoneName(s.map), s.x, s.y, s.inside and " (던전 안)" or "") or "배우는 곳 정보 없음"
	return info.name .. " 단계 (" .. how .. ")", where
end


-------------------------------------------------------------------------------
-- 패널
-------------------------------------------------------------------------------
local function Host()
	if _G.ProfessionsFrame and _G.ProfessionsFrame:IsShown() then return _G.ProfessionsFrame end
	if _G.CraftFrame and _G.CraftFrame:IsShown() then return _G.CraftFrame end
	if _G.TradeSkillFrame and _G.TradeSkillFrame:IsShown() then return _G.TradeSkillFrame end
end

local function Head(body)
	local h = CreateFrame("Frame", nil, body)
	h:SetSize(W - 20, 24)
	h.t = Ink:Text(h, F.semi, 11, C.text, "LEFT")
	h.t:SetPoint("BOTTOMLEFT", 4, 5)
	h.r = Ink:Text(h, F.sans, 10, C.muted, "RIGHT")
	h.r:SetPoint("BOTTOMRIGHT", -6, 5)
	h.line = h:CreateTexture(nil, "ARTWORK")
	h.line:SetColorTexture(1, 1, 1, 0.07)
	h.line:SetHeight(1)
	h.line:SetPoint("BOTTOMLEFT", 2, 0)
	h.line:SetPoint("BOTTOMRIGHT", -2, 0)
	return h
end

-- 툴팁: 아이템(만들어지는 것 · 제조법) · 링크 · 주문이 있으면 게임 툴팁을 먼저, 그 밑에 안내 줄
--  아이템 정보가 아직 없으면 받아 오는 대로 다시 그린다
local function ShowTip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local rich
	if self.link then
		rich = pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
	elseif self.item then
		rich = pcall(GameTooltip.SetItemByID, GameTooltip, self.item)
		local cached = true
		if C_Item and C_Item.IsItemDataCachedByID then local ok, v = pcall(C_Item.IsItemDataCachedByID, self.item); cached = not ok or v end
		if not cached and Item and Item.CreateFromItemID then
			local ok, it = pcall(Item.CreateFromItemID, Item, self.item)
			if ok and it and it.ContinueOnItemLoad then
				it:ContinueOnItemLoad(function()
					if GameTooltip:IsOwned(self) and self:IsMouseOver() then ShowTip(self) end
				end)
			end
		end
	elseif self.spell then
		rich = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spell)
	end
	if self.tip then
		if rich then GameTooltip:AddLine(" ") end
		local hinted
		for i, l in ipairs(self.tip) do
			if type(l) == "string" then
				if i == 1 then
					if not rich then Ink.TipLines(GameTooltip, l, 1, 1, 1, 32) end
				elseif l ~= "" then
					Ink.TipLines(GameTooltip, l, TIP_SOFT[1], TIP_SOFT[2], TIP_SOFT[3])
				end
			elseif type(l) == "table" then
				if l.gap then
					GameTooltip:AddLine(" ")
				elseif l.h then
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine(l.h, TIP_HEAD[1], TIP_HEAD[2], TIP_HEAD[3])
				elseif l.hint then
					if not hinted then GameTooltip:AddLine(" "); hinted = true end
					Ink.TipLines(GameTooltip, l.hint, TIP_DIM[1], TIP_DIM[2], TIP_DIM[3])
				elseif l.l then
					local lc, rc = l.lc or TIP_SOFT, l.rc or TIP_WHITE
					GameTooltip:AddDoubleLine(l.l, l.r or " ", lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
				elseif l.t then
					local c = l.c or TIP_SOFT
					Ink.TipLines(GameTooltip, l.t, c[1], c[2], c[3])
				end
			end
		end
	end
	GameTooltip:Show()
end
local function TipTarget(f, item, link, spell)
	f.item, f.link, f.spell = item, link, spell
end

local function Row(body)
	local r = CreateFrame("Button", nil, body)
	r:SetSize(W - 20, ROW)
	r.hl = Ink:Round(r, "BACKGROUND", true, false)
	r.hl:SetAllPoints()
	r.hl:SetVertexColor(1, 1, 1, 0)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(22, 22)
	r.icon:SetPoint("LEFT", 6, 0)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.dot = r:CreateTexture(nil, "OVERLAY")
	r.dot:SetTexture(Ink.tex.disc)
	r.dot:SetSize(7, 7)
	r.dot:SetPoint("CENTER", r.icon, "TOPRIGHT", -1, -1)
	r.name = Ink:Text(r, F.semi, 11, C.text, "LEFT")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 9, 1)
	r.name:SetPoint("RIGHT", -64, 0)
	r.sub = Ink:Text(r, F.sans, 10, C.muted, "LEFT")
	r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 9, -1)
	r.sub:SetPoint("RIGHT", -64, 0)
	r.right = Ink:Text(r, F.sans, 10, C.soft, "RIGHT")
	r.right:SetPoint("RIGHT", -6, 0)
	r:SetScript("OnEnter", function(self)
		self.hl:SetVertexColor(1, 1, 1, 0.05)
		if not (self.tip or self.item or self.link or self.spell) then return end
		ShowTip(self)
	end)
	r:SetScript("OnLeave", function(self) self.hl:SetVertexColor(1, 1, 1, 0); GameTooltip:Hide() end)
	r:SetScript("OnClick", function(self) if self.onClick then self.onClick(self) elseif self.vendor then Waypoint(self.vendor) end end)
	return r
end

function M:Build(host)
	local p = CreateFrame("Frame", "FOAProfessionGuide", host)
	p:SetSize(W, 470)
	p:SetFrameStrata(host:GetFrameStrata())
	p:SetFrameLevel(host:GetFrameLevel() + 20)
	p:SetClampedToScreen(true)
	p.bg = Ink:Round(p, "BACKGROUND", false, false)
	p.bg:SetAllPoints()
	p.bg:SetVertexColor(0.04, 0.045, 0.06, 0.97)
	p.bd = Ink:Round(p, "BORDER", false, true)
	p.bd:SetAllPoints()
	p.bd:SetVertexColor(1, 1, 1, 0.1)
	local acc = p:CreateTexture(nil, "ARTWORK")
	acc:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	acc:SetSize(22, 2)
	acc:SetPoint("TOPLEFT", 14, -1)
	p.title = Ink:Text(p, F.bold, 13, C.text, "LEFT")
	p.title:SetPoint("TOPLEFT", 14, -13)
	p.skill = Ink:Text(p, F.numR or F.semi, 11, C.soft, "RIGHT")
	p.skill:SetPoint("TOPRIGHT", -14, -15)
	p.bar = Ink:Bar(p, W - 28, 2, C.accent, { 1, 1, 1, 0.08 })
	p.bar:SetPoint("TOPLEFT", 14, -34)
	-- 지금 구간 카드
	local c = CreateFrame("Frame", nil, p)
	c:SetPoint("TOPLEFT", 10, -44)
	c:SetPoint("TOPRIGHT", -10, -44)
	c:SetHeight(120)
	c.bg = Ink:Round(c, "BACKGROUND", true, false)
	c.bg:SetAllPoints()
	c.bg:SetVertexColor(1, 1, 1, 0.035)
	c.bd = Ink:Round(c, "BORDER", true, true)
	c.bd:SetAllPoints()
	c.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.4)
	c.k = Ink:Text(c, F.sans, 10, C.accent, "LEFT")
	c.k:SetPoint("TOPLEFT", 12, -10)
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.icon:SetSize(30, 30)
	c.icon:SetPoint("TOPLEFT", 12, -28)
	c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	c.iconHit = CreateFrame("Frame", nil, c)
	c.iconHit:SetAllPoints(c.icon)
	c.iconHit:EnableMouse(true)
	c.iconHit:SetScript("OnEnter", function(self) if self.tip or self.item or self.link or self.spell then ShowTip(self) end end)
	c.iconHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	c.name = Ink:Text(c, F.bold, 13, C.text, "LEFT")
	c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, -1)
	c.name:SetPoint("RIGHT", -12, 0)
	c.sub = Ink:Text(c, F.sans, 10, C.soft, "LEFT")
	c.sub:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 10, 1)
	c.sub:SetPoint("RIGHT", -12, 0)
	c.mats = {}
	for i = 1, 5 do
		local m = CreateFrame("Frame", nil, c)
		m:SetSize(W - 44, 14)
		m:SetPoint("TOPLEFT", 12, -66 - (i - 1) * 15)
		m.n = Ink:Text(m, F.sans, 10, C.soft, "LEFT")
		m.n:SetPoint("LEFT")
		m.v = Ink:Text(m, F.numR or F.sans, 10, C.text, "RIGHT")
		m.v:SetPoint("RIGHT")
		m:EnableMouse(true)
		m:SetScript("OnEnter", function(self) if self.item or self.tip then ShowTip(self) end end)
		m:SetScript("OnLeave", function() GameTooltip:Hide() end)
		c.mats[i] = m
	end
	c.cost = Ink:Text(c, F.sans, 10, GOLD, "LEFT")
	c.src = Ink:Text(c, F.sans, 10, C.muted, "RIGHT")
	-- 상인 줄: 누르면 지도에 위치
	c.vend = CreateFrame("Button", nil, c)
	c.vend:SetHeight(34)
	c.vend:SetPoint("BOTTOMLEFT", 8, 6)
	c.vend:SetPoint("BOTTOMRIGHT", -8, 6)
	c.vend.bg = Ink:Round(c.vend, "BACKGROUND", true, false)
	c.vend.bg:SetAllPoints()
	c.vend.bg:SetVertexColor(1, 1, 1, 0.04)
	c.vend.icon = c.vend:CreateTexture(nil, "ARTWORK")
	c.vend.icon:SetTexture(Ink.icon("NpcVendor"))
	c.vend.icon:SetSize(14, 14)
	c.vend.icon:SetPoint("LEFT", 8, 0)
	c.vend.icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
	c.vend.t = Ink:Text(c.vend, F.semi, 10, C.text, "LEFT")
	c.vend.t:SetPoint("TOPLEFT", c.vend, "TOPLEFT", 30, -5)
	c.vend.t:SetPoint("RIGHT", -8, 0)
	c.vend.s = Ink:Text(c.vend, F.sans, 9, C.muted, "LEFT")
	c.vend.s:SetPoint("BOTTOMLEFT", c.vend, "BOTTOMLEFT", 30, 6)
	c.vend.s:SetPoint("RIGHT", -8, 0)
	c.vend:SetScript("OnClick", function(self) Waypoint(self.x) end)
	c.vend:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(1, 1, 1, 0.09)
		if self.item or self.tip then ShowTip(self) end
	end)
	c.vend:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0.04); GameTooltip:Hide() end)
	c.vend:Hide()
	p.card = c
	-- 목록
	local sf = CreateFrame("ScrollFrame", nil, p)
	sf:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 0, -8)
	sf:SetPoint("BOTTOMRIGHT", -10, 30)
	local body = CreateFrame("Frame", nil, sf)
	body:SetSize(W - 20, 10)
	sf:SetScrollChild(body)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, d)
		local r = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(math.max(0, math.min(r, self:GetVerticalScroll() - d * 40)))
	end)
	p.sf, p.body, p.rows, p.heads = sf, body, {}, {}
	p.foot = Ink:Text(p, F.sans, 9, C.dim, "LEFT")
	p.foot:SetPoint("BOTTOMLEFT", 14, 11)
	p.foot:SetPoint("BOTTOMRIGHT", -14, 11)
	p.foot:SetWordWrap(true)
	Ink:MakeDraggable(p, "prof", host)
	self.panel = p
	return p
end

-- 전문기술 창 첫 화면(기술 목록): 기술을 고르라는 안내 + 내 기술마다 다음 단계
function M:PaintOverview(p, host)
	if p:GetParent() ~= host then
		p:SetParent(host)
		Ink:MakeDraggable(p, "prof", host)
	end
	p.foaResetPos = function() Ink:PanelPoint(p, "prof", host, 6, -12) end
	if not p.placed or p.placedFor ~= host then Ink:PanelPoint(p, "prof", host, 6, -12); p.placed, p.placedFor = true, host end
	p:SetFrameStrata(host:GetFrameStrata())
	p:SetFrameLevel(host:GetFrameLevel() + 20)
	p:Show()
	p.title:SetText("전문기술 안내")
	p.skill:SetText("")
	p.bar:SetMinMaxValues(0, 1)
	p.bar:SetValue(0)
	local c = p.card
	TipTarget(c.iconHit); c.iconHit.tip = nil
	TipTarget(c.vend); c.vend.tip = nil
	for _, m in ipairs(c.mats) do m.item, m.tip = nil, nil; m:Hide() end
	c.k:SetText("안내")
	c.icon:SetTexture(136241)
	c.icon:SetDesaturated(false)
	c.name:SetText("전문기술을 하나 고르면 안내가 나와요")
	c.sub:SetText("지금 구간 · 재료 · 배울 제조법 · 다음 단계")
	c.cost:SetText(""); c.src:SetText("")
	c.vend:Hide()
	c:SetHeight(70)
	for _, r in ipairs(p.rows) do r:Hide() end
	for _, h in ipairs(p.heads) do h:Hide() end
	trCache, nameMiss = {}, nil
	local y, nr, nh = 0, 0, 0
	local function head(t, rt)
		nh = nh + 1
		local h = p.heads[nh] or Head(p.body)
		p.heads[nh] = h
		h.t:SetText(t); h.r:SetText(rt or "")
		h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:Show()
		y = y + 28
	end
	local function newRow()
		nr = nr + 1
		local r = p.rows[nr] or Row(p.body)
		p.rows[nr] = r
		r.vendor, r.item, r.link, r.spell, r.tip = nil, nil, nil, nil, nil
		r.icon:SetDesaturated(false)
		r.name:SetTextColor(C.text[1], C.text[2], C.text[3])
		r.dot:Hide()
		return r
	end
	local mine = MyProfs()
	local lv = UnitLevel("player") or 1
	local specs = {}
	if #mine > 0 then
		head("내 전문기술", "누르면 다음 단계 훈련사")
		for _, e in ipairs(mine) do
			local r = newRow()
			r.icon:SetTexture(ProfIcon(e.prof))
			r.name:SetText(e.name .. "  |cff8A9099" .. e.rank .. " / " .. e.max .. "|r")
			local sp = M.SpecState(e.prof, e.rank)
			local spOpen = sp and not (sp.learned and (not sp.master or sp.master.learned))
			if spOpen then specs[#specs + 1] = { e = e, sp = sp } end
			local nx = e.max < 300 and M.NextRank(e.prof, e.max) or nil
			if not nx then
				-- 단계는 다 배움: 심화 과정이 남았으면 그쪽으로 (아래 '심화 과정' 칸)
				if sp and sp.learned and not spOpen then
					r.sub:SetText(Short(19, SpecNameC(sp.learned), sp.master and sp.master.learned and SpecNameC(sp.master.learned) or nil, "|cff6FD39A배움|r"))
					r.right:SetText("|cff6FD39A완료|r")
				elseif spOpen then
					local grp = (sp.learned and sp.master) or sp
					r.sub:SetText("모든 단계 완료 · " .. (grp == sp.master and "대가 과정" or "심화 과정") .. " (아래)")
					r.right:SetText("|cffFFD15F심화 과정|r")
				else
					r.sub:SetText("모든 단계 완료 · 심화 과정 없음")
					r.right:SetText("|cff6FD39A완료|r")
				end
				r.tip = { e.name .. "  " .. e.rank .. " / " .. e.max, TipT(RankLabel(1) .. " · " .. RankLabel(2) .. " · " .. RankLabel(3) .. " · " .. RankLabel(4) .. "  단계를 모두 배웠어요", TIP_WHITE) }
				if spOpen then
					r.tip[#r.tip + 1] = "심화 과정은 아래 '심화 과정' 칸에서\n어디서 배우는지 볼 수 있어요"
				elseif not sp then
					r.tip[#r.tip + 1] = "이 기술은 클래식처럼 심화 과정이 없어요\n남은 건 상인 · 드랍 제조법"
				end
			else
				local sp = nx.spots[1]
				local how = nx.book and "책" or (nx.quest and "퀘스트" or (sp and TrainerName(sp.npc, sp.en) or "훈련사"))
				r.sub:SetText(Short(19, nx.name .. " 단계", how, sp and ZoneName(sp.map) or nil))
				local ready = lv >= nx.lvl and e.rank >= nx.skill
				local costT = M.RankCostText(nx)
				r.right:SetText(ready and ("|cff6FD39A지금 배움|r") or (lv < nx.lvl and ("|cffFF6B5E" .. nx.lvl .. "레벨|r") or ("숙련도 " .. nx.skill)))
				if ready then r.dot:SetVertexColor(GREEN[1], GREEN[2], GREEN[3]); r.dot:Show() else r.dot:Hide() end
				-- 그 뒤 단계도 미리 (숙련도가 모자라도 어디로 가야 하는지)
				local road = M.Roadmap(e.prof, e.max)
				local later = {}
				for i = 2, #road do later[#later + 1] = road[i] end
				r.tip = RankTip(nx, e.name .. " · " .. nx.name .. " 단계 · " .. nx.cap .. "까지", later)
				if sp then r.vendor = { sp.npc, sp.map, sp.x, sp.y, label = "훈련사" } end
				if nx.book then r.item = nx.book end
			end
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:Show()
			y = y + ROW + 2
		end
	end
	-- 심화 과정: 단계와 따로 (가죽세공 · 대장기술 · 기계공학)
	if #specs > 0 then
		y = y + 6
		head("심화 과정", "직업 추천 · 누르면 지도")
		local cls = MyClass()
		for _, x in ipairs(specs) do
			local sp, e = x.sp, x.e
			local grp = (sp.learned and sp.master) or sp
			local def, isMaster = grp.def, grp == sp.master
			local s = grp.best or def.list[1]
			local _, why = Fit(s, cls)
			local shorts = {}
			for _, v in ipairs(def.list) do shorts[#shorts + 1] = SpecShortC(v) end
			local r = newRow()
			r.icon:SetTexture(SpellIcon(s.spell) or ProfIcon(e.prof))
			r.name:SetText((isMaster and (SpecName(sp.learned) .. " 대가") or e.name) .. "  " .. table.concat(shorts, " |cff5E636B·|r "))
			r.sub:SetText(grp.best and Short(19, "|cffFFD15F추천|r " .. SpecShortC(s) .. (#grp.alt > 0 and ("/" .. SpecShortC(grp.alt[1])) or ""), why) or (def.advice or def.one or ""))
			local ok, stateT = SpecReady(def, e.rank, lv)
			r.right:SetText(stateT)
			if ok then r.dot:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]); r.dot:Show() end
			local _, pin = SpecTip(e.prof, s, def, isMaster)
			r.tip, r.vendor = GroupTip(def, isMaster, pin and (s.short or s.name)), pin
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:Show()
			y = y + ROW + 2
		end
	end
	p.body:SetHeight(math.max(10, y))
	p.foot:SetText("단계 · 훈련사: AllTheThings · 심화 과정: 클래식 규칙")
	M.RetryNames(self)
end

-- 이름을 아직 모르는 NPC 가 있었으면 잠시 뒤 한 번 더 그린다 (최대 3번)
function M.RetryNames(self)
	if not nameMiss then self.nameRetry = 0 return end
	self.nameRetry = (self.nameRetry or 0) + 1
	if self.nameRetry > 3 then return end
	C_Timer.After(1.5, function() if Host() then pcall(M.Paint, M) end end)
end

function M:Paint()
	local host = Host()
	if not host or Ink.db.profGuide == false then if self.panel then self.panel:Hide() end return end
	local name, skill, max, kind = ProfInfo()
	local route, rkey = RouteFor(name)
	local known = name and KnownRecipes(kind) or {}
	if name and not route and #known == 0 then if self.panel then self.panel:Hide() end return end
	local p = self.panel or self:Build(host)
	if not name then return self:PaintOverview(p, host) end
	if p:GetParent() ~= host then
		p:SetParent(host)
		Ink:MakeDraggable(p, "prof", host)
	end
	p.foaResetPos = function() Ink:PanelPoint(p, "prof", host, 6, -12) end
	if not p.placed or p.placedFor ~= host then Ink:PanelPoint(p, "prof", host, 6, -12); p.placed, p.placedFor = true, host end
	p:SetFrameStrata(host:GetFrameStrata())
	p:SetFrameLevel(host:GetFrameLevel() + 20)
	p:Show()
	local prof = ProfID(name)
	trCache, nameMiss = {}, nil
	local lv = UnitLevel("player") or 1
	local spec = prof and M.SpecState(prof, skill)
	p.title:SetText((name or "전문기술") .. " 안내")
	p.skill:SetText(skill .. " / " .. max)
	p.bar:SetMinMaxValues(0, math.max(1, max))
	p.bar:SetValue(skill)
	local byName = {}
	for _, r in ipairs(known) do byName[r.name] = r end
	-- 1) 지금 구간
	local cur, curI
	for i, s in ipairs(route or {}) do
		if s[4] > 0 and skill < s[2] then cur, curI = s, i break end
	end
	local c = p.card
	TipTarget(c.iconHit); c.iconHit.tip = nil
	TipTarget(c.vend); c.vend.tip = nil
	for _, m in ipairs(c.mats) do m.item, m.tip = nil, nil end
	-- 단계 한도에 닿았으면 경로 구간보다 "다음 단계를 어디서 배우나" 가 먼저 (배우기 전엔 더 못 올린다)
	local capped = prof and max > 0 and max < 300 and skill >= max
	if cur and not capped then
		local span = math.max(1, cur[2] - cur[1])
		local left = math.max(1, math.ceil((cur[2] - math.max(skill, cur[1])) * cur[4] / span))
		local kr = byName[cur[3]]
		local csid = (not kr or not kr.link) and CraftSpellByName(cur[3]) or nil
		local citem = CraftItem(csid) or (not kr and ItemByName(cur[3])) or nil
		c.k:SetText(string.format("지금 구간  %d → %d", cur[1], cur[2]))
		c.icon:SetTexture((kr and kr.icon) or (csid and CraftIcon(csid)) or (citem and ItemIcon(citem)) or 134400)
		c.icon:SetDesaturated(false)
		TipTarget(c.iconHit, citem, kr and kr.link, (not citem and csid) or nil)
		c.iconHit.tip = { cur[3], TipKV("이 구간", string.format("숙련도 %d → %d", cur[1], cur[2]), TIP_SOFT, TIP_WHITE) }
		c.name:SetText(cur[3])
		c.sub:SetText(string.format("약 %d번 더 만들기", left) .. (kr and kr.avail > 0 and ("  ·  |cff6FD39A지금 %d개 가능|r"):format(kr.avail) or "") .. (kr and "" or "  ·  |cffFFB75A아직 안 배움|r"))
		-- 재료: 아는 제조법이면 게임 자료(한 번에 드는 수 × 남은 횟수), 아니면 경로 자료(구간 합계를 남은 비율로)
		local mats = {}
		if kr and #kr.reagents > 0 then
			for _, rg in ipairs(kr.reagents) do mats[#mats + 1] = { RgName(rg), rg.need * left, Count(rg.name, rg.itemID), rg.itemID } end
		else
			for _, m in ipairs(cur[5]) do
				mats[#mats + 1] = { m[1], math.ceil(m[2] * left / math.max(1, cur[4])), Count(m[1]), ItemByName(m[1]), m[3] }
			end
		end
		local cost, priced = 0, 0
		for i, m in ipairs(c.mats) do
			local d = mats[i]
			if d then
				local enough = d[3] >= d[2]
				m.n:SetText(d[1] .. (d[5] and d[5] ~= "" and ("  |cff5E636B" .. d[5] .. "|r") or ""))
				m.v:SetText((enough and "|cff6FD39A" or "") .. d[3] .. "|r / " .. d[2])
				m.item = d[4]
				m.tip = { d[1], TipKV("가방 · 은행", d[3] .. "개", TIP_SOFT, enough and TIP_GREEN or TIP_WHITE), TipKV("필요", d[2] .. "개", TIP_SOFT, TIP_WHITE),
					d[5] and d[5] ~= "" and TipKV("구하는 곳", d[5], TIP_SOFT, TIP_SOFT) or "" }
				m:Show()
				local pr = Price(d[1], d[4])
				if pr and d[2] > d[3] then cost = cost + pr * (d[2] - d[3]); priced = priced + 1 end
			else
				m:Hide()
			end
		end
		local nm = math.min(#mats, #c.mats)
		local y = 66 + nm * 15 + 4
		c.cost:ClearAllPoints()
		c.cost:SetPoint("TOPLEFT", 12, -y)
		c.cost:SetText(priced > 0 and ("모자란 재료 " .. Money(cost) .. " |cff5E636B(경매장)|r") or "")
		c.src:ClearAllPoints()
		c.src:SetPoint("TOPRIGHT", -12, -y)
		-- 훈련사가 가르치는 제조법이면 "교관" 대신 실제 훈련사 (가까운 곳)
		local rt, rcost
		if not kr then rt, rcost = M.RouteTrainer(prof, cur[3], cur[6]) end
		-- 아직 안 배운 제조법이 상인 판매면: 상인 · 위치 · 값 (누르면 지도)
		local vx = (not kr) and PickVendor(VendorIndex(name)[cur[3]])
		-- 상인 · 훈련사는 아래 버튼에 이름 · 위치 · 값이 다 나오니 여기선 겹치지 않게 비운다
		c.src:SetText(kr and "|cff6FD39A배움|r" or ((vx or rt) and "" or ("배우는 곳  " .. (cur[6] or ""))))
		if vx then
			c.vend.icon:SetTexture(Ink.icon("NpcVendor"))
			local who, where, price = VendorText(vx)
			c.vend.x = vx
			c.vend.item = VendorIndex(name)[cur[3]].item
			c.vend.tip = { cur[3], TipH("파는 상인"), TipKV(who, price ~= "" and price or " ", TIP_WHITE, TIP_GOLD), TipKV(" ", where, TIP_SOFT, TIP_MUTED), TipHint("누르면 지도에 상인 위치") }
			c.vend.t:SetText(who .. (price ~= "" and ("  ·  |cffFFD15F" .. price .. "|r") or ""))
			c.vend.s:SetText(where .. "  ·  누르면 지도에 표시")
			c.vend:Show()
			c:SetHeight(y + 20 + 40)
		elseif rt then
			-- 훈련사: 이름 · 지역 · 비용 (누르면 지도)
			local who = TrainerName(rt.npc, rt.en)
			local where = string.format("%s %.0f, %.0f%s", ZoneName(rt.map), rt.x, rt.y, rt.inside and " (던전 안)" or "")
			c.vend.icon:SetTexture(Ink.icon("NpcTrainer"))
			c.vend.x = { rt.npc, rt.map, rt.x, rt.y, label = "훈련사" }
			c.vend.tip = { cur[3], TipH("가르치는 훈련사"), TipKV(who, rcost or " ", TIP_WHITE, TIP_GOLD), TipKV(" ", where, TIP_SOFT, TIP_MUTED),
				TRAINER_NOTE[rt.npc] and TipT(TRAINER_NOTE[rt.npc], TIP_GOLD) or "", TipHint("누르면 지도에 훈련사 위치") }
			c.vend.t:SetText(who .. (rcost and ("  ·  |cffFFD15F" .. rcost .. "|r") or ""))
			c.vend.s:SetText(where .. "  ·  누르면 지도에 표시")
			c.vend:Show()
			c:SetHeight(y + 20 + 40)
		else
			c.vend:Hide()
			c:SetHeight(y + 20)
		end
		c:Show()
	elseif skill >= (max > 0 and max or 300) then
		-- 이 단계 끝: 다음 단계를 어디서 배우는지 (누르면 지도)
		local nx = prof and max < 300 and M.NextRank(prof, max)
		c.k:SetText(max >= 300 and "숙련도 최대" or ("숙련도 " .. max .. " · 이 단계 끝"))
		c.icon:SetTexture(nx and M.RankIcon(nx) or 134400)
		c.icon:SetDesaturated(false)
		for _, m in ipairs(c.mats) do m:Hide() end
		c.cost:SetText(""); c.src:SetText("")
		if nx then
			local _, where = M.NextRankText(nx)
			local lv = UnitLevel("player") or 1
			local costT = M.RankCostText(nx)
			c.name:SetText(nx.name .. " 단계를 배워야 " .. nx.cap .. "까지 올라가요")
			c.sub:SetText((lv < nx.lvl and ("|cffFF6B5E" .. nx.lvl .. "레벨부터|r") or (nx.lvl .. "레벨 · 숙련도 " .. nx.skill))
				.. (costT ~= "" and ("  ·  |cffFFD15F" .. costT .. "|r") or ""))
			TipTarget(c.iconHit, nx.book, nil, nil)
			local road = M.Roadmap(prof, max)
			local later = {}
			for i = 2, #road do later[#later + 1] = road[i] end
			c.iconHit.tip = RankTip(nx, nil, later)
			local sp = nx.spots[1]
			if sp then
				c.vend.icon:SetTexture(Ink.icon(nx.book and "NpcVendor" or "NpcTrainer"))
				c.vend.x = { sp.npc, sp.map, sp.x, sp.y, label = "훈련사" }
				c.vend.tip = c.iconHit.tip
				c.vend.t:SetText(where .. (costT ~= "" and ("  ·  |cffFFD15F" .. costT .. "|r") or ""))
				c.vend.s:SetText((TRAINER_NOTE[sp.npc] or (#nx.spots > 1 and ("그 밖에 " .. (#nx.spots - 1) .. "곳") or "")) .. "  ·  누르면 지도에 표시")
				c.vend:Show()
				c:SetHeight(70 + 40)
			else
				c.vend:Hide()
				c:SetHeight(70)
			end
		elseif max >= 300 and spec and not (spec.learned and (not spec.master or spec.master.learned)) then
			-- 단계는 끝 · 심화 과정(또는 무기제작 대가)이 남았다: 추천 과정과 배우는 곳
			local grp = (spec.learned and spec.master) or spec
			local def, isMaster = grp.def, grp == spec.master
			local s = grp.best or def.list[1]
			local _, why = Fit(s, MyClass())
			local shorts = {}
			for _, v in ipairs(def.list) do shorts[#shorts + 1] = SpecShortC(v) end
			local ok, stateT = SpecReady(def, skill, lv)
			c.k:SetText("숙련도 최대 · 다음은 " .. (isMaster and "대가 과정" or "심화 과정"))
			c.icon:SetTexture(SpellIcon(s.spell) or ProfIcon(prof))
			c.name:SetText((isMaster and "대가 과정: " or "심화 과정: ") .. table.concat(shorts, " · "))
			c.sub:SetText((grp.best and Short(24, "|cffFFD15F추천|r " .. SpecShortC(s), why) or (def.advice or def.one or "")) .. (ok and "" or ("  ·  " .. stateT)))
			local tip, pin = SpecTip(prof, s, def, isMaster, true)
			TipTarget(c.iconHit, nil, nil, nil)
			c.iconHit.tip = tip
			local st = s.start and PickWho(s.start)
			local w = (st and st.map) and st or PickWho(s.who)
			if pin and w and w.map then
				c.vend.icon:SetTexture(Ink.icon("NpcTrainer"))
				c.vend.x, c.vend.tip = pin, tip
				c.vend.t:SetText((w == st and "|cff8A9099퀘스트 시작|r  " or "") .. TrainerName(w.npc, w.en) .. "  ·  " .. SpecNameC(s))
				c.vend.s:SetText(ZoneName(w.map) .. string.format(" %.0f, %.0f", w.x, w.y) .. "  ·  누르면 지도에 표시")
				c.vend:Show()
				c:SetHeight(70 + 40)
			else
				c.vend:Hide()
				c:SetHeight(70)
			end
		else
			if max >= 300 then
				c.name:SetText(spec and spec.learned and (SpecNameC(spec.learned) .. (spec.master and spec.master.learned and (" · " .. SpecNameC(spec.master.learned)) or "")) or "모든 단계를 다 배웠어요")
				c.sub:SetText(spec and "심화 과정까지 모두 배움 · 남은 건 상인 · 드랍 제조법" or "심화 과정 없는 기술 · 남은 건 상인 · 드랍 제조법")
			else
				c.name:SetText("다음 단계 훈련사에게 배우면 계속 올릴 수 있어요")
				c.sub:SetText("")
			end
			c.vend:Hide()
			c:SetHeight(70)
		end
	else
		c.k:SetText("빠른 레벨링 경로가 없는 전문기술")
		c.icon:SetTexture(134400)
		c.name:SetText(name)
		c.sub:SetText("아래 주황 · 노랑 제조법으로 올리세요")
		for _, m in ipairs(c.mats) do m:Hide() end
		c.cost:SetText(""); c.src:SetText("")
		c.vend:Hide()
		c:SetHeight(70)
	end
	self:PaintList(p, name, prof, skill, max, route, rkey, known, byName, curI, capped, lv, spec)
end

-------------------------------------------------------------------------------
-- 주요 제조법 (ProfessionPicks.lua): 많이 쓰이거나 만들어 팔 만한 것 · 도안 얻는 곳 · 재료비와 예상 이익
--  이익 = 경매장 판매가(수수료 5% 뺌) - 재료비 · 가격은 FOA 경매장 가격(가격 스캔 · 둘러본 값)
--  값을 모르는 재료가 있으면 이익을 짐작하지 않는다 (상인이 파는 실은 상인 값으로)
-------------------------------------------------------------------------------
local PICK_SRC = { v = "상인", t = "훈련사", d = "드랍", w = "무작위 드랍", q = "퀘스트" }
local Q_HEX = { [1] = "FFFFFF", [2] = "1EFF00", [3] = "0070DD", [4] = "A335EE", [5] = "FF8000" }
local function UnitCost(id)
	local p = Price(nil, id)
	if p then return p, false end
	if (ns.PROF_VENDOR_REAGENT or {})[id] and C_Item.GetItemInfo then
		local sell = select(11, C_Item.GetItemInfo(id))
		if type(sell) == "number" and sell > 0 then return sell * 4, true end   -- 상인 값은 보통 되파는 값의 4배
	end
end
local function CraftCost(r)
	local cost, miss = 0, 0
	for _, x in ipairs(r or {}) do
		local u = UnitCost(x[1])
		if u then cost = cost + u * x[2] else miss = miss + 1 end
	end
	return cost, miss
end
-- 이익 · 재료비 · 값 모르는 재료 수 · 판매가 · 귀속(팔 수 없음)
local function PickProfit(item, r)
	local cost, miss = CraftCost(r)
	local bind = C_Item.GetItemInfo and select(14, C_Item.GetItemInfo(item))
	local sale = Price(nil, item)
	if bind == 1 then return nil, cost, miss, sale, true end
	if sale and miss == 0 then return math.floor(sale * 0.95 - cost), cost, miss, sale end
	return nil, cost, miss, sale
end
-- 짧은 골드 (목록 오른쪽)
local function Gold(c)
	c = math.abs(c or 0)
	if c >= 1000000 then return string.format("%dg", math.floor(c / 10000)) end
	if c >= 10000 then
		local g, sv = math.floor(c / 10000), math.floor(c / 100) % 100
		return sv > 0 and string.format("%dg %ds", g, sv) or string.format("%dg", g)
	end
	return string.format("%ds", math.max(1, math.floor(c / 100)))
end
local function ProfitText(v)
	if not v then return nil end
	return v >= 0 and ("|cff6FD39A+" .. Gold(v) .. "|r") or ("|cffFF6B5E-" .. Gold(v) .. "|r")
end
local function PickItemName(item, spell)
	local n = C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
	if not n then ItemIcon(item); n = spell and SpellName(spell) end
	local q = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(item)
	return n and (Q_HEX[q] and ("|cff" .. Q_HEX[q] .. n .. "|r") or n) or "…", n
end
local function ReagentName(id)
	local n = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if not n then ItemIcon(id) end
	return n or "…"
end
-- 내 진영 자리 하나 (가까운 곳)
local function PickSpot(who)
	local fac, best, bd = MyFac(), nil, nil
	for _, w in ipairs(who or {}) do
		if w[2] == 0 or w[2] == fac then
			local d = (w[3] or 0) > 0 and Dist(w[3], w[4], w[5]) or 9e9
			if not best or d < bd then best, bd = w, d end
		end
	end
	return best
end
local function SpotName(w, src)
	return TrainerName(w[1], (w[6] and w[6] ~= "") and w[6] or (src == "t" and "훈련사" or (src == "q" and "퀘스트 NPC" or "상인")))
end
-- 평판 이름 · 단계 (게임 글자) · 지금 단계가 되는지
local function RepText(fid, need)
	local name, have
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, d = pcall(C_Reputation.GetFactionDataByID, fid)
		if ok and type(d) == "table" then name, have = d.name, d.reaction end
	end
	if not name and GetFactionInfoByID then
		local ok, n, _, st = pcall(GetFactionInfoByID, fid)
		if ok then name, have = n, st end
	end
	local id = need >= 42000 and 8 or (need >= 21000 and 7 or (need >= 9000 and 6 or (need >= 3000 and 5 or 4)))
	return (name or "평판") .. " " .. (_G["FACTION_STANDING_LABEL" .. id] or ""), have and have >= id
end
M.RepText = RepText
local function CostText(c)
	if not c then return end
	if c[1] == "i" then return ReagentName(c[2]) .. " " .. c[3] .. "개" end
	if c[1] == "c" then
		local nm
		if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
			local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, c[2])
			nm = ok and type(info) == "table" and info.name or nil
		end
		return (nm or "전문기술 화폐") .. " " .. c[3] .. "개"
	end
end
-- 도안 얻는 곳 줄들 (툴팁)
local function PickSourceLines(t, e, w, learned, skill)
	t[#t + 1] = TipH("도안 얻는 곳")
	t[#t + 1] = TipKV("필요 숙련도", learned and "|cff6FD39A배움|r" or (skill < (e.la or 0) and ("|cffFF6B5E" .. e.la .. "|r") or tostring(e.la or 0)), TIP_SOFT, TIP_WHITE)
	if w then
		t[#t + 1] = TipKV(e.src == "d" and "떨어뜨리는 몹" or (PICK_SRC[e.src] or ""), SpotName(w, e.src) .. ((e.src == "d" and #e.who > 1) and (" 외 " .. (#e.who - 1)) or ""), TIP_SOFT, TIP_WHITE)
		if (w[3] or 0) > 0 then t[#t + 1] = TipKV(" ", string.format("%s  %.0f, %.0f", ZoneName(w[3]), w[4], w[5]), TIP_SOFT, TIP_MUTED) end
		local c = not e.costs and w[7]   -- 레벨업 장비 묶음은 숙련마다 값이 달라 아래에 따로
		if c then
			t[#t + 1] = TipKV("값", CostText(c) or "", TIP_SOFT, TIP_GOLD)
			if c[1] == "c" and c[4] then
				local rt, ok = RepText(c[4], c[5] or 0)
				t[#t + 1] = TipKV("평판", rt, TIP_SOFT, ok and TIP_GREEN or TIP_WHITE)
			end
		end
	end
	if e.lim then t[#t + 1] = TipT("수량 한정: 팔리고 없으면 다시 채워질 때까지 기다려야 해요", TIP_MUTED) end
	if e.src == "w" then t[#t + 1] = TipT("필드 · 던전 몹이 무작위로 떨어뜨려요 · 경매장에서 도안을 찾아보세요", TIP_SOFT) end
	if e.how then t[#t + 1] = TipT(e.how, TIP_SOFT) end
end
local function ReagentLines(t, r, title)
	t[#t + 1] = TipH(title or "재료 (한 번 만들 때)")
	for _, x in ipairs(r or {}) do
		local u, vend = UnitCost(x[1])
		local have = Count(nil, x[1])
		t[#t + 1] = TipKV(ReagentName(x[1]) .. "  |cff8A9099" .. x[2] .. "개" .. (have > 0 and (" · 가방 " .. have) or "") .. "|r",
			u and (Money(u * x[2]) .. (vend and " |cff5E636B상인|r" or "")) or "|cff5E636B값 모름|r", TIP_SOFT, TIP_WHITE)
	end
end
local function MoneyLines(t, profit, cost, miss, sale, bound)
	t[#t + 1] = TipKV("재료비", (cost > 0 and Money(cost) or "") .. (miss > 0 and ("  |cff8A9099값 모르는 재료 " .. miss .. "개|r") or ""), TIP_SOFT, TIP_WHITE)
	if bound then
		t[#t + 1] = TipT("획득 시 귀속 · 경매장에 팔 수 없어요 (직접 쓰거나 주문 제작)", TIP_GOLD)
		return
	end
	t[#t + 1] = TipKV("경매장 판매가", sale and Money(sale) or "|cff5E636B기록 없음|r", TIP_SOFT, TIP_WHITE)
	if profit then
		t[#t + 1] = TipKV("예상 이익", (profit >= 0 and "|cff6FD39A+" or "|cffFF6B5E-") .. Money(math.abs(profit)) .. "|r  |cff5E636B수수료 5% 뺌|r", TIP_SOFT, TIP_WHITE)
	end
end

-- 목록에 넣을 묶음 하나 계산 { e, w, learned, ok, profit, ... }
local function PickState(e, skill, byName, mySpec, cls)
	local w = PickSpot(e.who)
	local st = { e = e, w = w }
	local function known(sid) local nm = SpellName(sid); return (nm and byName[nm]) and true or Knows(sid) end
	st.specOK = (e.spec or 0) == 0 or (mySpec and e.spec == mySpec)
	st.skillOK = skill >= (e.la or 0)
	if e.items then
		local n, best = 0, nil
		for _, it in ipairs(e.items) do
			local kn = known(it[1])
			if kn then n = n + 1 end
			local pr, cost, miss, sale, bound = PickProfit(it[2], it[3])
			if pr and (not best or pr > best.profit) then best = { profit = pr, it = it } end
			it.k, it.p, it.c, it.m, it.s, it.b = kn, pr, cost, miss, sale, bound
		end
		st.nKnown, st.best = n, best
		st.profit = best and best.profit
		st.item = (best and best.it or e.items[1])[2]
		st.mine = e.set == cls
	else
		st.learned = known(e.s)
		st.profit, st.cost, st.miss, st.sale, st.bound = PickProfit(e.i, e.r)
		st.item = e.i
	end
	return st
end

function M:PaintPicks(prof, skill, byName, spec, head, row)
	local list = prof and ns.PROF_PICKS and ns.PROF_PICKS[prof]
	if not list or skill < 200 then return 0 end
	local mySpec = spec and spec.learned and spec.learned.spell
	local cls = MyClass()
	local all = {}
	for i, e in ipairs(list) do
		-- 다른 심화 과정 전용은 뺀다 (아직 안 골랐으면 보여 주되 흐리게)
		if (e.spec or 0) == 0 or not mySpec or e.spec == mySpec then
			local st = PickState(e, skill, byName, mySpec, cls)
			st.order = i - ((st.mine and 100) or 0)
			all[#all + 1] = st
		end
	end
	-- 이익을 아는 것(많이 남는 순) → 나머지는 정리한 순서 (내 직업 세트 먼저)
	table.sort(all, function(a, b)
		local pa, pb = a.profit and a.profit > 0, b.profit and b.profit > 0
		if pa ~= pb then return pa end
		if pa and a.profit ~= b.profit then return a.profit > b.profit end
		return a.order < b.order
	end)
	local limit = Ink.db.profPicksAll and #all or math.min(#all, 10)
	head("주요 제조법", "도안 · 재료비 · 경매장 이익")
	local SPEC = {}
	for _, s in ipairs(spec and spec.def and spec.def.list or {}) do SPEC[s.spell] = s end
	for k = 1, limit do
		local st = all[k]
		local e, w = st.e, st.w
		local dim = not st.skillOK or not st.specOK
		local specTag = ((e.spec or 0) > 0 and SPEC[e.spec] and not mySpec) and ("  " .. SpecShortC(SPEC[e.spec])) or ""
		local where = w and (w[3] or 0) > 0 and ZoneName(w[3]) or nil
		local srcT = PICK_SRC[e.src] or ""
		if e.src == "d" and w then srcT = srcT .. " · " .. SpotName(w, "d") .. (#e.who > 1 and " 등" or "")
		elseif w then srcT = srcT .. " · " .. SpotName(w, e.src) end
		if e.lim then srcT = srcT .. " (한정)" end
		local tip, nameT, icon
		if e.items then
			local n = #e.items
			local label = e.set and (ClassText(e.set) .. " 영웅 세트") or "레벨업 희귀 장비"
			nameT = label .. "  |cff8A9099" .. n .. (e.set and "부위" or "종") .. "|r" .. specTag
			icon = ItemIcon(st.item)
			tip = { label, TipT(e.why or "", TIP_GOLD) }
			PickSourceLines(tip, e, w, st.nKnown == n, skill)
			if e.cost then
				for i = 1, #e.cost, 2 do
					local sid, c = e.cost[i], e.cost[i + 1]
					for _, it in ipairs(e.items) do
						if it[1] == sid then
							local _, pn = PickItemName(it[2], it[1])
							tip[#tip + 1] = TipKV("  " .. (pn or "…") .. " 도안", CostText(c) or "", TIP_MUTED, TIP_GOLD)
							break
						end
					end
				end
			elseif e.set then
				tip[#tip + 1] = TipT("도안 값은 상인 창에서 확인해 주세요 (자료에 아직 없어요)", TIP_MUTED)
			end
			if e.costs then
				for _, la in ipairs({ 210, 225, 235, 250 }) do
					local c = e.costs[la]
					if c then
						local rt, ok = RepText(MyFac() == 1 and 2587 or 2586, c[2])
						tip[#tip + 1] = TipKV("  숙련 " .. la, CostText({ "c", 3402, c[1] }) .. " · " .. rt, TIP_MUTED, ok and TIP_GREEN or TIP_WHITE)
					end
				end
			end
			tip[#tip + 1] = TipH((e.set and "부위" or "종류") .. "마다 예상 이익" .. (st.nKnown > 0 and ("  |cff6FD39A배움 " .. st.nKnown .. "/" .. n .. "|r") or ""))
			local shown, rows = 0, {}
			for _, it in ipairs(e.items) do rows[#rows + 1] = it end
			table.sort(rows, function(a, b)
				if (a.p ~= nil) ~= (b.p ~= nil) then return a.p ~= nil end
				if a.p and b.p and a.p ~= b.p then return a.p > b.p end
				return (a[4] or 0) < (b[4] or 0)
			end)
			for _, it in ipairs(rows) do
				shown = shown + 1
				if shown > 14 then tip[#tip + 1] = TipT("… " .. (#rows - 14) .. "개 더", TIP_MUTED) break end
				local nm = PickItemName(it[2], it[1])
				local r = it.b and "|cffFFD15F귀속|r" or (it.p and ProfitText(it.p) or (it.c and it.c > 0 and it.m == 0 and ("재료 " .. Gold(it.c)) or "|cff5E636B값 모름|r"))
				tip[#tip + 1] = TipKV((it.k and "|cff6FD39A✓|r " or "") .. nm .. (it[4] and ("  |cff8A9099" .. it[4] .. "|r") or ""), r, TIP_SOFT, TIP_WHITE)
			end
			local first = (st.best and st.best.it) or e.items[1]
			ReagentLines(tip, first[3], "재료 (" .. (select(2, PickItemName(first[2], first[1])) or "한 부위") .. ")")
		else
			nameT = PickItemName(e.i, e.s) .. specTag
			icon = ItemIcon(e.i)
			tip = { select(2, PickItemName(e.i, e.s)) or "제조법", TipT(e.why or "", TIP_GOLD) }
			if (e.spec or 0) > 0 and SPEC[e.spec] then tip[#tip + 1] = TipKV("심화 과정", SpecNameC(SPEC[e.spec]), TIP_SOFT, st.specOK and TIP_GREEN or TIP_WHITE) end
			PickSourceLines(tip, e, w, st.learned, skill)
			ReagentLines(tip, e.r)
			MoneyLines(tip, st.profit, st.cost, st.miss, st.sale, st.bound)
		end
		tip[#tip + 1] = TipHint("가격: FOA 경매장 가격 (경매장에서 가격 스캔 · 둘러본 값)" .. (w and (w[3] or 0) > 0 and " · 누르면 지도에 표시" or ""))
		local learned = st.learned or (st.nKnown and st.nKnown > 0)
		local right = ProfitText(st.profit) or (st.bound and "|cffFFD15F귀속|r") or (learned and "|cff6FD39A배움|r") or (not st.skillOK and ("숙련 " .. e.la)) or ""
		local dot = learned and GREEN or ((st.skillOK and st.specOK) and GOLD or nil)
		local r = row(icon or 134400, nameT, Short(22, srcT, where), right, dot, tip, dim)
		r.item = st.item
		if w and (w[3] or 0) > 0 then r.vendor = { w[1], w[3], w[4], w[5], label = PICK_SRC[e.src] == "드랍" and "도안 드랍" or (PICK_SRC[e.src] or "상인") } end
	end
	if #all > 10 then
		local r = row(134400, Ink.db.profPicksAll and "접기" or ("그 밖에 " .. (#all - 10) .. "개 더 보기"), "", "", nil, nil, true)
		r.icon:SetTexture(Ink.icon and Ink.icon("Chevron") or 134400)
		r.onClick = function() Ink.db.profPicksAll = not Ink.db.profPicksAll; M:Paint() end
	end
	return limit
end

-- 목록 (Paint 에서 나눔: 한 함수가 쓰는 바깥 변수가 60개를 넘으면 Lua 5.1 에서 안 열린다)
function M:PaintList(p, name, prof, skill, max, route, rkey, known, byName, curI, capped, lv, spec)
	-- 2) 목록
	for _, r in ipairs(p.rows) do r:Hide() end
	for _, h in ipairs(p.heads) do h:Hide() end
	local y, nr, nh = 0, 0, 0
	local function head(t, rt)
		nh = nh + 1
		local h = p.heads[nh] or Head(p.body)
		p.heads[nh] = h
		h.t:SetText(t); h.r:SetText(rt or "")
		h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:Show()
		y = y + 28
	end
	local function row(icon, nameT, sub, right, dotC, tip, dim)
		nr = nr + 1
		local r = p.rows[nr] or Row(p.body)
		p.rows[nr] = r
		r.icon:SetTexture(icon or 134400)
		r.icon:SetDesaturated(dim and true or false)
		r.name:SetText(nameT)
		r.name:SetTextColor(dim and C.soft[1] or C.text[1], dim and C.soft[2] or C.text[2], dim and C.soft[3] or C.text[3])
		r.sub:SetText(sub or "")
		r.right:SetText(right or "")
		if dotC then r.dot:SetVertexColor(dotC[1], dotC[2], dotC[3]); r.dot:Show() else r.dot:Hide() end
		r.tip = tip
		r.vendor, r.onClick = nil, nil
		r.item, r.link, r.spell = nil, nil, nil
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:Show()
		y = y + ROW + 2
		return r
	end
	-- 단계 로드맵: 남은 단계 전부 (숙련도가 모자라도 "몇에는 어디로" 를 미리 · 이미 배운 단계는 뺀다)
	if prof and max > 0 and max < 300 then
		local road = M.Roadmap(prof, max)
		if #road > 0 then
			head("단계 로드맵", "남은 단계 · 누르면 지도")
			for i, nx in ipairs(road) do
				local sp = nx.spots[1]
				local costT = M.RankCostText(nx)
				local costN = (not nx.book and not nx.quest) and costT:gsub("%s+$", "") or ""
				local ready = lv >= nx.lvl and skill >= nx.skill
				local near = i == 1 and skill >= max - 25
				local state = ready and "|cff6FD39A지금 배움|r" or (lv < nx.lvl and ("|cffFF6B5E" .. nx.lvl .. "레벨|r") or ("숙련도 " .. nx.skill))
				local how = nx.book and "책" or (nx.quest and "퀘스트" or nil)
				local tip = RankTip(nx)
				local sub = sp and Short(20, TrainerName(sp.npc, sp.en), ZoneName(sp.map)) or "배우는 곳 정보 없음"
				row(M.RankIcon(nx), nx.name .. " 단계  |cff8A9099" .. nx.cap .. "까지" .. (how and (" · " .. how) or "") .. (costN ~= "" and (" · " .. costN) or "") .. "|r",
					sub, state, (ready or near) and (ready and GREEN or GOLD) or nil, tip, not ready and i > 1)
				if sp then p.rows[nr].vendor = { sp.npc, sp.map, sp.x, sp.y, label = "훈련사" } end
				if nx.book then p.rows[nr].item = nx.book end
			end
			y = y + 6
		end
	end
	-- 심화 과정: 단계와 따로 (가죽세공 용비늘 · 원소 · 전통 / 대장기술 방어구 · 무기 → 대가 / 기계공학 노움 · 고블린)
	local function specSection()
		if not spec then return end
		local cls = MyClass()
		local function group(grp, isMaster)
			local def = grp.def
			local ok, stateT = SpecReady(def, skill, lv)
			head(isMaster and "대가 과정 · 무기제작 다음" or def.group,
				grp.learned and ("배움: " .. (grp.learned.short or grp.learned.name)) or string.format("%d레벨 · 숙련도 %d", def.lvl, def.skill))
			-- 내 직업 추천 한 줄 (안 배웠을 때)
			if not grp.learned then
				local s = grp.best or def.list[1]
				local _, why, long = Fit(s, cls)
				local _, pin = SpecTip(prof, s, def, isMaster)
				local tip = { ClassText(cls) .. "에게 맞는 " .. (isMaster and "대가 과정" or "심화 과정") }
				if grp.best then
					tip[#tip + 1] = TipKV("추천", SpecNameC(s) .. (#grp.alt > 0 and (" · " .. SpecShortC(grp.alt[1])) or ""), TIP_SOFT, TIP_GOLD)
					if long then tip[#tip + 1] = long end
				end
				FitTable(def, tip)
				if pin then tip[#tip + 1] = TipHint("누르면 지도에 " .. (s.short or s.name) .. " 위치") end
				if grp.best then
					row(SpellIcon(s.spell) or ProfIcon(prof), ClassText(cls) .. " 추천  " .. SpecNameC(s) .. (#grp.alt > 0 and (" · " .. SpecShortC(grp.alt[1])) or ""),
						why or "", "|cffFFD15F추천|r", GOLD, tip)
				else
					row(ProfIcon(prof), "고르는 법", def.advice or def.one or "", "", nil, tip)
				end
				p.rows[nr].vendor = pin
			end
			for _, s in ipairs(def.list) do
				local tip, pin = SpecTip(prof, s, def, isMaster, not isMaster and not grp.learned)
				local learned = grp.learned == s
				local other = grp.learned and not learned
				local sc = Fit(s, cls)
				local w = PickWho(s.who)
				local st = (not grp.learned) and s.start and PickWho(s.start) or nil
				local who = (st and st.map) and st or w
				local sub = who and Short(20, (who == st and "시작 " or "") .. TrainerName(who.npc, who.en), who.map and ZoneName(who.map) or nil) or ""
				local right = learned and "|cff6FD39A배움|r" or (other and "다른 과정" or stateT)
				local rec = not def.advice and sc >= 2 and not grp.learned
				local dot = learned and GREEN or ((rec and ok) and GOLD or nil)
				row(SpellIcon(s.spell) or ProfIcon(prof), (other and SpecName(s) or SpecNameC(s)) .. (rec and "  |cffFFD15F추천|r" or ""), sub, right, dot, tip, other or (not grp.learned and not ok))
				p.rows[nr].vendor = pin
			end
			y = y + 6
		end
		group(spec, false)
		if spec.master then group(spec.master, true) end
	end
	local specNear = spec and (spec.learned or max >= 300 or skill >= (spec.def.skill or 0) - 50)
	if specNear then specSection() end
	-- 주요 제조법: 많이 쓰이거나 만들어 팔 만한 것 (도안 얻는 곳 · 재료비 · 경매장 이익)
	if self:PaintPicks(prof, skill, byName, spec, head, row) > 0 then y = y + 6 end
	-- 숙련이 오르는 아는 제조법
	local up = {}
	for _, r in ipairs(known) do if r.diff <= 1 then up[#up + 1] = r end end
	table.sort(up, function(a, b)
		if a.diff ~= b.diff then return a.diff < b.diff end
		if (a.avail > 0) ~= (b.avail > 0) then return a.avail > 0 end
		return a.name < b.name
	end)
	if #up > 0 then
		head("숙련도가 오르는 제조법", "주황 · 노랑")
		for i = 1, math.min(8, #up) do
			local r = up[i]
			local mats = {}
			for _, rg in ipairs(r.reagents) do mats[#mats + 1] = RgName(rg) .. " " .. rg.need end
			local tip = { r.name, TipT(r.diff == 0 and "주황 · 만들 때마다 숙련도 +1" or "노랑 · 대부분 숙련도 +1", DIFF_C[r.diff]), TipH("재료 (한 번에)") }
			for _, rg in ipairs(r.reagents) do tip[#tip + 1] = TipKV(RgName(rg), rg.need .. "개", TIP_SOFT, TIP_WHITE) end
			row(r.icon, r.name, table.concat(mats, " · "), r.avail > 0 and ("|cff6FD39A" .. r.avail .. "개 가능|r") or "재료 부족", DIFF_C[r.diff], tip, r.avail == 0)
			p.rows[nr].link = r.link
		end
		y = y + 6
	end
	-- 다음 구간
	if route and curI then
		local shown = 0
		for i = (capped and curI or curI + 1), #route do
			local s = route[i]
			if s[4] > 0 then
				if shown == 0 then head("다음 구간", rkey and ("wowf.io · " .. rkey) or nil) end
				shown = shown + 1
				local kr = byName[s[3]]
				local mats = {}
				for _, m in ipairs(s[5]) do mats[#mats + 1] = m[1] .. " " .. m[2] end
				local vx = (not kr) and PickVendor(VendorIndex(name)[s[3]])
				local rt, rcost
				if not kr and not vx then rt, rcost = M.RouteTrainer(prof, s[3], s[6]) end
				local tip = { s[3], TipKV("숙련도", s[1] .. " → " .. s[2], TIP_SOFT, TIP_WHITE), TipKV("만들기", s[4] .. "번", TIP_SOFT, TIP_WHITE), TipH("재료 (구간 전체)") }
				for _, m in ipairs(s[5]) do tip[#tip + 1] = TipKV(m[1], m[2] .. "개" .. (m[3] and m[3] ~= "" and ("  |cff8A9099" .. m[3] .. "|r") or ""), TIP_SOFT, TIP_WHITE) end
				if kr then
					tip[#tip + 1] = TipH("이미 배운 제조법")
				elseif vx then
					local who, where, price = VendorText(vx)
					tip[#tip + 1] = TipH("파는 상인")
					tip[#tip + 1] = TipKV(who, price ~= "" and price or " ", TIP_WHITE, TIP_GOLD)
					tip[#tip + 1] = TipKV(" ", where, TIP_SOFT, TIP_MUTED)
					tip[#tip + 1] = TipHint("누르면 지도에 상인 위치")
				elseif rt then
					tip[#tip + 1] = TipH("가르치는 훈련사")
					tip[#tip + 1] = TipKV(TrainerName(rt.npc, rt.en), rcost or " ", TIP_WHITE, TIP_GOLD)
					tip[#tip + 1] = TipKV(" ", string.format("%s  %.0f, %.0f", ZoneName(rt.map), rt.x, rt.y), TIP_SOFT, TIP_MUTED)
					if TRAINER_NOTE[rt.npc] then tip[#tip + 1] = TipT(TRAINER_NOTE[rt.npc], TIP_GOLD) end
					tip[#tip + 1] = TipHint("누르면 지도에 훈련사 위치")
				else
					tip[#tip + 1] = TipH("배우는 곳")
					tip[#tip + 1] = TipT(s[6] or "?", TIP_WHITE)
				end
				local ssid = (not kr or not kr.link) and CraftSpellByName(s[3]) or nil
				local sitem = CraftItem(ssid) or (not kr and ItemByName(s[3])) or nil
				local sub = string.format("%d → %d  ·  %d번", s[1], s[2], s[4])
				if rt then sub = Short(21, sub, TrainerName(rt.npc, rt.en)) end
				row((kr and kr.icon) or (ssid and CraftIcon(ssid)) or (sitem and ItemIcon(sitem)) or 134400, s[3],
					sub, kr and "|cff6FD39A배움|r" or (rt and (rcost or "훈련사") or (s[6] or "")), nil, tip, false)
				p.rows[nr].vendor = vx or (rt and { rt.npc, rt.map, rt.x, rt.y, label = "훈련사" }) or nil
				p.rows[nr].link = kr and kr.link or nil
				p.rows[nr].item = (not (kr and kr.link)) and sitem or nil
				p.rows[nr].spell = (not sitem and not (kr and kr.link)) and ssid or nil
				if shown >= 4 then break end
			end
		end
		if shown > 0 then y = y + 6 end
	end
	-- 상인에게 사는 제조법 (지금 숙련 ± 범위 · 안 배운 것 · 내 진영)
	do
		local list = {}
		for craft, v in pairs(VendorIndex(name)) do
			if not byName[craft] and (v.req or 0) <= skill + 20 and (v.req or 0) >= skill - 40 then
				local vx = PickVendor(v)
				if vx then list[#list + 1] = { craft = craft, v = v, x = vx } end
			end
		end
		table.sort(list, function(a, b) return (a.v.req or 0) < (b.v.req or 0) end)
		if #list > 0 then
			head("상인에게 사는 제조법", "누르면 지도")
			for i = 1, math.min(6, #list) do
				local e = list[i]
				local who, where, price = VendorText(e.x)
				local icon = CraftIcon(e.v.spell) or ItemIcon(e.v.item) or 134939
				local req = e.v.req or 0
				row(icon, e.craft, Short(20, who, where), price ~= "" and price or ("숙련도 " .. req), req <= skill and GREEN or nil,
					{ e.craft, TipKV("필요 숙련도", req, TIP_SOFT, req <= skill and TIP_GREEN or TIP_WHITE), TipH("파는 상인"),
						TipKV(who, price ~= "" and price or " ", TIP_WHITE, TIP_GOLD), TipKV(" ", where, TIP_SOFT, TIP_MUTED), TipHint("누르면 지도에 상인 위치") }, req > skill)
				p.rows[nr].vendor = e.x
				p.rows[nr].item = e.v.item   -- 제조법 툴팁: 만들어지는 아이템까지 같이 나온다
			end
			y = y + 6
		end
	end
	-- 훈련사에게 배울 제조법: 훈련사 자료(단계마다 가르치는 제조법이 다름) + 훈련사 창에서 본 비용
	--  예전엔 마지막으로 연 훈련사 목록만 써서, 수습 훈련사를 열면 수습 제조법에서 멈췄다
	local costByName, tr = {}, nil
	for k, v in pairs(Ink.db.profTrainer or {}) do
		if name and (k == name or k:find(name, 1, true) or name:find(k, 1, true)) then
			tr = v
			for _, e in ipairs(v.list or {}) do if e[6] then costByName[e[2]] = e[6] end end
		end
	end
	if prof then
		local can = {}
		for sid, e in pairs(TrainerRecipesC(prof)) do
			local nm = SpellName(sid)
			local known = (nm and byName[nm]) or Knows(sid)
			-- 심화 과정 주문은 '심화 과정' 칸에서 · 심화 과정 훈련사의 제조법은 그 과정을 배운 경우만
			if nm and not known and not IsSpecSpell(sid) and e.la <= skill + 25 and e.la >= skill - 40 and e.la <= (max > 0 and max or 300) then
				local who = {}
				for _, t in ipairs(e.who) do
					if not SpecLocked(t) then t.d = t.d or Dist(t.map, t.x, t.y); who[#who + 1] = t end
				end
				if #who > 0 then
					table.sort(who, function(a, b) return a.d < b.d end)
					can[#can + 1] = { sid = sid, name = nm, la = e.la, who = who }
				end
			end
		end
		table.sort(can, function(a, b) if a.la ~= b.la then return a.la < b.la end return a.name < b.name end)
		if #can > 0 then
			head("훈련사에게 배울 제조법", "숙련도 기준 · 누르면 지도")
			for i = 1, math.min(10, #can) do
				local e = can[i]
				local t = e.who[1]
				local who = TrainerName(t.npc, t.en)
				local icon = CraftIcon(e.sid) or 134939
				local tip = { e.name, TipKV("필요 숙련도", e.la, TIP_SOFT, e.la <= skill and TIP_GREEN or TIP_WHITE) }
				if costByName[e.name] then tip[#tip + 1] = TipKV("비용", Money(costByName[e.name]), TIP_SOFT, TIP_GOLD) end
				tip[#tip + 1] = TipH("배우는 곳")
				for k = 1, math.min(3, #e.who) do WhoLines(tip, k == 1 and "가까운 곳" or "그 밖에", e.who[k]) end
				tip[#tip + 1] = TipHint("누르면 지도에 훈련사 위치")
				row(icon, e.name, Short(21, "숙련도 " .. e.la, who, ZoneName(t.map)),
					costByName[e.name] and Money(costByName[e.name]) or (e.la <= skill and "|cff6FD39A지금 배움|r" or ""), e.la <= skill and GREEN or nil, tip, e.la > skill)
				p.rows[nr].vendor = { t.npc, t.map, t.x, t.y, label = "훈련사" }
				p.rows[nr].item = CraftItem(e.sid)
				p.rows[nr].spell = not p.rows[nr].item and e.sid or nil
			end
			y = y + 6
		end
	end
	-- 심화 과정이 아직 먼 숙련도면 맨 아래에 (미리 보기)
	if spec and not specNear then specSection() end
	p.body:SetHeight(math.max(10, y))
	p.foot:SetText((route and "빠른 레벨링: wowf.io · " or "") .. "훈련사: AllTheThings" .. (tr and " · 비용 기억됨" or " · 훈련사 창을 열면 비용도"))
	M.RetryNames(self)
end

function M:Hook()
	for _, n in ipairs({ "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }) do
		local f = _G[n]
		if f and not f.foaProfHooked then
			f.foaProfHooked = true
			f:HookScript("OnShow", function() M.nameRetry = 0; C_Timer.After(0.2, function() pcall(M.Paint, M) end) end)
			f:HookScript("OnHide", function() C_Timer.After(0, function() if not Host() and M.panel then M.panel:Hide() end end) end)
		end
	end
end

-- 숙련이 단계 한도에 가까워지면 다음 단계를 배우는 곳을 채팅으로 한 번 알려 준다
--  (채집 기술은 창이 없어서 이게 유일한 안내 · 한도마다 캐릭터당 한 번)
local function SkillMax(id)
	local SI = C_SkillInfo
	if SI and SI.GetSkillLineInfoByID then
		local ok, d = pcall(SI.GetSkillLineInfoByID, id)
		if ok and type(d) == "table" and not d.isHeader and (d.rank or 0) > 0 then return d.rank, d.maxRank end
	end
end
function M:CapCheck()
	if Ink.db.profCapNote == false then return end
	local cdb = Ink.cdb
	if not cdb then return end
	cdb.profCapNote = cdb.profCapNote or {}
	local lvl = UnitLevel("player") or 1
	for name, id in pairs(PROF_ID) do
		local rank, max = SkillMax(id)
		if not rank then rank, max = SkillByName(name) end
		-- 심화 과정 조건이 막 채워졌으면 한 번: 어떤 과정이 있고 내 직업엔 뭐가 맞는지 · 어디서
		local sp = rank and M.SpecState(id, rank)
		if sp then
			local grp = (sp.learned and sp.master) or ((not sp.learned) and sp) or nil
			if grp and grp.lvlOK and grp.skillOK and not grp.learned then
				local key = id .. ":spec:" .. (grp == sp.master and "m" or "s")
				if not cdb.profCapNote[key] then
					cdb.profCapNote[key] = time()
					local def = grp.def
					local s = grp.best or def.list[1]
					local shorts = {}
					for _, v in ipairs(def.list) do shorts[#shorts + 1] = SpecShortC(v) end
					local st = s.start and PickWho(s.start)
					local w = (st and st.map) and st or PickWho(s.who)
					print(string.format("|cffFFF468FOA|r %s %d · %s을 배울 수 있어요 |cff8A9099(%s · %s)|r", name, rank,
						grp == sp.master and "무기제작 대가 과정" or "심화 과정", table.concat(shorts, " · "), def.one or ""))
					print(string.format("      %s%s → %s  |cff8A9099· 전문기술 창에서 자세히|r", grp.best and "|cffFFD15F추천|r " or "", SpecNameC(s), WhoText(w)))
				end
			end
		end
		if rank and max and max < 300 and rank >= max - 10 then
			local key = id .. ":" .. max
			if not cdb.profCapNote[key] then
				local info = M.NextRank(id, max)
				local head, where = M.NextRankText(info)
				if head then
					cdb.profCapNote[key] = time()
					local need = {}
					if (info.lvl or 0) > lvl then need[#need + 1] = info.lvl .. "레벨 필요" end
					local sp = info.spots[1]
					if sp and TRAINER_NOTE[sp.npc] then need[#need + 1] = TRAINER_NOTE[sp.npc] end
					local costT = M.RankCostText(info)
					print(string.format("|cffFFF468FOA|r %s %d/%d · 곧 막혀요 → 다음은 %s", name, rank, max, head))
					print(string.format("      %s%s%s", where,
						costT ~= "" and ("  |cffFFD15F" .. costT .. "|r") or "",
						#need > 0 and ("  |cffFF8A80" .. table.concat(need, ", ") .. "|r") or ""))
				end
			end
		end
	end
end

function M:Init()
	if not FOREVER then return end
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE",
		"SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "TRADE_SKILL_DATA_SOURCE_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do pcall(e.RegisterEvent, e, ev) end
	local pending, capPending
	e:SetScript("OnEvent", function(_, event, a1)
		if event == "GET_ITEM_INFO_RECEIVED" then
			-- 패널이 기다리던 아이템(그림)만 다시 그린다
			if not (a1 and waitItems[a1]) then return end
			waitItems[a1] = nil
		end
		pcall(M.Hook, M)
		if event == "ADDON_LOADED" then return end
		if event == "SKILL_LINES_CHANGED" and not capPending then
			capPending = true
			C_Timer.After(2, function() capPending = nil; pcall(M.CapCheck, M) end)
		end
		if pending then return end
		pending = true
		C_Timer.After(0.3, function()
			pending = nil
			if Host() then pcall(M.Paint, M) end
		end)
	end)
	pcall(M.Hook, M)
	C_Timer.After(8, function() pcall(M.CapCheck, M) end)
end
