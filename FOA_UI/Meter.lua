-- FOA UI · 미터기 (피해량 / DPS / 치유 …)
--  12.x 부터 전투 기록(전투 로그)은 애드온이 직접 못 읽는다. 대신 블리자드가 집계해 주는
--  C_DamageMeter 데이터를 FOA 디자인으로 보여 준다. (Details! 와 같은 방식)
--  전투 중 값은 비공개(secret)라서 계산은 하지 않고 위젯에 그대로 넘긴다 (막대·글자 모두 안전).
--  · 제목 클릭: 보기 종류 / 현재·전체 전투 / 초기화 메뉴
--  · 오른쪽 위: 현재 / 전체 전환, 전투 시간

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Meter")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local W, HEAD, ROW, ROWS = 300, 30, 20, 8

-- 막대가 새 값까지 미끄러지듯 차오르게 (엔진 보간이라 비공개 값도 그대로 된다)
local SMOOTH = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local function SetBar(bar, v)
	if SMOOTH and pcall(bar.SetValue, bar, v, SMOOTH) then return end
	pcall(bar.SetValue, bar, v)
end

-- 1·2·3등 색 (금 / 은 / 동), 나머지는 흐리게
local RANK = { { 1, 0.86, 0.38 }, { 0.80, 0.84, 0.90 }, { 0.86, 0.58, 0.38 } }

local DMT = Enum.DamageMeterType or {}
local SESSION = Enum.DamageMeterSessionType or { Overall = 0, Current = 1 }
local MODES = {
	{ type = DMT.DamageDone or 0, name = "피해량", rate = false },
	{ type = DMT.Dps or 1, name = "초당 피해", rate = true },
	{ type = DMT.HealingDone or 2, name = "치유량", rate = false },
	{ type = DMT.Hps or 3, name = "초당 치유", rate = true },
	{ type = DMT.Absorbs or 4, name = "보호막", rate = false },
	{ type = DMT.DamageTaken or 7, name = "받은 피해", rate = false },
	{ type = DMT.Interrupts or 5, name = "차단", count = true },
	{ type = DMT.Dispels or 6, name = "해제", count = true },
}

