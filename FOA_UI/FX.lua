-- FOA UI · 효과 (애니메이션 · 이펙트)
--  원칙: 짧고, 얇고, 한 번에 하나. 노란 강조색(accent)은 "지금 봐야 할 것"에만.
--  12.x 전투 중에는 체력 · 자원 수치가 비공개라 숫자로 판단하지 않는다.
--  색 · 투명도 · 막대 움직임은 엔진(곡선 · StatusBar)에 넘겨서 전투 중에도 동작한다.
--  효과마다 Ink.db.fx[key] == false 면 꺼진다 (설정 창 "효과").
--  테스트 모드에서는 효과마다 예시(Demo)가 돌아간다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("FX")
local F, C = Ink.font, Ink.c
local safe, plain = Ink.safe, Ink.plain

local FX = {}
ns.FX = FX
Ink.FX = FX

local MEDIA = "Interface\\AddOns\\FOA_UI\\Media\\"
local SMOOTH = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

-- 설정 창 · 테스트 목록 (순서 = 화면 표시 순서)
FX.LIST = {
	{ "trail", "체력 잔상", "맞은 만큼 흰 잔상이 남았다가 따라 줄어듦" },
	{ "lowHp", "저체력 화면 테두리", "35% 아래에서 화면 가장자리가 붉게 숨 쉼" },
	{ "powerFull", "자원 가득 빛", "자원이 가득 차면 바 위로 빛이 지나감" },
	{ "comboPop", "연계 점수 차오름", "칸이 은은하게 차오르고, 모일수록 색이 진해짐" },
	{ "manaLow", "마나 부족 깜빡임", "마나 20% 아래에서 바가 은은하게 깜빡" },
	{ "cdReady", "쿨 끝 빛 고리", "쿨이 끝나는 순간 아이콘에서 고리가 퍼짐" },
	{ "procBracket", "주문 강화 모서리", "발동 효과를 노란 모서리 괄호로" },
	{ "press", "눌림 반응", "키를 누르면 칸이 짧게 반짝" },
	{ "rangeDesat", "사거리 밖 흑백", "사거리 밖 · 자원 부족 주문은 흑백" },
	{ "castFinish", "시전 성공 · 차단", "성공하면 섬광, 차단되면 흔들림" },
	{ "interruptPing", "차단 가능 알림", "적이 차단 가능한 주문을 쓰면 이름표가 번쩍" },
	{ "targetBracket", "대상 괄호 조임", "대상을 바꾸면 양쪽 표시가 착 조여짐" },
	{ "aggroPulse", "어그로 맥박", "어그로를 끌면 이름표 테두리가 맥박" },
	{ "questPop", "퀘스트 진행 톡", "퀘스트 수치가 오르면 숫자가 톡" },
	{ "dispelPulse", "해제 디버프 숨쉬기", "해제할 디버프가 걸린 파티원이 숨 쉼", true },
	{ "deathFade", "사망 · 부활", "파티원이 죽으면 가라앉고, 살아나면 빛" },
	{ "readyCheck", "전투 준비 확인", "파티원 옆에 체크가 차례로 톡" },
	{ "levelUp", "레벨업 연출", "화면 가운데 큰 숫자와 펼쳐지는 선" },
	{ "lootToast", "전리품 알림", "희귀 이상 아이템을 얻으면 왼쪽에 알림" },
	{ "mailRipple", "우편 잔물결", "새 우편이 오면 미니맵에 잔물결" },
	{ "bossDrop", "보스 경고 등장", "보스 경고가 위에서 떨어지듯 + 선 펼침" },
	{ "meterSlide", "미터기 순위 이동", "순위가 바뀌면 줄이 미끄러지며 자리바꿈" },
	{ "meterGlow", "미터기 1등 빛", "1등 줄에 은은한 빛이 지나감" },
}

function FX.on(key)
	local t = Ink.db and Ink.db.fx
	return not (t and t[key] == false)
end

function FX.set(key, on)
	Ink.db.fx = Ink.db.fx or {}
	Ink.db.fx[key] = (not on) and false or nil
	if FX.onToggle[key] then pcall(FX.onToggle[key], on) end
end
FX.onToggle = {}

FX.demo = {}
function FX.demoOn(key) return FX.demo[key] and true or false end

-------------------------------------------------------------------------------
-- 공용 도구
-------------------------------------------------------------------------------
local function Anim(region, loop)
	local ag = region:CreateAnimationGroup()
	if loop then ag:SetLooping(loop) end
	return ag
end

local function A(ag, kind, dur, smooth, order, delay)
	local a = ag:CreateAnimation(kind)
	a:SetDuration(dur)
	if smooth then a:SetSmoothing(smooth) end
	if order then a:SetOrder(order) end
	if delay then a:SetStartDelay(delay) end
	return a
end
FX.Anim, FX.A = Anim, A

-- 빛 고리: 가운데서 퍼지며 사라진다 (+ 안쪽 섬광)
function FX.Ring(parent, size, color, level)
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(size, size)
	h:SetPoint("CENTER")
	h:SetFrameLevel(parent:GetFrameLevel() + (level or 6))
	h:EnableMouse(false)
	local col = color or C.accent
	local r = h:CreateTexture(nil, "OVERLAY")
	r:SetTexture(Ink.tex.ring)
	r:SetAllPoints()
	r:SetBlendMode("ADD")
	r:SetVertexColor(col[1], col[2], col[3])
	r:SetAlpha(0)
	local fl = h:CreateTexture(nil, "ARTWORK")
	fl:SetTexture(Ink.tex.glow)
	fl:SetPoint("TOPLEFT", -size * 0.35, size * 0.35)
	fl:SetPoint("BOTTOMRIGHT", size * 0.35, -size * 0.35)
	fl:SetBlendMode("ADD")
	fl:SetVertexColor(col[1], col[2], col[3])
	fl:SetAlpha(0)
	local ag = Anim(r)
	local s = A(ag, "Scale", 0.5, "OUT")
	s:SetScaleFrom(0.55, 0.55)
	s:SetScaleTo(1.75, 1.75)
	local a = A(ag, "Alpha", 0.5, "OUT")
	a:SetFromAlpha(0.95)
	a:SetToAlpha(0)
	local fg = Anim(fl)
	local fa = A(fg, "Alpha", 0.08, nil, 1)
	fa:SetFromAlpha(0)
	fa:SetToAlpha(0.55)
	local fb = A(fg, "Alpha", 0.4, "OUT", 2)
	fb:SetFromAlpha(0.55)
	fb:SetToAlpha(0)
	return function()
		ag:Stop(); fg:Stop()
		ag:Play(); fg:Play()
	end
end

-- 위에 덮는 짧은 섬광 (둥근 칸 모양)
function FX.Flash(parent, small, color, peak, dur, level)
	local h = CreateFrame("Frame", nil, parent)
	h:SetAllPoints()
	h:SetFrameLevel(parent:GetFrameLevel() + (level or 5))
	h:EnableMouse(false)
	local t = Ink:Round(h, "OVERLAY", small, false)
	t:SetAllPoints()
	t:SetBlendMode("ADD")
	local col = color or C.text
	t:SetVertexColor(col[1], col[2], col[3])
	t:SetAlpha(0)
	local ag = Anim(t)
	local a = A(ag, "Alpha", dur or 0.3, "OUT")
	a:SetFromAlpha(peak or 0.35)
	a:SetToAlpha(0)
	return function() ag:Stop(); ag:Play() end, t
end

-- 좌우 흔들림 (끝나면 제자리)
function FX.Shake(frame, amp)
	local ag = Anim(frame)
	amp = amp or 5
	for i, o in ipairs({ 1, -2, 1.6, -1.1, 0.5 }) do
		local t = A(ag, "Translation", 0.045, nil, i)
		t:SetOffset(o * amp, 0)
	end
	return function() ag:Stop(); ag:Play() end
end

-- 톡: 커졌다 제자리 (글자 · 아이콘)
function FX.Pop(region, from, dur)
	local ag = Anim(region)
	local s = A(ag, "Scale", dur or 0.22, "OUT")
	s:SetScaleFrom(from or 1.45, from or 1.45)
	s:SetScaleTo(1, 1)
	return function() ag:Stop(); ag:Play() end
