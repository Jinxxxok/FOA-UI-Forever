-- FOA UI · 특성 가이드 (포에버)
--  레벨업 특성 순서(TalentData)를 보고 "다음에 찍을 특성"을 알려 준다.
--  · 특성 창: 다음 특성 칸에 노란 테두리, 오른쪽에 FOA 안내판(다음 8개 · 빌드 고르기)
--  · 특성 포인트가 생기면 채팅에 추천을 한 줄
--  게임 안 특성은 아이콘 파일 번호로 찾는다 → 한글 / 영문 클라이언트 상관없이 맞는다.

local ADDON, ns = ...
local Ink = ns.Ink
local C, F = Ink.c, Ink.font
local M = Ink:Module("Talents")
ns.Talents = M

local GetFileIDFromPath = GetFileIDFromPath

local function TalentInfo(tab, i)
	local name, icon, tier, column, rank, maxRank = GetTalentInfo(tab, i)
	if type(icon) == "string" and GetFileIDFromPath then icon = GetFileIDFromPath(icon) or icon end
	return name, icon, tier, column, tonumber(rank) or 0, tonumber(maxRank) or 0
end

local function Unspent()
	if GetUnspentTalentPoints then return GetUnspentTalentPoints() or 0 end
	if UnitCharacterPoints then return (UnitCharacterPoints("player")) or 0 end
	return 0
end