-- 미터기용 숫자 축약 (1천부터 k)
local ABBR = { breakpointData = {
	{ breakpoint = 1e9, abbreviation = "b", significandDivisor = 1e7, fractionDivisor = 100, abbreviationIsGlobal = false },
	{ breakpoint = 1e6, abbreviation = "m", significandDivisor = 1e4, fractionDivisor = 100, abbreviationIsGlobal = false },
	{ breakpoint = 1e3, abbreviation = "k", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
	-- 1천 미만은 소수점 없이 정수로 (초당 피해 9.4666… 같은 표시 방지)
	{ breakpoint = 1, abbreviation = "", significandDivisor = 1, fractionDivisor = 1, abbreviationIsGlobal = false },
	{ breakpoint = 0, abbreviation = "", significandDivisor = 1, fractionDivisor = 1, abbreviationIsGlobal = false },
} }
local function Abbr(v)
	-- 전투 밖(일반 숫자)이면 직접 정리
	local p = plain(v)
	if type(p) == "number" and p < 1000 then return tostring(math.floor(p + 0.5)) end
	local ok, s = pcall(AbbreviateNumbers, v, ABBR)
	if ok and s then return s end
	ok, s = pcall(AbbreviateNumbers, v)
	return ok and s or ""
end

local function Clock(sec)
	sec = plain(sec)
	if not sec then return "" end
	sec = math.floor(sec)
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-------------------------------------------------------------------------------
-- 만들기
-------------------------------------------------------------------------------
local function Row(parent, i)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(W - 12, ROW - 2)
	r:SetPoint("TOPLEFT", 6, -HEAD - (i - 1) * ROW)
	r.bar = CreateFrame("StatusBar", nil, r)
	r.bar:SetAllPoints()
	r.bar:SetStatusBarTexture(Ink.tex.white)
	r.bar:SetMinMaxValues(0, 1)
	r.bar:SetValue(0)
	r.edge = r.bar:CreateTexture(nil, "OVERLAY")
	r.edge:SetWidth(2)
	r.edge:SetPoint("TOPLEFT")
	r.edge:SetPoint("BOTTOMLEFT")
	-- 차오르는 끝부분 빛줄 (막대 끝을 따라 움직인다)
	r.tip = r.bar:CreateTexture(nil, "OVERLAY")
	r.tip:SetWidth(2)
	r.tip:SetPoint("TOPRIGHT", r.bar:GetStatusBarTexture(), "TOPRIGHT")
	r.tip:SetPoint("BOTTOMRIGHT", r.bar:GetStatusBarTexture(), "BOTTOMRIGHT")
	-- 글자·아이콘은 막대보다 위 층에 (막대가 자식 프레임이라 그냥 두면 덮인다)
	r.over = CreateFrame("Frame", nil, r)
	r.over:SetAllPoints()
	r.over:SetFrameLevel(r.bar:GetFrameLevel() + 2)
	-- 순위: 막대 왼쪽 끝에 따로 칸을 둔다
	r.rank = Ink:Text(r.over, F.latinB, 10, C.dim, "CENTER", "OVERLAY")
	r.rank:SetPoint("LEFT", 4, 0)
	r.rank:SetWidth(16)
	r.icon = r.over:CreateTexture(nil, "OVERLAY")
	r.icon:SetSize(14, 14)
	r.icon:SetPoint("LEFT", 22, 0)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local m = r.over:CreateMaskTexture()
	m:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m:SetAllPoints(r.icon)
	r.icon:AddMaskTexture(m)
	r.name = Ink:Text(r.over, F.semi, 11, C.text, "LEFT", "OVERLAY")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 7, 0)
	r.name:SetWidth(118)
	r.value = Ink:Text(r.over, F.latin, 11, C.text, "RIGHT", "OVERLAY")
	r.value:SetPoint("RIGHT", -8, 0)
	if ns.FX then pcall(ns.FX.AttachMeterRow, r, ROW - 2) end
	r:Hide()
	return r
end

function M:Build()
	local f = CreateFrame("Frame", "FOAMeter", Ink.root)
	f:SetSize(W, HEAD + ROWS * ROW + 8)
	f:SetFrameStrata("LOW")
	self.frame = f
	f.bg = Ink:Round(f, "BACKGROUND", false, false, -8)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(0.035, 0.04, 0.052, 0.86)
	f.bd = Ink:Round(f, "BORDER", false, true, -8)
	f.bd:SetAllPoints()
	f.bd:SetVertexColor(1, 1, 1, 0.07)
	f.accent = f:CreateTexture(nil, "ARTWORK")
	f.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
	f.accent:SetSize(22, 2)
	f.accent:SetPoint("TOPLEFT", 12, -1)

	-- 제목 (누르면 메뉴)
	local head = CreateFrame("Button", nil, f)
	head:SetPoint("TOPLEFT", 6, -2)
	head:SetSize(170, HEAD - 4)
	head:RegisterForClicks("AnyUp")
	f.title = Ink:Text(head, F.bold, 13, C.text, "LEFT")
	f.title:SetPoint("LEFT", 6, 0)
	f.caret = Ink:Text(head, F.sans, 10, C.dim, "LEFT")
	f.caret:SetPoint("LEFT", f.title, "RIGHT", 5, -1)
	f.caret:SetText("변경")
	head:SetScript("OnClick", function(self) M:OpenMenu(self) end)
	head:SetScript("OnEnter", function() f.caret:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end)
	head:SetScript("OnLeave", function() f.caret:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end)

	-- 현재 / 전체 전환 + 시간
	local ses = CreateFrame("Button", nil, f)
	ses:SetSize(44, 20)
	ses:SetPoint("TOPRIGHT", -8, -5)
	ses.bg = Ink:Round(ses, "BACKGROUND", true, false)
	ses.bg:SetAllPoints()
	ses.bg:SetVertexColor(1, 1, 1, 0.06)
	ses.text = Ink:Text(ses, F.semi, 10, C.soft, "CENTER")
	ses.text:SetPoint("CENTER", 0, 0)
	ses:SetScript("OnClick", function()
		Ink.db.meterSession = (Ink.db.meterSession == SESSION.Overall) and SESSION.Current or SESSION.Overall
		M:Refresh()
	end)
	f.ses = ses
	f.time = Ink:Text(f, F.latin, 11, C.muted, "RIGHT")
	f.time:SetPoint("RIGHT", ses, "LEFT", -8, 0)

	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetColorTexture(1, 1, 1, 0.05)
	f.line:SetHeight(1)
	f.line:SetPoint("TOPLEFT", 10, -HEAD + 2)
	f.line:SetPoint("TOPRIGHT", -10, -HEAD + 2)

	f.rows = {}
	for i = 1, ROWS do f.rows[i] = Row(f, i) end
	f.empty = Ink:Text(f, F.sans, 11, C.dim, "CENTER")
	f.empty:SetPoint("CENTER", 0, -HEAD / 2)
	f.empty:SetText("아직 전투 기록이 없어요")

	Ink:Movable("meter", "미터기", f, "bottomright", 16, 48)
