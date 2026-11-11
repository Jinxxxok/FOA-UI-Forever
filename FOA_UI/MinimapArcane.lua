-- FOA UI · 아케인 미니맵
--  Blizzard.lua 의 네모 미니맵에 덧입힌다 (설정 → 화면 구성 → 미니맵)
--   · 금세공 모서리 4개 (나머지 테두리는 없음 · 지도 끝은 화면에 번지듯)
--   · 뒤에서 천천히 도는 금빛 마법진
--   · 위 나침반 띠: 보는 방향에 맞춰 N · E · S · W 가 흐르고, 길 안내 중인 곳은 금색 마름모
--   · 아래: 지역 이름 + 적정 레벨 · 시간 · 좌표 · 보는 방향
--   · 둥근 금테 버튼: 오른쪽 위 애드온 목록 · 오른쪽 아래 우편 · 추적
--  치수는 시안(지도 한 변 300)을 기준으로 실제 미니맵 크기에 맞춰 줄인다.

local _, ns = ...
local Ink = ns.Ink
local M = Ink.modules.Blizzard
local F = Ink.font
local safe = Ink.safe
local TEX = "Interface\\AddOns\\FOA_UI\\Media\\Textures\\"

local GOLD = { 0.89, 0.75, 0.48 }      -- 금 (E3C07A)
local GOLD_HI = { 1, 0.906, 0.659 }    -- 밝은 금 (FFE7A8)
local GOLD_DK = { 0.56, 0.4, 0.165 }   -- 어두운 금 (8F652A)
local CREAM = { 0.965, 0.906, 0.757 }  -- 글자 (F6E7C1)
local SOFT = { 0.804, 0.749, 0.62 }    -- 옅은 글자 (CDBF9E)
local INK = { 0.047, 0.035, 0.02 }     -- 바탕 밤색 (0C0905)
local NORTH = { 1, 0.56, 0.42 }        -- N (FF8F6B)
local DESIGN = 300                     -- 시안 지도 한 변

local DIRS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
local DIRS_KR = { "북", "북동", "동", "남동", "남", "남서", "서", "북서" }

M.ARC_GOLD, M.ARC_INK, M.ARC_CREAM = GOLD, INK, CREAM

-------------------------------------------------------------------------------
-- 작은 도우미
-------------------------------------------------------------------------------
local function Spin(tex, deg, dur)
	local ag = tex:CreateAnimationGroup()
	local r = ag:CreateAnimation("Rotation")
	r:SetDegrees(deg)
	r:SetDuration(dur)
	if r.SetOrigin then r:SetOrigin("CENTER", 0, 0) end
	ag:SetLooping("REPEAT")
	ag:Play()
	return ag
end

local function Pulse(tex, a1, a2, dur)
	local ag = tex:CreateAnimationGroup()
	local al = ag:CreateAnimation("Alpha")
	al:SetFromAlpha(a1)
	al:SetToAlpha(a2)
	al:SetDuration(dur)
	if al.SetSmoothing then al:SetSmoothing("IN_OUT") end
	ag:SetLooping("BOUNCE")
	ag:Play()
	return ag
end

local function White(parent, layer, sub)
	local t = parent:CreateTexture(nil, layer, nil, sub)
	t:SetTexture(Ink.tex.white)
	return t
end

-- 가로 그라데이션 (a1 → a2). 옛 클라이언트면 가운데 값으로
local function HGrad(t, c, a1, a2)
	if t.SetGradient and CreateColor then
		t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a1), CreateColor(c[1], c[2], c[3], a2))
	else
		t:SetVertexColor(c[1], c[2], c[3], (a1 + a2) / 2)
	end
end

