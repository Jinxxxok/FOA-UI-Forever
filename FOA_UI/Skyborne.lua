-- FOA UI · 스카이본 지맥 · 정기의 합일점 (지역 지도)
--  하이 오더 스카이본(얼라이언스)은 지맥, 윈드셰이퍼 스카이본(호드)은 정기의 합일점을 지역 지도에만 찍는다
--  (대륙 · 세계 지도엔 안 찍는다 · 스카이본이 아니면 아무것도 안 한다)
--  · 자리: SkyborneNodes.lua (SLLCM · MIT) — 알려진 자리 모음이라 늘 다 있는 건 아니다
--  · 120야드 안에 모인 자리는 한 표시로 묶는다 → 그 자리에 서면 미니맵 추적에 지금 있는 것이 다 보이는 거리
--  · 조율(충전) 버프가 10분 넘게 남아 있으면 표시를 흐리게 (지금은 안 가도 된다)
--  · 지도 왼쪽 위(적정 레벨 아래)에 이 지역 자리 수 · 버프 남은 시간

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Skyborne")
local F, C = Ink.font, Ink.c
local plain = Ink.plain or function(v) return v end

local KIND = {
	ley = { name = "지맥", spell = "지맥 읽기", buffName = "조율", buff = 1259691, rgb = Ink.hex("B49CFF"),
		how = "가까이서 「지맥 읽기」를 쓰면 1시간 동안 조율", eff = "생명력 · 마나 회복 증가 50% → 100% · 죽어도 유지 · 공격대에 들어가면 사라짐" },
	conv = { name = "정기의 합일점", spell = "창공안", buffName = "충전", buff = 1270893, rgb = Ink.hex("5FD8C8"),
		how = "가까이서 「창공안」을 쓰면 1시간 동안 충전", eff = "이동 · 탈것 속도 증가 15% → 30% · 죽어도 유지 · 공격대에 들어가면 사라짐" },
}
M.KIND = KIND
local GROUP_YARDS = 120  -- 이 안에 모인 자리는 한 표시로
local FRESH_MIN = 10     -- 버프가 이보다 적게 남으면 다시 또렷하게
local DIM = 0.42

-- 내 캐릭터가 쓰는 쪽 (스카이본이 아니면 nil) · 하이 오더 = 얼라이언스, 윈드셰이퍼 = 호드
function M:Kind()
	if not ns.SKYBORNE_NODES then return end
	local name, file, id = UnitRace("player")
	local sky = id == 95 or id == 96
		or (type(file) == "string" and file:lower():find("skyborn", 1, true))
		or (type(name) == "string" and name:find("스카이본", 1, true))
	if not sky then return end
	local fac = UnitFactionGroup("player")
	if fac == "Alliance" then return "ley" end
	if fac == "Horde" then return "conv" end
	return id == 96 and "conv" or "ley"
end