end

-------------------------------------------------------------------------------
-- 메뉴
-------------------------------------------------------------------------------
function M:Mode()
	local idx = Ink.db.meterMode or 1
	return MODES[idx] or MODES[1], idx
end

function M:OpenMenu(owner)
	if MenuUtil and MenuUtil.CreateContextMenu then
		local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
			root:CreateTitle("보기")
			for i, m in ipairs(MODES) do
				root:CreateRadio(m.name, function() return (Ink.db.meterMode or 1) == i end, function()
					Ink.db.meterMode = i
					M:Refresh()
				end)
			end
			root:CreateDivider()
			root:CreateTitle("전투")
			root:CreateRadio("현재 전투", function() return Ink.db.meterSession ~= SESSION.Overall end, function()
				Ink.db.meterSession = SESSION.Current
				M:Refresh()
			end)
			root:CreateRadio("전체", function() return Ink.db.meterSession == SESSION.Overall end, function()
				Ink.db.meterSession = SESSION.Overall
				M:Refresh()
			end)
			root:CreateDivider()
			root:CreateButton("|cffFF6B5E기록 초기화|r", function()
				if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then pcall(C_DamageMeter.ResetAllCombatSessions) end
				M:Refresh()
			end)
		end)
		if ok then return end
	end
	-- 메뉴를 못 쓰면 다음 보기로 넘긴다
	local _, idx = self:Mode()
	Ink.db.meterMode = idx % #MODES + 1
	self:Refresh()
end

-------------------------------------------------------------------------------
-- 그리기
-------------------------------------------------------------------------------
local function Paint(r, src, maxAmount, mode, rank)
	local class = plain(src.classFilename)
	local cr, cg, cb = ns.ClassColorOf(class)
	r.bar:SetStatusBarColor(cr, cg, cb, 0.3)
	r.edge:SetColorTexture(cr, cg, cb, 0.9)
	r.tip:SetColorTexture(cr, cg, cb, 0.85)
	pcall(r.bar.SetMinMaxValues, r.bar, 0, maxAmount)
	SetBar(r.bar, mode.rate and src.amountPerSecond or src.totalAmount)
	r.icon:SetTexture(src.specIconID)
	r.rank:SetText(rank)
	local rc = RANK[rank] or C.dim
	r.rank:SetTextColor(rc[1], rc[2], rc[3])
	r.name:SetText(src.name or "")
	r.name:SetTextColor(cr, cg, cb)
	local main = mode.rate and src.amountPerSecond or src.totalAmount
	local text
	if mode.count then
		text = Abbr(main)
	else
		local sub = mode.rate and src.totalAmount or src.amountPerSecond
		local ok, s = pcall(function() return Abbr(main) .. "  |cff8E939B" .. Abbr(sub) .. "|r" end)
		text = ok and s or Abbr(main)
	end
	r.value:SetText(text)
	r:SetAlpha(1)
	r:Show()
	-- 효과: 순위가 바뀐 줄은 미끄러져 들어오고, 1등 줄엔 은은한 빛
	local fx = ns.FX
	if fx then
		local nm = plain(src.name)
		local ok = not M.testing or fx.demoOn("meterSlide")
		if ok and nm and r.fxName and r.fxName ~= nm and M.prevRank then
			local from = M.prevRank[nm]
			if from and from ~= rank then
				local dy = math.max(-2, math.min(2, rank - from)) * ROW
				r.fxSlide(dy)
			end
		end
		r.fxName = nm
		if nm and M.curRank then M.curRank[nm] = rank end
		fx.MeterTop(r, rank == 1 and (not M.testing or fx.demoOn("meterGlow")), cr, cg, cb)
	end
