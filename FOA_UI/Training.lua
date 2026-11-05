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
		if id and self.e.rank <= 1 and GameTooltip.SetSpellByID then
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
	p.title = Ink:Text(p, F.bold, 13, C.text, "LEFT")
	p.title:SetPoint("TOPLEFT", 14, -13)
	p.title:SetText("배울 기술")
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