-- 양 끝이 사라지는 띠 (왼쪽 22% 서서히 · 가운데 · 오른쪽 22% 서서히)
local function FadeBar(parent, layer, sub, c, a)
	local bar = { l = White(parent, layer, sub), m = White(parent, layer, sub), r = White(parent, layer, sub) }
	HGrad(bar.l, c, 0, a)
	bar.m:SetVertexColor(c[1], c[2], c[3], a)
	HGrad(bar.r, c, a, 0)
	bar.Place = function(self, w, h, point, rel, relPoint, y)
		local e = math.floor(w * 0.22 + 0.5)
		self.l:ClearAllPoints(); self.m:ClearAllPoints(); self.r:ClearAllPoints()
		self.l:SetSize(e, h); self.r:SetSize(e, h); self.m:SetSize(w - 2 * e, h)
		self.m:SetPoint(point, rel, relPoint, 0, y)
		self.l:SetPoint("RIGHT", self.m, "LEFT")
		self.r:SetPoint("LEFT", self.m, "RIGHT")
	end
	bar.SetShown = function(self, on) self.l:SetShown(on); self.m:SetShown(on); self.r:SetShown(on) end
	return bar
end

local function Diamond(parent, layer, size, c, a, sub)
	local t = White(parent, layer, sub)
	t:SetSize(size, size)
	t:SetVertexColor(c[1], c[2], c[3], a or 1)
	if t.SetRotation then t:SetRotation(math.rad(45)) end
	return t
end

-- 둥근 금테 버튼
function M:ArcButton(parent, icon, size, name)
	local b = CreateFrame("Button", name, parent)
	b:SetSize(size, size)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -2)
	b.glow:SetTexture(Ink.tex.glow)
	b.glow:SetPoint("CENTER")
	b.glow:SetSize(size * 2.1, size * 2.1)
	b.glow:SetBlendMode("ADD")
	b.glow:SetVertexColor(1, 0.78, 0.47, 0.55)
	b.glow:Hide()
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetTexture(Ink.tex.disc)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(INK[1], INK[2], INK[3], 0.66)
	b.rim = b:CreateTexture(nil, "BORDER")
	b.rim:SetTexture(Ink.tex.ring)
	b.rim:SetAllPoints()
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(Ink.icon(icon))
	b.icon:SetSize(math.floor(size * 0.52 + 0.5), math.floor(size * 0.52 + 0.5))
	b.icon:SetPoint("CENTER")
	b.Lit = function(self, on)
		self.lit = on
		local hot = on or self.hover
		self.rim:SetVertexColor(hot and GOLD_HI[1] or GOLD[1], hot and GOLD_HI[2] or GOLD[2], hot and GOLD_HI[3] or GOLD[3], hot and 1 or 0.62)
		self.icon:SetVertexColor(hot and GOLD_HI[1] or CREAM[1], hot and GOLD_HI[2] or CREAM[2], hot and GOLD_HI[3] or CREAM[3])
		self.glow:SetShown(on and true or false)
	end
	-- 설명은 b.OnTip 으로 (SetScript 를 다시 부르면 빛나는 효과가 사라지므로)
	b:SetScript("OnEnter", function(self)
		self.hover = true
		self:Lit(self.lit)
		if self.OnTip then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			self:OnTip(GameTooltip)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.hover = false
		self:Lit(self.lit)
		GameTooltip:Hide()
	end)
	b:Lit(false)
	return b
end

