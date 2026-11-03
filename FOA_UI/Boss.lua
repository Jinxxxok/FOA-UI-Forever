-- FOA UI · 보스 알림 (DBM / BigWigs 같은 역할)
--  12.x 부터 보스 패턴 정보는 블리자드가 직접 내려 준다 (C_EncounterTimeline / C_EncounterWarnings).
--  그 데이터를 FOA 디자인으로 보여 준다.
--   · 패턴 타이머 막대: 다음에 올 기술이 가까운 순서대로 (아이콘 · 이름 · 남은 시간 · 얇은 진행 막대)
--   · 경고 문구: 화면 위쪽 가운데에 크게 (치명적인 기술은 붉은 빛)
--  블리자드 기본 타이머/경고 창은 숨긴다. 기술 이름·아이콘은 비공개 값이라 그대로 위젯에 넘긴다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Boss")
local F, C = Ink.font, Ink.c
local plain = Ink.plain

local BAR_W, BAR_H, BAR_GAP, MAX_BARS = 270, 30, 6, 7

local TL = C_EncounterTimeline
local WR = C_EncounterWarnings

-------------------------------------------------------------------------------
-- 타이머 막대
--  [아이콘] [ 이름 ················ 12.3 ]   ← 막대 전체가 남은 시간만큼 옅게 채워지고
--                                             채움 끝에 밝은 빛 줄기(스파크)
--  5초 이하: 시간 빨강 + 테두리 빛 깜빡임 + 살짝 커짐 / 0초: "지금"
-------------------------------------------------------------------------------
local function NewBar(parent)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(BAR_W, BAR_H)

	-- 아이콘 (둥근 사각 + 기술 색 테두리)
	b.ic = CreateFrame("Frame", nil, b)
	b.ic:SetSize(BAR_H, BAR_H)
	b.ic:SetPoint("LEFT")
	b.ic.bg = Ink:Round(b.ic, "BACKGROUND", true, false, -8)
	b.ic.bg:SetAllPoints()
	b.ic.bg:SetVertexColor(0, 0, 0, 0.7)
	b.icon = b.ic:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 2, -2)
	b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local m = b.ic:CreateMaskTexture()
	m:SetTexture(Ink.tex.round4, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m:SetAllPoints(b.icon)
	b.icon:AddMaskTexture(m)
	b.ic.bd = Ink:Round(b.ic, "OVERLAY", true, true)
	b.ic.bd:SetAllPoints()

	-- 몸통
	b.body = CreateFrame("Frame", nil, b)
	b.body:SetPoint("TOPLEFT", b.ic, "TOPRIGHT", 5, 0)
	b.body:SetPoint("BOTTOMRIGHT")
	b.bg = Ink:Round(b.body, "BACKGROUND", true, false, -8)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(0.035, 0.04, 0.052, 0.88)
	b.glow = b.body:CreateTexture(nil, "BACKGROUND", nil, -8)
	b.glow:SetTexture(Ink.tex.glow)
	b.glow:SetPoint("TOPLEFT", -16, 14)
	b.glow:SetPoint("BOTTOMRIGHT", 16, -14)
	b.glow:SetVertexColor(C.red[1], C.red[2], C.red[3])
	b.glow:SetAlpha(0)

	b.bar = CreateFrame("StatusBar", nil, b.body)
	b.bar:SetPoint("TOPLEFT", 1, -1)
	b.bar:SetPoint("BOTTOMRIGHT", -1, 1)
	b.bar:SetStatusBarTexture(Ink.tex.white)
	b.bar:SetMinMaxValues(0, 1)
	b.bar:SetValue(1)
	b.spark = b.bar:CreateTexture(nil, "OVERLAY")
	b.spark:SetTexture(Ink.tex.glow)
	b.spark:SetBlendMode("ADD")
	b.spark:SetSize(14, BAR_H + 6)
	b.spark:SetPoint("CENTER", b.bar:GetStatusBarTexture(), "RIGHT", 0, 0)
	b.edge = b.bar:CreateTexture(nil, "OVERLAY", nil, 1)
	b.edge:SetWidth(2)
	b.edge:SetPoint("TOPRIGHT", b.bar:GetStatusBarTexture(), "TOPRIGHT")
	b.edge:SetPoint("BOTTOMRIGHT", b.bar:GetStatusBarTexture(), "BOTTOMRIGHT")
	b.edge:SetColorTexture(1, 1, 1, 0.9)
	b.bd = Ink:Round(b.body, "BORDER", true, true, -8)
	b.bd:SetAllPoints()
	b.bd:SetVertexColor(1, 1, 1, 0.07)

	b.text = CreateFrame("Frame", nil, b.body)
	b.text:SetAllPoints()
	b.text:SetFrameLevel(b.bar:GetFrameLevel() + 2)
	b.name = Ink:Text(b.text, F.semi, 12, C.text, "LEFT")
	b.name:SetPoint("LEFT", 10, 0)
	b.name:SetWidth(BAR_W - BAR_H - 70)
	b.time = Ink:Text(b.text, F.latinB, 14, C.text, "RIGHT")
	b.time:SetPoint("RIGHT", -10, 0)
	b:Hide()
	return b
end

local function SetColor(b, r, g, bl)
	b.bar:SetStatusBarColor(r, g, bl, 0.24)
	b.spark:SetVertexColor(r, g, bl, 0.9)
	b.ic.bd:SetVertexColor(r, g, bl, 0.9)
end

local function TimeText(sec)
	sec = plain(sec)
	if not sec then return "" end
	if sec <= 0.05 then return "0.0" end
	if sec < 10 then return string.format("%.1f", sec) end
	if sec < 60 then return string.format("%d", sec) end
	return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

-- 남은 시간에 따른 강조 (5초 이하)
local function Urgency(b, rem)
	local soon = rem and rem <= 5
	local c = soon and C.red or C.text
	b.time:SetTextColor(c[1], c[2], c[3])
	if soon then
		local pulse = 0.5 + 0.5 * math.sin(GetTime() * 9)
		b.glow:SetAlpha(0.18 + 0.22 * pulse)
		b.bd:SetVertexColor(C.red[1], C.red[2], C.red[3], 0.35 + 0.3 * pulse)
	else
		b.glow:SetAlpha(0)
		b.bd:SetVertexColor(1, 1, 1, 0.07)
	end
end

function M:BuildBars()
	local f = CreateFrame("Frame", "FOABossBars", Ink.root)
	f:SetSize(BAR_W, MAX_BARS * (BAR_H + BAR_GAP))
	self.barFrame = f
	-- 머리글
	f.title = Ink:Text(f, F.semi, 11, C.muted, "LEFT")
	f.title:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 6)
	f.title:SetText("보스 패턴")
	f.accent = f:CreateTexture(nil, "ARTWORK")
	f.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
	f.accent:SetSize(16, 2)
	f.accent:SetPoint("BOTTOMLEFT", f.title, "TOPLEFT", 0, 3)
	f.title:Hide()
	f.accent:Hide()
	f.headerOn = false
	self.bars = {}
	for i = 1, MAX_BARS do
		local b = NewBar(f)
		b:SetPoint("TOPLEFT", 0, -(i - 1) * (BAR_H + BAR_GAP))
		self.bars[i] = b
	end
	Ink:Movable("bossBars", "보스 타이머", f, "center", 1240, 330)