-------------------------------------------------------------------------------
-- 자료 읽기 · 묶기
-------------------------------------------------------------------------------
local parsed = {}
local function Nodes(kind, mapID)
	local t = parsed[kind]
	if not t then
		t = {}
		for _, seg in ipairs(ns.SKYBORNE_NODES and ns.SKYBORNE_NODES[kind] or {}) do
			local id, rest = seg:match("^(%d+):(.+)$")
			if id then
				local l = {}
				for x, y in rest:gmatch("(%d+),(%d+)") do l[#l + 1] = { tonumber(x) / 10000, tonumber(y) / 10000 } end
				t[tonumber(id)] = l
			end
		end
		parsed[kind] = t
	end
	return t[mapID]
end
M.Nodes = Nodes

-- 지역 지도 한 장의 가로 · 세로 (야드). 지도 x 는 세계 Y, 지도 y 는 세계 X 방향
local sizeCache = {}
local function MapYards(mapID)
	local s = sizeCache[mapID]
	if s ~= nil then
		if s then return s[1], s[2] end
		return
	end
	local w, h
	if C_Map.GetWorldPosFromMapPos and CreateVector2D then
		local ok1, _, a = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
		local ok2, _, b = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
		if ok1 and ok2 and a and b and a.GetXY and b.GetXY then
			local ax, ay = a:GetXY()
			local bx, by = b:GetXY()
			ax, ay, bx, by = plain(ax), plain(ay), plain(bx), plain(by)
			if type(ax) == "number" and type(ay) == "number" and type(bx) == "number" and type(by) == "number" then
				w, h = math.abs(ay - by), math.abs(ax - bx)
				if w < 50 or h < 50 then w, h = nil, nil end
			end
		end
	end
	sizeCache[mapID] = w and { w, h } or false
	return w, h
end

local groupCache = {}
local function Groups(kind, mapID)
	local key = kind .. ":" .. mapID
	local gs = groupCache[key]
	if gs then return gs end
	local pts = Nodes(kind, mapID)
	if not pts then return end
	local w, h = MapYards(mapID)
	w, h = w or 3000, h or 2000 -- 못 재면 보통 지역 크기로
	local r2 = GROUP_YARDS * GROUP_YARDS
	gs = {}
	for _, p in ipairs(pts) do
		local best, bd
		for _, g in ipairs(gs) do
			local dx, dy = (p[1] - g.x) * w, (p[2] - g.y) * h
			local d = dx * dx + dy * dy
			if d <= r2 and (not bd or d < bd) then best, bd = g, d end
		end
		if best then
			best.n = best.n + 1
			best.sx, best.sy = best.sx + p[1], best.sy + p[2]
			best.x, best.y = best.sx / best.n, best.sy / best.n
		else
			gs[#gs + 1] = { x = p[1], y = p[2], sx = p[1], sy = p[2], n = 1 }
		end
	end
	groupCache[key] = gs
	return gs
end
M.Groups = Groups

-- 조율 · 충전 남은 초 (없으면 nil)
local function BuffLeft(kind)
	local k = KIND[kind]
	if not (k and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return end
	local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, k.buff)
	if not (ok and a) then return end
	local exp = plain(a.expirationTime)
	if type(exp) ~= "number" or exp <= 0 then return 3600 end
	return math.max(0, exp - GetTime())
end
M.BuffLeft = BuffLeft

-------------------------------------------------------------------------------
-- 지도 표시
-------------------------------------------------------------------------------
local function Waypoint(x, y)
	local wm = WorldMapFrame
	local mapID = wm and wm:GetMapID()
	if mapID and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
	end
end

function M:Tip(p)
	local k = KIND[p.kind]
	if not k then return end
	local c = k.rgb
	GameTooltip:SetOwner(p, "ANCHOR_RIGHT", 4, 0)
	GameTooltip:AddLine(k.name .. (p.n > 1 and ("  |cff8E939B·  알려진 자리 " .. p.n .. "곳|r") or ""), c[1], c[2], c[3])
	GameTooltip:AddLine(k.how, 0.9, 0.9, 0.92)
	Ink.TipLine(GameTooltip, k.eff, 0.7, 0.72, 0.75)
	local left = BuffLeft(p.kind)
	if left and left > 0 then
		local m = math.ceil(left / 60)
		local col = m > FRESH_MIN and "|cff6FD39A" or "|cffFFB75A"
		GameTooltip:AddLine(string.format("%s%s 중|r  ·  %d분 남음", col, k.buffName, m), 1, 1, 1)
	else
		GameTooltip:AddLine(string.format("|cffFFB75A%s 안 됨|r  ·  여기서 「%s」", k.buffName, k.spell), 1, 1, 1)
	end
	GameTooltip:AddLine(" ")
	Ink.TipLine(GameTooltip, p.n > 1
		and string.format("반경 %d야드 안에 알려진 자리 %d곳 · 가서 미니맵을 보면 지금 있는 곳이 보여요", GROUP_YARDS, p.n)
		or "알려진 자리예요 · 늘 있는 건 아니라 가서 미니맵으로 확인하세요", 0.56, 0.58, 0.61)
	GameTooltip:AddLine(string.format("%.1f, %.1f  ·  클릭: 길 안내", p.wx * 100, p.wy * 100), 0.56, 0.58, 0.61)
	GameTooltip:Show()
end

function M:Pin(i, layer)
	self.pins = self.pins or {}
	local p = self.pins[i]
	if p then return p end
	p = CreateFrame("Button", nil, layer)
	p:SetSize(20, 20)
	p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	p.art = CreateFrame("Frame", nil, p)
	p.art:SetPoint("CENTER")
	p.art:SetSize(20, 20)
	p.art:EnableMouse(false)
	local a = p.art
	a.glow = a:CreateTexture(nil, "BACKGROUND", nil, -1)
	a.glow:SetTexture(Ink.tex.glow)
	a.glow:SetPoint("TOPLEFT", -9, 9)
	a.glow:SetPoint("BOTTOMRIGHT", 9, -9)
	a.glow:SetBlendMode("ADD")
	a.disc = a:CreateTexture(nil, "BACKGROUND")
	a.disc:SetTexture(Ink.tex.disc)
	a.disc:SetAllPoints()
	a.disc:SetVertexColor(0.03, 0.03, 0.05, 0.94)
	a.core = a:CreateTexture(nil, "BORDER")
	a.core:SetTexture(Ink.tex.glow)
	a.core:SetPoint("TOPLEFT", 3, -3)
	a.core:SetPoint("BOTTOMRIGHT", -3, 3)
	a.core:SetBlendMode("ADD")
	a.ring = a:CreateTexture(nil, "ARTWORK")
	a.ring:SetTexture(Ink.tex.ring)
	a.ring:SetAllPoints()
	a.icon = a:CreateTexture(nil, "OVERLAY")
	a.icon:SetTexture(Ink.icon("Sparkles"))
	a.icon:SetSize(11, 11)
	a.icon:SetPoint("CENTER")
	-- 묶인 자리 수
	a.badge = CreateFrame("Frame", nil, a)
	a.badge:SetSize(12, 12)
	a.badge:SetPoint("CENTER", a, "BOTTOMRIGHT", -2, 2)
	a.badge.bg = a.badge:CreateTexture(nil, "ARTWORK")
	a.badge.bg:SetTexture(Ink.tex.disc)
	a.badge.bg:SetAllPoints()
	a.badge.t = Ink:Text(a.badge, F.latinB or F.bold, 8, C.text, "CENTER")
	a.badge.t:SetPoint("CENTER", 0, 0)
	a.badge.t:SetShadowOffset(0, 0)
	-- 천천히 숨 쉬는 빛
	local ag = a.glow:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local al = ag:CreateAnimation("Alpha")
	al:SetFromAlpha(0.45)
	al:SetToAlpha(1)
	al:SetDuration(1.6)
	al:SetSmoothing("IN_OUT")
	p.pulse = ag
	-- 마우스를 올리면 살짝 커진다
	local gr = a:CreateAnimationGroup()
	local scl = gr:CreateAnimation("Scale")
	scl:SetDuration(0.12); scl:SetScaleFrom(1, 1); scl:SetScaleTo(1.18, 1.18); scl:SetSmoothing("OUT")
	gr:SetScript("OnFinished", function() a:SetScale(1.18) end)
	p.grow = gr
	p:SetScript("OnEnter", function(self)
		self.lvl = self:GetFrameLevel()
		self:SetFrameLevel(self.lvl + 300)
		self.grow:Play()
		M:Tip(self)
	end)
	p:SetScript("OnLeave", function(self)
		if self.lvl then self:SetFrameLevel(self.lvl); self.lvl = nil end
		self.grow:Stop()
		self.art:SetScale(1)
		GameTooltip:Hide()
	end)
	p:SetScript("OnClick", function(self) Waypoint(self.wx, self.wy) end)
	self.pins[i] = p
	return p
end

-- Map:Refresh 에서 부른다 (wide = 대륙 · 세계 지도)
function M:Draw(mapID, cv, pinScale, layer, wide)
	local n = 0
	local kind = Ink.db.mapSkyborne ~= false and self:Kind() or nil
	local gs = kind and mapID and not wide and Groups(kind, mapID) or nil
	self.kindNow, self.count = gs and kind or nil, 0
	if gs and cv and layer then
		local W, H = cv:GetWidth(), cv:GetHeight()
		local sc = (pinScale or 1) * 0.86
		for _, g in ipairs(gs) do
			n = n + 1
			local p = self:Pin(n, layer)
			p:ClearAllPoints()
			p:SetScale(sc)
			-- 크기를 바꾼 틀의 위치 값은 그 크기만큼 곱해져서 미리 나눠 둔다
			p:SetPoint("CENTER", cv, "TOPLEFT", g.x * W / sc, -g.y * H / sc)
			p:SetFrameLevel(layer:GetFrameLevel() + 12)
			p.kind, p.n, p.wx, p.wy = kind, g.n, g.x, g.y
			self.count = self.count + g.n
			p:Show()
		end
	end
	for i = n + 1, #(self.pins or {}) do
		local p = self.pins[i]
		p:Hide()
		p.pulse:Stop()
	end
	self.shown = n
	self:Paint()
end

-- 색 · 흐림 · 왼쪽 위 칸 (버프가 바뀌거나 시간이 지나면 이것만 다시)
function M:Paint()
	local kind = self.kindNow
	local chip = self.chip
	if not kind then
		if chip then chip:Hide() end
		return
	end
	local k = KIND[kind]
	local c = k.rgb
	local left = BuffLeft(kind)
	local dim = left and left > FRESH_MIN * 60
	for i = 1, self.shown or 0 do
		local p = self.pins[i]
		local a = p.art
		a.ring:SetVertexColor(c[1], c[2], c[3], 1)
		a.icon:SetVertexColor(c[1], c[2], c[3], 1)
		a.core:SetVertexColor(c[1], c[2], c[3], 0.22)
		a.glow:SetVertexColor(c[1], c[2], c[3], 0.34)
		a.badge.bg:SetVertexColor(c[1], c[2], c[3], 1)
		a.badge.t:SetTextColor(0.04, 0.04, 0.06)
		a.badge.t:SetText(p.n > 1 and tostring(p.n) or "")
		a.badge:SetShown(p.n > 1)
		a:SetAlpha(dim and DIM or 1)
		a.glow:SetShown(not dim)
		if dim then p.pulse:Stop() elseif not p.pulse:IsPlaying() then p.pulse:Play() end
	end
	self:PaintChip(k, left)
end

function M:BuildChip()
	local wm = WorldMapFrame
	local sc = wm and wm.ScrollContainer
	if not sc then return end
	local f = CreateFrame("Frame", nil, sc)
	f:SetHeight(24)
	f:SetFrameLevel(sc:GetFrameLevel() + 3000)
	f.bg = Ink:Round(f, "BACKGROUND", true, false)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(0.035, 0.04, 0.052, 0.88)
	f.bd = Ink:Round(f, "BORDER", true, true)
	f.bd:SetAllPoints()
	f.dot = f:CreateTexture(nil, "ARTWORK")
	f.dot:SetTexture(Ink.icon("Sparkles"))
	f.dot:SetSize(12, 12)
	f.dot:SetPoint("LEFT", 8, 0)
	f.name = Ink:Text(f, F.semi, 11, C.text, "LEFT")
	f.name:SetPoint("LEFT", f.dot, "RIGHT", 6, 0)
	f.cnt = Ink:Text(f, F.sans, 10, C.muted, "LEFT")
	f.cnt:SetPoint("LEFT", f.name, "RIGHT", 7, 0)
	f.sep = f:CreateTexture(nil, "ARTWORK")
	f.sep:SetColorTexture(1, 1, 1, 0.12)
	f.sep:SetSize(1, 11)
	f.sep:SetPoint("LEFT", f.cnt, "RIGHT", 8, 0)
	f.buff = Ink:Text(f, F.sans, 10, C.green, "LEFT")
	f.buff:SetPoint("LEFT", f.sep, "RIGHT", 8, 0)
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self)
		local kk = M.kindNow and KIND[M.kindNow]
		if not kk then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, -2)
		GameTooltip:AddLine("스카이본 · " .. kk.name, kk.rgb[1], kk.rgb[2], kk.rgb[3])
		GameTooltip:AddLine(kk.how, 0.9, 0.9, 0.92)
		Ink.TipLine(GameTooltip, "이 지역에서 알려진 자리를 모두 찍었어요 · 늘 다 있는 건 아니에요", 0.7, 0.72, 0.75)
		Ink.TipLine(GameTooltip, string.format("%s 버프가 %d분 넘게 남아 있으면 표시가 흐려져요", kk.buffName, FRESH_MIN), 0.56, 0.58, 0.61)
		GameTooltip:AddLine("자료: SLLCM (tr0tsky · MIT)", 0.45, 0.47, 0.5)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", GameTooltip_Hide)
	f:Hide()
	self.chip = f
	return f