-------------------------------------------------------------------------------
-- 빌드 고르기 · 게임 특성과 맞추기
-------------------------------------------------------------------------------
function M:Builds()
	local _, class = UnitClass("player")
	local list = {}
	local data = ns.TalentData and ns.TalentData.builds or {}
	for key, b in pairs(data) do
		if key:match("^" .. class .. ":") then list[#list + 1] = key end
	end
	table.sort(list)
	return list
end

function M:BuildKey()
	local list = self:Builds()
	if #list == 0 then return end
	local want = Ink.cdb and Ink.cdb.talentBuild
	if want and ns.TalentData.builds[want] then return want end
	local class, spec = ns.Score and ns.Score:Spec()
	local key = class and spec and (class .. ":" .. spec)
	if key and ns.TalentData.builds[key] then return key end
	return list[1]
end

-- 아이콘 → 게임 특성 위치
local function IconMap()
	local map = {}
	local tabs = GetNumTalentTabs and GetNumTalentTabs() or 0
	for t = 1, tabs do
		for i = 1, (GetNumTalents(t) or 0) do
			local name, icon, _, _, _, maxRank = TalentInfo(t, i)
			if icon then
				map[icon] = map[icon] or {}
				table.insert(map[icon], { t = t, i = i, max = maxRank, name = name })
			end
		end
	end
	return map
end

function M:Resolve()
	local key = self:BuildKey()
	if not key then return end
	if self.resolved and self.resolvedKey == key then return self.resolved end
	local map = IconMap()
	local steps = {}
	local prev = {}
	local miss = 0
	for _, s in ipairs(ns.TalentData.builds[key].steps) do
		local fid, target, max, lo, hi, en = s[1], s[2], s[3], s[4], s[5], s[6]
		local cands = map[fid]
		local pick
		if cands then
			for _, c in ipairs(cands) do if c.max == max then pick = c break end end
			pick = pick or cands[1]
		end
		local r = { lo = lo, hi = hi, en = en, icon = fid }
		if pick then
			r.t, r.i, r.max, r.name = pick.t, pick.i, pick.max, pick.name
			local k = pick.t .. ":" .. pick.i
			r.from = prev[k] or 0
			r.target = math.min(target, pick.max)
			prev[k] = r.target
		else
			miss = miss + 1
		end
		steps[#steps + 1] = r
	end
	self.resolved, self.resolvedKey, self.missing = steps, key, miss
	return steps
end

-- 다음에 찍을 특성 n개 (지금 찍힌 단계부터 이어서)
function M:Next(n)
	local steps = self:Resolve()
	if not steps then return {} end
	local out, sim = {}, {}
	for _, s in ipairs(steps) do
		if s.t then
			local k = s.t .. ":" .. s.i
			local cur = sim[k]
			if cur == nil then cur = select(5, TalentInfo(s.t, s.i)) end
			while cur < s.target and #out < n do
				cur = cur + 1
				out[#out + 1] = { t = s.t, i = s.i, name = s.name or s.en, icon = s.icon, rank = cur, max = s.max,
					level = math.max(s.lo, math.min(s.hi, s.lo + (cur - s.from) - 1)) }
			end
			sim[k] = cur
			if #out >= n then break end
		end
	end
	return out
end

-------------------------------------------------------------------------------
-- 특성 창: 다음 특성 테두리 + 안내판
-------------------------------------------------------------------------------
local function TalentFrame()
	return _G.PlayerTalentFrame or _G.TalentFrame
end

local function SelectedTab(f)
	if PanelTemplates_GetSelectedTab then
		local t = PanelTemplates_GetSelectedTab(f)
		if t then return t end
	end
	return f.selectedTab or f.talentTabIndex or 1
end

local function Glow(b)
	if b.foaNext then return b.foaNext end
	local g = CreateFrame("Frame", nil, b)
	g:SetPoint("TOPLEFT", -3, 3)
	g:SetPoint("BOTTOMRIGHT", 3, -3)
	g:SetFrameLevel(b:GetFrameLevel() + 5)
	g.edge = Ink:Round(g, "OVERLAY", true, true)
	g.edge:SetAllPoints()
	g.edge:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
	g.tag = Ink:Text(g, F.bold, 10, C.accent, "CENTER")
	g.tag:SetPoint("BOTTOM", g, "TOP", 0, 1)
	g.tag:SetText("다음")
	local ag = g:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.35)
	a:SetDuration(0.7)
	a:SetSmoothing("IN_OUT")
	ag:Play()
	g.ag = ag
	b.foaNext = g
	return g
end

function M:PaintFrame()
	local f = TalentFrame()
	if not f or not f:IsShown() then if self.panel then self.panel:Hide() end return end
	local nxt = self:Next(8)
	local first = nxt[1]
	local tab = SelectedTab(f)
	local prefix = (f == _G.PlayerTalentFrame) and "PlayerTalentFrameTalent" or "TalentFrameTalent"
	for i = 1, 40 do
		local b = _G[prefix .. i]
		if not b then break end
		local on = first and first.t == tab and b:GetID() == first.i and Ink.db.talentGuide ~= false
		if on then Glow(b):Show() elseif b.foaNext then b.foaNext:Hide() end
	end
	-- 추천이 다른 탭이면 그 탭 버튼에 점
	local tabPrefix = (f == _G.PlayerTalentFrame) and "PlayerTalentFrameTab" or "TalentFrameTab"
	for t = 1, 3 do
		local tb = _G[tabPrefix .. t]
		if tb then
			if not tb.foaDot then
				tb.foaDot = tb:CreateTexture(nil, "OVERLAY", nil, 7)
				tb.foaDot:SetTexture(Ink.tex.round4)
				tb.foaDot:SetSize(7, 7)
				tb.foaDot:SetPoint("TOPRIGHT", -6, -4)
				tb.foaDot:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
			end
			tb.foaDot:SetShown(first and first.t == t and Ink.db.talentGuide ~= false and true or false)
		end
	end
	self:PaintPanel(f, nxt)
end

function M:BuildPanel(f)
	local p = CreateFrame("Frame", "FOATalentGuide", f)
	p:SetSize(250, 330)
	p:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, -12)
	p:SetFrameStrata(f:GetFrameStrata())
	p.bg = Ink:Round(p, "BACKGROUND", false, false)
	p.bg:SetAllPoints()
	p.bg:SetVertexColor(0.05, 0.06, 0.08, 0.96)
	p.bd = Ink:Round(p, "BORDER", false, true)
	p.bd:SetAllPoints()
	p.bd:SetVertexColor(1, 1, 1, 0.1)
	local acc = p:CreateTexture(nil, "ARTWORK")
	acc:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	acc:SetSize(22, 2)
	acc:SetPoint("TOPLEFT", 14, -1)
	p.title = Ink:Text(p, F.bold, 13, C.text, "LEFT")
	p.title:SetPoint("TOPLEFT", 14, -12)
	p.title:SetText("FOA 특성 가이드")
	p.build = CreateFrame("Button", nil, p)
	p.build:SetSize(222, 24)
	p.build:SetPoint("TOPLEFT", 14, -34)
	p.build.bg = Ink:Round(p.build, "BACKGROUND", true, false)
	p.build.bg:SetAllPoints()
	p.build.bg:SetVertexColor(1, 1, 1, 0.05)
	p.build.text = Ink:Text(p.build, F.semi, 11, C.accent, "LEFT")
	p.build.text:SetPoint("LEFT", 8, 0)
	p.build.hint = Ink:Text(p.build, F.sans, 10, C.dim, "RIGHT")
	p.build.hint:SetPoint("RIGHT", -8, 0)
	p.build.hint:SetText("바꾸기")
	p.build:SetScript("OnClick", function()
		local list = M:Builds()
		local cur = M:BuildKey()
		local idx = 1
		for n, k in ipairs(list) do if k == cur then idx = n end end
		Ink.cdb.talentBuild = list[idx % #list + 1]
		M.resolved = nil
		M:PaintFrame()
	end)
	p.rows = {}
	for i = 1, 8 do
		local r = CreateFrame("Frame", nil, p)
		r:SetSize(222, 28)
		r:SetPoint("TOPLEFT", 14, -66 - (i - 1) * 30)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(24, 24)
		r.icon:SetPoint("LEFT", 0, 0)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.name = Ink:Text(r, F.semi, 11, C.text, "LEFT")
		r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 5)
		r.name:SetWidth(150)
		r.sub = Ink:Text(r, F.sans, 10, C.dim, "LEFT")
		r.sub:SetPoint("LEFT", r.icon, "RIGHT", 8, -7)
		r.lv = Ink:Text(r, F.latinB, 10, C.muted, "RIGHT")
		r.lv:SetPoint("RIGHT", 0, 0)
		p.rows[i] = r
	end
	p.foot = Ink:Text(p, F.sans, 9, C.dim, "LEFT")
	p.foot:SetPoint("BOTTOMLEFT", 14, 10)
	p.foot:SetWidth(222)
	p.foot:SetWordWrap(true)
	self.panel = p
	return p
