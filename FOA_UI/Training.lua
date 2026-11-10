-- FOA UI · 배울 기술 (포에버 · 마법책 옆)
--  · 지금 배울 수 있는 기술 / 다음 레벨들에 배울 기술을 레벨별로
--  · 직업 상급자 창을 한 번 열면 그 목록(정확한 비용 · 단계)을 기억해서 그걸 우선으로 쓴다 (같은 직업 캐릭터끼리 공유)
--  · 그 전에는 wowf.io 스킬북 자료 (ClassSpells.lua)
--  · 전문기술 훈련사 창도 같이 기억해 둔다 (전문기술 안내에서 사용)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Training")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local FOREVER = (function() local b = select(4, GetBuildInfo()) or 0 return b >= 16001 and b < 20000 end)()
local W, ROW, HEAD = 268, 30, 24
local GOLD = { 1, 0.82, 0.38 }
local NEW_C = { 0.44, 0.83, 0.6 }

local function Money(c)
	if not c or c <= 0 then return "" end
	if GetCoinTextureString then return GetCoinTextureString(c) end
	local g, s, b = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	return (g > 0 and (g .. "g ") or "") .. (s > 0 and (s .. "s ") or "") .. (b > 0 and (b .. "c") or "")
end

-------------------------------------------------------------------------------
-- 내가 아는 기술 (이름 → 배운 단계). 단계를 못 읽으면 true
-------------------------------------------------------------------------------
local function KnownRank(name)
	-- 이름으로 찾으면 내 마법책에 있는 기술만 나온다
	if not (C_Spell and C_Spell.GetSpellInfo) then return end
	local ok, info = pcall(C_Spell.GetSpellInfo, name)
	if not (ok and info and info.spellID) then return end
	local id = info.spellID
	local sub
	if C_Spell.GetSpellSubtext then
		local ok2, v = pcall(C_Spell.GetSpellSubtext, id)
		sub = ok2 and v
	end
	local r = type(sub) == "string" and tonumber(sub:match("(%d+)"))
	return r or true, id
end

-------------------------------------------------------------------------------
-- 목록 만들기: 상급자 기억 → 없으면 wowf 자료
-------------------------------------------------------------------------------
function M:List()
	local _, cls = UnitClass("player")
	local saved = Ink.db.classTrainer and Ink.db.classTrainer[cls]
	if saved and saved.list and #saved.list > 0 then return saved.list, saved end
	return ns.CLASS_SPELLS and ns.CLASS_SPELLS[cls] or {}, nil
end