end

-- 숨쉬기 반복 (Play / Stop 으로 켜고 끈다)
function FX.Breathe(region, lo, hi, dur)
	local ag = Anim(region, "BOUNCE")
	local a = A(ag, "Alpha", dur or 0.9, "IN_OUT")
	a:SetFromAlpha(hi or 1)
	a:SetToAlpha(lo or 0.35)
	return ag
end

-- 모서리 괄호: 바깥에서 착 조여 들어온 뒤 은은하게 숨 쉰다
function FX.Brackets(parent, pad, len, thick, color, level)
	local h = CreateFrame("Frame", nil, parent)
	h:SetPoint("TOPLEFT", -pad, pad)
	h:SetPoint("BOTTOMRIGHT", pad, -pad)
	h:SetFrameLevel(parent:GetFrameLevel() + (level or 8))
	h:EnableMouse(false)
	h:Hide()
	local col = color or C.accent
	h.corners = {}
	for _, d in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
		local pt, sx, sy = d[1], d[2], d[3]
		local c = CreateFrame("Frame", nil, h)
		c:SetSize(len, len)
		c:SetPoint(pt)
		local hz = c:CreateTexture(nil, "OVERLAY")
		hz:SetColorTexture(col[1], col[2], col[3], 1)
		hz:SetSize(len, thick)
		hz:SetPoint(pt)
		local vt = c:CreateTexture(nil, "OVERLAY")
		vt:SetColorTexture(col[1], col[2], col[3], 1)
		vt:SetSize(thick, len)
		vt:SetPoint(pt)
		local ag = Anim(c)
		local out = A(ag, "Translation", 0, nil, 1)
		out:SetOffset(-sx * 5, -sy * 5)
		local back = A(ag, "Translation", 0.24, "OUT", 2)
		back:SetOffset(sx * 5, sy * 5)
		local al = A(ag, "Alpha", 0.2, "OUT", 2)
		al:SetFromAlpha(0)
		al:SetToAlpha(1)
		c.ag = ag
		h.corners[#h.corners + 1] = c
	end
	h.breathe = FX.Breathe(h, 0.5, 1, 0.8)
	function h:Open()
		if self:IsShown() then return end
		self:Show()
		for _, c in ipairs(self.corners) do c.ag:Stop(); c.ag:Play() end
		self.breathe:Play()
	end
	function h:Close()
		self.breathe:Stop()
		self:Hide()
	end
	return h
end

-------------------------------------------------------------------------------
-- 1. 체력 잔상
--  원래 막대 뒤에 흰 막대를 하나 더 깔고, 0.4초 늦게 부드럽게 따라가게 한다.
--  값은 엔진에 그대로 넘겨서(비공개여도) 전투 중에도 동작한다.
-------------------------------------------------------------------------------
local trails = {}

function FX.Trail(bar, alpha)
	if not bar or bar.inkTrail then return bar and bar.inkTrail end
	local t = CreateFrame("StatusBar", nil, bar:GetParent())
	t:SetAllPoints(bar)
	t:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
	t:SetStatusBarTexture(Ink.tex.white)
	t:SetStatusBarColor(1, 1, 1, alpha or 0.38)
	t:SetMinMaxValues(0, 1)
	t:SetValue(0)
	t.bar = bar
	bar.inkTrail = t
	trails[#trails + 1] = t
	return t
end

local function TrailValue(t, v, smooth)
	if smooth and SMOOTH and pcall(t.SetValue, t, v, SMOOTH) then return end
	pcall(t.SetValue, t, v)
end

-- 실제 유닛 체력으로 (막대를 갱신한 직후에 부른다)
function FX.TrailSet(bar, unit)
	local t = bar and bar.inkTrail
	if not t then return end
	if not FX.on("trail") then t:Hide() return end
	t:Show()
	pcall(t.SetMinMaxValues, t, 0, UnitHealthMax(unit))
	if t.pending then return end
	t.pending = true
	C_Timer.After(0.4, function()
		t.pending = nil
		if UnitExists(unit) then TrailValue(t, UnitHealth(unit), true) end
	end)
end

-- 대상이 바뀌었을 때: 잔상 없이 바로 맞춘다
function FX.TrailSnap(bar, unit)
	local t = bar and bar.inkTrail
	if not t then return end
	t.pending = nil
	pcall(t.SetMinMaxValues, t, 0, UnitHealthMax(unit))
	TrailValue(t, UnitHealth(unit), false)
end

-- 가짜 값 (테스트 예시)
function FX.TrailFake(bar, v, max)
	local t = bar and bar.inkTrail
	if t then
		-- 잔상은 "지금 막대 값"에서 출발한다 (처음이면 0 이라 안 보이므로)
		pcall(function()
			local _, mx = bar:GetMinMaxValues()
			local cur = bar:GetValue() / (mx > 0 and mx or 1) * (max or 100)
			t:SetMinMaxValues(0, max or 100)
			if t:GetValue() < cur then t:SetValue(cur) end
		end)
	end
	bar:SetMinMaxValues(0, max or 100)
	bar:SetValue(v)
	if not t then return end
	t:SetShown(FX.on("trail"))
	t:SetMinMaxValues(0, max or 100)
	C_Timer.After(0.4, function() TrailValue(t, v, true) end)
end

-------------------------------------------------------------------------------
-- 2. 저체력 화면 테두리 (곡선: 체력 % → 붉은색 진하기)
-------------------------------------------------------------------------------
function M:BuildVignette()
	local v = CreateFrame("Frame", "FOAVignette", UIParent)
	v:SetAllPoints()
	v:SetFrameStrata("BACKGROUND")
	v:SetFrameLevel(0)
	v:EnableMouse(false)
	v.tex = v:CreateTexture(nil, "BACKGROUND")
	v.tex:SetAllPoints()
	v.tex:SetTexture(MEDIA .. "Textures\\Vignette")
	v.tex:SetVertexColor(C.red[1], C.red[2], C.red[3], 0)
	v.breathe = FX.Breathe(v, 0.5, 1, 0.85)
	v.breathe:Play()
	if C_CurveUtil and C_CurveUtil.CreateColorCurve then
		local c = C_CurveUtil.CreateColorCurve()
		c:SetType(Enum.LuaCurveType.Linear)
		c:AddPoint(0, CreateColor(C.red[1], C.red[2], C.red[3], 0.8))
		c:AddPoint(0.2, CreateColor(C.red[1], C.red[2], C.red[3], 0.5))
		c:AddPoint(0.35, CreateColor(C.red[1], C.red[2], C.red[3], 0))
		c:AddPoint(1, CreateColor(C.red[1], C.red[2], C.red[3], 0))
		v.curve = c
	end
	self.vignette = v
	local e = CreateFrame("Frame")
	e:RegisterUnitEvent("UNIT_HEALTH", "player")
	e:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	e:RegisterEvent("PLAYER_ENTERING_WORLD")
	e:RegisterEvent("PLAYER_DEAD")
	e:RegisterEvent("PLAYER_UNGHOST")
	e:SetScript("OnEvent", function() M:UpdateVignette() end)
	FX.onToggle.lowHp = function() M:UpdateVignette() end
end

function M:UpdateVignette()
	local v = self.vignette
	if not v or v.demo then return end
	if not FX.on("lowHp") or plain(UnitIsDeadOrGhost("player")) then
		v.tex:SetVertexColor(C.red[1], C.red[2], C.red[3], 0)
		return
	end
	if v.curve and UnitHealthPercent then
		local ok, col = pcall(UnitHealthPercent, "player", true, v.curve)
		if ok and col then
			if pcall(v.tex.SetVertexColor, v.tex, col:GetRGBA()) then return end
		end
	end
	local h, m = plain(UnitHealth("player")), plain(UnitHealthMax("player"))
	local p = (h and m and m > 0) and h / m or 1
	local a = p < 0.35 and (0.8 - p * 1.6) or 0
	v.tex:SetVertexColor(C.red[1], C.red[2], C.red[3], math.max(0, a))
end

-------------------------------------------------------------------------------
-- 3 · 5. 주 자원 바: 가득 차면 빛이 훑고 지나감 / 마나 20% 아래면 은은하게 깜빡
-------------------------------------------------------------------------------
function FX.AttachPower(f)
	local bar = f.bar
	-- 지나가는 빛 (바 안쪽으로만)
	local clip = CreateFrame("Frame", nil, bar)
	clip:SetAllPoints()
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(bar:GetFrameLevel() + 3)
	local sh = clip:CreateTexture(nil, "OVERLAY")
	sh:SetTexture(Ink.tex.glow)
	sh:SetBlendMode("ADD")
	sh:SetSize(60, 26)
	sh:SetPoint("CENTER", clip, "LEFT", -40, 0)
	sh:SetVertexColor(1, 1, 1, 0)
	local ag = Anim(sh, "REPEAT")
	local mv = A(ag, "Translation", 0.9, "IN_OUT", 1, 1.8)
	mv:SetOffset(bar:GetWidth() + 80, 0)
	ag:Play()
	f.fxSheen = sh
	-- 마나 부족 깜빡임 (바 위 덮개)
	local lowH = CreateFrame("Frame", nil, bar)
	lowH:SetAllPoints()
	lowH:SetFrameLevel(bar:GetFrameLevel() + 2)
	local low = lowH:CreateTexture(nil, "OVERLAY")
	low:SetAllPoints()
	low:SetTexture(Ink.tex.white)
	low:SetBlendMode("ADD")
	low:SetVertexColor(1, 1, 1, 0)
	local br = FX.Breathe(lowH, 0.15, 1, 0.7)
	br:Play()
	f.fxLow = low
	if C_CurveUtil and C_CurveUtil.CreateColorCurve then
		local full = C_CurveUtil.CreateColorCurve()
		full:SetType(Enum.LuaCurveType.Step)
		full:AddPoint(0, CreateColor(1, 1, 1, 0))
		full:AddPoint(0.995, CreateColor(1, 1, 1, 0.75))
		f.fxFullCurve = full
		local lc = C_CurveUtil.CreateColorCurve()
		lc:SetType(Enum.LuaCurveType.Step)
		lc:AddPoint(0, CreateColor(0.55, 0.75, 1, 0.32))
		lc:AddPoint(0.2, CreateColor(0.55, 0.75, 1, 0))
		f.fxLowCurve = lc
	end
end

function FX.UpdatePower(f, ptype)
	if not f.fxSheen or f.fxDemo then return end
	local isMana = ptype == (Enum.PowerType and Enum.PowerType.Mana or 0)
	local function apply(tex, curve, enabled)
		if not enabled then tex:SetVertexColor(1, 1, 1, 0) return end
		if curve and UnitPowerPercent then
			local ok, col = pcall(UnitPowerPercent, "player", ptype, true, curve)
			if ok and col and pcall(tex.SetVertexColor, tex, col:GetRGBA()) then return end
		end
		tex:SetVertexColor(1, 1, 1, 0)
	end
	apply(f.fxSheen, f.fxFullCurve, FX.on("powerFull"))
	apply(f.fxLow, f.fxLowCurve, isMana and FX.on("manaLow"))
end

-------------------------------------------------------------------------------
-- 4. 연계 점수: 칸이 찰 때 번쩍이지 않고 잉크가 스미듯 은은하게 차오른다
--  + 모일수록 색이 점점 진해진다 (1칸 = 옅게 ... 가득 = 가장 진하게)
-------------------------------------------------------------------------------
local function SegFill(s)
	if not s.fxFill then
		local ag = Anim(s.fill)
		local a = A(ag, "Alpha", 0.45, "IN_OUT")
		a:SetFromAlpha(0.15)
		a:SetToAlpha(1)
		s.fxFill = ag
	end
	s.fxFill:Stop()
	s.fxFill:Play()
end

-- 채워진 칸의 진하기 (0~1). 값이 비공개면 nil → 원래대로(가장 진하게)
function FX.ComboIntensity(pts, n)
	if not pts or not n or n <= 0 or not FX.on("comboPop") then return nil end
	local center = Ink.modules.Center
	if center and center.testing and not FX.demo.comboPop then return nil end
	return 0.5 + 0.5 * math.min(1, pts / n)
end

-- holder: 연계 점수 묶음, pts: 지금 칸 수(공개 값일 때만)
function FX.Combo(holder, pts)
	local center = Ink.modules.Center
	local blocked = center and center.testing and not FX.demo.comboPop
	if blocked or not FX.on("comboPop") or not pts then holder.fxLast = pts return end
	local last = holder.fxLast
	holder.fxLast = pts
	if not last or pts <= last then return end
	for i = last + 1, math.min(pts, holder.n or 0) do
		local s = holder.segs[i]
		if s then SegFill(s) end
	end
end

-------------------------------------------------------------------------------
-- 6~9. 행동 단축바 · 쿨다운 칸
-------------------------------------------------------------------------------
-- 쿨다운이 끝나는 순간 빛 고리 (전역 쿨다운 1.5초는 제외: 2.5초 넘게 돈 것만)
function FX.AttachCooldown(owner, cd, size, top)
	if not cd or cd.inkFX then return end
	cd.inkFX = true
	local host = top or owner
	local ring = FX.Ring(host, size * 1.05)
	owner.fxRing = ring
	cd:HookScript("OnShow", function(self) self.inkStart = GetTime() end)
	cd:HookScript("OnCooldownDone", function(self)
		local st = self.inkStart
		self.inkStart = nil
		if not FX.on("cdReady") or not st then return end
		if owner.fxPreview and not FX.demo.cdReady then return end
		if GetTime() - st > 2.5 and owner:IsVisible() then ring() end
	end)
end

-- 행동 단축바 버튼 하나에 효과를 붙인다 (Blizzard.lua 의 스킨에서 부른다)
local actionButtons = {}
function FX.AttachActionButton(b, small)
	local s = b.inkSkin
	if not s or b.inkFX then return end
	b.inkFX = true
	actionButtons[#actionButtons + 1] = b
	local size = b:GetWidth() or 40
	if size < 10 then size = small and 30 or 40 end
	local cd = b.cooldown or b.Cooldown
	if cd then FX.AttachCooldown(b, cd, size, s.top) end
	-- 눌림: 노란 테두리가 짧게 + 안쪽이 살짝 밝아졌다 사라짐
	local flash = FX.Flash(s.top, small, C.text, 0.18, 0.22, 1)
	local edge = Ink:Round(s.top, "OVERLAY", small, true, 3)
	edge:SetAllPoints()
	edge:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	edge:SetAlpha(0)
	local eg = Anim(edge)
	local ea = A(eg, "Alpha", 0.28, "OUT")
	ea:SetFromAlpha(0.9)
	ea:SetToAlpha(0)
	b.fxPress = function()
		if not FX.on("press") then return end
		flash()
		eg:Stop(); eg:Play()
	end
	hooksecurefunc(b, "SetButtonState", function(_, state) if state == "PUSHED" then b.fxPress() end end)
	b:HookScript("OnMouseDown", function() b.fxPress() end)
end

-- 주문 강화(발동): 블리자드 개미줄 반짝임 대신 노란 모서리 괄호 + 안쪽 테두리 숨쉬기
local function ProcFrame(button)
	if button.fxProc then return button.fxProc end
	local s = button.inkSkin
	local host = (s and s.top) or button
	local small = (button:GetWidth() or 40) < 34
	local p = FX.Brackets(host, 3, small and 7 or 9, 2, C.accent, 4)
	p.edge = Ink:Round(p, "OVERLAY", small, true)
	p.edge:SetPoint("TOPLEFT", 3, -3)
	p.edge:SetPoint("BOTTOMRIGHT", -3, 3)
	p.edge:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.85)
	p.glow = p:CreateTexture(nil, "BACKGROUND")
	p.glow:SetTexture(Ink.tex.glow)
	p.glow:SetPoint("TOPLEFT", -8, 8)
	p.glow:SetPoint("BOTTOMRIGHT", 8, -8)
	p.glow:SetBlendMode("ADD")
	p.glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.35)
	button.fxProc = p
	return p
end

function FX.ProcShow(button, force)
	if not button or (not force and not FX.on("procBracket")) then return end
	local p = ProcFrame(button)
	p:Open()
	local a = button.SpellActivationAlert
	if a and a.SetAlpha then a:SetAlpha(0) end
end

function FX.ProcHide(button)
	local p = button and button.fxProc
	if p then p:Close() end
	local a = button and button.SpellActivationAlert
	if a and a.SetAlpha then a:SetAlpha(1) end
end

-- 사거리 밖 / 자원 부족 → 흑백 (0.2초마다, 보이는 버튼만)
local function RangeTick()
	local on = FX.on("rangeDesat")
	for _, b in ipairs(actionButtons) do
		local icon = b.icon or b.Icon
		if icon and b:IsVisible() and not b.fxDemoDesat then
			local want = false
			local slot = b.action
			if on and type(slot) == "number" and C_ActionBar then
				local okR, inRange = pcall(C_ActionBar.IsActionInRange, slot)
				local okU, usable, noMana = pcall(C_ActionBar.IsUsableAction, slot)
				inRange = okR and plain(inRange)
				noMana = okU and plain(noMana)
				want = (inRange == false) or (noMana == true)
			end
			if b.fxDesat ~= want then
				b.fxDesat = want
				pcall(icon.SetDesaturated, icon, want)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- 10. 시전 결과: 성공하면 흰 섬광 후 스르륵 / 차단되면 빨갛게 흔들리며 "차단됨"
--  시전바(ns.CastBar)에 붙인다. 결과를 보여 주는 동안(hold)은 바를 숨기지 않는다.
-------------------------------------------------------------------------------
function FX.AttachCast(cb, fill)
	if cb.fxCast then return end
	cb.fxCast = true
	cb.fxFill = fill
	local h = CreateFrame("Frame", nil, cb)
	h:SetAllPoints(cb.bar)
	h:SetFrameLevel(cb.bar:GetFrameLevel() + 3)
	local fl = h:CreateTexture(nil, "OVERLAY")
	fl:SetPoint("TOPLEFT", -2, 4)
	fl:SetPoint("BOTTOMRIGHT", 2, -4)
	fl:SetTexture(Ink.tex.glow)
	fl:SetBlendMode("ADD")
	fl:SetAlpha(0)
	local ag = Anim(fl)
	local a1 = A(ag, "Alpha", 0.06, nil, 1)
	a1:SetFromAlpha(0)
	a1:SetToAlpha(0.9)
	local a2 = A(ag, "Alpha", 0.35, "OUT", 2)
	a2:SetFromAlpha(0.9)
	a2:SetToAlpha(0)
	cb.fxFlashTex, cb.fxFlash = fl, ag
	cb.fxShake = FX.Shake(cb, 4)
	cb.fxFade = Anim(cb)
	local fo = A(cb.fxFade, "Alpha", 0.35, "IN", 1, 0.15)
	fo:SetFromAlpha(1)
	fo:SetToAlpha(0)
	cb.fxFadeAnim = fo
	cb.fxFade:SetScript("OnFinished", function() cb:SetAlpha(0) end)
end

-- 시전 이벤트를 받아 결과를 정한다. true 를 돌려주면 호출한 쪽은 바를 갱신하지 않는다.
--  멈춤(STOP) 직후 0.06초 동안 성공(SUCCEEDED) / 실패(INTERRUPTED · FAILED) 신호를 기다렸다가 판단.
--  그 사이 새 시전이 시작되면(fxSeq 가 바뀜) 결과는 버린다.
function FX.CastEvent(cb, event, refresh)
	if not cb or not cb.fxCast then return false end
	local now = GetTime()
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		cb.fxOK = now
		return true
	end
	if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then cb.fxFail = now end
	local stop = event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED"
	if not (stop and cb:IsShown() and not cb.fxState and not cb.preview and FX.on("castFinish")) then return false end
	if cb.fxDeciding then return true end
	cb.fxDeciding = true
	local seq, wasChannel = cb.fxSeq, cb.channel
	cb.hold = now + 0.3
	C_Timer.After(0.06, function()
		cb.fxDeciding = nil
		if cb.fxSeq ~= seq or cb.fxState then return end
		cb.hold = nil
		local t = GetTime()
		local kind
		if cb.fxFail and t - cb.fxFail < 0.3 then
			kind = "fail"
		elseif wasChannel or (cb.fxOK and t - cb.fxOK < 0.3) then
			kind = "ok"
		end
		if kind then FX.CastResult(cb, kind, refresh) else refresh() end
	end)
	return true
end

-- 새 시전이 시작되면 원래 모습으로
function FX.CastReset(cb)
	if not cb.fxState then return end
	cb.fxState, cb.hold = nil, nil
	cb.fxFade:Stop()
	cb:SetAlpha(1)
	local c = cb.fxFill or C.text
	cb.bar:SetStatusBarColor(c[1], c[2], c[3])
	if cb.fxNameColor then cb.name:SetTextColor(cb.fxNameColor[1], cb.fxNameColor[2], cb.fxNameColor[3]) end
end

-- kind = "ok" | "fail". after(): 결과 표시가 끝나면 부를 함수(보통 다시 갱신)
function FX.CastResult(cb, kind, after)
	if not cb.fxCast or not FX.on("castFinish") then return end
	if not cb:IsShown() or cb.fxState then return end
	cb.fxState = kind
	cb.dur, cb.endTime = nil, nil
	pcall(cb.bar.SetMinMaxValues, cb.bar, 0, 1)
	pcall(cb.bar.SetValue, cb.bar, 1)
	if cb.shield then cb.shield:SetAlpha(0) end
	if cb.time then cb.time:SetText("") end
	local hold
	if kind == "fail" then
		cb.bar:SetStatusBarColor(C.red[1], C.red[2], C.red[3])
		if not cb.fxNameColor then cb.fxNameColor = { cb.name:GetTextColor() } end
		cb.name:SetText("차단됨")
		cb.name:SetTextColor(C.red[1], C.red[2], C.red[3])
		cb.fxShake()
		hold = 0.75
	else
		cb.fxFlashTex:SetVertexColor(1, 1, 1)
		cb.fxFlash:Stop(); cb.fxFlash:Play()
		hold = 0.5
	end
	cb.hold = GetTime() + hold
	cb:SetAlpha(1)
	cb.fxFadeAnim:SetStartDelay(kind == "fail" and 0.4 or 0.15)
	cb.fxFade:Stop(); cb.fxFade:Play()
	C_Timer.After(hold + 0.02, function()
		if cb.fxState ~= kind then return end
		cb.hold = nil
		FX.CastReset(cb)
		cb:Hide()
		if after then pcall(after) end
	end)
end

-------------------------------------------------------------------------------
-- 11~14. 네임플레이트
-------------------------------------------------------------------------------
-- 플레이트 하나에 효과 준비 (Plates.lua 의 Build 에서)
function FX.AttachPlate(f)
	local back = f.back
	-- 차단 가능 알림: 노란 빛이 한 번 번쩍 (차단 불가면 holder 투명)
	local ph = CreateFrame("Frame", nil, back)
	ph:SetAllPoints()
	ph:SetFrameLevel(back:GetFrameLevel() + 6)
	local pt = ph:CreateTexture(nil, "OVERLAY")
	pt:SetTexture(Ink.tex.glow)
	pt:SetBlendMode("ADD")
	pt:SetPoint("TOPLEFT", -16, 12)
	pt:SetPoint("BOTTOMRIGHT", 16, -12)
	pt:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	pt:SetAlpha(0)
	local pg = Anim(pt)
	for i, d in ipairs({ { 0, 0.9, 0.08 }, { 0.9, 0.2, 0.18 }, { 0.2, 0.8, 0.1 }, { 0.8, 0, 0.35 } }) do
		local a = A(pg, "Alpha", d[3], "OUT", i)
		a:SetFromAlpha(d[1])
		a:SetToAlpha(d[2])
	end
	f.fxPingHolder, f.fxPing = ph, pg
	-- 대상 괄호 조임 + 테두리 섬광
	local function fly(mark, dx)
		local ag = Anim(mark)
		local o = A(ag, "Translation", 0, nil, 1)
		o:SetOffset(dx, 0)
		local b = A(ag, "Translation", 0.22, "OUT", 2)
		b:SetOffset(-dx, 0)
		return ag
	end
	f.fxMarkL, f.fxMarkR = fly(f.markL, -12), fly(f.markR, 12)
	local tf = Ink:Round(back, "OVERLAY", true, true, 4)
	tf:SetAllPoints()
	tf:SetBlendMode("ADD")
	tf:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	tf:SetAlpha(0)
	local tg = Anim(tf)
	local ta = A(tg, "Alpha", 0.35, "OUT")
	ta:SetFromAlpha(1)
	ta:SetToAlpha(0)
	f.fxTargetFlash = tg
	-- 어그로 맥박 (붉은 빛)
	local ag = back:CreateTexture(nil, "BACKGROUND", nil, -7)
	ag:SetTexture(Ink.tex.glow)
	ag:SetPoint("TOPLEFT", -14, 12)
	ag:SetPoint("BOTTOMRIGHT", 14, -12)
	ag:SetVertexColor(C.red[1], C.red[2], C.red[3])
	ag:SetAlpha(0)
	ag:Hide()
	f.fxAggroTex, f.fxAggro = ag, FX.Breathe(ag, 0.1, 0.55, 0.6)
	-- 퀘스트 수치 톡
	f.fxQuestPop = FX.Pop(f.qtext, 1.6, 0.25)
	f.fxQuestIconPop = FX.Pop(f.qicon, 1.5, 0.25)
end

function FX.PlateTarget(f, isTarget)
	if not f.fxMarkL then return end
	if isTarget and not f.fxWasTarget and FX.on("targetBracket") then
		f.fxMarkL:Stop(); f.fxMarkR:Stop(); f.fxTargetFlash:Stop()
		f.fxMarkL:Play(); f.fxMarkR:Play(); f.fxTargetFlash:Play()
	end
	f.fxWasTarget = isTarget
end

function FX.PlateAggro(f, on)
	if not f.fxAggro then return end
	on = on and FX.on("aggroPulse")
	if on and not f.fxAggroTex:IsShown() then
		f.fxAggroTex:Show()
		f.fxAggro:Play()
	elseif not on and f.fxAggroTex:IsShown() then
		f.fxAggro:Stop()
		f.fxAggroTex:Hide()
	end
end

function FX.PlatePing(f, notInterruptible)
	if not f.fxPing or not FX.on("interruptPing") then return end
	local h = f.fxPingHolder
	if h.SetAlphaFromBoolean and notInterruptible ~= nil then
		if not pcall(h.SetAlphaFromBoolean, h, notInterruptible, 0, 1) then h:SetAlpha(1) end
	else
		h:SetAlpha(plain(notInterruptible) and 0 or 1)
	end
	f.fxPing:Stop()
	f.fxPing:Play()
end

function FX.PlateQuest(f, prev, info)
	if not f.fxQuestPop or not FX.on("questPop") then return end
	if prev and info and prev.text ~= info.text then
		f.fxQuestPop()
		f.fxQuestIconPop()
	end
end

-------------------------------------------------------------------------------
-- 15~17. 파티
-------------------------------------------------------------------------------
-- 사망 · 부활: 어두운 막이 스르륵 내려앉고, 살아나면 빛이 한 번 차오른다
function FX.AttachMember(f)
	if f.fxTop then return end
	local top = CreateFrame("Frame", nil, f)
	top:SetAllPoints()
	top:SetFrameLevel(f:GetFrameLevel() + 12)
	top:EnableMouse(false)
	local veil = top:CreateTexture(nil, "OVERLAY")
	veil:SetPoint("TOPLEFT", -4, 4)
	veil:SetPoint("BOTTOMRIGHT", 4, -4)
	veil:SetTexture(Ink.tex.round)
	if veil.SetTextureSliceMargins then veil:SetTextureSliceMargins(8, 8, 8, 8) end
	veil:SetVertexColor(0.02, 0.022, 0.03, 1)
	veil:SetAlpha(0)
	local vin = Anim(veil)
	local va = A(vin, "Alpha", 0.6, "OUT")
	va:SetFromAlpha(0)
	va:SetToAlpha(0.5)
	vin:SetScript("OnFinished", function() veil:SetAlpha(0.5) end)
	local vout = Anim(veil)
	local vo = A(vout, "Alpha", 0.5, "OUT")
	vo:SetFromAlpha(0.5)
	vo:SetToAlpha(0)
	vout:SetScript("OnFinished", function() veil:SetAlpha(0) end)
	local rise = top:CreateTexture(nil, "OVERLAY", nil, 2)
	rise:SetTexture(Ink.tex.glow)
	rise:SetBlendMode("ADD")
	rise:SetPoint("TOPLEFT", f.hp, "TOPLEFT", -20, 16)
	rise:SetPoint("BOTTOMRIGHT", f.hp, "BOTTOMRIGHT", 20, -16)
	rise:SetVertexColor(C.green[1], C.green[2], C.green[3])
	rise:SetAlpha(0)
	local rg = Anim(rise)
	local r1 = A(rg, "Alpha", 0.12, nil, 1)
	r1:SetFromAlpha(0)
	r1:SetToAlpha(0.9)
	local r2 = A(rg, "Alpha", 0.9, "OUT", 2)
	r2:SetFromAlpha(0.9)
	r2:SetToAlpha(0)
	f.fxTop, f.fxVeil, f.fxVeilIn, f.fxVeilOut, f.fxRise = top, veil, vin, vout, rg
	-- 전투 준비 확인 표시 (프레임 오른쪽 바깥)
	local rc = CreateFrame("Frame", nil, top)
	rc:SetSize(22, 22)
	rc:SetPoint("LEFT", f, "RIGHT", 10, 8)
	rc.disc = rc:CreateTexture(nil, "BACKGROUND")
	rc.disc:SetTexture(Ink.tex.disc)
	rc.disc:SetAllPoints()
	rc.disc:SetVertexColor(0.035, 0.04, 0.052, 0.95)
	rc.ring = rc:CreateTexture(nil, "BORDER")
	rc.ring:SetTexture(Ink.tex.ring)
	rc.ring:SetAllPoints()
	rc.icon = rc:CreateTexture(nil, "ARTWORK")
	rc.icon:SetSize(13, 13)
	rc.icon:SetPoint("CENTER")
	local pop = Anim(rc)
	local ps = A(pop, "Scale", 0.25, "OUT")
	ps:SetScaleFrom(0.3, 0.3)
	ps:SetScaleTo(1, 1)
	local pa = A(pop, "Alpha", 0.15)
	pa:SetFromAlpha(0)
	pa:SetToAlpha(1)
	rc.pop = pop
	rc.fade = Anim(rc)
	local fo = A(rc.fade, "Alpha", 0.6, "IN")
	fo:SetFromAlpha(1)
	fo:SetToAlpha(0)
	rc.fade:SetScript("OnFinished", function() rc:Hide() end)
	rc.wait = FX.Breathe(rc.icon, 0.35, 1, 0.6)
	rc:Hide()
	f.fxReady = rc
end

function FX.MemberDead(f, dead)
	if not f.fxVeil then return end
	if f.fxWasDead == nil then
		f.fxWasDead = dead
		f.fxVeil:SetAlpha((dead and FX.on("deathFade")) and 0.5 or 0)
		return
	end
	if dead == f.fxWasDead then return end
	f.fxWasDead = dead
	if not FX.on("deathFade") then f.fxVeil:SetAlpha(0) return end
	f.fxVeilIn:Stop(); f.fxVeilOut:Stop()
	if dead then
		f.fxVeilIn:Play()
	else
		f.fxVeilOut:Play()
		f.fxRise:Stop(); f.fxRise:Play()
	end
end

local READY = {
	ready = { "Check", "green" },
	notready = { "Cross", "red" },
	waiting = { "Wait", "muted" },
}
function FX.MemberReady(f, status, delay)
	local rc = f.fxReady
	if not rc then return end
	if not status or not FX.on("readyCheck") then rc.wait:Stop(); rc.fade:Stop(); rc:Hide() return end
	local d = READY[status] or READY.waiting
	local col = C[d[2]]
	local function show()
		rc.fade:Stop()
		rc.icon:SetTexture(Ink.icon(d[1]))
		rc.icon:SetVertexColor(col[1], col[2], col[3])
		rc.ring:SetVertexColor(col[1], col[2], col[3], 0.85)
		rc:SetAlpha(1)
		rc:Show()
		rc.pop:Stop(); rc.pop:Play()
		if status == "waiting" then rc.wait:Play() else rc.wait:Stop(); rc.icon:SetAlpha(1) end
	end
	if delay and delay > 0 then C_Timer.After(delay, show) else show() end
end

function FX.MemberReadyEnd(f, delay)
	local rc = f.fxReady
	if not rc or not rc:IsShown() then return end
	C_Timer.After(delay or 3, function() if rc:IsShown() then rc.fade:Play() end end)
end

-- 해제 디버프 숨쉬기 (텍스처에 반복 애니메이션)
function FX.DispelBreathe(tex)
	if not FX.on("dispelPulse") or tex.fxBreathe then return end
	tex.fxBreathe = FX.Breathe(tex, 0.25, 0.75, 0.7)
	tex.fxBreathe:Play()
end

-------------------------------------------------------------------------------
-- 18. 레벨업 연출
-------------------------------------------------------------------------------
function M:BuildLevelUp()
	local f = CreateFrame("Frame", "FOALevelUp", Ink.root)
	f:SetSize(480, 170)
	f:SetPoint("TOP", Ink.root, "TOP", 0, -150)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(false)
	f.glow = f:CreateTexture(nil, "BACKGROUND")
	f.glow:SetTexture(Ink.tex.glow)
	f.glow:SetPoint("TOPLEFT", 60, -10)
	f.glow:SetPoint("BOTTOMRIGHT", -60, 20)
	f.glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.16)
	f.tag = Ink:Text(f, F.latinB, 11, C.accent, "CENTER")
	f.tag:SetPoint("TOP", 0, -6)
	f.tag:SetText("L E V E L   U P")
	f.num = Ink:Text(f, F.num, 92, C.text, "CENTER")
	f.num:SetPoint("TOP", f.tag, "BOTTOM", 0, -2)
	f.num:SetShadowOffset(0, -2)
	f.num:SetShadowColor(0, 0, 0, 0.5)
	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
	f.line:SetSize(220, 2)
	f.line:SetPoint("TOP", f.num, "BOTTOM", 0, -6)
	f.sub = Ink:Text(f, F.sans, 13, C.soft, "CENTER")
	f.sub:SetPoint("TOP", f.line, "BOTTOM", 0, -10)
	f:Hide()
	-- 전체: 나타남 → 유지 → 사라짐
	local ag = Anim(f)
	local a1 = A(ag, "Alpha", 0.35, "OUT", 1)
	a1:SetFromAlpha(0)
	a1:SetToAlpha(1)
	local a2 = A(ag, "Alpha", 0.7, "IN", 2, 2.6)
	a2:SetFromAlpha(1)
	a2:SetToAlpha(0)
	ag:SetScript("OnFinished", function() f:Hide() end)
	f.ag = ag
	-- 숫자는 아래에서 살짝 올라오며
	local ng = Anim(f.num)
	local n0 = A(ng, "Translation", 0, nil, 1)
	n0:SetOffset(0, -14)
	local n1 = A(ng, "Translation", 0.5, "OUT", 2)
	n1:SetOffset(0, 14)
	f.ng = ng
	-- 선은 가운데서 좌우로 펼쳐지며
	local lg = Anim(f.line)
	local l0 = A(lg, "Scale", 0.55, "OUT", 1, 0.15)
	l0:SetScaleFrom(0.02, 1)
	l0:SetScaleTo(1, 1)
	f.lg = lg
	self.levelUp = f
	local e = CreateFrame("Frame")
	e:RegisterEvent("PLAYER_LEVEL_UP")
	e:SetScript("OnEvent", function(_, _, level) M:ShowLevelUp(level) end)