-------------------------------------------------------------------------------
-- 만들기
-------------------------------------------------------------------------------
function M:BuildArcane()
	local o, a = self.mmOverlay, self.mmAnchor
	local A = {}
	self.arc = A

	-- 기존 위 · 아래 띠와 테두리는 쓰지 않는다
	for _, k in ipairs({ "top", "bottom", "zone", "north", "coords" }) do
		if o[k] then o[k]:Hide() end
	end
	if o.inkBorder then for _, t in ipairs(o.inkBorder) do t:Hide() end end

	-- 1) 뒤에서 도는 마법진 (미니맵보다 뒤 · 지도 끝이 번지는 곳으로 비친다)
	local sg = CreateFrame("Frame", nil, o)
	sg:SetFrameStrata("BACKGROUND")
	sg:SetFrameLevel(1)
	sg:SetPoint("CENTER", a, "CENTER")
	sg.halo = sg:CreateTexture(nil, "BACKGROUND")
	sg.halo:SetTexture(Ink.tex.glow)
	sg.halo:SetPoint("CENTER")
	sg.halo:SetBlendMode("ADD")
	sg.halo:SetVertexColor(0.94, 0.78, 0.47, 1)
	sg.outer = sg:CreateTexture(nil, "ARTWORK")
	sg.outer:SetTexture(TEX .. "MMSigilOuter")
	sg.outer:SetAllPoints()
	sg.outer:SetBlendMode("ADD")
	sg.outer:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.5)
	sg.inner = sg:CreateTexture(nil, "ARTWORK", nil, 1)
	sg.inner:SetTexture(TEX .. "MMSigilInner")
	sg.inner:SetAllPoints()
	sg.inner:SetBlendMode("ADD")
	sg.inner:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.45)
	Spin(sg.outer, -360, 140)
	Spin(sg.inner, 360, 200)
	Pulse(sg.halo, 0.08, 0.2, 2.25)
	A.sigil = sg

	-- 2) 금세공 모서리 (한 장을 뒤집어 네 귀퉁이에)
	A.corners = {}
	local tc = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }
	for i = 1, 4 do
		local t = o:CreateTexture(nil, "OVERLAY", nil, 6)
		t:SetTexture(TEX .. "MMCorner")
		t:SetTexCoord(tc[i][1], tc[i][2], tc[i][3], tc[i][4])
		A.corners[i] = t
	end

	-- 3) 나침반 띠
	local rb = CreateFrame("Frame", nil, o)
	rb:SetFrameLevel(o:GetFrameLevel() + 4)
	rb.bg = FadeBar(rb, "BACKGROUND", 0, INK, 0.55)
	rb.hiT = FadeBar(rb, "BORDER", 0, GOLD, 0.85)
	rb.hiB = FadeBar(rb, "BORDER", 0, GOLD, 0.55)
	local strip = CreateFrame("Frame", nil, rb)
	strip:SetAllPoints()
	if strip.SetClipsChildren then strip:SetClipsChildren(true) end
	rb.strip = strip
	rb.ticks = {}
	rb.labels = {}
	for i = 1, 8 do
		local card = (i % 2 == 1)
		local fs = Ink:Text(strip, F.latinB, card and 11 or 8, CREAM, "CENTER")
		fs:SetText(DIRS[i])
		if i == 1 then fs:SetTextColor(NORTH[1], NORTH[2], NORTH[3]) elseif not card then fs:SetTextColor(SOFT[1], SOFT[2], SOFT[3]) end
		fs:Hide()
		rb.labels[i] = fs
	end
	rb.markBack = Diamond(strip, "ARTWORK", 8, { 0.23, 0.16, 0 }, 1)
	rb.mark = Diamond(strip, "ARTWORK", 6, { 1, 0.82, 0 }, 1, 1)
	rb.markBack:Hide(); rb.mark:Hide()
	rb.pointer = o:CreateTexture(nil, "OVERLAY", nil, 7)
	rb.pointer:SetTexture(TEX .. "MMPointer")
	rb.pointer:SetSize(16, 16)
	rb.pointer:SetVertexColor(1, 0.94, 0.77, 1)
	rb.pointer:SetPoint("BOTTOM", rb, "TOP", 0, -6)
	rb:SetScript("OnUpdate", function(self, e)
		self.t = (self.t or 0) + e
		if self.t < 0.03 then return end
		self.t = 0
		M:PaintRibbon()
	end)
	A.ribbon = rb

	-- 4) 아래 지역 정보
	local inf = CreateFrame("Frame", nil, o)
	inf:SetSize(10, 40)
	inf:SetFrameLevel(o:GetFrameLevel() + 3)
	inf.shade = inf:CreateTexture(nil, "BACKGROUND")
	inf.shade:SetTexture(Ink.tex.glow)
	inf.shade:SetPoint("CENTER", 0, -2)
	inf.shade:SetVertexColor(INK[1], INK[2], INK[3], 0.62)
	inf.zone = Ink:Text(inf, F.bold, 13, CREAM, "CENTER")
	inf.zone:SetPoint("TOP", 0, 0)
	inf.zone:SetShadowColor(0, 0, 0, 1)
	inf.diaL = Diamond(inf, "ARTWORK", 4, GOLD)
	inf.diaR = Diamond(inf, "ARTWORK", 4, GOLD)
	inf.diaL:SetPoint("RIGHT", inf.zone, "LEFT", -8, 0)
	inf.diaR:SetPoint("LEFT", inf.zone, "RIGHT", 8, 0)
	inf.lineL = White(inf, "ARTWORK")
	inf.lineR = White(inf, "ARTWORK")
	inf.lineL:SetSize(28, Ink:Px(1)); inf.lineR:SetSize(28, Ink:Px(1))
	HGrad(inf.lineL, GOLD, 0, 1); HGrad(inf.lineR, GOLD, 1, 0)
	inf.lineL:SetPoint("RIGHT", inf.diaL, "LEFT", -6, 0)
	inf.lineR:SetPoint("LEFT", inf.diaR, "RIGHT", 6, 0)
	inf.lv = Ink:Text(inf, F.numR, 11, { 1, 0.82, 0.3 }, "LEFT")
	inf.tm = Ink:Text(inf, F.numR, 11, { 0.945, 0.902, 0.8 }, "LEFT")
	inf.co = Ink:Text(inf, F.numR, 11, SOFT, "LEFT")
	inf.hd = Ink:Text(inf, F.sans, 11, SOFT, "LEFT")
	inf.dots = {}
	for i = 1, 3 do
		local d = inf:CreateTexture(nil, "ARTWORK")
		d:SetTexture(Ink.tex.disc)
		d:SetSize(3, 3)
		d:SetVertexColor(GOLD_DK[1], GOLD_DK[2], GOLD_DK[3], 1)
		inf.dots[i] = d
	end
	for _, fs in ipairs({ inf.lv, inf.tm, inf.co, inf.hd }) do fs:SetShadowColor(0, 0, 0, 1) end
	A.info = inf

	-- 5) 버튼: 우편 · 추적 (오른쪽 아래). 애드온 목록은 BuildAddonList 가 오른쪽 위에 만든다
	local mail = self:ArcButton(o, "NpcMail", 20)
	mail:SetFrameLevel(o:GetFrameLevel() + 6)
	mail.dot = mail:CreateTexture(nil, "OVERLAY")
	mail.dot:SetTexture(Ink.tex.disc)
	mail.dot:SetSize(6, 6)
	mail.dot:SetPoint("TOPRIGHT", 1, 1)
	mail.dot:SetVertexColor(1, 0.7, 0.28, 1)
	mail.OnTip = function(_, tt)
		tt:SetText("새 우편", 1, 1, 1)
		local s1, s2, s3 = nil, nil, nil
		if GetLatestThreeSenders then s1, s2, s3 = GetLatestThreeSenders() end
		if s1 then tt:AddLine(s1, 0.8, 0.8, 0.8) end
		if s2 then tt:AddLine(s2, 0.8, 0.8, 0.8) end
		if s3 then tt:AddLine(s3, 0.8, 0.8, 0.8) end
	end
	mail:RegisterEvent("UPDATE_PENDING_MAIL")
	mail:RegisterEvent("PLAYER_ENTERING_WORLD")
	mail:RegisterEvent("MAIL_CLOSED")
	mail:SetScript("OnEvent", function() M:UpdateArcaneMail() end)
	A.mail = mail

	local track = self:ArcButton(o, "Search", 20)
	track:SetFrameLevel(o:GetFrameLevel() + 6)
	track:SetScript("OnClick", function() M:OpenTracking() end)
	track.OnTip = function(_, tt)
		tt:SetText("추적", 1, 1, 1)
		tt:AddLine("약초 · 광석 · 마을 사람 찾기", 0.7, 0.7, 0.7)
		tt:AddLine("미니맵 오른쪽 클릭도 같아요", 0.56, 0.58, 0.61)
	end
	A.track = track

	-- 블리자드 우편 표시는 숨기고 위 버튼으로 대신
	local ind = MinimapCluster and MinimapCluster.IndicatorFrame
	if ind and ind.MailFrame then Ink:KeepHidden(ind.MailFrame) end

	-- 편집 모드에서 미니맵을 옮기면 띠 위치(위 · 아래)를 다시 정한다
	hooksecurefunc(a, "SetPoint", function()
		if A.relayoutQueued then return end
		A.relayoutQueued = true
		C_Timer.After(0, function()
			A.relayoutQueued = nil
			local ok, err = pcall(M.LayoutArcane, M)
			if not ok then Ink:LogError("Blizzard.LayoutArcane: " .. tostring(err)) end
		end)
	end)

	self:UpdateArcaneMail()
	self:ApplyArcaneOptions()
