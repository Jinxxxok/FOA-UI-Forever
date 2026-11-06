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
local function ProfInfo()
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

-- 아는 제조법 { name, icon, diff(0~3), avail, reagents = { {name, need, have, itemID} } }
local function KnownRecipes(kind)
	local out = {}
	if kind == "modern" then
		local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
		for _, id in ipairs(ok and ids or {}) do
			local ok2, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
			if ok2 and info and info.learned and not info.isDummyRecipe then
				local r = { name = info.name, icon = info.icon, diff = info.relativeDifficulty or 3, avail = info.numAvailable or 0, id = id, reagents = {} }
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
				for j = 1, (GetCraftNumReagents and GetCraftNumReagents(i) or 0) do
					local rn, _, need, have = GetCraftReagentInfo(i, j)
					r.reagents[#r.reagents + 1] = { name = rn, need = need or 1, have = have or 0 }
				end
				out[#out + 1] = r
			end
		end
	end
	return out
end

local function RouteFor(name)
	if not (ns.PROF_ROUTES and name) then return end
	if ns.PROF_ROUTES[name] then return ns.PROF_ROUTES[name], name end
	for k, v in pairs(ns.PROF_ROUTES) do
		if name:find(k, 1, true) or k:find(name, 1, true) then return v, k end
	end
end

local function Count(name, itemID)
	if itemID and C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, itemID, true)
		if ok and n then return n end
	end
	if name and GetItemCount then
		local ok, n = pcall(GetItemCount, name, true)
		if ok and n then return n end
	end
	return 0
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
local function VendorIndex(prof)
	if vendorIdx[prof] then return vendorIdx[prof] end
	local idx = {}
	for item, e in pairs(ns.RECIPE_VENDORS or {}) do
		if prof and (e[1] == prof or prof:find(e[1], 1, true)) then
			local n = SpellName(e[2])
			if n then idx[n] = { item = item, req = e[3], list = e[4] } end
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
		print(string.format("|cffFFF468FOA|r 지도에 상인 위치를 찍었어요 (%s)", (C_Map.GetMapInfo(x[2]) or {}).name or ""))
	end
end

M.PickVendor, M.VendorText, M.Waypoint = PickVendor, VendorText, Waypoint

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
		if not self.tip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		for i, l in ipairs(self.tip) do
			if i == 1 then Ink.TipLine(GameTooltip, l, 1, 1, 1) else GameTooltip:AddLine(l, 0.75, 0.77, 0.8) end
		end
		GameTooltip:Show()
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
	c.vend:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.09) end)
	c.vend:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0.04) end)
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