end

-- 사람 수에 맞춰 창 높이 (최소 3줄)
function M:FitHeight(n)
	local h = HEAD + math.max(3, math.min(n, ROWS)) * ROW + 6
	self.frame:SetHeight(h)
	if self.threat then self.threat:SetHeight(h) end
end

function M:Refresh()
	local f = self.frame
	if not f then return end
	local mode = self:Mode()
	f.title:SetText(mode.name)
	local sesType = Ink.db.meterSession == SESSION.Overall and SESSION.Overall or SESSION.Current
	f.ses.text:SetText(sesType == SESSION.Overall and "전체" or "현재")

	if self.testing then return self:PaintTest(mode) end

	local session
	if C_DamageMeter and C_DamageMeter.GetCombatSessionFromType then
		local ok, s = pcall(C_DamageMeter.GetCombatSessionFromType, sesType, mode.type)
		if ok then session = s end
	end
	local list = session and session.combatSources or {}
	local maxAmount = session and session.maxAmount or 0
	local shown = 0
	self.curRank = {}
	for i = 1, ROWS do
		local src = list[i]
		if src then
			shown = i
			pcall(Paint, f.rows[i], src, maxAmount, mode, i)
		else
			f.rows[i]:Hide()
		end
	end
	self.prevRank = self.curRank
	f.empty:SetShown(shown == 0)
	self:FitHeight(shown)
	local dur = C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds and C_DamageMeter.GetSessionDurationSeconds(sesType)
	f.time:SetText(Clock(dur))
end

-------------------------------------------------------------------------------
-- 위협 수준 (어그로) - 미터기 왼쪽에 붙는다
--  지금 대상에 대한 내 위협 + 파티원(레이드면 탱커) 위협.
--  전투 중 값이 비공개일 수 있어 정렬하지 않고, 막대·글자에 그대로 넘긴다.
-------------------------------------------------------------------------------
local TW, TROWS = 190, 6