end

-------------------------------------------------------------------------------
-- 설정 반영 (마법진 · 나침반 띠 · 가장자리 번짐)
-------------------------------------------------------------------------------
function M:ApplyArcaneOptions()
	local A = self.arc
	if not A then return end
	A.sigil:SetShown(Ink.db.mmSigil ~= false)
	local rib = Ink.db.mmRibbon ~= false
	A.ribbon:SetShown(rib)
	A.ribbon.pointer:SetShown(rib)
	self:LayoutArcane()
	if self.ApplyMinimapMask then self:ApplyMinimapMask() end
end

-------------------------------------------------------------------------------
-- 배치 (미니맵 크기 · 위치가 바뀔 때마다)
-------------------------------------------------------------------------------
function M:LayoutArcane()
	local A, a, o = self.arc, self.mmAnchor, self.mmOverlay
	if not A then return end
	local W = a:GetWidth() or 200
	if W < 10 then W = 200 end
	local k = W / DESIGN

	-- 모서리: 텍스처 한 장 = 시안 84칸, 꼭짓점은 지도 모서리에서 바깥으로 10칸
	local cs, off = 84 * k, 24 * k
	local c = A.corners
	for i = 1, 4 do c[i]:ClearAllPoints(); c[i]:SetSize(cs, cs) end
	c[1]:SetPoint("TOPLEFT", a, "TOPLEFT", -off, off)
	c[2]:SetPoint("TOPRIGHT", a, "TOPRIGHT", off, off)
	c[3]:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", -off, -off)
	c[4]:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", off, -off)

	-- 마법진: 텍스처 512 = 시안 512칸 (바깥 원 반지름 236)
	local ss = 512 * k * 0.92
	A.sigil:SetSize(ss, ss)
	A.sigil.halo:SetSize(ss * 1.05, ss * 1.05)

	-- 나침반 띠: 위에 자리가 없으면(화면 맨 위에 붙인 경우) 지도 아래로
	local rb = A.ribbon
	local rw, rh = math.floor(W * 0.8 + 0.5), 20
	rb:SetSize(rw, rh)
	rb.bg:Place(rw, rh, "CENTER", rb, "CENTER", 0)
	rb.hiT:Place(rw, Ink:Px(1), "TOP", rb, "TOP", 0)
	rb.hiB:Place(rw, Ink:Px(1), "BOTTOM", rb, "BOTTOM", 0)
	rb.k = rw / 120 -- 띠 안에 ±60°
	local top, rt = a:GetTop(), Ink.root:GetTop()
	local above = not (top and rt) or (rt - top) >= rh + 16
	A.ribbonAbove = above
	rb:ClearAllPoints()
	local inf = A.info
	inf:ClearAllPoints()
	local rib = rb:IsShown()
	local below = math.floor(14 * k + 6)
	if above or not rib then
		rb:SetPoint("BOTTOM", a, "TOP", 0, math.floor(16 * k + 2))
		inf:SetPoint("TOP", a, "BOTTOM", 0, -below)
	else
		rb:SetPoint("TOP", a, "BOTTOM", 0, -below)
		inf:SetPoint("TOP", rb, "BOTTOM", 0, -8)
	end

	-- 버튼: 오른쪽 위 애드온 목록 · 오른쪽 아래 [낮밤] [우편] [추적]
	local lb = self.listButton
	if lb and lb.arc then
		lb:ClearAllPoints()
		lb:SetPoint("TOPRIGHT", o, "TOPRIGHT", -6, -6)
	end
	local ind = MinimapCluster and MinimapCluster.IndicatorFrame
	if ind then
		safe(function()
			ind:ClearAllPoints()
			ind:SetPoint("TOPRIGHT", o, "TOPRIGHT", -32, -6)
		end)
	end
	self:LayoutArcaneButtons()
	if rib then self:PaintRibbon(true) end
	self:UpdateArcaneText()