end

-- 테스트용 가짜 패턴 (이름, 아이콘, 주기, 색)
local FAKE = {
	{ "어둠의 심연", 136201, 9, C.red },
	{ "공허 일격", 136222, 14, C.orange },
	{ "화염 폭풍", 135807, 21, C.orange },
	{ "그림자 사슬", 136122, 30, C.mana },
	{ "분노의 포효", 132117, 45, C.soft },
}

-- "보스 패턴" 머리글은 막대가 하나라도 있을 때만
function M:Header(on)
	local f = self.barFrame
	if not f or f.headerOn == on then return end
	f.headerOn = on
	f.title:SetShown(on)
	f.accent:SetShown(on)
end

function M:PaintFake()
	local now = GetTime()
	self.fakeStart = self.fakeStart or now
	local list = {}
	for i, d in ipairs(FAKE) do
		local period = d[3] + 2
		local t = (now - self.fakeStart + i * 1.7) % period
		list[#list + 1] = { d = d, rem = d[3] - t }
	end
	table.sort(list, function(a, b) return a.rem < b.rem end)
	for i = 1, MAX_BARS do
		local b, e = self.bars[i], list[i]
		if e then
			local d = e.d
			b.icon:SetTexture(d[2])
			b.name:SetText(d[1])
			SetColor(b, d[4][1], d[4][2], d[4][3])
			b.bar:SetMinMaxValues(0, d[3])
			b.bar:SetValue(math.max(0, e.rem))
			b.time:SetText(TimeText(math.max(0, e.rem)))
			Urgency(b, e.rem)
			b:Show()
		else
			b:Hide()
		end
	end
	self:Header(#list > 0)
end

function M:UpdateBars(full)
	if not self.bars then return end
	if self.testing then return self:PaintFake() end
	local ok, list = pcall(TL.GetSortedEventList, MAX_BARS, nil, true, true)
	if not ok or type(list) ~= "table" then list = {} end
	for i = 1, MAX_BARS do
		local b = self.bars[i]
		local id = list[i]
		if id then
			if full or b.id ~= id then
				b.id = id
				local okI, info = pcall(TL.GetEventInfo, id)
				if okI and info then
					b.icon:SetTexture(info.iconFileID)
					b.name:SetText(info.spellName or "")
				end
				local okT, dur = pcall(TL.GetEventTimer, id)
				if okT and dur and b.bar.SetTimerDuration then
					pcall(b.bar.SetTimerDuration, b.bar, dur, Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate)
				end
				SetColor(b, C.orange[1], C.orange[2], C.orange[3])
				local okC, col = pcall(TL.GetEventColor, id)
				if okC and col then
					pcall(function()
						local r, g, bl = col:GetRGB()
						SetColor(b, r, g, bl)
					end)
				end
			end
			local okR, rem = pcall(TL.GetEventTimeRemaining, id)
			rem = okR and plain(rem) or nil
			b.time:SetText(TimeText(rem))
			Urgency(b, rem)
			b:Show()
		else
			b.id = nil
			b:Hide()
		end
	end
	self:Header(list[1] ~= nil)
end

-------------------------------------------------------------------------------
-- 경고 문구
-------------------------------------------------------------------------------
local function NewWarn(parent)
	local w = CreateFrame("Frame", nil, parent)
	w:SetSize(700, 46)
	w.glow = w:CreateTexture(nil, "BACKGROUND", nil, -8)
	w.glow:SetTexture(Ink.tex.glow)
	w.glow:SetPoint("TOPLEFT", 60, 30)
	w.glow:SetPoint("BOTTOMRIGHT", -60, -30)
	w.glow:SetVertexColor(C.red[1], C.red[2], C.red[3])
	w.glow:SetAlpha(0)
	w.text = Ink:Text(w, F.bold, 26, C.text, "CENTER")
	w.text:SetFont(F.bold, 26, "")
	w.text:SetShadowOffset(2, -2)
	w.text:SetPoint("CENTER", 14, 0)
	w.text:SetWidth(640)
	w.icon = w:CreateTexture(nil, "ARTWORK")
	w.icon:SetSize(36, 36)
	w.icon:SetPoint("RIGHT", w.text, "LEFT", -10, 0)
	w.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local m = w:CreateMaskTexture()
	m:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m:SetAllPoints(w.icon)
	w.icon:AddMaskTexture(m)
	w.line = w:CreateTexture(nil, "ARTWORK")
	w.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
	w.line:SetSize(40, 2)
	w.line:SetPoint("TOP", w.text, "BOTTOM", 0, -6)

	local ag = w:CreateAnimationGroup()
	local s1 = ag:CreateAnimation("Scale")
	s1:SetScaleFrom(1.25, 1.25)
	s1:SetScaleTo(1, 1)
	s1:SetDuration(0.18)
	s1:SetSmoothing("OUT")
	local a1 = ag:CreateAnimation("Alpha")
	a1:SetFromAlpha(0)
	a1:SetToAlpha(1)
	a1:SetDuration(0.15)
	w.pop = ag
	w:Hide()
	return w
end

function M:BuildWarnings()
	local f = CreateFrame("Frame", "FOABossWarnings", Ink.root)
	f:SetSize(700, 3 * 52)
	f:SetFrameStrata("HIGH")
	self.warnFrame = f
	self.warns = {}
	for i = 1, 3 do
		local w = NewWarn(f)
		w:SetPoint("TOP", 0, -(i - 1) * 52)
		self.warns[i] = w
	end
	self.warnIdx = 0
	Ink:Movable("bossWarn", "보스 경고", f, "center", 610, 220)
end

function M:ShowWarning(info, text)
	self.warnIdx = self.warnIdx % #self.warns + 1
	local w = self.warns[self.warnIdx]
	w.text:SetText(text or "")
	if info.color then
		pcall(function() w.text:SetTextColor(info.color:GetRGB()) end)
	else
		w.text:SetTextColor(C.text[1], C.text[2], C.text[3])
	end
	w.icon:SetTexture(info.iconFileID)
	-- 치명적인 기술이면 붉은 빛 (비공개 참/거짓이라 SetAlphaFromBoolean 사용)
	if w.glow.SetAlphaFromBoolean and info.isDeadly ~= nil then
		pcall(w.glow.SetAlphaFromBoolean, w.glow, info.isDeadly, 0.55, 0)
	else
		w.glow:SetAlpha(plain(info.isDeadly) and 0.55 or 0)
	end
	w:SetAlpha(1)
	w:Show()
	w.pop:Stop()
	w.pop:Play()
	local dur = plain(info.duration)
	if not dur or dur <= 0 then dur = 3.5 end
	w.until_ = GetTime() + dur
end

function M:OnWarning(info)
	if not info then return end
	-- 문구에 시전자 / 대상 이름이 들어간다
	local ok, text = pcall(string.format, info.text, info.casterName or "", info.targetName or "")
	if not ok then text = info.text end
	self:ShowWarning(info, text)
	if plain(info.shouldPlaySound) and WR.PlaySound then pcall(WR.PlaySound, info.severity) end
end

function M:TickWarnings()
	local now = GetTime()
	for _, w in ipairs(self.warns or {}) do
		if w:IsShown() and w.until_ then
			local left = w.until_ - now
			if left <= 0 then
				w:Hide()
			elseif left < 0.4 then
				w:SetAlpha(left / 0.4)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- 테스트 모드
-------------------------------------------------------------------------------
local SAMPLES = {
	{ "흩어지세요! 화염 폭풍", 135807, false },
	{ "탱커 교대: 공허 일격", 136222, false },
	{ "곧 전멸기: 어둠의 심연", 136201, true },
}
function M:SetTest(on)
	self.testing = on
	if not self.bars then return end
	if on then
		M.fakeStart = GetTime()
		local i = 0
		Ink:Loop("bossTest", function()
			if not M.testNext or GetTime() >= M.testNext then
				M.testNext = GetTime() + 4
				i = i % #SAMPLES + 1
				local s = SAMPLES[i]
				M:ShowWarning({ iconFileID = s[2], isDeadly = s[3], duration = 3 }, s[1])
			end
		end)
	else
		Ink:Loop("bossTest", nil)
		M.testNext = nil
		-- 테스트 경고 문구도 바로 치운다
		for _, w in ipairs(self.warns or {}) do w.pop:Stop(); w:Hide() end
	end
	self:UpdateBars(true)
end

-------------------------------------------------------------------------------
function M:HideBlizzard()
	-- 블리자드 타이머 화면은 "없음"으로, 경고 문구는 숨김 (소리는 FOA 쪽에서 낸다)
	if EncounterTimeline and EncounterTimeline.SetAttribute and Enum.EncounterTimelineViewType then
		pcall(EncounterTimeline.SetAttribute, EncounterTimeline, "overrideViewType", Enum.EncounterTimelineViewType.None)
	end
	if TL and TL.SetViewType and Enum.EncounterTimelineViewType then
		pcall(TL.SetViewType, Enum.EncounterTimelineViewType.None)
	end
	if WR and WR.SetWarningsShown then pcall(WR.SetWarningsShown, false) end
end

function M:Init()
	if Ink.db.bossMod == false or not TL or not WR then
		if WR and WR.SetWarningsShown then pcall(WR.SetWarningsShown, true) end
		return
	end
	-- 보스 타임라인 / 경고 기능 켜기
	for _, cv in ipairs({ "encounterTimelineEnabled", "encounterWarningsEnabled" }) do
		if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(cv) == "0" then pcall(C_CVar.SetCVar, cv, "1") end
	end
	self:BuildBars()
	self:BuildWarnings()
	self:HideBlizzard()

	local e = CreateFrame("Frame")
	for _, ev in ipairs({ "ENCOUNTER_TIMELINE_EVENT_ADDED", "ENCOUNTER_TIMELINE_EVENT_REMOVED",
		"ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", "ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED",
		"ENCOUNTER_TIMELINE_EVENT_COLOR_CHANGED", "ENCOUNTER_TIMELINE_VIEW_ACTIVATED",
		"ENCOUNTER_WARNING", "PLAYER_ENTERING_WORLD", "ENCOUNTER_START", "ENCOUNTER_END" }) do
		pcall(e.RegisterEvent, e, ev)
	end
	e:SetScript("OnEvent", function(_, event, a1)
		if event == "ENCOUNTER_WARNING" then
			pcall(M.OnWarning, M, a1)
		elseif event == "PLAYER_ENTERING_WORLD" or event == "ENCOUNTER_TIMELINE_VIEW_ACTIVATED" then
			M:HideBlizzard()
			M:UpdateBars(true)
		else
			M.dirty = true
		end
	end)
	-- 남은 시간은 0.1초마다, 순서·내용은 바뀌었을 때만 다시
	-- 테스트 막대는 매 프레임(부드럽게), 실제 막대는 엔진이 채움을 움직이니 글자만 0.1초마다
	local t = 0
	e:SetScript("OnUpdate", function(_, el)
		if M.testing then M:PaintFake() end
		t = t + el
		if t < 0.1 then return end
		t = 0
		if not M.testing then
			M:UpdateBars(M.dirty)
			M.dirty = nil
		end
		M:TickWarnings()
	end)
end