function M:BuildThreat()
	local f = CreateFrame("Frame", "FOAThreat", self.frame)
	f:SetSize(TW, self.frame:GetHeight())
	f:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMLEFT", -8, 0)
	self.threat = f
	f.bg = Ink:Round(f, "BACKGROUND", false, false, -8)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(0.035, 0.04, 0.052, 0.86)
	f.bd = Ink:Round(f, "BORDER", false, true, -8)
	f.bd:SetAllPoints()
	f.bd:SetVertexColor(1, 1, 1, 0.07)
	f.accent = f:CreateTexture(nil, "ARTWORK")
	f.accent:SetColorTexture(C.red[1], C.red[2], C.red[3], 0.95)
	f.accent:SetSize(22, 2)
	f.accent:SetPoint("TOPLEFT", 12, -1)
	f.title = Ink:Text(f, F.bold, 13, C.text, "LEFT")
	f.title:SetPoint("TOPLEFT", 12, -9)
	f.title:SetText("위협")
	f.target = Ink:Text(f, F.sans, 10, C.muted, "RIGHT")
	f.target:SetPoint("TOPRIGHT", -10, -11)
	f.target:SetWidth(TW - 60)
	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetColorTexture(1, 1, 1, 0.05)
	f.line:SetHeight(1)
	f.line:SetPoint("TOPLEFT", 10, -HEAD + 2)
	f.line:SetPoint("TOPRIGHT", -10, -HEAD + 2)
	f.rows = {}
	for i = 1, TROWS do
		local r = CreateFrame("Frame", nil, f)
		r:SetSize(TW - 12, ROW - 2)
		r:SetPoint("TOPLEFT", 6, -HEAD - (i - 1) * ROW)
		r.bar = CreateFrame("StatusBar", nil, r)
		r.bar:SetAllPoints()
		r.bar:SetStatusBarTexture(Ink.tex.white)
		r.bar:SetMinMaxValues(0, 100)
		r.edge = r:CreateTexture(nil, "ARTWORK")
		r.edge:SetWidth(2)
		r.edge:SetPoint("TOPLEFT")
		r.edge:SetPoint("BOTTOMLEFT")
		r.over = CreateFrame("Frame", nil, r)
		r.over:SetAllPoints()
		r.over:SetFrameLevel(r.bar:GetFrameLevel() + 2)
		r.tank = r.over:CreateTexture(nil, "OVERLAY")
		r.tank:SetTexture(Ink.tex.roleTank)
		r.tank:SetSize(11, 11)
		r.tank:SetPoint("LEFT", 7, 0)
		r.tank:SetVertexColor(C.red[1], C.red[2], C.red[3])
		r.name = Ink:Text(r.over, F.semi, 11, C.text, "LEFT", "OVERLAY")
		r.name:SetPoint("LEFT", 22, 0)
		r.name:SetWidth(TW - 80)
		r.value = Ink:Text(r.over, F.latin, 11, C.text, "RIGHT", "OVERLAY")
		r.value:SetPoint("RIGHT", -8, 0)
		r:Hide()
		f.rows[i] = r
	end
	f.empty = Ink:Text(f, F.sans, 11, C.dim, "CENTER")
	f.empty:SetPoint("CENTER", 0, -HEAD / 2)
	f.empty:SetText("전투 중인 대상이 없어요")
end