end

function M:LayoutArcaneButtons()
	local A, o = self.arc, self.mmOverlay
	if not A then return end
	local x = -6
	A.track:ClearAllPoints()
	A.track:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", x, 6)
	x = x - 24
	if A.mail:IsShown() then
		A.mail:ClearAllPoints()
		A.mail:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", x, 6)
		x = x - 24
	end
	local d = self.mmDiel
	if d then
		d:ClearAllPoints()
		d:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", x, 8)
	end
end

function M:UpdateArcaneMail()
	local A = self.arc
	if not A then return end
	local has = HasNewMail and HasNewMail()
	local was = A.mail:IsShown()
	A.mail:SetShown(has and true or false)
	if was ~= A.mail:IsShown() then self:LayoutArcaneButtons() end
end

-- 추적 메뉴 (미니맵 오른쪽 클릭과 같다)
function M:OpenTracking()
	local mc = MinimapCluster
	local tr = mc and (mc.Tracking or mc.TrackingFrame)
	local b = tr and (tr.Button or tr)
	if b and b.OpenMenu then safe(b.OpenMenu, b)
	elseif b and b.Click then safe(b.Click, b)
	elseif MiniMapTrackingDropDown and ToggleDropDownMenu then
		safe(ToggleDropDownMenu, 1, nil, MiniMapTrackingDropDown, self.arc and self.arc.track or "cursor", 0, 0)
	end