end

-- 블리자드 레벨업 알림(가운데 큰 글자 / 알림 띠)은 FOA 효과와 겹치니 그동안만 투명하게
local BLIZZ_LEVELUP = { "LevelUpDisplay", "EventToastManagerFrame" }
function M:MuteBlizzLevelUp()
	self.muteUntil = GetTime() + 5
	for _, n in ipairs(BLIZZ_LEVELUP) do
		local fr = _G[n]
		if fr then
			if not fr.foaMuteHook then
				fr.foaMuteHook = true
				fr:HookScript("OnShow", function(self) if (M.muteUntil or 0) > GetTime() then self:SetAlpha(0) end end)
			end
			fr:SetAlpha(0)
		end
	end
	C_Timer.After(5.2, function()
		for _, n in ipairs(BLIZZ_LEVELUP) do if _G[n] then _G[n]:SetAlpha(1) end end
	end)
end

function M:ShowLevelUp(level, force)
	local f = self.levelUp
	if not f or (not force and not FX.on("levelUp")) then return end
	if not force then self:MuteBlizzLevelUp() end
	level = plain(level) or plain(UnitLevel("player")) or 0
	f.num:SetText(tostring(level))
	local _, class = UnitClass("player")
	local name = UnitName("player")
	f.sub:SetText((name and (name .. "  ·  ") or "") .. level .. " 레벨 달성")
	if class then
		local r, g, b = ns.ClassTint(class)
		f.sub:SetTextColor(r, g, b)
	end
	f:SetAlpha(1)
	f:Show()
	f.ag:Stop(); f.ng:Stop(); f.lg:Stop()
	f.ag:Play(); f.ng:Play(); f.lg:Play()