local function ThreatUnits()
	local list = { "player" }
	if IsInRaid() then
		for i = 1, 40 do
			local u = "raid" .. i
			if UnitExists(u) and not UnitIsUnit(u, "player") and UnitGroupRolesAssigned(u) == "TANK" then list[#list + 1] = u end
		end
	elseif IsInGroup() then
		for i = 1, 4 do
			if UnitExists("party" .. i) then list[#list + 1] = "party" .. i end
		end
	end
	if UnitExists("pet") then list[#list + 1] = "pet" end
	return list
end

local function PaintThreat(r, name, class, pct, tanking)
	local cr, cg, cb = ns.ClassColorOf(class)
	r.bar:SetStatusBarColor(cr, cg, cb, 0.2)
	r.edge:SetColorTexture(cr, cg, cb, 0.9)
	r.name:SetText(name or "")
	r.name:SetTextColor(cr, cg, cb)
	SetBar(r.bar, pct or 0)
	local ok, txt = pcall(string.format, "%.0f%%", pct or 0)
	r.value:SetText(ok and txt or "")
	-- 대상의 공격을 받고 있으면 방패 표시 (비공개 참/거짓도 안전하게)
	if r.tank.SetAlphaFromBoolean and tanking ~= nil then
		pcall(r.tank.SetAlphaFromBoolean, r.tank, tanking, 1, 0.15)
	else
		r.tank:SetAlpha(plain(tanking) and 1 or 0.15)
	end
	r:Show()
end

function M:RefreshThreat()
	local f = self.threat
	if not f then return end
	if self.testing then
		local fake = { { "방패벽", "WARRIOR", 100, true }, { "디피킹", "ROGUE", 87 }, { "얼음꽃", "MAGE", 64 }, { "빛의서약", "PALADIN", 21 } }
		for i = 1, TROWS do
			local d = fake[i]
			if d then PaintThreat(f.rows[i], d[1], d[2], d[3], d[4] or false) else f.rows[i]:Hide() end
		end
		f.target:SetText("훈련용 허수아비")
		f.empty:Hide()
		return
	end
	local has = UnitExists("target") and plain(UnitCanAttack("player", "target"))
	local n = 0
	if has then
		f.target:SetText(UnitName("target") or "")
		for _, u in ipairs(ThreatUnits()) do
			if n >= TROWS then break end
			local ok, tanking, _, scaled = pcall(UnitDetailedThreatSituation, u, "target")
			if ok and scaled ~= nil then
				n = n + 1
				local _, class = UnitClass(u)
				PaintThreat(f.rows[n], UnitName(u), plain(class), scaled, tanking)
			end
		end
	else
		f.target:SetText("")
	end
	for i = n + 1, TROWS do f.rows[i]:Hide() end
	f.empty:SetShown(n == 0)
end

-- 테스트 모드 예시
local FAKE = {
	{ "방패벽", "WARRIOR", 132355, 4.82e6, 32100 }, { "디피킹", "ROGUE", 132320, 4.41e6, 29400 },
	{ "얼음꽃", "MAGE", 135846, 3.97e6, 26500 }, { "매의눈", "HUNTER", 461112, 3.55e6, 23700 },
	{ "그림자손", "WARLOCK", 136145, 2.9e6, 19300 }, { "빛의서약", "PALADIN", 135920, 1.1e6, 7300 },
}
-- 테스트 모드: 시간이 지나며 딜이 쌓이고 순위도 뒤바뀌는 가짜 전투
function M:PaintTest(mode)
	local f = self.frame
	self.testStart = self.testStart or GetTime()
	local t = GetTime() - self.testStart + 1
	local list = {}
	for i, d in ipairs(FAKE) do
		-- 사람마다 딜 타이밍이 출렁이게 (쿨기 / 이동 구간 흉내)
		local wave = 1 + 0.35 * math.sin(t * (0.35 + i * 0.07) + i * 1.3)
		local dps = d[5] * wave
		local total = d[5] * t + d[5] * 2.2 * math.sin(t * (0.35 + i * 0.07) + i * 1.3) / (0.35 + i * 0.07) * 0.35
		list[i] = { name = d[1], classFilename = d[2], specIconID = d[3], totalAmount = math.max(0, total), amountPerSecond = dps }
	end
	local key = mode.rate and "amountPerSecond" or "totalAmount"
	table.sort(list, function(a, b) return a[key] > b[key] end)
	local top = list[1] and list[1][key] or 1
	self.curRank = {}
	for i = 1, ROWS do
		if list[i] then
			pcall(Paint, f.rows[i], list[i], top, mode, i)
		else
			f.rows[i]:Hide()
		end
	end
	self.prevRank = self.curRank
	f.empty:Hide()
	self:FitHeight(#FAKE)
	f.time:SetText(Clock(t))
end

function M:SetTest(on)
	self.testing = on
	self.testStart = nil
	self:Refresh()
	self:RefreshThreat()
end

function M:Schedule()
	if self.pending then return end
	self.pending = true
	C_Timer.After(0.25, function()
		M.pending = nil
		M:Refresh()
	end)
end

function M:Init()
	if Ink.db.meter == false then return end
	if not C_DamageMeter then return end
	-- 블리자드 미터기 집계를 켜고, 블리자드 미터기 창은 숨긴다 (FOA 창이 대신 보여 준다)
	if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("damageMeterEnabled") == "0" then
		pcall(C_CVar.SetCVar, "damageMeterEnabled", "1")
	end
	if DamageMeter then Ink:Disable(DamageMeter, true) end
	self:Build()
	if Ink.db.threat ~= false then self:BuildThreat() end
	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
		"DAMAGE_METER_RESET", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
		"UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	e:SetScript("OnEvent", function(_, event)
		if event:find("THREAT") or event == "PLAYER_TARGET_CHANGED" or event == "GROUP_ROSTER_UPDATE" then
			M:RefreshThreat()
		else
			M:Schedule()
		end
	end)
	-- 전투 중엔 시간·값이 계속 바뀌니 0.3초마다 (막대는 그 사이를 부드럽게 채운다)
	local t = 0
	e:SetScript("OnUpdate", function(_, el)
		t = t + el
		if t < 0.3 then return end
		t = 0
		if M.testing or InCombatLockdown() or UnitAffectingCombat("player") then
			M:Refresh()
			M:RefreshThreat()
		end
	end)
	self:Refresh()
	self:RefreshThreat()
end