end

-------------------------------------------------------------------------------
-- 길 안내 방향 (북쪽에서 시계 방향 각도). 미니맵에 찍은 길 안내 핀 기준
-------------------------------------------------------------------------------
local function Bearing()
	local wp = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
	if not wp or not wp.position then return end
	local map = C_Map.GetBestMapForUnit("player")
	if not map then return end
	local pp = C_Map.GetPlayerMapPosition(map, "player")
	if not pp then return end
	local tx, ty
	if wp.uiMapID == map then
		tx, ty = wp.position:GetXY()
	elseif C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos then
		local cont, wpos = C_Map.GetWorldPosFromMapPos(wp.uiMapID, wp.position)
		if cont and wpos then
			local _, mpos = C_Map.GetMapPosFromWorldPos(cont, wpos, map)
			if mpos then tx, ty = mpos:GetXY() end
		end
	end
	if not tx then return end
	local px, py = pp:GetXY()
	-- 지역 지도는 가로가 세로의 1.5배 (게임 자료가 있으면 실제 크기)
	local w, h = 1.5, 1
	if C_Map.GetMapWorldSize then
		local ok, a, b = pcall(C_Map.GetMapWorldSize, map)
		if ok and type(a) == "number" and type(b) == "number" and a > 0 and b > 0 then w, h = a, b end
	end
	local ex, sy = (tx - px) * w, (ty - py) * h
	if ex * ex + sy * sy < 1e-12 then return end
	local atan2 = math.atan2 or atan2
	return (math.deg(atan2(ex, -sy)) + 360) % 360
end

function M:TargetBearing()
	local A = self.arc
	local now = GetTime()
	if A.tbAt and now - A.tbAt < 0.25 then return A.tb end
	A.tbAt = now
	local ok, b = pcall(Bearing)
	A.tb = ok and b or nil
	return A.tb