end

local TREE_NAMES
function M:PaintPanel(f, nxt)
	if Ink.db.talentGuide == false then if self.panel then self.panel:Hide() end return end
	local p = self.panel or self:BuildPanel(f)
	p:Show()
	local key = self:BuildKey()
	local b = key and ns.TalentData.builds[key]
	p.build.text:SetText(b and b.label or "빌드 없음")
	TREE_NAMES = TREE_NAMES or {}
	for i, r in ipairs(p.rows) do
		local n = nxt[i]
		if n then
			r:Show()
			r.icon:SetTexture(n.icon)
			r.name:SetText(n.name or "?")
			if not TREE_NAMES[n.t] and GetTalentTabInfo then
				local a, b2 = GetTalentTabInfo(n.t)
				TREE_NAMES[n.t] = type(a) == "string" and a or (type(b2) == "string" and b2) or ""
			end
			r.sub:SetText(string.format("%s · %d/%d", TREE_NAMES[n.t] or "", n.rank, n.max))
			r.lv:SetText("Lv " .. n.level)
			if i == 1 then
				r.name:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
				r.icon:SetDesaturated(false)
			else
				r.name:SetTextColor(C.text[1], C.text[2], C.text[3])
			end
		else
			r:Hide()
		end
	end
	if #nxt == 0 then
		p.rows[1]:Show()
		p.rows[1].icon:SetTexture(nil)
		p.rows[1].name:SetText("이 빌드의 순서를 다 찍었어요")
		p.rows[1].sub:SetText("")
		p.rows[1].lv:SetText("")
	end
	local foot = "wowf.io 레벨업 순서 · 출시 후 바뀔 수 있음"
	if (self.missing or 0) > 0 then foot = foot .. string.format("\n게임 특성과 안 맞는 단계 %d개는 건너뜀", self.missing) end
	p.foot:SetText(foot)
end

function M:HookFrame()
	if self.hooked then return end
	local f = TalentFrame()
	if not f then return end
	self.hooked = true
	f:HookScript("OnShow", function() M:PaintFrame() end)
	f:HookScript("OnHide", function() if M.panel then M.panel:Hide() end end)
	for _, fn in ipairs({ "TalentFrame_Update", "PlayerTalentFrame_Update", "PlayerTalentFrame_Refresh" }) do
		if type(_G[fn]) == "function" then hooksecurefunc(fn, function() M:PaintFrame() end) end
	end
end

-------------------------------------------------------------------------------
-- 포인트가 생기면 채팅에 추천
-------------------------------------------------------------------------------
function M:Remind()
	if Ink.db.talentGuide == false then return end
	local pts = Unspent()
	if pts <= 0 then return end
	local n = self:Next(1)[1]
	if not n then return end
	print(string.format("|cffFFF468FOA|r 특성 포인트 %d · 추천: |cffFFF468%s|r (%d/%d) · N 키로 특성 창", pts, n.name or "?", n.rank, n.max))
end

function M:Init()
	local build = select(4, GetBuildInfo()) or 0
	if not (build >= 16001 and build < 20000) then return end -- 포에버 전용 (본섭은 특성 체계가 다름)
	if not (GetNumTalentTabs and GetTalentInfo and ns.TalentData) then return end
	if #self:Builds() == 0 then return end
	self:HookFrame()
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event, arg)
		if event == "ADDON_LOADED" then
			if arg == "Blizzard_TalentUI" or arg == "Blizzard_PlayerTalentUI" then M:HookFrame() end
			return
		end
		M.resolved = nil
		if event == "PLAYER_LEVEL_UP" then
			C_Timer.After(1, function() M:Remind() end)
		elseif event == "CHARACTER_POINTS_CHANGED" then
			C_Timer.After(0.2, function() M:PaintFrame() end)
		else
			M:PaintFrame()
		end
	end)
	C_Timer.After(5, function() M:Remind() end)
end