function M:Paint()
	local host = Host()
	if not host or Ink.db.profGuide == false then if self.panel then self.panel:Hide() end return end
	local name, skill, max, kind = ProfInfo()
	local route, rkey = RouteFor(name)
	local known = name and KnownRecipes(kind) or {}
	if not name or (not route and #known == 0) then if self.panel then self.panel:Hide() end return end
	local p = self.panel or self:Build(host)
	if p:GetParent() ~= host then
		p:SetParent(host)
		Ink:MakeDraggable(p, "prof", host)
	end
	p.foaResetPos = function() Ink:PanelPoint(p, "prof", host, 6, -12) end
	if not p.placed or p.placedFor ~= host then Ink:PanelPoint(p, "prof", host, 6, -12); p.placed, p.placedFor = true, host end
	p:SetFrameStrata(host:GetFrameStrata())
	p:SetFrameLevel(host:GetFrameLevel() + 20)
	p:Show()
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
	if cur then
		local span = math.max(1, cur[2] - cur[1])
		local left = math.max(1, math.ceil((cur[2] - math.max(skill, cur[1])) * cur[4] / span))
		local kr = byName[cur[3]]
		c.k:SetText(string.format("지금 구간  %d → %d", cur[1], cur[2]))
		c.icon:SetTexture(kr and kr.icon or 134400)
		c.icon:SetDesaturated(not kr)
		c.name:SetText(cur[3])
		c.sub:SetText(string.format("약 %d번 더 만들기", left) .. (kr and kr.avail > 0 and ("  ·  |cff6FD39A지금 %d개 가능|r"):format(kr.avail) or "") .. (kr and "" or "  ·  |cffFFB75A아직 안 배움|r"))
		-- 재료: 아는 제조법이면 게임 자료(한 번에 드는 수 × 남은 횟수), 아니면 경로 자료(구간 합계를 남은 비율로)
		local mats = {}
		if kr and #kr.reagents > 0 then
			for _, rg in ipairs(kr.reagents) do mats[#mats + 1] = { rg.name or "?", rg.need * left, Count(rg.name, rg.itemID), rg.itemID } end
		else
			for _, m in ipairs(cur[5]) do
				mats[#mats + 1] = { m[1], math.ceil(m[2] * left / math.max(1, cur[4])), Count(m[1]), nil, m[3] }
			end
		end
		local cost, priced = 0, 0
		for i, m in ipairs(c.mats) do
			local d = mats[i]
			if d then
				local enough = d[3] >= d[2]
				m.n:SetText(d[1] .. (d[5] and d[5] ~= "" and ("  |cff5E636B" .. d[5] .. "|r") or ""))
				m.v:SetText((enough and "|cff6FD39A" or "") .. d[3] .. "|r / " .. d[2])
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
		c.k:SetText("숙련 최대")
		c.icon:SetTexture(134400)
		c.name:SetText("다음 단계 훈련사에게 배우면 계속 올릴 수 있어요")
		c.sub:SetText("")
		for _, m in ipairs(c.mats) do m:Hide() end
		c.cost:SetText(""); c.src:SetText("")
		c.vend:Hide()
		c:SetHeight(70)
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
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:Show()
		y = y + ROW + 2
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
		head("숙련이 오르는 제조법", "주황 · 노랑")
		for i = 1, math.min(8, #up) do
			local r = up[i]
			local mats = {}
			for _, rg in ipairs(r.reagents) do mats[#mats + 1] = (rg.name or "?") .. " " .. rg.need end
			local tip = { r.name, (r.diff == 0 and "주황: 만들 때마다 숙련 +1" or "노랑: 대부분 숙련 +1"), table.concat(mats, ", ") }
			row(r.icon, r.name, table.concat(mats, " · "), r.avail > 0 and ("|cff6FD39A" .. r.avail .. "개 가능|r") or "재료 부족", DIFF_C[r.diff], tip, r.avail == 0)
		end
		y = y + 6
	end
	-- 다음 구간
	if route and curI then
		local shown = 0
		for i = curI + 1, #route do
			local s = route[i]
			if s[4] > 0 then
				if shown == 0 then head("다음 구간", rkey and ("wowf.io · " .. rkey) or nil) end
				shown = shown + 1
				local kr = byName[s[3]]
				local mats = {}
				for _, m in ipairs(s[5]) do mats[#mats + 1] = m[1] .. " " .. m[2] end
				local vx = (not kr) and PickVendor(VendorIndex(name)[s[3]])
				local tip = { s[3], string.format("숙련 %d → %d · %d번 만들기", s[1], s[2], s[4]), "재료: " .. table.concat(mats, ", "), "배우는 곳: " .. (s[6] or "?") }
				if vx then
					local who, where, price = VendorText(vx)
					tip[#tip + 1] = "상인: " .. who .. " · " .. where .. (price ~= "" and (" · " .. price) or "")
					tip[#tip + 1] = "누르면 지도에 상인 위치"
				end
				row(kr and kr.icon or 134400, s[3], string.format("%d → %d  ·  %d번", s[1], s[2], s[4]), kr and "|cff6FD39A배움|r" or (s[6] or ""), nil, tip, not kr)
				p.rows[nr].vendor = vx or nil
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
				local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.v.item) or 134939
				local req = e.v.req or 0
				row(icon, e.craft, who .. " · " .. where, price ~= "" and price or ("숙련 " .. req), req <= skill and GREEN or nil,
					{ e.craft, "필요 숙련 " .. req, "상인: " .. who, where, price ~= "" and ("값: " .. price) or "", "누르면 지도에 상인 위치" }, req > skill)
				p.rows[nr].vendor = e.x
			end
			y = y + 6
		end
	end
	-- 훈련사에게 배울 제조법 (훈련사 창을 열었을 때 기억한 것)
	local tr
	for k, v in pairs(Ink.db.profTrainer or {}) do
		if name and (k == name or k:find(name, 1, true) or name:find(k, 1, true)) then tr = v end
	end
	if tr and tr.list then
		local can = {}
		for _, e in ipairs(tr.list) do
			local req = e[8] or 0
			if not byName[e[2]] and req <= skill + 25 then can[#can + 1] = e end
		end
		table.sort(can, function(a, b) return (a[8] or 0) < (b[8] or 0) end)
		if #can > 0 then
			head("훈련사에게 배울 제조법", "숙련 기준")
			for i = 1, math.min(8, #can) do
				local e = can[i]
				local req = e[8] or 0
				row(e[4], e[2], "숙련 " .. req .. (req <= skill and "  ·  |cff6FD39A지금 배울 수 있음|r" or ""), e[6] and Money(e[6]) or "", req <= skill and GREEN or nil,
					{ e[2], "필요 숙련 " .. req, e[6] and ("비용 " .. Money(e[6])) or "" }, req > skill)
			end
		end
	end
	p.body:SetHeight(math.max(10, y))
	p.foot:SetText((route and "빠른 레벨링: wowf.io · " or "") .. (tr and "훈련사 목록 기억됨" or "훈련사 창을 한 번 열면 배울 제조법 · 비용이 나와요"))
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

function M:Init()
	if not FOREVER then return end
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE",
		"SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do pcall(e.RegisterEvent, e, ev) end
	local pending
	e:SetScript("OnEvent", function(_, event)
		pcall(M.Hook, M)
		if event == "ADDON_LOADED" then return end
		if pending then return end
		pending = true
		C_Timer.After(0.3, function()
			pending = nil
			if Host() then pcall(M.Paint, M) end
		end)
	end)
	pcall(M.Hook, M)
end