end

-------------------------------------------------------------------------------
-- 나침반 띠 그리기
-------------------------------------------------------------------------------
local function Heading()
	local fac = GetPlayerFacing and GetPlayerFacing()
	fac = Ink.plain(fac)
	if type(fac) ~= "number" then return end
	return (360 - math.deg(fac)) % 360
end
M.ArcHeading = Heading

function M:PaintRibbon(force)
	local A = self.arc
	local rb = A and A.ribbon
	if not (rb and rb:IsShown()) then return end
	local h = Heading()
	local tb = self:TargetBearing()
	if not force and h == A.lastH and tb == A.lastTB then return end
	A.lastH, A.lastTB = h, tb
	if not h then
		-- 방향을 알 수 없는 곳 (일부 인스턴스): 마지막 모습을 흐리게
		rb.strip:SetAlpha(0.35)
		self:SetArcHeadingText(nil)
		return
	end
	rb.strip:SetAlpha(1)
	local K, strip = rb.k or 1.33, rb.strip
	local half = (rb:GetWidth() or 160) / 2
	local used = rb.used or {}
	rb.used = used
	wipe(used)
	local ti = 0
	local d = math.floor((h - 66) / 5) * 5
	while d <= h + 66 do
		local x = (d - h) * K
		local ax = math.abs(x) / half
		if ax < 1 then
			local al = 1 - ax * ax
			local dd = d % 360
			if dd % 45 == 0 then
				local i = dd / 45 + 1
				local fs = rb.labels[i]
				fs:ClearAllPoints()
				fs:SetPoint("CENTER", strip, "CENTER", x, 3)
				fs:SetAlpha(al)
				fs:Show()
				used[i] = true
			else
				ti = ti + 1
				local t = rb.ticks[ti]
				if not t then
					t = White(strip, "ARTWORK")
					rb.ticks[ti] = t
				end
				local mid = (dd % 15 == 0)
				t:SetSize(Ink:Px(1), mid and 6 or 4)
				if mid then t:SetVertexColor(0.94, 0.83, 0.56, 1) else t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.6) end
				t:ClearAllPoints()
				t:SetPoint("BOTTOM", strip, "BOTTOM", x, 2)
				t:SetAlpha(al)
				t:Show()
			end
		end
		d = d + 5
	end
	for i = ti + 1, #rb.ticks do rb.ticks[i]:Hide() end
	for i = 1, 8 do if not used[i] then rb.labels[i]:Hide() end end
	-- 길 안내 방향: 띠 밖이면 가장자리에 걸쳐 보인다
	if tb then
		local dx = ((tb - h + 540) % 360) - 180
		local x = dx * K
		local lim = half - 6
		local edge = math.abs(x) > lim
		if edge then x = (x > 0) and lim or -lim end
		for _, t in ipairs({ rb.markBack, rb.mark }) do
			t:ClearAllPoints()
			t:SetPoint("BOTTOM", strip, "BOTTOM", x, t == rb.mark and 3 or 2)
			t:SetAlpha(edge and 0.7 or 1)
			t:Show()
		end
	else
		rb.markBack:Hide(); rb.mark:Hide()
	end
	self:SetArcHeadingText(h)
end

function M:SetArcHeadingText(h)
	local inf = self.arc and self.arc.info
	if not inf then return end
	local txt = ""
	if h then
		local r = math.floor(h + 0.5) % 360
		txt = DIRS_KR[math.floor(r / 45 + 0.5) % 8 + 1] .. " " .. r .. "°"
	end
	if inf.hd:GetText() ~= txt then
		inf.hd:SetText(txt)
		self:LayoutArcaneRow()
	end
end