end

-------------------------------------------------------------------------------
-- 20. 전리품 알림 (희귀 이상)
-------------------------------------------------------------------------------
local QCOLOR = {
	[2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 },
	[5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 }, [8] = { 0, 0.8, 1 },
}

local function Toast(parent)
	local t = CreateFrame("Frame", nil, parent)
	t:SetSize(260, 46)
	t.bg = Ink:Round(t, "BACKGROUND", false, false)
	t.bg:SetAllPoints()
	t.bg:SetVertexColor(0.035, 0.04, 0.052, 0.94)
	t.bd = Ink:Round(t, "BORDER", false, true)
	t.bd:SetAllPoints()
	t.bd:SetVertexColor(1, 1, 1, 0.08)
	t.edge = t:CreateTexture(nil, "ARTWORK")
	t.edge:SetSize(2, 26)
	t.edge:SetPoint("LEFT", 0, 0)
	t.icon = t:CreateTexture(nil, "ARTWORK")
	t.icon:SetSize(30, 30)
	t.icon:SetPoint("LEFT", 10, 0)
	t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local m = t:CreateMaskTexture()
	m:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m:SetAllPoints(t.icon)
	t.icon:AddMaskTexture(m)
	t.ibd = Ink:Round(t, "OVERLAY", true, true)
	t.ibd:SetAllPoints(t.icon)
	t.name = Ink:Text(t, F.semi, 12, C.text, "LEFT")
	t.name:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 10, -1)
	t.name:SetWidth(200)
	t.sub = Ink:Text(t, F.sans, 10, C.muted, "LEFT")
	t.sub:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 10, 1)
	t.sheen = t:CreateTexture(nil, "OVERLAY")
	t.sheen:SetTexture(Ink.tex.glow)
	t.sheen:SetBlendMode("ADD")
	t.sheen:SetSize(80, 46)
	t.sheen:SetPoint("CENTER", t, "LEFT", 0, 0)
	t.sheen:SetAlpha(0)
	-- 왼쪽에서 미끄러져 들어와 4초 뒤 스르륵
	local ag = Anim(t)
	local m0 = A(ag, "Translation", 0, nil, 1)
	m0:SetOffset(-24, 0)
	local a0 = A(ag, "Alpha", 0, nil, 1)
	a0:SetFromAlpha(0)
	a0:SetToAlpha(0)
	local m1 = A(ag, "Translation", 0.32, "OUT", 2)
	m1:SetOffset(24, 0)
	local a1 = A(ag, "Alpha", 0.25, "OUT", 2)
	a1:SetFromAlpha(0)
	a1:SetToAlpha(1)
	local a2 = A(ag, "Alpha", 0.5, "IN", 3, 4)
	a2:SetFromAlpha(1)
	a2:SetToAlpha(0)
	ag:SetScript("OnFinished", function() t:Hide(); t.busy = nil end)
	t.ag = ag
	local sg = Anim(t.sheen)
	local s0 = A(sg, "Alpha", 0.05, nil, 1, 0.3)
	s0:SetFromAlpha(0)
	s0:SetToAlpha(0.5)
	local s1 = A(sg, "Translation", 0.7, "IN_OUT", 2)
	s1:SetOffset(260, 0)
	local s2 = A(sg, "Alpha", 0.7, "IN", 2)
	s2:SetFromAlpha(0.5)
	s2:SetToAlpha(0)
	t.sg = sg
	t:Hide()
	return t
