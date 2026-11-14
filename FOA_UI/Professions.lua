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
local function VendorText(x)
	if not x then return end
	local who = NpcName(x[1]) or "상인"
	local zone = x[2] > 0 and C_Map.GetMapInfo and (C_Map.GetMapInfo(x[2]) or {}).name or nil
	local where = zone and string.format("%s %.0f, %.0f", zone, x[3], x[4]) or ""
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

local function TrainerName(npc, en)
	local Q = Ink.modules.QuestMap
	local n = Q and Q.GiverName and Q:GiverName(npc)
	if not n then
		local s = Ink.db.npcSpot and Ink.db.npcSpot[npc]
		n = type(s) == "table" and s[4] or nil
	end
	return n or (en ~= "" and en) or "훈련사"
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

-- 다음 단계를 배우는 곳 (가까운 순) · 보조 기술은 책 · 퀘스트
function M.NextRank(prof, max)
	local cur = RankOfMax(max)
	if cur >= 4 then return end
	local nr = cur + 1
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
	return { rank = nr, name = RANK_NAME[nr], cap = RANK_CAP[nr], lvl = req[1], skill = req[2], spots = spots, book = sec and sec.book, quest = sec and sec.quest,
		cost = cost, costSeen = seen, svc = (not sec and PROF_NAME[prof]) and (SERVICE_NAME[nr] .. " " .. PROF_NAME[prof]) or nil, spell = rankSpell }
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
		for i, l in ipairs(self.tip) do
			if i == 1 then
				if not rich then Ink.TipLine(GameTooltip, l, 1, 1, 1) end
			elseif l ~= "" then
				GameTooltip:AddLine(l, 0.75, 0.77, 0.8, true)
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
	r:SetScript("OnClick", function(self) if self.vendor then Waypoint(self.vendor) end end)
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
	c.vend:SetHeight(28)
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
	c.vend.t:SetPoint("TOPLEFT", c.vend.icon, "TOPRIGHT", 8, 6)
	c.vend.t:SetPoint("RIGHT", -8, 0)
	c.vend.s = Ink:Text(c.vend, F.sans, 9, C.muted, "LEFT")
	c.vend.s:SetPoint("BOTTOMLEFT", c.vend.icon, "BOTTOMRIGHT", 8, -6)
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
	local y, nr, nh = 0, 0, 0
	local mine = MyProfs()
	if #mine > 0 then
		nh = 1
		local h = p.heads[1] or Head(p.body)
		p.heads[1] = h
		h.t:SetText("내 전문기술"); h.r:SetText("누르면 다음 단계 훈련사")
		h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:Show()
		y = y + 28
		local lv = UnitLevel("player") or 1
		for _, e in ipairs(mine) do
			nr = nr + 1
			local r = p.rows[nr] or Row(p.body)
			p.rows[nr] = r
			r.icon:SetTexture(ProfIcon(e.prof))
			r.icon:SetDesaturated(false)
			r.name:SetText(e.name .. "  |cff8A9099" .. e.rank .. " / " .. e.max .. "|r")
			r.name:SetTextColor(C.text[1], C.text[2], C.text[3])
			r.vendor, r.item, r.link, r.spell, r.tip = nil, nil, nil, nil, nil
			local nx = e.max < 300 and M.NextRank(e.prof, e.max) or nil
			if not nx then
				r.sub:SetText("모든 단계를 배웠어요")
				r.right:SetText("")
				r.dot:Hide()
			else
				local sp = nx.spots[1]
				local how = nx.book and "책" or (nx.quest and "퀘스트" or (sp and TrainerName(sp.npc, sp.en) or "훈련사"))
				r.sub:SetText(nx.name .. " 단계 · " .. how .. (sp and (" · " .. ZoneName(sp.map)) or ""))
				local ready = lv >= nx.lvl and e.rank >= nx.skill
				local costT = M.RankCostText(nx)
				r.right:SetText(ready and ("|cff6FD39A지금 배움|r") or (lv < nx.lvl and ("|cffFF6B5E" .. nx.lvl .. "레벨|r") or ("숙련도 " .. nx.skill)))
				if ready then r.dot:SetVertexColor(GREEN[1], GREEN[2], GREEN[3]); r.dot:Show() else r.dot:Hide() end
				local _, where = M.NextRankText(nx)
				r.tip = { e.name .. " · " .. nx.name .. " 단계 (" .. nx.cap .. "까지)", where, nx.lvl .. "레벨 · 숙련도 " .. nx.skill .. " 필요",
					costT ~= "" and ("비용: " .. costT .. (nx.cost and not nx.costSeen and " (기본 값 · 평판이 높으면 싸져요)" or "")) or "",
					nx.svc and ("훈련사 창에서 '" .. nx.svc .. "' 배우기") or "",
					sp and TRAINER_NOTE[sp.npc] or "", sp and "누르면 지도에 표시" or "" }
				if sp then r.vendor = { sp.npc, sp.map, sp.x, sp.y, label = "훈련사" } end
				if nx.book then r.item = nx.book end
			end
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:Show()
			y = y + ROW + 2
		end
	end
	p.body:SetHeight(math.max(10, y))
	p.foot:SetText("단계 · 훈련사: AllTheThings")
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
		c.iconHit.tip = { cur[3], string.format("숙련도 %d → %d 구간", cur[1], cur[2]) }
		c.name:SetText(cur[3])
		c.sub:SetText(string.format("약 %d번 더 만들기", left) .. (kr and kr.avail > 0 and ("  ·  |cff6FD39A지금 %d개 가능|r"):format(kr.avail) or "") .. (kr and "" or "  ·  |cffFFB75A아직 안 배움|r"))
		-- 재료: 아는 제조법이면 게임 자료(한 번에 드는 수 × 남은 횟수), 아니면 경로 자료(구간 합계를 남은 비율로)
		local mats = {}
		if kr and #kr.reagents > 0 then
			for _, rg in ipairs(kr.reagents) do mats[#mats + 1] = { rg.name or "?", rg.need * left, Count(rg.name, rg.itemID), rg.itemID } end
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
				m.tip = { d[1], string.format("가방 %d · 필요 %d", d[3], d[2]), d[5] and d[5] ~= "" and ("구하는 곳: " .. d[5]) or "" }
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
		c.src:SetText(kr and "|cff6FD39A배움|r" or ("배우는 곳  " .. (cur[6] or "")))
		-- 아직 안 배운 제조법이 상인 판매면: 상인 · 위치 · 값 (누르면 지도)
		local vx = (not kr) and PickVendor(VendorIndex(name)[cur[3]])
		if vx then
			local who, where, price = VendorText(vx)
			c.vend.x = vx
			c.vend.item = VendorIndex(name)[cur[3]].item
			c.vend.tip = { cur[3], "상인: " .. who, where, price ~= "" and ("값: " .. price) or "", "누르면 지도에 상인 위치" }
			c.vend.t:SetText(who .. (price ~= "" and ("  ·  |cffFFD15F" .. price .. "|r") or ""))
			c.vend.s:SetText(where .. "  ·  누르면 지도에 표시")
			c.vend:Show()
			c:SetHeight(y + 20 + 34)
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
			c.iconHit.tip = { nx.name .. " 단계 (" .. nx.cap .. "까지)", nx.lvl .. "레벨 · 숙련도 " .. nx.skill .. " 필요",
				costT ~= "" and ("비용: " .. costT .. (nx.cost and not nx.costSeen and " (기본 값 · 평판이 높으면 싸져요)" or "")) or "",
				nx.svc and ("훈련사 창에서 '" .. nx.svc .. "' 배우기") or "" }
			local sp = nx.spots[1]
			if sp then
				c.vend.x = { sp.npc, sp.map, sp.x, sp.y, label = "훈련사" }
				c.vend.tip = c.iconHit.tip
				c.vend.t:SetText(where .. (costT ~= "" and ("  ·  |cffFFD15F" .. costT .. "|r") or ""))
				c.vend.s:SetText((TRAINER_NOTE[sp.npc] or (#nx.spots > 1 and ("그 밖에 " .. (#nx.spots - 1) .. "곳") or "")) .. "  ·  누르면 지도에 표시")
				c.vend:Show()
				c:SetHeight(70 + 34)
			else
				c.vend:Hide()
				c:SetHeight(70)
			end
		else
			c.name:SetText(max >= 300 and "모든 단계를 배웠어요" or "다음 단계 훈련사에게 배우면 계속 올릴 수 있어요")
			c.sub:SetText("")
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
		r.vendor = nil
		r.item, r.link, r.spell = nil, nil, nil
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:Show()
		y = y + ROW + 2
	end
	-- 다음 단계: 이 단계 끝이 가까우면 (막히기 전에) 어디서 배우는지
	if prof and max > 0 and max < 300 and skill >= max - 25 and skill < max then
		local nx = M.NextRank(prof, max)
		if nx and nx.spots[1] then
			head("다음 단계 · " .. nx.name, max .. "에서 막혀요")
			local lv = UnitLevel("player") or 1
			for i = 1, math.min(2, #nx.spots) do
				local sp = nx.spots[i]
				local _, where = M.NextRankText({ name = nx.name, spots = { sp }, book = nx.book, quest = nx.quest })
				local costT = M.RankCostText(nx)
				local tip = { nx.name .. " 단계 (" .. nx.cap .. "까지)", where, nx.lvl .. "레벨 · 숙련도 " .. nx.skill .. " 필요",
					costT ~= "" and ("비용: " .. costT .. (nx.cost and not nx.costSeen and " (기본 값 · 평판이 높으면 싸져요)" or "")) or "",
					nx.svc and ("훈련사 창에서 '" .. nx.svc .. "' 배우기") or "",
					nx.book and "훈련사가 아니라 책으로 배워요 (그 NPC 가 팔아요)" or (nx.quest and "훈련사가 아니라 퀘스트로 배워요" or ""),
					TRAINER_NOTE[sp.npc] or "", "누르면 지도에 표시" }
				row(M.RankIcon(nx), TrainerName(sp.npc, sp.en), ZoneName(sp.map) .. string.format("  %.0f, %.0f", sp.x, sp.y)
					.. "  ·  " .. (lv < nx.lvl and ("|cffFF6B5E" .. nx.lvl .. "레벨|r") or (nx.lvl .. "레벨")),
					costT ~= "" and ("|cffFFD15F" .. costT .. "|r") or "", GOLD, tip)
				p.rows[nr].vendor = { sp.npc, sp.map, sp.x, sp.y, label = "훈련사" }
				if nx.book then p.rows[nr].item = nx.book end
			end
			y = y + 6
		end
	end
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
			for _, rg in ipairs(r.reagents) do mats[#mats + 1] = (rg.name or "?") .. " " .. rg.need end
			local tip = { r.name, (r.diff == 0 and "주황: 만들 때마다 숙련도 +1" or "노랑: 대부분 숙련도 +1"), table.concat(mats, ", ") }
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
				local tip = { s[3], string.format("숙련도 %d → %d · %d번 만들기", s[1], s[2], s[4]), "재료: " .. table.concat(mats, ", "), "배우는 곳: " .. (s[6] or "?") }
				if vx then
					local who, where, price = VendorText(vx)
					tip[#tip + 1] = "상인: " .. who .. " · " .. where .. (price ~= "" and (" · " .. price) or "")
					tip[#tip + 1] = "누르면 지도에 상인 위치"
				end
				local ssid = (not kr or not kr.link) and CraftSpellByName(s[3]) or nil
				local sitem = CraftItem(ssid) or (not kr and ItemByName(s[3])) or nil
				row((kr and kr.icon) or (ssid and CraftIcon(ssid)) or (sitem and ItemIcon(sitem)) or 134400, s[3],
					string.format("%d → %d  ·  %d번", s[1], s[2], s[4]), kr and "|cff6FD39A배움|r" or (s[6] or ""), nil, tip, false)
				p.rows[nr].vendor = vx or nil
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
				row(icon, e.craft, who .. " · " .. where, price ~= "" and price or ("숙련도 " .. req), req <= skill and GREEN or nil,
					{ e.craft, "필요 숙련도 " .. req, "상인: " .. who, where, price ~= "" and ("값: " .. price) or "", "누르면 지도에 상인 위치" }, req > skill)
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
		for sid, e in pairs(TrainerRecipes(prof)) do
			local nm = SpellName(sid)
			local known = (nm and byName[nm]) or (IsPlayerSpell and IsPlayerSpell(sid))
			if nm and not known and e.la <= skill + 25 and e.la >= skill - 40 and e.la <= (max > 0 and max or 300) then
				for _, t in ipairs(e.who) do t.d = t.d or Dist(t.map, t.x, t.y) end
				table.sort(e.who, function(a, b) return a.d < b.d end)
				can[#can + 1] = { sid = sid, name = nm, la = e.la, who = e.who }
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
				local tip = { e.name, "필요 숙련도 " .. e.la }
				for k = 1, math.min(3, #e.who) do
					local w = e.who[k]
					tip[#tip + 1] = string.format("배우는 곳: %s · %s %.0f, %.0f", TrainerName(w.npc, w.en), ZoneName(w.map), w.x, w.y)
				end
				if costByName[e.name] then tip[#tip + 1] = "비용 " .. Money(costByName[e.name]) end
				tip[#tip + 1] = "누르면 지도에 훈련사 위치"
				row(icon, e.name, "숙련도 " .. e.la .. "  ·  " .. who .. " · " .. ZoneName(t.map),
					costByName[e.name] and Money(costByName[e.name]) or (e.la <= skill and "|cff6FD39A지금 배움|r" or ""), e.la <= skill and GREEN or nil, tip, e.la > skill)
				p.rows[nr].vendor = { t.npc, t.map, t.x, t.y, label = "훈련사" }
				p.rows[nr].item = CraftItem(e.sid)
				p.rows[nr].spell = not p.rows[nr].item and e.sid or nil
			end
			y = y + 6
		end
	end
	p.body:SetHeight(math.max(10, y))
	p.foot:SetText((route and "빠른 레벨링: wowf.io · " or "") .. "훈련사: AllTheThings" .. (tr and " · 비용 기억됨" or " · 훈련사 창을 열면 비용도"))
end

function M:Hook()
	for _, n in ipairs({ "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }) do
		local f = _G[n]
		if f and not f.foaProfHooked then
			f.foaProfHooked = true
			f:HookScript("OnShow", function() C_Timer.After(0.2, function() pcall(M.Paint, M) end) end)
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
					print(string.format("|cffFFF468FOA|r %s %d/%d · 다음 %s → %s%s%s", name, rank, max, head, where,
						costT ~= "" and (" · |cffFFD15F" .. costT .. "|r") or "",
						#need > 0 and (" · |cffFF8A80" .. table.concat(need, ", ") .. "|r") or ""))
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