-------------------------------------------------------------------------------
-- 아래 정보 (0.5초마다 UpdateMinimapText 에서)
-------------------------------------------------------------------------------
local function ZoneLv(map)
	local Map = Ink.modules.Map
	if not (Map and Map.ZoneLevels and map) then return end
	local id = map
	for _ = 1, 4 do
		local lo, hi = Map.ZoneLevels(id)
		if lo then return lo, hi end
		local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
		id = info and info.parentMapID
		-- 대륙(2) 이상으로 올라가면 그만
		if not id or id == 0 or (info and info.mapType and info.mapType <= 2) then return end
	end
end

local function LvColor(lo, hi)
	local me = UnitLevel("player") or 1
	local function qc(l)
		local c = GetQuestDifficultyColor and GetQuestDifficultyColor(l)
		if c then return c.r, c.g, c.b end
		return 1, 1, 1
	end
	if me < lo then return qc(lo) end
	if me > hi then return qc(hi) end
	return 1, 0.82, 0.3
end

function M:UpdateArcaneText()
	local A = self.arc
	if not A then return end
	local inf = A.info
	local zone = GetMinimapZoneText and GetMinimapZoneText() or ""
	if inf.zone:GetText() ~= zone then inf.zone:SetText(zone) end
	local map, x, y
	safe(function()
		map = C_Map.GetBestMapForUnit("player")
		local pos = map and C_Map.GetPlayerMapPosition(map, "player")
		if pos then x, y = pos:GetXY() end
	end)
	local lo, hi = ZoneLv(map)
	if lo then
		inf.lv:SetText(lo == hi and tostring(lo) or (lo .. "–" .. hi))
		inf.lv:SetTextColor(LvColor(lo, hi))
	else
		inf.lv:SetText("")
	end
	local hh, mm
	if Ink.db.clockServer and GetGameTime then hh, mm = GetGameTime() else hh, mm = tonumber(date("%H")), tonumber(date("%M")) end
	inf.tm:SetFormattedText("%02d:%02d", hh or 0, mm or 0)
	if x and y and (x > 0 or y > 0) then inf.co:SetFormattedText("%.1f, %.1f", x * 100, y * 100) else inf.co:SetText("") end
	-- 띠를 껐으면 방향 글자는 여기서
	if not (A.ribbon and A.ribbon:IsShown()) then self:SetArcHeadingText(Heading()) end
	self:LayoutArcaneRow()
end

-- 두 번째 줄: [레벨] · [시간] · [좌표] · [방향] 가운데 정렬 (빈 칸은 건너뜀)
function M:LayoutArcaneRow()
	local inf = self.arc and self.arc.info
	if not inf then return end
	local parts = {}
	for _, fs in ipairs({ inf.lv, inf.tm, inf.co, inf.hd }) do
		local t = fs:GetText()
		if t and t ~= "" then parts[#parts + 1] = fs; fs:Show() else fs:Hide() end
	end
	local GAP, DOT = 7, 3
	local total = 0
	for i, fs in ipairs(parts) do
		total = total + (fs:GetStringWidth() or 0)
		if i > 1 then total = total + DOT + GAP * 2 end
	end
	local x = -total / 2
	local y = -22
	for i, fs in ipairs(parts) do
		if i > 1 then
			local d = inf.dots[i - 1]
			d:ClearAllPoints()
			d:SetPoint("CENTER", inf, "TOP", x + GAP + DOT / 2, y)
			d:Show()
			x = x + DOT + GAP * 2
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", inf, "TOP", x, y)
		x = x + (fs:GetStringWidth() or 0)
	end
	for i = math.max(#parts, 1), 3 do inf.dots[i]:Hide() end
	local zw = (inf.zone:GetStringWidth() or 0) + 90
	local w = math.max(zw, total + 70, 150)
	inf.shade:SetSize(w, 62)
end

-------------------------------------------------------------------------------
-- 애드온 목록 금색 꾸밈 (BuildAddonList 에서)
-------------------------------------------------------------------------------
function M:StyleArcaneList(f)
	if not f then return end
	f.bg:SetVertexColor(INK[1], INK[2], INK[3], 0.93)
	f.bd:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
	f.accent:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.95)
	f.title:SetTextColor(0.66, 0.6, 0.47)
	f.arc = true
end