end

function M:PaintChip(k, left)
	local f = self.chip or self:BuildChip()
	if not f then return end
	local wm = WorldMapFrame
	local Mp = Ink.modules.Map
	local zl = Mp and Mp.zoneLv
	f:ClearAllPoints()
	if zl and zl:IsShown() then f:SetPoint("TOPLEFT", zl, "BOTTOMLEFT", 0, -4)
	else f:SetPoint("TOPLEFT", wm.ScrollContainer, "TOPLEFT", 8, -8) end
	local c = k.rgb
	f.dot:SetVertexColor(c[1], c[2], c[3], 1)
	f.bd:SetVertexColor(c[1], c[2], c[3], 0.28)
	f.name:SetText(k.name)
	f.name:SetTextColor(c[1], c[2], c[3])
	f.cnt:SetText(string.format("알려진 자리 %d곳", self.count or 0))
	if left and left > 0 then
		local m = math.ceil(left / 60)
		f.buff:SetText(string.format("%s %d분", k.buffName, m))
		local bc = m > FRESH_MIN and C.green or C.orange
		f.buff:SetTextColor(bc[1], bc[2], bc[3])
	else
		f.buff:SetText(k.buffName .. " 없음")
		f.buff:SetTextColor(C.orange[1], C.orange[2], C.orange[3])
	end
	local w = 8 + 12 + 6 + f.name:GetStringWidth() + 7 + f.cnt:GetStringWidth() + 8 + 1 + 8 + f.buff:GetStringWidth() + 12
	f:SetWidth(math.floor(w + 0.5))
	f:Show()
end

function M:Init()
	if not ns.SKYBORNE_NODES then return end
	local e = CreateFrame("Frame")
	pcall(e.RegisterUnitEvent, e, "UNIT_AURA", "player")
	e:SetScript("OnEvent", function()
		if M.kindNow and WorldMapFrame and WorldMapFrame:IsShown() then pcall(M.Paint, M) end
	end)
	-- 지도를 띄워 둔 동안 남은 시간 갱신
	C_Timer.NewTicker(15, function()
		if M.kindNow and WorldMapFrame and WorldMapFrame:IsShown() then pcall(M.Paint, M) end
	end)
end