-- { now = {...}, next = { [level] = {...} }, cost = 총 비용(아는 것만) }
function M:Plan()
	local lvl = UnitLevel("player") or 1
	local list, saved = self:List()
	local now, later, total, costKnown = {}, {}, 0, true
	local knownCache = {}
	for _, e in ipairs(list) do
		local L, name, rank, icon, flag, cost, state = e[1], e[2], e[3], e[4], e[5], e[6], e[7]
		local k = knownCache[name]
		if k == nil then k = KnownRank(name) or false; knownCache[name] = k end
		local learned
		if state then
			learned = state == "used"
		elseif k == false then
			learned = false
		elseif k == true then
			learned = true                       -- 단계를 못 읽음: 이미 배운 것으로
		else
			learned = rank == 0 or k >= rank
		end
		if not learned then
			local row = { level = L, name = name, rank = rank, icon = icon, flag = flag, cost = cost }
			if L <= lvl then
				now[#now + 1] = row
				if cost then total = total + cost else costKnown = false end
			elseif L <= lvl + 10 then
				later[L] = later[L] or {}
				table.insert(later[L], row)
			end
		end
	end
	return { now = now, later = later, cost = total, costKnown = costKnown and #now > 0, saved = saved, lvl = lvl }
end

-------------------------------------------------------------------------------
-- 상급자 · 훈련사 창 기억
-------------------------------------------------------------------------------
local reading
function M:ReadTrainer()
	if reading or not GetNumTrainerServices then return end
	reading = true
	-- 필터를 잠깐 다 켜서(배운 것 · 못 배우는 것 포함) 전부 읽고 원래대로
	local filters = {}
	if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
		for _, t in ipairs({ "available", "unavailable", "used" }) do
			local ok, v = pcall(GetTrainerServiceTypeFilter, t)
			filters[t] = ok and v
			if ok and not v then pcall(SetTrainerServiceTypeFilter, t, 1) end
		end
	end
	local list = {}
	local n = GetNumTrainerServices() or 0
	for i = 1, n do
		local ok, name, rankText, kind = pcall(GetTrainerServiceInfo, i)
		if ok and name and kind ~= "header" then
			local cost = GetTrainerServiceCost and select(1, GetTrainerServiceCost(i)) or nil
			local lv = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
			local icon = GetTrainerServiceIcon and GetTrainerServiceIcon(i)
			local skill, skillRank = nil, nil
			if GetTrainerServiceSkillReq then skill, skillRank = GetTrainerServiceSkillReq(i) end
			list[#list + 1] = { lv or 0, name, tonumber(type(rankText) == "string" and rankText:match("(%d+)") or "") or 0, icon, 0, cost, kind, skillRank }
		end
	end
	for t, v in pairs(filters) do if not v then pcall(SetTrainerServiceTypeFilter, t, 0) end end
	reading = nil
	if #list == 0 then return end
	local isProf = IsTradeskillTrainer and IsTradeskillTrainer()
	if isProf then
		-- 전문기술 훈련사: 기술 이름 = 창 제목
		local title = (ClassTrainerFrame and ClassTrainerFrame.TitleText and ClassTrainerFrame.TitleText:GetText())
			or (GetTrainerGreetingText and "") or "?"
		local key = (GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(1)) or title
		Ink.db.profTrainer = Ink.db.profTrainer or {}
		if key then Ink.db.profTrainer[key] = { t = time(), list = list } end
	else
		local _, cls = UnitClass("player")
		Ink.db.classTrainer = Ink.db.classTrainer or {}
		table.sort(list, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
		-- "used"/"available" 상태는 이 캐릭터 기준이라 목록에는 레벨 · 비용만 남기고, 상태는 캐릭터별로
		local plainList = {}
		for i, e in ipairs(list) do plainList[i] = { e[1], e[2], e[3], e[4], 0, e[6] } end
		Ink.db.classTrainer[cls] = { t = time(), list = plainList, npc = UnitName("npc") }
	end
	self:Paint()
end

-------------------------------------------------------------------------------
-- 마법책 옆 패널
-------------------------------------------------------------------------------
local function Host()
	local psf = _G.PlayerSpellsFrame
	if psf and psf.SpellBookFrame then return psf.SpellBookFrame, psf end
	return _G.SpellBookFrame, _G.SpellBookFrame
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
	local m = r:CreateMaskTexture()
	m:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m:SetAllPoints(r.icon)
	r.icon:AddMaskTexture(m)
	r.bd = Ink:Round(r, "BORDER", true, true)
	r.bd:SetPoint("TOPLEFT", r.icon, -1, 1)
	r.bd:SetPoint("BOTTOMRIGHT", r.icon, 1, -1)
	r.bd:SetVertexColor(1, 1, 1, 0.12)
	r.name = Ink:Text(r, F.semi, 11, C.text, "LEFT")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 9, 1)
	r.name:SetPoint("RIGHT", -70, 0)
	r.sub = Ink:Text(r, F.sans, 10, C.muted, "LEFT")
	r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 9, -1)
	r.sub:SetPoint("RIGHT", -70, 0)
	r.tag = Ink:Text(r, F.semi, 9, NEW_C, "LEFT")
	r.right = Ink:Text(r, F.sans, 10, C.soft, "RIGHT")
	r.right:SetPoint("RIGHT", -6, 0)
	r:SetScript("OnEnter", function(self)
		self.hl:SetVertexColor(1, 1, 1, 0.05)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local _, id = KnownRank(self.e.name)
		-- 아직 안 배운 기술도 진짜 기술 툴팁 (게임 파일에서 뽑은 주문 번호 · ClassSpellIDs.lua)
		local _, cls = UnitClass("player")
		local ids = ns.CLASS_SPELL_IDS and ns.CLASS_SPELL_IDS[cls]
		local exact = ids and ids[self.e.level .. ":" .. self.e.name]
		if exact then id = exact end
		if id and (exact or self.e.rank <= 1) and GameTooltip.SetSpellByID then
			GameTooltip:SetSpellByID(id)
		else
			GameTooltip:AddLine(self.e.name, 1, 1, 1)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(self.e.rank > 0 and (self.e.rank .. "단계") or "기술", "Lv " .. self.e.level, 0.7, 0.72, 0.75, 1, 1, 1)
		if self.e.cost then GameTooltip:AddDoubleLine("훈련 비용", Money(self.e.cost), 0.7, 0.72, 0.75, 1, 1, 1) end
		if self.e.flag == 1 then GameTooltip:AddLine("포에버 신규 기술", NEW_C[1], NEW_C[2], NEW_C[3]) end
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function(self) self.hl:SetVertexColor(1, 1, 1, 0); GameTooltip:Hide() end)
	return r
end

local function SectionHead(body)
	local h = CreateFrame("Frame", nil, body)
	h:SetSize(W - 20, HEAD)
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

-------------------------------------------------------------------------------
-- 무기 기술 · 대도시 무기 전문가 (Warcraft Tavern 포에버 무기 기술 표)
--  한 가지에 10실버 · 장창은 20레벨부터 1골드 · 마법봉은 처음부터 알고 있어서 배우지 않는다
--  아이템 무기 종류 번호: 0 한손 도끼 · 1 양손 도끼 · 2 활 · 3 총 · 4 한손 둔기 · 5 양손 둔기 · 6 장창
--  7 한손 도검 · 8 양손 도검 · 10 지팡이 · 13 장착 무기 · 15 단검 · 16 투척 무기 · 18 석궁
-------------------------------------------------------------------------------
local WMASTERS = {
	{ fac = "Alliance", map = 1453, x = 63.8, y = 69.0, npc = 11867, en = "Woo Ping", s = { 15, 7, 8, 6, 10, 18 } },
	{ fac = "Alliance", map = 1455, x = 62.2, y = 89.6, npc = 11865, en = "Buliwyf Stonehand", s = { 13, 3, 0, 1, 4, 5 } },
	{ fac = "Alliance", map = 1455, x = 62.2, y = 89.6, npc = 13084, en = "Bixi Wobblebonk", s = { 15, 18, 16 } },
	{ fac = "Alliance", map = 1457, x = 57.6, y = 46.7, npc = 11866, en = "Ilyenia Moonfire", s = { 2, 15, 13, 10, 16 } },
	{ fac = "Horde", map = 1454, x = 81.5, y = 19.6, npc = 11868, en = "Sayoc", s = { 2, 15, 13, 0, 1, 10, 16 } },
	{ fac = "Horde", map = 1454, x = 81.5, y = 19.6, npc = 2704, en = "Hanashi", s = { 2, 0, 1, 10, 16 } },
	{ fac = "Horde", map = 1456, x = 40.9, y = 62.7, npc = 11869, en = "Ansekhwa", s = { 3, 4, 5, 10 } },
	{ fac = "Horde", map = 1458, x = 57.3, y = 32.8, npc = 11870, en = "Archibald", s = { 15, 7, 8, 6, 18 } },
}
M.WMASTERS = WMASTERS
-- 무기 기술 주문 번호 (배웠는지 확인)
local WEAPON_SPELL = { [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200, [7] = 201, [8] = 202,
	[10] = 227, [13] = 15590, [15] = 1180, [16] = 2567, [18] = 5011, [19] = 5009 }
local WEAPON_KO = { [0] = "한손 도끼", [1] = "양손 도끼", [2] = "활", [3] = "총", [4] = "한손 둔기", [5] = "양손 둔기", [6] = "장창",
	[7] = "한손 도검", [8] = "양손 도검", [10] = "지팡이", [13] = "장착 무기", [15] = "단검", [16] = "투척 무기", [18] = "석궁", [19] = "마법봉" }
local function WeaponName(sub)
	local n = GetItemSubClassInfo and GetItemSubClassInfo(2, sub)
	return (type(n) == "string" and n ~= "") and n or WEAPON_KO[sub] or tostring(sub)
end

-- 배운 무기 기술 { [종류] = true } · 하나도 못 읽으면 nil (확인 불가 → 표시만)
local function KnownWeapons()
	local skills = {}
	if GetNumSkillLines and GetSkillLineInfo then
		for i = 1, (GetNumSkillLines() or 0) do
			local n = GetSkillLineInfo(i)
			if type(n) == "string" then skills[n] = true end
		end
	end
	local known, any = {}, false
	for sub, id in pairs(WEAPON_SPELL) do
		local k = (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or skills[WeaponName(sub)]
		if k then known[sub] = true; any = true end
	end
	return any and known or nil
end
M.KnownWeapons = KnownWeapons

local function NpcName(e)
	local Q = Ink.modules.QuestMap
	local n = Q and Q.GiverName and Q:GiverName(e.npc)
	return n or e.en
end

local WROW = 46
local function WRow(body)
	local r = CreateFrame("Button", nil, body)
	r:SetSize(W - 20, WROW)
	r.hl = Ink:Round(r, "BACKGROUND", true, false)
	r.hl:SetAllPoints()
	r.hl:SetVertexColor(1, 1, 1, 0)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(14, 14)
	r.icon:SetPoint("TOPLEFT", 8, -8)
	r.icon:SetTexture(Ink.icon("MapPin"))
	r.name = Ink:Text(r, F.semi, 11, C.text, "LEFT")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 7, 0)
	r.name:SetPoint("RIGHT", -56, 0)
	r.right = Ink:Text(r, F.sans, 10, C.muted, "RIGHT")
	r.right:SetPoint("RIGHT", r, "TOPRIGHT", -8, -15)
	r.sub = Ink:Text(r, F.sans, 10, C.soft, "LEFT")
	r.sub:SetPoint("TOPLEFT", r.icon, "BOTTOMLEFT", 0, -5)
	r.sub:SetPoint("RIGHT", -8, 0)
	r.sub:SetWordWrap(true)
	r.sub:SetJustifyV("TOP")
	r:SetScript("OnEnter", function(self)
		self.hl:SetVertexColor(1, 1, 1, 0.05)
		local e = self.e
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(NpcName(e), 1, 1, 1)
		local mi = C_Map.GetMapInfo and C_Map.GetMapInfo(e.map)
		GameTooltip:AddLine(string.format("%s  %.1f, %.1f", mi and mi.name or "", e.x, e.y), 0.7, 0.72, 0.75)
		GameTooltip:AddLine(" ")
		for _, sub in ipairs(e.s) do
			local st = self.state[sub]
			local r2, g2, b2 = 0.45, 0.47, 0.5
			local right = "내 직업은 못 씀"
			if st == "learn" then r2, g2, b2, right = C.accent[1], C.accent[2], C.accent[3], (sub == 6 and "배울 수 있음 · 20레벨 · 1골드" or "배울 수 있음 · 10실버")
			elseif st == "known" then r2, g2, b2, right = 0.44, 0.83, 0.6, "배움"
			elseif st == "ok" then r2, g2, b2, right = 0.85, 0.86, 0.88, (sub == 6 and "20레벨 · 1골드" or "10실버") end
			GameTooltip:AddDoubleLine(WeaponName(sub), right, r2, g2, b2, r2, g2, b2)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("누르면 지도에 위치 표시", 0.55, 0.57, 0.6)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function(self) self.hl:SetVertexColor(1, 1, 1, 0); GameTooltip:Hide() end)
	r:SetScript("OnClick", function(self)
		local e = self.e
		local Q = Ink.modules.QuestMap
		if Q and Q.Waypoint then Q:Waypoint({ mapID = e.map, wx = e.x / 100, wy = e.y / 100 }) end
		local mi = C_Map.GetMapInfo and C_Map.GetMapInfo(e.map)
		print(string.format("|cffFFF468FOA|r 무기 전문가 |cffFFF468%s|r · %s (%.1f, %.1f) 위치를 지도에 표시했어요", NpcName(e), mi and mi.name or "", e.x, e.y))
	end)
	return r
end

function M:PaintWeapons(p)
	local _, cls = UnitClass("player")
	local fac = UnitFactionGroup("player")
	local ok = ns.WEAPON_OK and ns.WEAPON_OK[cls] or {}
	local known = KnownWeapons()
	local a = C.accent
	local hexA = string.format("%02x%02x%02x", a[1] * 255, a[2] * 255, a[3] * 255)
	-- 배울 수 있는데 아직 안 배운 무기
	local todo, seen = {}, {}
	for _, e in ipairs(WMASTERS) do
		if e.fac == fac then
			for _, sub in ipairs(e.s) do
				if ok[sub] and known and not known[sub] and not seen[sub] then seen[sub] = true; todo[#todo + 1] = WeaponName(sub) end
			end
		end
	end
	p.card.n:SetText(known and #todo or "-")
	local on = known and #todo > 0
	p.card.n:SetTextColor(on and a[1] or C.muted[1], on and a[2] or C.muted[2], on and a[3] or C.muted[3])
	p.card.l:SetText(not known and "무기 기술" or (#todo > 0 and "더 배울 수 있는 무기" or "배울 무기 기술 없음"))
	p.card.s:SetText(#todo > 0 and table.concat(todo, " · ") or "대도시 무기 전문가에게서 배워요")
	p.card.cost:SetText(#todo > 0 and "|cff8E939B한 가지 10실버|r" or "")
	p.card.bd:SetVertexColor(a[1], a[2], a[3], on and 0.4 or 0.06)
	for _, r in ipairs(p.rows) do r:Hide() end
	for _, r in ipairs(p.wrows or {}) do r:Hide() end
	for _, h in ipairs(p.heads) do h:Hide() end
	p.wrows = p.wrows or {}
	local y, nr, nh, lastMap = 0, 0, 0, nil
	for _, e in ipairs(WMASTERS) do
		if e.fac == fac then
			if e.map ~= lastMap then
				lastMap = e.map
				nh = nh + 1
				local h = p.heads[nh] or SectionHead(p.body)
				p.heads[nh] = h
				local mi = C_Map.GetMapInfo and C_Map.GetMapInfo(e.map)
				h.t:SetText(mi and mi.name or "")
				local cnt = 0
				for _, e2 in ipairs(WMASTERS) do if e2.map == e.map then cnt = cnt + 1 end end
				h.r:SetText(cnt .. "명")
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", 0, -y)
				h:Show()
				y = y + HEAD + 4
			end
			nr = nr + 1
			local r = p.wrows[nr] or WRow(p.body)
			p.wrows[nr] = r
			r.e = e
			r.state = {}
			local parts, mine = {}, 0
			for _, sub in ipairs(e.s) do
				local st
				if not ok[sub] then st = "no"
				elseif known and known[sub] then st = "known"
				elseif known then st = "learn"; mine = mine + 1
				else st = "ok" end
				r.state[sub] = st
				local nm = WeaponName(sub)
				if st == "learn" then parts[#parts + 1] = "|cff" .. hexA .. nm .. "|r"
				elseif st == "known" then parts[#parts + 1] = "|cff6FD39A" .. nm .. "|r"
				elseif st == "ok" then parts[#parts + 1] = "|cffD9DBE0" .. nm .. "|r"
				else parts[#parts + 1] = "|cff5E636B" .. nm .. "|r" end
			end
			r.name:SetText(NpcName(e))
			r.right:SetText(mine > 0 and ("|cff" .. hexA .. "+" .. mine .. "|r") or "")
			r.icon:SetVertexColor(mine > 0 and a[1] or 0.6, mine > 0 and a[2] or 0.62, mine > 0 and a[3] or 0.66)
			r.sub:SetText(table.concat(parts, " · "))
			local hgt = math.max(WROW, 30 + math.ceil(r.sub:GetStringHeight() or 12))
			r:SetHeight(hgt)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -y)
			r:Show()
			y = y + hgt + 2
		end
	end
	p.empty:SetShown(nr == 0)
	p.empty:SetText("무기 전문가 정보가 없어요")
	p.body:SetHeight(math.max(10, y))
	p.foot:SetText((known and "|cffE3C07A노란색|r 배울 수 있음 · |cff6FD39A초록|r 배움 · 회색은 내 직업이 못 씀" or "회색은 내 직업이 못 씀") .. " · 누르면 위치")
end

function M:Build(host)
	local p = CreateFrame("Frame", "FOATraining", host)
	p:SetSize(W, 440)
	p:SetFrameStrata(host:GetFrameStrata())
	p:SetFrameLevel(host:GetFrameLevel() + 20)
	p:EnableMouse(true)
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
	p.acc = acc
	-- 탭: 배울 기술 | 무기 기술
	p.tabs = {}
	local function Tab(key, text, prev)
		local b = CreateFrame("Button", nil, p)
		b.t = Ink:Text(b, F.bold, 13, C.text, "LEFT")
		b.t:SetPoint("LEFT")
		b.t:SetText(text)
		b:SetSize(math.max(54, (b.t:GetStringWidth() or 0) + 2), 22)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 14, 0) else b:SetPoint("TOPLEFT", 14, -9) end
		b.key = key
		b:SetScript("OnClick", function()
			M.tab = key
			Ink.db.trainingTab = key
			if p.sf then p.sf:SetVerticalScroll(0) end
			M:Paint()
		end)
		b:SetScript("OnEnter", function(self) if M.tab ~= self.key then self.t:SetTextColor(C.soft[1], C.soft[2], C.soft[3]) end end)
		b:SetScript("OnLeave", function(self) if M.tab ~= self.key then self.t:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end end)
		p.tabs[#p.tabs + 1] = b
		return b
	end
	p.title = Tab("spells", "배울 기술").t
	Tab("weapons", "무기 기술", p.tabs[1])
	p.cls = Ink:Text(p, F.semi, 10, C.soft, "RIGHT")
	p.cls:SetPoint("TOPRIGHT", -14, -15)
	-- 요약 카드: 지금 배울 수 있는 수 · 비용
	p.card = CreateFrame("Frame", nil, p)
	p.card:SetPoint("TOPLEFT", 10, -36)
	p.card:SetPoint("TOPRIGHT", -10, -36)
	p.card:SetHeight(50)
	p.card.bg = Ink:Round(p.card, "BACKGROUND", true, false)
	p.card.bg:SetAllPoints()
	p.card.bg:SetVertexColor(1, 1, 1, 0.035)
	p.card.bd = Ink:Round(p.card, "BORDER", true, true)
	p.card.bd:SetAllPoints()
	p.card.n = Ink:Text(p.card, F.num, 26, C.accent, "LEFT")
	p.card.n:SetPoint("LEFT", 12, 0)
	p.card.l = Ink:Text(p.card, F.semi, 11, C.text, "LEFT")
	p.card.l:SetPoint("TOPLEFT", p.card.n, "TOPRIGHT", 10, -2)
	p.card.s = Ink:Text(p.card, F.sans, 10, C.muted, "LEFT")
	p.card.s:SetPoint("BOTTOMLEFT", p.card.n, "BOTTOMRIGHT", 10, 2)
	p.card.cost = Ink:Text(p.card, F.semi, 11, GOLD, "RIGHT")
	p.card.cost:SetPoint("RIGHT", -12, 0)
	-- 목록
	local sf = CreateFrame("ScrollFrame", nil, p)
	sf:SetPoint("TOPLEFT", 10, -94)
	sf:SetPoint("BOTTOMRIGHT", -10, 34)
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
	p.foot:SetPoint("BOTTOMLEFT", 14, 12)
	p.foot:SetPoint("BOTTOMRIGHT", -14, 12)
	p.foot:SetWordWrap(true)
	p.empty = Ink:Text(body, F.sans, 11, C.muted, "CENTER")
	p.empty:SetPoint("TOP", 0, -24)
	p.empty:SetWidth(W - 40)
	p.empty:SetWordWrap(true)
	-- 옮기기 (머리 부분을 끌어서 · 위치 기억)
	Ink:MakeDraggable(p, "training", host)
	p.foaResetPos = function() M:Place(host) end
	self.panel = p
	return p
end

function M:Place(host)
	Ink:PanelPoint(self.panel, "training", host, 6, -12)
end

function M:Paint()
	local host, outer = Host()
	local p = self.panel
	if not (p and outer and outer:IsShown() and host:IsVisible()) then if p then p:Hide() end return end
	p:Show()
	local plan = self:Plan()
	local _, cls = UnitClass("player")
	local cr, cg, cb = 1, 1, 1
	if ns.ClassTint then cr, cg, cb = ns.ClassTint(cls) end
	p.cls:SetText((UnitClass("player") or "") .. " · Lv " .. plan.lvl)
	p.cls:SetTextColor(cr, cg, cb)
	self.tab = self.tab or Ink.db.trainingTab or "spells"
	for _, b in ipairs(p.tabs or {}) do
		local on = b.key == self.tab
		local c = on and C.text or C.muted
		b.t:SetTextColor(c[1], c[2], c[3])
		if on and p.acc then p.acc:ClearAllPoints(); p.acc:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 6) end
	end
	if self.tab == "weapons" then return self:PaintWeapons(p) end
	for _, r in ipairs(p.wrows or {}) do r:Hide() end
	local n = #plan.now
	local a = C.accent
	p.card.n:SetText(n)
	p.card.n:SetTextColor(n > 0 and a[1] or C.muted[1], n > 0 and a[2] or C.muted[2], n > 0 and a[3] or C.muted[3])
	p.card.l:SetText(n > 0 and "지금 배울 수 있어요" or "지금 배울 기술 없음")
	local nextLv
	for L in pairs(plan.later) do if not nextLv or L < nextLv then nextLv = L end end
	p.card.s:SetText(nextLv and ("다음 훈련 Lv " .. nextLv) or "다음 10레벨 안에는 없어요")
	p.card.cost:SetText(plan.costKnown and Money(plan.cost) or (n > 0 and "|cff8E939B비용은 상급자에게서|r" or ""))
	p.card.bd:SetVertexColor(a[1], a[2], a[3], n > 0 and 0.4 or 0.06)
	-- 목록
	for _, r in ipairs(p.rows) do r:Hide() end
	for _, h in ipairs(p.heads) do h:Hide() end
	local y, nr, nh = 0, 0, 0
	local function head(t, r)
		nh = nh + 1
		local h = p.heads[nh] or SectionHead(p.body)
		p.heads[nh] = h
		h.t:SetText(t)
		h.r:SetText(r or "")
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", 0, -y)
		h:Show()
		y = y + HEAD + 4
	end
	local function row(e, now)
		nr = nr + 1
		local r = p.rows[nr] or Row(p.body)
		p.rows[nr] = r
		r.e = e
		local tex = e.icon
		if type(tex) == "string" and not tex:find("\\") then tex = "Interface\\Icons\\" .. tex end
		r.icon:SetTexture(tex or 134400)
		r.icon:SetDesaturated(not now)
		r.icon:SetAlpha(now and 1 or 0.75)
		r.name:SetText(e.name)
		r.name:SetTextColor(now and C.text[1] or C.soft[1], now and C.text[2] or C.soft[2], now and C.text[3] or C.soft[3])
		r.sub:SetText(e.rank > 0 and (e.rank .. "단계") or "새 기술")
		r.tag:ClearAllPoints()
		r.tag:SetPoint("LEFT", r.sub, "LEFT", r.sub:GetStringWidth() + 6, 0)
		r.tag:SetText(e.flag == 1 and "신규" or "")
		r.right:SetText(e.cost and Money(e.cost) or "")
		r.bd:SetVertexColor(now and a[1] or 1, now and a[2] or 1, now and a[3] or 1, now and 0.5 or 0.12)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, -y)
		r:Show()
		y = y + ROW + 2
	end
	if n > 0 then
		head("지금 배울 수 있어요", plan.costKnown and Money(plan.cost) or nil)
		for _, e in ipairs(plan.now) do row(e, true) end
		y = y + 6
	end
	local levels = {}
	for L in pairs(plan.later) do levels[#levels + 1] = L end
	table.sort(levels)
	for _, L in ipairs(levels) do
		local list = plan.later[L]
		local c, known = 0, true
		for _, e in ipairs(list) do if e.cost then c = c + e.cost else known = false end end
		head("Lv " .. L, known and Money(c) or (#list .. "개"))
		for _, e in ipairs(list) do row(e, false) end
		y = y + 6
	end
	p.empty:SetShown(nr == 0)
	p.empty:SetText("배울 기술 목록이 비어 있어요\n직업 상급자 창을 한 번 열면 채워져요")
	p.body:SetHeight(math.max(10, y))
	if plan.saved then
		local days = math.floor((time() - (plan.saved.t or time())) / 86400)
		p.foot:SetText("직업 상급자 목록 · " .. (days <= 0 and "오늘" or (days .. "일 전")) .. " 확인 · 비용 포함")
	else
		p.foot:SetText("wowf.io 스킬북 기준 · 직업 상급자에게 한 번 가면 비용까지 정확해져요")
	end
end

function M:Hook()
	local host, outer = Host()
	if not host or self.hooked == host then return end
	self.hooked = host
	if not self.panel then self:Build(outer) end
	self.panel:SetParent(outer)
	self:Place(outer)
	local function show()
		C_Timer.After(0.05, function()
			M:Place(outer)
			M:Paint()
			-- 같은 자리의 특성 가이드는 마법책을 보는 동안 숨김
			local T = Ink.modules.Talents
			if T and T.panel and M.panel:IsShown() then T.panel:Hide() end
		end)
	end
	outer:HookScript("OnShow", show)
	outer:HookScript("OnHide", function() if M.panel then M.panel:Hide() end end)
	if host ~= outer and host.HookScript then
		host:HookScript("OnShow", show)
		host:HookScript("OnHide", function() if M.panel then M.panel:Hide() end end)
	end
	if outer:IsShown() then show() end
end

function M:Init()
	if not FOREVER or Ink.db.training == false then return end
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "TRAINER_SHOW", "TRAINER_UPDATE", "PLAYER_LEVEL_UP", "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	local pending
	e:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then
			pcall(M.Hook, M)
			return
		end
		if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
			if reading then return end
			C_Timer.After(0.2, function() pcall(M.ReadTrainer, M) end)
			return
		end
		if pending then return end
		pending = true
		C_Timer.After(0.4, function()
			pending = nil
			if M.panel and M.panel:IsShown() then pcall(M.Paint, M) end
		end)
	end)
	pcall(M.Hook, M)
end