end

function M:BuildLoot()
	local a = Ink:Anchor(260, 160)
	self.lootAnchor = a
	self.toasts = {}
	for i = 1, 3 do
		local t = Toast(Ink.root)
		t:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 0, (i - 1) * 52)
		self.toasts[i] = t
	end
	Ink:Movable("loot", "전리품 알림", a, "bottomleft", 16, 330)
	-- "받은 전리품: %s." 같은 문장을 패턴으로
	local pats = {}
	for _, g in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF" }) do
		local s = _G[g]
		if type(s) == "string" then
			s = s:gsub("%%%d%$", "%%"):gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
			pats[#pats + 1] = "^" .. s .. "$"
		end
	end
	local e = CreateFrame("Frame")
	e:RegisterEvent("CHAT_MSG_LOOT")
	e:SetScript("OnEvent", function(_, _, msg)
		if not FX.on("lootToast") then return end
		msg = plain(msg)
		if type(msg) ~= "string" then return end
		for _, p in ipairs(pats) do
			local link, count = msg:match(p)
			if link then
				M:LootToast(link, tonumber(count))
				return
			end
		end
	end)
end

function M:LootToast(link, count, demo)
	local q, icon, name
	if demo then
		q, icon, name = demo[1], demo[2], demo[3]
	else
		local okQ, qq = pcall(C_Item.GetItemQualityByID, link)
		q = okQ and plain(qq)
		if not q and C_Item.GetItemInfo then
			local okI, _, _, q2 = pcall(C_Item.GetItemInfo, link)
			q = okI and plain(q2)
		end
		if not q or q < 3 then return end
		local okI, ii = pcall(C_Item.GetItemIconByID, link)
		icon = okI and ii
		name = link:match("%[(.-)%]") or link
	end
	local t
	for _, x in ipairs(self.toasts) do if not x.busy then t = x break end end
	if not t then
		t = self.toasts[1]
		for i = 1, #self.toasts - 1 do self.toasts[i] = self.toasts[i + 1] end
		self.toasts[#self.toasts] = t
	end
	local col = QCOLOR[q] or C.text
	t.busy = true
	t.icon:SetTexture(icon or 134400)
	t.ibd:SetVertexColor(col[1], col[2], col[3], 0.8)
	t.edge:SetColorTexture(col[1], col[2], col[3], 1)
	t.name:SetText(name)
	t.name:SetTextColor(col[1], col[2], col[3])
	t.sub:SetText("획득" .. ((count and count > 1) and ("  ·  " .. count .. "개") or ""))
	t.sheen:SetVertexColor(col[1], col[2], col[3])
	t:SetAlpha(1)
	t:Show()
	t.ag:Stop(); t.sg:Stop()
	t.ag:Play(); t.sg:Play()
end

-------------------------------------------------------------------------------
-- 21. 우편 잔물결
-------------------------------------------------------------------------------
function M:BuildMail()
	local h = CreateFrame("Frame", nil, Ink.root)
	h:SetSize(26, 26)
	h:SetFrameStrata("MEDIUM")
	h:EnableMouse(false)
	h.rings = {}
	for i = 1, 3 do
		local r = h:CreateTexture(nil, "OVERLAY")
		r:SetTexture(Ink.tex.ring)
		r:SetAllPoints()
		r:SetBlendMode("ADD")
		r:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
		r:SetAlpha(0)
		local ag = Anim(r)
		local s = A(ag, "Scale", 1.1, "OUT", 1, (i - 1) * 0.3)
		s:SetScaleFrom(0.6, 0.6)
		s:SetScaleTo(2.4, 2.4)
		local a = A(ag, "Alpha", 1.1, "OUT", 1, (i - 1) * 0.3)
		a:SetFromAlpha(0.85)
		a:SetToAlpha(0)
		r.ag = ag
		h.rings[i] = r
	end
	self.mail = h
	local e = CreateFrame("Frame")
	e:RegisterEvent("UPDATE_PENDING_MAIL")
	e:SetScript("OnEvent", function()
		local has = HasNewMail and HasNewMail()
		if has and not M.hadMail then M:Ripple() end
		M.hadMail = has
	end)
	M.hadMail = HasNewMail and HasNewMail()
end

function M:Ripple(force)
	if not force and not FX.on("mailRipple") then return end
	local h = self.mail
	local mc = MinimapCluster
	local icon = mc and mc.IndicatorFrame and mc.IndicatorFrame.MailFrame
	h:ClearAllPoints()
	if icon and icon:IsVisible() then
		h:SetPoint("CENTER", icon, "CENTER")
	elseif Minimap then
		h:SetPoint("CENTER", Minimap, "TOPRIGHT", -36, -36)
	else
		return
	end
	for _, r in ipairs(h.rings) do r.ag:Stop(); r.ag:Play() end
end

-------------------------------------------------------------------------------
-- 22. 보스 경고 등장 (Boss.lua 경고 줄을 만들 때 붙인다)
-------------------------------------------------------------------------------
function FX.AttachBossWarn(w)
	if not w.pop or w.fxDrop then return end
	local dg = Anim(w)
	local d0 = A(dg, "Translation", 0)
	d0:SetOffset(0, 22)
	local d1 = A(dg, "Translation", 0.3, "OUT")
	d1:SetOffset(0, -22)
	local lg = Anim(w.line)
	local ls = A(lg, "Scale", 0.4, "OUT", 1, 0.12)
	ls:SetScaleFrom(0.05, 1)
	ls:SetScaleTo(1, 1)
	w.fxDrop = dg
	w.pop:HookScript("OnPlay", function()
		if not FX.on("bossDrop") then return end
		local boss = Ink.modules.Boss
		if boss and boss.testing and not FX.demoOn("bossDrop") then return end
		dg:Stop(); lg:Stop()
		dg:Play(); lg:Play()
	end)
end

-------------------------------------------------------------------------------
-- 23 · 24. 미터기
-------------------------------------------------------------------------------
function FX.AttachMeterRow(r, rowH)
	if r.fxSlide then return end
	local ag = Anim(r)
	local t0 = A(ag, "Translation", 0, nil, 1)
	local t1 = A(ag, "Translation", 0.28, "OUT", 2)
	local a1 = A(ag, "Alpha", 0.28, "OUT", 2)
	a1:SetFromAlpha(0.35)
	a1:SetToAlpha(1)
	r.fxSlide = function(dy)
		if not FX.on("meterSlide") then return end
		ag:Stop()
		t0:SetOffset(0, dy)
		t1:SetOffset(0, -dy)
		ag:Play()
	end
	-- 1등 빛: 은은한 바탕 빛 + 3초마다 지나가는 반짝임
	local g = CreateFrame("Frame", nil, r)
	g:SetAllPoints()
	g:SetFrameLevel(r:GetFrameLevel() + 1)
	g:SetClipsChildren(true)
	g:EnableMouse(false)
	g.sheen = g:CreateTexture(nil, "OVERLAY")
	g.sheen:SetTexture(Ink.tex.glow)
	g.sheen:SetBlendMode("ADD")
	g.sheen:SetSize(70, rowH * 1.6)
	g.sheen:SetPoint("CENTER", g, "LEFT", -40, 0)
	g.sheen:SetAlpha(0.35)
	local sg = Anim(g.sheen, "REPEAT")
	local sm = A(sg, "Translation", 1.1, "IN_OUT", 1, 2.4)
	sm:SetOffset((r:GetWidth() or 200) + 80, 0)
	g.sg, g.sm = sg, sm
	g:Hide()
	r.fxGlow = g
end

function FX.MeterTop(r, on, cr, cg, cb)
	local g = r.fxGlow
	if not g then return end
	on = on and FX.on("meterGlow")
	if on then
		g.sheen:SetVertexColor(cr or 1, cg or 1, cb or 1)
		if not g:IsShown() then
			g.sm:SetOffset(math.max(120, r:GetWidth() or 200) + 80, 0)
			g:Show()
			g.sg:Play()
		end
	elseif g:IsShown() then
		g.sg:Stop()
		g:Hide()
	end
end

-------------------------------------------------------------------------------
-- 테스트 예시
--  효과마다 켜고 끌 수 있다. 하나의 시계(0.1초)로 돌리며, 각 예시는 자기 주기로 움직인다.
-------------------------------------------------------------------------------
local demoT0
local DEMOS = {}

-- 행동 단축바에서 보이는 버튼 몇 개
local function SomeButtons(n, offset)
	local list = {}
	for _, b in ipairs(actionButtons) do
		if b:IsVisible() and (b.icon or b.Icon) then list[#list + 1] = b end
	end
	local out = {}
	for i = 1, math.min(n, #list) do out[i] = list[((i - 1 + (offset or 0)) % #list) + 1] end
	return out
end

-- 주기 함수: every 초마다 한 번씩 fn(cycle) (예시 켠 직후 바로 한 번)
local function Every(key, every, fn)
	DEMOS[key] = { every = every, fn = fn, last = -999 }
end

Every("lowHp", 7, function()
	local v = M.vignette
	if not v then return end
	v.demo = true
	v.tex:SetVertexColor(C.red[1], C.red[2], C.red[3], 0.6)
	C_Timer.After(3, function()
		if not FX.demo.lowHp then return end
		v.tex:SetVertexColor(C.red[1], C.red[2], C.red[3], 0)
	end)
end)

Every("powerFull", 6, function()
	local f = Ink.modules.Center and Ink.modules.Center.power
	if not f or not f.fxSheen then return end
	f.fxDemo = true
	f.fxSheen:SetVertexColor(1, 1, 1, 0.75)
	C_Timer.After(3.5, function() if f.fxSheen then f.fxSheen:SetVertexColor(1, 1, 1, 0) end end)
end)

Every("manaLow", 6, function()
	local f = Ink.modules.Center and Ink.modules.Center.power
	if not f or not f.fxLow then return end
	f.fxDemo = true
	C_Timer.After(3, function()
		if not FX.demo.manaLow then return end
		f.fxLow:SetVertexColor(0.55, 0.75, 1, 0.32)
		C_Timer.After(2.6, function() f.fxLow:SetVertexColor(1, 1, 1, 0) end)
	end)
end)

Every("cdReady", 2.2, function(n)
	for _, b in ipairs(SomeButtons(2, n * 3)) do if b.fxRing then b.fxRing() end end
	local c = Ink.modules.Center
	local row = c and c.pvMain
	if row and row:IsShown() and row.slots then
		local s = row.slots[(n % #row.slots) + 1]
		if s and s.fxRing then s.fxRing() end
	end
end)

Every("procBracket", 5, function(n)
	local list = SomeButtons(2, n * 5 + 2)
	for _, b in ipairs(list) do FX.ProcShow(b, true) end
	local c = Ink.modules.Center
	local row = c and c.pvMain
	local s = row and row:IsShown() and row.slots and row.slots[3]
	if s then FX.ProcShow(s, true) end
	C_Timer.After(3.2, function()
		for _, b in ipairs(list) do FX.ProcHide(b) end
		if s then FX.ProcHide(s) end
	end)
end)

Every("press", 2.8, function(n)
	for i, b in ipairs(SomeButtons(5, 0)) do
		C_Timer.After((i - 1) * 0.42, function()
			if FX.demo.press and b.fxPress then b.fxPress() end
		end)
	end
end)

Every("rangeDesat", 5, function(n)
	local list = SomeButtons(3, n + 6)
	for _, b in ipairs(list) do
		local icon = b.icon or b.Icon
		b.fxDemoDesat = true
		pcall(icon.SetDesaturated, icon, true)
	end
	C_Timer.After(2.6, function()
		for _, b in ipairs(list) do
			local icon = b.icon or b.Icon
			b.fxDemoDesat, b.fxDesat = nil, nil
			pcall(icon.SetDesaturated, icon, false)
		end
	end)
end)

Every("levelUp", 9, function()
	local lvl = (plain(UnitLevel("player")) or 1) + 1
	M:ShowLevelUp(lvl, true)
end)

local LOOT_DEMO = {
	{ 4, 135349, "황혼의 결의 장검" },
	{ 3, 132649, "은빛 서리 망토" },
	{ 5, 133038, "아즈샤라의 눈물" },
}
Every("lootToast", 4.5, function(n)
	M:LootToast(nil, n % 3 == 1 and 2 or nil, LOOT_DEMO[(n % #LOOT_DEMO) + 1])
end)

Every("mailRipple", 4, function() M:Ripple(true) end)


-- 모듈(유닛 · 파티 · 플레이트 · 미터기)이 각자 쓰는 예시 주기는 거기서 FX.demoOn 으로 확인한다.
function FX.Demo(key, on)
	FX.demo[key] = on and true or nil
	if not on then
		if key == "lowHp" and M.vignette then M.vignette.demo = nil; M:UpdateVignette() end
		if key == "powerFull" or key == "manaLow" then
			local f = Ink.modules.Center and Ink.modules.Center.power
			if f then
				f.fxDemo = nil
				if f.fxSheen then f.fxSheen:SetVertexColor(1, 1, 1, 0) end
				if f.fxLow then f.fxLow:SetVertexColor(1, 1, 1, 0) end
			end
		end
		if key == "procBracket" then for _, b in ipairs(actionButtons) do FX.ProcHide(b) end end
		if key == "trail" then
			local U = Ink.modules.Units
			if U and U.RestoreBars then pcall(U.RestoreBars, U) end
		end
	elseif DEMOS[key] then
		DEMOS[key].last = -999
	end
	local any = next(FX.demo) ~= nil
	if any and not M.demoTicker then
		demoT0 = GetTime()
		M.demoTicker = C_Timer.NewTicker(0.1, function()
			local now = GetTime() - demoT0
			for k, d in pairs(DEMOS) do
				if FX.demo[k] and now - d.last >= d.every then
					d.last = now
					d.n = (d.n or 0) + 1
					local ok, err = pcall(d.fn, d.n)
					if not ok then Ink:LogError("FX.demo " .. k .. ": " .. tostring(err)) end
				end
			end
		end)
	elseif not any and M.demoTicker then
		M.demoTicker:Cancel()
		M.demoTicker = nil
	end
end

function FX.DemoAll(on)
	for _, d in ipairs(FX.LIST) do FX.Demo(d[1], on) end
end

-------------------------------------------------------------------------------
function M:Init()
	Ink.db.fx = Ink.db.fx or {}
	for _, fn in ipairs({ "BuildVignette", "BuildLevelUp", "BuildLoot", "BuildMail" }) do
		local ok, err = pcall(self[fn], self)
		if not ok then Ink:LogError("FX." .. fn .. ": " .. tostring(err)) end
	end
	C_Timer.NewTicker(0.2, function() pcall(RangeTick) end)
	C_Timer.After(1, function() M:UpdateVignette() end)
end
