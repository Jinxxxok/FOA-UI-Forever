-- InkUI · 설정 / 편집 모드 / 테스트 모드

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Config")
local F, C = Ink.font, Ink.c

-------------------------------------------------------------------------------
-- 버튼 / 체크박스 (Ink 스타일)
-------------------------------------------------------------------------------
local function Button(parent, text, w, onClick, primary)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w or 120, 30)
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bd = Ink:Round(b, "BORDER", true, true)
	b.bd:SetAllPoints()
	b.text = Ink:Text(b, F.semi, 12, C.text, "CENTER")
	b.text:SetPoint("CENTER")
	b.text:SetText(text)
	function b:SetActive(on)
		self.active = on
		if on or primary then
			self.bg:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], on and 0.22 or 0.14)
			self.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
			self.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
		else
			self.bg:SetVertexColor(1, 1, 1, 0.05)
			self.bd:SetVertexColor(1, 1, 1, 0.16)
			self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
		end
	end
	b:SetActive(false)
	b:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.10) end)
	b:SetScript("OnLeave", function(self) self:SetActive(self.active) end)
	b:SetScript("OnClick", onClick)
	return b
end

local function Check(parent, label, desc, key)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(420, 36)
	f.box = CreateFrame("Frame", nil, f)
	f.box:SetSize(16, 16)
	f.box:SetPoint("TOPLEFT", 0, -2)
	f.box.bd = Ink:Round(f.box, "BORDER", true, true)
	f.box.bd:SetAllPoints()
	f.box.bd:SetVertexColor(1, 1, 1, 0.3)
	f.box.fill = Ink:Round(f.box, "ARTWORK", true, false)
	f.box.fill:SetPoint("TOPLEFT", 3, -3)
	f.box.fill:SetPoint("BOTTOMRIGHT", -3, 3)
	f.box.fill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	f.label = Ink:Text(f, F.semi, 13, C.text, "LEFT")
	f.label:SetPoint("TOPLEFT", f.box, "TOPRIGHT", 10, 1)
	f.label:SetText(label)
	f.desc = Ink:Text(f, F.sans, 11, C.muted, "LEFT")
	f.desc:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -3)
	f.desc:SetText(desc)
	local function refresh() f.box.fill:SetShown(Ink.db[key] and true or false) end
	f:SetScript("OnShow", refresh)
	f:SetScript("OnClick", function()
		Ink.db[key] = not Ink.db[key]
		refresh()
		if key == "barLock" then
			local A = Ink.modules.ActionBars
			if A and A.ApplyLock then A:ApplyLock() end
		else
			M:NeedReload()
		end
	end)
	refresh()
	return f
end

-------------------------------------------------------------------------------
-- 편집 모드 (엘브UI처럼): 격자 · 요소 선택 · 좌표 입력 · 크기 조절 · 화살표 키 미세 이동
--  · 드래그로 이동 (격자 맞춤을 켜면 8칸 단위로 붙는다)
--  · 클릭으로 선택 → 위쪽 막대에서 X / Y 입력, 크기 −/+, 화살표 키(Shift = 10칸)
--  · 우클릭: 이 요소만 기본 위치로
--  · 화면 비율마다 배치가 따로 저장된다 (16:10 / 16:9 / 21:9 / 32:9)
-------------------------------------------------------------------------------
M.overlays = {}
local GRID = 32
local SNAP = 8
local ASPECT_CYCLE = { "auto", "16:10", "16:9", "21:9", "32:9" }

local function MoverSize(m)
	local w, h = m.frame:GetSize()
	if m.w then w = m.w end
	if m.h then h = m.h end
	if not w or w < 20 then w = 120 end
	if not h or h < 14 then h = 24 end
	return w, h
end

local function AspectLabel()
	local mode = Ink.cdb.aspect or "auto"
	local cur = Ink.activeAspect or Ink:DetectAspect()
	if mode == "auto" then return "비율: 자동 (" .. cur .. ")" end
	return "비율: " .. cur
end

-- 격자
function M:BuildGrid()
	local g = CreateFrame("Frame", nil, Ink.root)
	g:SetAllPoints(Ink.root)
	g:SetFrameStrata("DIALOG")
	g:SetFrameLevel(1)
	g.lines = {}
	self.grid = g
end

function M:DrawGrid()
	local g = self.grid
	if not g then return end
	for _, t in ipairs(g.lines) do t:Hide() end
	local n = 0
	local function line(vertical, pos, r, gg, b, a, thick)
		n = n + 1
		local t = g.lines[n]
		if not t then
			t = g:CreateTexture(nil, "BACKGROUND")
			g.lines[n] = t
		end
		t:ClearAllPoints()
		t:SetColorTexture(r, gg, b, a)
		if vertical then
			t:SetPoint("TOPLEFT", g, "TOPLEFT", pos, 0)
			t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", pos, 0)
			t:SetWidth(thick or 1)
		else
			t:SetPoint("TOPLEFT", g, "TOPLEFT", 0, -pos)
			t:SetPoint("TOPRIGHT", g, "TOPRIGHT", 0, -pos)
			t:SetHeight(thick or 1)
		end
		t:Show()
	end
	local w, h = Ink.root:GetWidth(), Ink.root:GetHeight()
	local cx, cy = w / 2, h / 2
	-- 가운데에서 바깥으로 그려서 가운데 선이 정확히 맞게
	for x = cx % GRID, w, GRID do
		local major = math.abs((x - cx) % (GRID * 4)) < 0.5
		line(true, x, 1, 1, 1, major and 0.10 or 0.05)
	end
	for y = cy % GRID, h, GRID do
		local major = math.abs((y - cy) % (GRID * 4)) < 0.5
		line(false, y, 1, 1, 1, major and 0.10 or 0.05)
	end
	local a = C.accent
	line(true, cx - 1, a[1], a[2], a[3], 0.55, 2)
	line(false, cy - 1, a[1], a[2], a[3], 0.55, 2)
	-- 32:9: 요소를 모으는 가운데 21:9 영역 표시
	local inset = Ink.EdgeInset()
	if inset > 0 then
		line(true, inset, a[1], a[2], a[3], 0.35, 2)
		line(true, w - inset, a[1], a[2], a[3], 0.35, 2)
	end
end

function M:ShowGrid(on)
	if on and not self.grid then self:BuildGrid() end
	if not self.grid then return end
	self.grid:SetShown(on)
	if on then self:DrawGrid() end
end

-- 요소 상자 (루트 좌표: 왼쪽 위 x, y / 너비, 높이). 끄는 동안 자석 정렬 · 거리 표시에 쓴다
local MAGNET = 12
local function Box(key)
	local m = Ink.movers[key]
	if not (m and m.frame and m.frame:IsShown()) then return end
	local x, y, w = Ink:FrameBox(key)
	if not x then return end
	local f = m.frame
	local k = f:GetEffectiveScale() / Ink.root:GetEffectiveScale()
	local h = (m.h and m.h * (f:GetScale() or 1)) or f:GetHeight() * k
	if not (w and h) or w < 1 or h < 1 then return end
	return x, y, w, h
end
M.MoverBox = Box

local function IsBar(key)
	return key:match("^bar%d$") or key == "stance" or key == "pet"
end

local function BarGap(key)
	local b = ns.Bars
	if b and b.Settings and IsBar(key) then return b.Settings(key).gap or 0 end
	return 0
end

-- 크기 조절 (미터기 · 채팅): 아래쪽 띠 = 높이, 오른쪽 아래 모서리 = 폭과 높이
--  끄는 동안 왼쪽 위 모서리는 그대로 두고 오른쪽 · 아래로 늘어난다
local function StartResize(m, o, both)
	if InCombatLockdown() or not m.resize then return end
	M:PushUndo(m.key)
	M:Select(m.key)
	local f = m.frame
	local x, y = Ink:FrameBox(m.key)
	if not x then return end
	local s = f:GetScale() or 1
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", Ink.root, "TOPLEFT", x / s, -y / s)
	local cx, cy = GetCursorPosition()
	local es = f:GetEffectiveScale()
	local w0, h0 = f:GetSize()
	o.resizing = true
	o:SetScript("OnUpdate", function()
		if InCombatLockdown() then return end
		local nx, ny = GetCursorPosition()
		local w = both and (w0 + (nx - cx) / es) or w0
		local h = h0 + (cy - ny) / es
		w = math.max(m.minW or 100, math.min(m.maxW or 2000, w))
		h = math.max(m.minH or 40, math.min(m.maxH or 2000, h))
		if Ink.db.editGrid ~= false then
			w = math.floor(w / 4 + 0.5) * 4
			h = math.floor(h / 4 + 0.5) * 4
		end
		local cw, ch = f:GetSize()
		if math.abs(cw - w) >= 1 or math.abs(ch - h) >= 1 then
			m.resize(w, h)
			M:SyncOverlay(m)
			if o.sizeTxt then o.sizeTxt:SetText(string.format("%d × %d", w, h)) end
		end
	end)
	if o.sizeTxt then o.sizeTxt:SetText(string.format("%d × %d", w0, h0)); o.sizeTxt:Show() end
end

local function StopResize(m, o)
	if not o.resizing then return end
	o.resizing = nil
	o:SetScript("OnUpdate", nil)
	if o.sizeTxt then o.sizeTxt:Hide() end
	if InCombatLockdown() then return end
	Ink:SavePos(m.key)
	Ink:Relayout()
	M:SyncAll()
end

local function AddResizeGrips(m, o)
	local a = C.accent
	-- 아래쪽 띠 (가운데 작은 손잡이)
	local bottom = CreateFrame("Button", nil, o)
	bottom:SetPoint("BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", -18, 0)
	bottom:SetHeight(8)
	bottom:SetFrameLevel(o:GetFrameLevel() + 4)
	bottom.pill = bottom:CreateTexture(nil, "OVERLAY")
	bottom.pill:SetTexture(Ink.tex.round4)
	if bottom.pill.SetTextureSliceMargins then bottom.pill:SetTextureSliceMargins(3, 3, 3, 3) end
	bottom.pill:SetSize(34, 4)
	bottom.pill:SetPoint("CENTER", o, "BOTTOM", 0, 3)
	bottom.pill:SetVertexColor(a[1], a[2], a[3], 0.8)
	-- 오른쪽 아래 모서리 (대각선 세 줄)
	local corner = CreateFrame("Button", nil, o)
	corner:SetSize(18, 18)
	corner:SetPoint("BOTTOMRIGHT", 0, 0)
	corner:SetFrameLevel(o:GetFrameLevel() + 5)
	for i, len in ipairs({ 5, 10, 15 }) do
		local t = corner:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(a[1], a[2], a[3], 0.95)
		t:SetSize(len, 1.5)
		t:SetRotation(math.rad(45))
		t:SetPoint("CENTER", corner, "BOTTOMRIGHT", -len * 0.38 - 2, len * 0.38 + 2)
	end
	for _, g in ipairs({ bottom, corner }) do
		g:SetScript("OnMouseDown", function(_, btn) if btn == "LeftButton" then StartResize(m, o, g == corner) end end)
		g:SetScript("OnMouseUp", function() StopResize(m, o) end)
		g:SetScript("OnHide", function() StopResize(m, o) end)
		g:SetScript("OnEnter", function()
			GameTooltip:SetOwner(g, "ANCHOR_RIGHT")
			GameTooltip:SetText(g == corner and "끌어서 폭 · 높이 조절" or "끌어서 높이 조절", 1, 1, 1)
			GameTooltip:Show()
		end)
		g:SetScript("OnLeave", GameTooltip_Hide)
	end
	o.sizeTxt = Ink:Text(o, F.latinB, 11, C.accent, "CENTER")
	o.sizeTxt:SetPoint("CENTER")
	o.sizeTxt:Hide()
end

local function ResetSize(m)
	if m and m.resize and m.defW then
		m.resize(m.defW, m.defH)
		Ink:SaveSize(m.key, nil)
	end
end


-------------------------------------------------------------------------------
-- 끄는 동안: 자석 정렬(노란 안내선) · 원래 자리 유령(점선) · 이웃까지 거리(빨간 숫자) · 되돌리기
--  · 다른 요소의 가장자리 · 가운데, 화면 가장자리 · 가운데에 8칸 안으로 다가가면 착 붙는다
--  · Alt 를 누른 채 끌면 아무 데도 붙지 않고 자유롭게
--  · 격자를 켜 두면 붙지 않은 방향은 놓을 때 8칸 격자에 맞춘다
-------------------------------------------------------------------------------
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local LIVE_MAG = 8
local function MagnetOn() return Ink.db.editMagnet ~= false end
local function GridOn() return Ink.db.editGrid ~= false end
local function DistOn() return Ink.db.editDist ~= false end

local function Tw(id, ch, dur, ease, step, done, delay)
	local S = Ink.modules.Sheet
	if S and S.Tween then return S.Tween(id, ch, dur, ease and S.E[ease] or nil, step, done, delay) end
	step(1)
	if done then done() end
end

-- 붙을 후보: v = 붙을 때 왼쪽(위쪽) 좌표, at = 안내선 위치, lo ~ hi = 안내선이 그어질 범위
local function Candidates(key, x, y, w, h, rw, rh)
	local cx, cy = {}, {}
	local function X(v, at, lo, hi) cx[#cx + 1] = { v = v, at = at, lo = lo, hi = hi } end
	local function Y(v, at, lo, hi) cy[#cy + 1] = { v = v, at = at, lo = lo, hi = hi } end
	X(0, 0, 0, rh); X(rw - w, rw, 0, rh); X(rw / 2 - w / 2, rw / 2, 0, rh)
	Y(0, 0, 0, rw); Y(rh - h, rh, 0, rw); Y(rh / 2 - h / 2, rh / 2, 0, rw)
	for _, other in ipairs(Ink.moverOrder) do
		if other ~= key then
			local ox, oy, ow, oh = Box(other)
			if ox then
				local pad = (IsBar(key) and IsBar(other)) and math.max(BarGap(key), BarGap(other)) or 0
				local nearV = y < oy + oh + 48 and y + h > oy - 48
				local nearH = x < ox + ow + 48 and x + w > ox - 48
				local vlo, vhi = math.min(y, oy), math.max(y + h, oy + oh)
				local hlo, hhi = math.min(x, ox), math.max(x + w, ox + ow)
				-- 가장자리 · 가운데 줄 맞추기 (멀리 있어도)
				X(ox, ox, vlo, vhi); X(ox + ow - w, ox + ow, vlo, vhi); X(ox + (ow - w) / 2, ox + ow / 2, vlo, vhi)
				Y(oy, oy, hlo, hhi); Y(oy + oh - h, oy + oh, hlo, hhi); Y(oy + (oh - h) / 2, oy + oh / 2, hlo, hhi)
				-- 옆 · 위아래에 붙이기 (행동단축바끼리는 버튼 간격만큼 띄워서 한 덩어리처럼)
				if nearV then
					X(ox + ow + pad, ox + ow + pad / 2, vlo, vhi)
					X(ox - w - pad, ox - pad / 2, vlo, vhi)
				end
				if nearH then
					Y(oy + oh + pad, oy + oh + pad / 2, hlo, hhi)
					Y(oy - h - pad, oy - pad / 2, hlo, hhi)
				end
			end
		end
	end
	return cx, cy
end

local function Best(list, cur, th)
	local best, bd
	for _, c in ipairs(list) do
		local d = math.abs(c.v - cur)
		if d <= th and (not bd or d < bd - 0.01) then best, bd = c, d end
	end
	return best
end

local function Span(list, best)
	local lo, hi = best.lo, best.hi
	for _, c in ipairs(list) do
		if math.abs(c.v - best.v) < 0.5 and math.abs(c.at - best.at) < 0.5 then
			lo, hi = math.min(lo, c.lo), math.max(hi, c.hi)
		end
	end
	return lo, hi
end

function M:PlaceAt(m, x, y)
	local s = m.frame:GetScale() or 1
	m.frame:ClearAllPoints()
	m.frame:SetPoint("TOPLEFT", Ink.root, "TOPLEFT", x / s, -y / s)
end

-- 안내선 · 거리 그리는 층 (그때그때 필요한 만큼 선 · 숫자를 꺼내 쓴다)
function M:FxBegin()
	local g = self.fx
	if not g then
		g = CreateFrame("Frame", nil, Ink.root)
		g:SetAllPoints(Ink.root)
		g:SetFrameStrata("FULLSCREEN")
		g.lines, g.labels = {}, {}
		self.fx = g
	end
	g.n, g.m = 0, 0
	g:Show()
end

function M:FxLine(x, y, w, h, c, a)
	local g = self.fx
	g.n = g.n + 1
	local t = g.lines[g.n]
	if not t then
		t = g:CreateTexture(nil, "OVERLAY")
		t:SetTexture(WHITE8)
		g.lines[g.n] = t
	end
	local one = Ink:Px(1)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", g, "TOPLEFT", x, -y)
	t:SetSize(math.max(w, one), math.max(h, one))
	t:SetVertexColor(c[1], c[2], c[3], a or 1)
	t:Show()
end

function M:FxLabel(cx, cy, text)
	local g = self.fx
	g.m = g.m + 1
	local l = g.labels[g.m]
	if not l then
		l = CreateFrame("Frame", nil, g)
		l:SetHeight(17)
		l.bg = Ink:Round(l, "BACKGROUND", true, false)
		l.bg:SetAllPoints()
		l.text = Ink:Text(l, F.latinB, 10, { 0.067, 0.075, 0.094 }, "CENTER")
		l.text:SetPoint("CENTER", 0, 0)
		g.labels[g.m] = l
	end
	l.text:SetText(text)
	l:SetWidth(math.ceil(l.text:GetStringWidth() or 10) + 12)
	l.bg:SetVertexColor(C.red[1], C.red[2], C.red[3], 1)
	l:ClearAllPoints()
	l:SetPoint("CENTER", g, "TOPLEFT", cx, -cy)
	l:Show()
end

function M:FxEnd()
	local g = self.fx
	if not g then return end
	for i = g.n + 1, #g.lines do g.lines[i]:Hide() end
	for i = g.m + 1, #g.labels do g.labels[i]:Hide() end
end

function M:FxClear()
	if not self.fx then return end
	self:FxBegin()
	self:FxEnd()
end

-- 이웃까지 거리: 왼쪽 · 오른쪽 · 위 · 아래에서 가장 가까운 요소 하나씩
function M:DrawGaps(key, x, y, w, h)
	local L, R, U, D
	for _, other in ipairs(Ink.moverOrder) do
		if other ~= key then
			local ox, oy, ow, oh = Box(other)
			if ox then
				local vOver = oy < y + h and oy + oh > y
				local hOver = ox < x + w and ox + ow > x
				if vOver and ox + ow <= x + 0.5 and (not L or ox + ow > L[1] + L[3]) then L = { ox, oy, ow, oh } end
				if vOver and ox >= x + w - 0.5 and (not R or ox < R[1]) then R = { ox, oy, ow, oh } end
				if hOver and oy + oh <= y + 0.5 and (not U or oy + oh > U[2] + U[4]) then U = { ox, oy, ow, oh } end
				if hOver and oy >= y + h - 0.5 and (not D or oy < D[2]) then D = { ox, oy, ow, oh } end
			end
		end
	end
	local red = C.red
	local function midY(o) local a, b = math.max(y, o[2]), math.min(y + h, o[2] + o[4]); return (a + b) / 2 end
	local function midX(o) local a, b = math.max(x, o[1]), math.min(x + w, o[1] + o[3]); return (a + b) / 2 end
	if L then
		local g, my = x - (L[1] + L[3]), midY(L)
		if g >= 1 and g < 900 then
			self:FxLine(L[1] + L[3], my, g, 1, red)
			self:FxLine(L[1] + L[3], my - 4, 1, 9, red); self:FxLine(x - 1, my - 4, 1, 9, red)
			self:FxLabel(L[1] + L[3] + g / 2, my - 12, tostring(math.floor(g + 0.5)))
		end
	end
	if R then
		local g, my = R[1] - (x + w), midY(R)
		if g >= 1 and g < 900 then
			self:FxLine(x + w, my, g, 1, red)
			self:FxLine(x + w, my - 4, 1, 9, red); self:FxLine(R[1] - 1, my - 4, 1, 9, red)
			self:FxLabel(x + w + g / 2, my - 12, tostring(math.floor(g + 0.5)))
		end
	end
	if U then
		local g, mx = y - (U[2] + U[4]), midX(U)
		if g >= 1 and g < 900 then
			self:FxLine(mx, U[2] + U[4], 1, g, red)
			self:FxLine(mx - 4, U[2] + U[4], 9, 1, red); self:FxLine(mx - 4, y - 1, 9, 1, red)
			self:FxLabel(mx + 18, U[2] + U[4] + g / 2, tostring(math.floor(g + 0.5)))
		end
	end
	if D then
		local g, mx = D[2] - (y + h), midX(D)
		if g >= 1 and g < 900 then
			self:FxLine(mx, y + h, 1, g, red)
			self:FxLine(mx - 4, y + h, 9, 1, red); self:FxLine(mx - 4, D[2] - 1, 9, 1, red)
			self:FxLabel(mx + 18, y + h + g / 2, tostring(math.floor(g + 0.5)))
		end
	end
end

-- 고른 요소의 거리 표시 (끌지 않을 때도)
function M:ShowSelGaps()
	if not (self.editing and self.sel and DistOn()) or self.dragging then
		if not self.dragging then self:FxClear() end
		return
	end
	local x, y, w, h = Box(self.sel)
	self:FxBegin()
	if x then self:DrawGaps(self.sel, x, y, w, h) end
	self:FxEnd()
end

-- 원래 자리 유령 (점선)
function M:ShowGhost(x, y, w, h)
	local gh = self.ghost
	if not gh then
		gh = CreateFrame("Frame", nil, Ink.root)
		gh:SetFrameStrata("DIALOG")
		gh:SetFrameLevel(12)
		gh.fill = gh:CreateTexture(nil, "BACKGROUND")
		gh.fill:SetTexture(WHITE8)
		gh.fill:SetAllPoints()
		gh.fill:SetVertexColor(1, 1, 1, 0.035)
		gh.d = {}
		gh.label = Ink:Text(gh, F.sans, 10, C.dim, "LEFT")
		gh.label:SetPoint("TOPLEFT", 5, -4)
		gh.label:SetText("원래 자리")
		self.ghost = gh
	end
	gh:ClearAllPoints()
	gh:SetPoint("TOPLEFT", Ink.root, "TOPLEFT", x, -y)
	gh:SetSize(w, h)
	gh.label:SetShown(w > 70 and h > 22)
	local n = 0
	local function dash(px, py, dw, dh)
		n = n + 1
		local t = gh.d[n]
		if not t then
			t = gh:CreateTexture(nil, "BORDER")
			t:SetTexture(WHITE8)
			gh.d[n] = t
		end
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", gh, "TOPLEFT", px, -py)
		t:SetSize(dw, dh)
		t:SetVertexColor(0.95, 0.95, 0.93, 0.4)
		t:Show()
	end
	local DL, GP, T = 6, 4, 1.5
	if w > 900 or h > 900 then DL, GP = 10, 6 end
	for px = 0, w - 1, DL + GP do
		local dw = math.min(DL, w - px)
		dash(px, 0, dw, T); dash(px, h - T, dw, T)
	end
	for py = 0, h - 1, DL + GP do
		local dh = math.min(DL, h - py)
		dash(0, py, T, dh); dash(w - T, py, T, dh)
	end
	for i = n + 1, #gh.d do gh.d[i]:Hide() end
	gh:SetAlpha(0)
	gh:Show()
	Tw(gh, "a", 0.18, "out", function(p) gh:SetAlpha(p) end)
end

function M:HideGhost()
	local gh = self.ghost
	if not gh or not gh:IsShown() then return end
	Tw(gh, "a", 0.2, "out", function(p) gh:SetAlpha(1 - p) end, function() gh:Hide() end)
end

-- 되돌리기 (Ctrl+Z · 도구막대 버튼): 위치 · 크기 · 배율
M.undo = {}
function M:PushUndo(key, coalesce)
	local m = Ink.movers[key]
	if not m then return end
	local last = self.undo[#self.undo]
	local now = GetTime()
	if coalesce and last and last.key == key and now - (last.t or 0) < 1.2 then
		last.t = now
		return
	end
	local p = Ink.pos and Ink.pos[key]
	local sz = Ink.cdb and Ink.cdb.sizes and Ink.cdb.sizes[key]
	local fw, fh = m.frame:GetSize()
	table.insert(self.undo, { key = key, t = now, p = p and CopyTable(p) or false,
		size = sz and CopyTable(sz) or false, fw = m.resize and fw, fh = m.resize and fh })
	if #self.undo > 40 then table.remove(self.undo, 1) end
	if self.bar then self:SyncButtons() end
end

function M:Undo()
	if InCombatLockdown() then return end
	local u = table.remove(self.undo)
	if not u then return end
	local m = Ink.movers[u.key]
	if not m then return self:Undo() end
	if Ink.pos then Ink.pos[u.key] = u.p and CopyTable(u.p) or nil end
	if m.resize and u.fw then
		m.resize(u.fw, u.fh)
		if u.size then Ink:SaveSize(u.key, u.size[1], u.size[2]) else Ink:SaveSize(u.key, nil) end
	end
	Ink:ApplyPos(u.key)
	if u.p then Ink:SavePos(u.key) end
	Ink:Relayout()
	self:Select(u.key)
	self:SyncAll()
	self:SyncButtons()
end

function M:DragStart(m, o)
	if InCombatLockdown() then return end
	self:Select(m.key)
	local x, y, w, h = Box(m.key)
	if not x then return end
	self:PushUndo(m.key)
	local es = Ink.root:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	o.drag = { x0 = x, y0 = y, w = w, h = h, cx = cx / es, cy = cy / es }
	o.dragging = true
	self.dragging = true
	self:ShowGhost(x, y, w, h)
	o:SetScript("OnUpdate", function() M:DragUpdate(m, o) end)
end

function M:DragUpdate(m, o)
	local d = o.drag
	if not d or InCombatLockdown() then return end
	local es = Ink.root:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	cx, cy = cx / es, cy / es
	local rw, rh = Ink.root:GetWidth(), Ink.root:GetHeight()
	local dx, dy = cx - d.cx, -(cy - d.cy)
	-- Shift: 많이 움직인 한 방향으로만
	if IsShiftKeyDown() then
		if math.abs(dx) >= math.abs(dy) then dy = 0 else dx = 0 end
	end
	local nx = math.max(0, math.min(rw - d.w, d.x0 + dx))
	local ny = math.max(0, math.min(rh - d.h, d.y0 + dy))
	local gx, gy, lx, ly
	if MagnetOn() and not IsAltKeyDown() then
		lx, ly = Candidates(m.key, nx, ny, d.w, d.h, rw, rh)
		gx = Best(lx, nx, LIVE_MAG)
		gy = Best(ly, ny, LIVE_MAG)
		if gx then nx = gx.v end
		if gy then ny = gy.v end
	end
	d.sx, d.sy = gx and true or nil, gy and true or nil
	self:PlaceAt(m, nx, ny)
	self:FxBegin()
	local a = C.accent
	if gx then
		local lo, hi = Span(lx, gx)
		lo, hi = math.min(lo, ny), math.max(hi, ny + d.h)
		self:FxLine(gx.at, lo - 10, 1, hi - lo + 20, a)
	end
	if gy then
		local lo, hi = Span(ly, gy)
		lo, hi = math.min(lo, nx), math.max(hi, nx + d.w)
		self:FxLine(lo - 10, gy.at, hi - lo + 20, 1, a)
	end
	if DistOn() then self:DrawGaps(m.key, nx, ny, d.w, d.h) end
	self:FxEnd()
	self:UpdateFields()
end

function M:DragStop(m, o)
	local d = o.drag
	o.drag = nil
	o.dragging = nil
	self.dragging = nil
	o:SetScript("OnUpdate", nil)
	self:HideGhost()
	self:FxClear()
	if not d or InCombatLockdown() then return end
	local x, y = Box(m.key)
	if x and GridOn() and not IsAltKeyDown() then
		-- 붙지 않았고 실제로 움직인 방향만 8칸 격자에 (안 움직인 방향은 그대로)
		local nx = (d.sx or math.abs(x - d.x0) < 0.5) and x or math.floor(x / SNAP + 0.5) * SNAP
		local ny = (d.sy or math.abs(y - d.y0) < 0.5) and y or math.floor(y / SNAP + 0.5) * SNAP
		self:PlaceAt(m, nx, ny)
	end
	Ink:SavePos(m.key)
	Ink:Relayout()
	self:SyncAll()
	-- 놓은 자리에서 테두리가 한 번 반짝
	local ov = self.overlays[m.key]
	if ov then
		Tw(ov, "drop", 0.35, "out", function(p) ov.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.22 + 0.25 * (1 - p)) end,
			function() M:PaintOverlay(m.key) end)
	end
end

local function BuildOverlay(m)
	local o = CreateFrame("Frame", nil, Ink.root)
	o:SetFrameStrata("DIALOG")
	o:SetFrameLevel(20)
	o:SetMovable(true)
	o:EnableMouse(true)
	o:RegisterForDrag("LeftButton")
	o:SetClampedToScreen(true)
	o.bg = o:CreateTexture(nil, "BACKGROUND")
	o.bg:SetAllPoints()
	o.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.08)
	Ink:Border(o, { C.accent[1], C.accent[2], C.accent[3], 0.6 })
	o.label = Ink:Text(o, F.semi, 11, C.accent, "LEFT")
	o.label:SetPoint("BOTTOMLEFT", o, "TOPLEFT", 0, 3)
	o.label:SetText(m.label)
	o.coords = Ink:Text(o, F.latin, 10, C.muted, "RIGHT")
	o.coords:SetPoint("BOTTOMRIGHT", o, "TOPRIGHT", 0, 3)
	o:SetScript("OnEnter", function(self) if M.sel ~= m.key then self.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.18) end end)
	o:SetScript("OnLeave", function(self) M:PaintOverlay(m.key) end)
	o:SetScript("OnMouseDown", function(_, btn)
		if btn == "LeftButton" then M:Select(m.key) end
	end)
	o:SetScript("OnDragStart", function(self) M:DragStart(m, self) end)
	o:SetScript("OnDragStop", function(self) M:DragStop(m, self) end)
	o:SetScript("OnHide", function(self) if self.drag then M:DragStop(m, self) end end)
	-- 우클릭: 이 요소만 기본 위치로
	o:SetScript("OnMouseUp", function(_, btn)
		if btn == "RightButton" and not InCombatLockdown() then
			M:PushUndo(m.key)
			ResetSize(m)
			Ink:ResetPos(m.key)
			Ink:Relayout()
			M:SyncAll()
		end
	end)
	-- 마우스 휠: 크기 조절
	o:EnableMouseWheel(true)
	o:SetScript("OnMouseWheel", function(_, d)
		if InCombatLockdown() or not Ink:CanScale(m.key) then return end
		M:Select(m.key)
		M:PushUndo(m.key, true)
		M:Nudge(nil, nil, d > 0 and 0.05 or -0.05)
	end)
	if m.resize then AddResizeGrips(m, o) end
	return o
end

function M:PaintOverlay(key)
	local o = self.overlays[key]
	if not o then return end
	local a = C.accent
	if self.sel == key then
		o.bg:SetColorTexture(a[1], a[2], a[3], 0.22)
		Ink:Border(o, { a[1], a[2], a[3], 1 }, 2)
	else
		o.bg:SetColorTexture(a[1], a[2], a[3], 0.08)
		Ink:Border(o, { a[1], a[2], a[3], 0.6 }, 1)
	end
end

local SIDE = { l = "왼쪽", r = "오른쪽", c = "가운데" }
function M:SyncOverlay(m)
	local o = self.overlays[m.key]
	if not o then return end
	local w, h = MoverSize(m)
	-- 요소의 실제 화면 크기(배율 포함)에 맞춘다
	local k = m.frame:GetEffectiveScale() / o:GetEffectiveScale()
	o:ClearAllPoints()
	o:SetPoint("TOPLEFT", m.frame, "TOPLEFT")
	o:SetSize(w * k, h * k)
	local p = Ink:GetPos(m.key)
	local scaleTxt = (p and p.s and p.s ~= 1) and string.format("  ·  %d%%", p.s * 100) or ""
	o.coords:SetText(p and (SIDE[p.a or "c"] .. " 기준" .. scaleTxt) or ("기본 위치" .. scaleTxt))
	self:PaintOverlay(m.key)
end

function M:SyncAll()
	for _, key in ipairs(Ink.moverOrder) do self:SyncOverlay(Ink.movers[key]) end
	self:UpdateFields()
	if self.grid and self.grid:IsShown() then self:DrawGrid() end
	if self.bar then self:SyncButtons() end
	self:ShowSelGaps()
end

function M:Select(key)
	local old = self.sel
	self.sel = key
	if old then self:PaintOverlay(old) end
	if key then self:PaintOverlay(key) end
	self:UpdateFields()
	self:ShowSelGaps()
end

-- 선택한 요소의 좌표 / 크기를 위쪽 막대에 표시
function M:UpdateFields()
	local bar = self.bar
	if not bar then return end
	local key = self.sel
	local m = key and Ink.movers[key]
	local insp = bar.insp
	local hint = self.hint
	if not m then
		if insp:IsShown() and not insp.hiding then
			insp.hiding = true
			Tw(insp, "in", 0.18, "out", function(p) insp:SetAlpha(1 - p) end, function()
				insp:Hide(); insp.hiding = nil
				if not M.sel and hint then
					hint:Show()
					Tw(hint, "a", 0.25, "out", function(p) hint:SetAlpha(p) end)
				end
			end)
		end
		self:SyncOpts()
		return
	end
	if hint and hint:IsShown() then Tw(hint, "a", 0.01, "out", function() hint:Hide() end) end
	-- 고른 요소 칸이 도구막대 위로 톡 올라온다
	if not insp:IsShown() or insp.hiding then
		insp.hiding = nil
		insp:Show()
		insp:SetAlpha(0)
		Tw(insp, "in", 0.32, "back", function(p)
			insp:SetAlpha(math.min(1, p * 1.5))
			insp:ClearAllPoints()
			insp:SetPoint("BOTTOM", bar, "TOP", 0, 10 - 10 * (1 - p))
		end)
	end
	insp.mark:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	bar.selName:SetText(m.label)
	bar.selName:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
	local x, y = Ink:FrameBox(key)
	for _, w in ipairs({ bar.xBox, bar.yBox }) do w:Enable() end
	if x and not bar.xBox:HasFocus() then bar.xBox:SetText(tostring(math.floor(x + 0.5))) end
	if y and not bar.yBox:HasFocus() then bar.yBox:SetText(tostring(math.floor(y + 0.5))) end
	if Ink:CanScale(key) then
		local p = Ink:GetPos(key)
		bar.scaleTxt:SetText(string.format("%d%%", ((p and p.s) or 1) * 100))
	else
		bar.scaleTxt:SetText("고정")
	end
	self:SyncOpts()
end

-- 선택한 요소만의 조절 칸 (행동단축바: 켜기 · 버튼 수 · 한 줄 · 크기 · 간격 · 빈칸 표시)
function M:SyncOpts()
	local bar = self.bar
	if not bar or not bar.optRow then return end
	local m = self.sel and Ink.movers[self.sel]
	local opts = m and m.opts
	local row = bar.optRow
	if not opts then
		row:Hide()
		self:SizeInspector(false)
		return
	end
	row:Show()
	if row.forKey ~= m.key then
		for _, w in ipairs(row.widgets or {}) do w:Hide() end
		row.widgets = {}
		local prev
		for i, o in ipairs(opts) do
			local w
			if o.kind == "toggle" then
				w = Button(row, o.label, 84, function()
					o.set(not o.get())
					M:SyncOpts(); M:SyncAll()
				end)
				w:SetHeight(24)
			else
				w = CreateFrame("Frame", nil, row)
				w:SetHeight(24)
				w.label = Ink:Text(w, F.sans, 11, C.muted, "LEFT")
				w.label:SetPoint("LEFT")
				w.label:SetText(o.label)
				local function step(dir)
					local v = (o.get() or o.min) + dir * o.step
					if v >= o.min and v <= o.max then o.set(v) end
					M:SyncOpts(); M:SyncAll()
				end
				w.minus = Button(w, "−", 24, function() step(-1) end)
				w.minus:SetHeight(24)
				w.minus:SetPoint("LEFT", w.label, "RIGHT", 6, 0)
				w.val = Ink:Text(w, F.latinB, 12, C.text, "CENTER")
				w.val:SetWidth(30)
				w.val:SetPoint("LEFT", w.minus, "RIGHT", 2, 0)
				w.plus = Button(w, "+", 24, function() step(1) end)
				w.plus:SetHeight(24)
				w.plus:SetPoint("LEFT", w.val, "RIGHT", 2, 0)
				w:SetWidth(math.ceil(w.label:GetStringWidth()) + 6 + 24 + 2 + 30 + 2 + 24)
			end
			w.opt = o
			if prev then w:SetPoint("LEFT", prev, "RIGHT", 14, 0) else w:SetPoint("LEFT", row, "LEFT", 0, 0) end
			prev = w
			row.widgets[i] = w
		end
		row.forKey = m.key
	end
	local total = 0
	for i, w in ipairs(row.widgets) do total = total + w:GetWidth() + (i > 1 and 14 or 0) end
	self:SizeInspector(true, total)
	for _, w in ipairs(row.widgets) do
		local o = w.opt
		if o.kind == "toggle" then
			w:SetActive(o.get() and true or false)
		else
			w.val:SetText(tostring(o.get() or ""))
		end
	end
end

-- 선택 요소를 (x, y)로 옮기거나 dx / dy 만큼 밀거나, 크기를 ds 만큼
function M:Nudge(dx, dy, ds, ax, ay)
	local key = self.sel
	local m = key and Ink.movers[key]
	if not m or InCombatLockdown() then return end
	self:PushUndo(key, true)
	if ds then
		local p = Ink:GetPos(key)
		Ink:SetMoverScale(key, ((p and p.s) or 1) + ds)
	else
		local x, y = Ink:FrameBox(key)
		if not x then return end
		x, y = ax or (x + (dx or 0)), ay or (y + (dy or 0))
		local s = m.frame:GetScale() or 1
		m.frame:ClearAllPoints()
		m.frame:SetPoint("TOPLEFT", Ink.root, "TOPLEFT", x / s, -y / s)
		Ink:SavePos(key)
	end
	Ink:Relayout()
	self:SyncAll()
end

function M:SetEdit(on)
	if InCombatLockdown() then
		print("|cffFFF468FOA|r 전투 중에는 편집 모드를 쓸 수 없어요.")
		return
	end
	local S = Ink.modules.Sheet
	if on and S and S.IsOpen and S:IsOpen() then S:Close() end
	self.editing = on
	for _, key in ipairs(Ink.moverOrder) do
		local m = Ink.movers[key]
		local o = self.overlays[key]
		if on then
			if not o then
				o = BuildOverlay(m)
				self.overlays[key] = o
			end
			self:SyncOverlay(m)
			o:Show()
		elseif o then
			o:Hide()
		end
	end
	if not on then
		self.sel = nil
		self.dragging = nil
		if self.presetPop then self.presetPop:Hide() end
		self:FxClear()
		if self.ghost then self.ghost:Hide() end
		wipe(self.undo)
		pcall(Ink.PushShared, Ink)   -- 모든 캐릭터 같은 배치: 공용 배치로 저장
	end
	self:ShowBar(on)
	self:ShowGrid(on and Ink.db.editGrid ~= false)
	if on and not self.testing then self:SetTest(true) end
	if not on and self.testFromEdit then self:SetTest(false) end
	self:SyncButtons()
	if on then self:SyncAll() end
	-- 설정 시트에서 들어왔으면 완료할 때 시트를 다시 올린다
	local S = Ink.modules.Sheet
	if not on and S and S.EditDone then S:EditDone() end
end

-------------------------------------------------------------------------------
-- 테스트 모드: 파티 / 레이드 / 대상 프레임 등을 예시 데이터로 띄운다
-------------------------------------------------------------------------------
-- 테스트 항목 (체크 해제한 것은 테스트에서 빠진다. 처음엔 전부 켜짐)
local TEST_MODS = {
	{ "Units", "유닛 프레임" }, { "Group", "파티 · 레이드" }, { "Center", "자원 · 쿨다운 · 시전바" },
	{ "Plates", "네임플레이트" }, { "Meter", "미터기 · 위협" }, { "Boss", "보스 알림" },
	{ "Quest", "퀘스트 목록" }, { "Blizzard", "경험치 · 대사" }, { "Dungeon", "던전 전리품 · BIS" },
}
local function TestSel(key)
	local t = Ink.db.testSel
	return not (t and t[key] == false)
end
local function SetTestSel(key, on)
	Ink.db.testSel = Ink.db.testSel or {}
	Ink.db.testSel[key] = (not on) and false or nil
end

local function ModTest(mod, on)
	local ok, err = pcall(mod.SetTest, mod, on)
	if not ok then
		print("|cffFF6B5EFOA|r " .. mod.name .. ".SetTest: " .. tostring(err))
		Ink:LogError(mod.name .. ".SetTest: " .. tostring(err))
	end
end

function M:SetTest(on)
	if InCombatLockdown() then
		print("|cffFFF468FOA|r 전투 중에는 테스트 모드를 바꿀 수 없어요.")
		return
	end
	self.testing = on
	self.testFromEdit = on and self.editing or nil
	if on then C_Timer.After(0.3, function() Ink:CrispAll() end) end
	for _, mod in ipairs(Ink.modules) do
		if mod ~= self and mod.SetTest then ModTest(mod, on and TestSel(mod.name)) end
	end
	-- 효과 예시는 테스트 모드에서만 (편집 모드에서 켠 예시는 화면 요소만)
	local fxOn = on and not self.testFromEdit
	if ns.FX then
		for _, d in ipairs(ns.FX.LIST) do ns.FX.Demo(d[1], fxOn and TestSel("fx:" .. d[1])) end
	end
	self:ShowTestPicker(fxOn)
	self:SyncButtons()
end

function M:ToggleTestItem(key, on)
	SetTestSel(key, on)
	if self.testing then
		if key:sub(1, 3) == "fx:" then
			if ns.FX then ns.FX.Demo(key:sub(4), on) end
		elseif not InCombatLockdown() then
			local mod = Ink.modules[key]
			if mod and mod.SetTest then ModTest(mod, on) end
		end
	end
	self:UpdatePickerCount()
end

-------------------------------------------------------------------------------
-- 테스트 항목 고르기 창 (테스트 모드를 켜면 화면 위에 뜬다 · 끌어서 옮기기 · 접기)
-------------------------------------------------------------------------------
local PK_COLS, PK_COLW, PK_ROW = 6, 150, 22

local function PickCheck(parent, label, key, desc)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(PK_COLW - 6, PK_ROW - 2)
	b.box = CreateFrame("Frame", nil, b)
	b.box:SetSize(12, 12)
	b.box:SetPoint("LEFT", 0, 0)
	b.box.bd = Ink:Round(b.box, "BORDER", true, true)
	b.box.bd:SetAllPoints()
	b.box.bd:SetVertexColor(1, 1, 1, 0.3)
	b.box.fill = Ink:Round(b.box, "ARTWORK", true, false)
	b.box.fill:SetPoint("TOPLEFT", 2.5, -2.5)
	b.box.fill:SetPoint("BOTTOMRIGHT", -2.5, 2.5)
	b.box.fill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	b.label = Ink:Text(b, F.sans, 11, C.text, "LEFT")
	b.label:SetPoint("LEFT", b.box, "RIGHT", 7, 0)
	b.label:SetWidth(PK_COLW - 26)
	b.label:SetText(label)
	function b:Refresh()
		local on = TestSel(key)
		self.box.fill:SetShown(on)
		self.label:SetTextColor(on and C.text[1] or C.muted[1], on and C.text[2] or C.muted[2], on and C.text[3] or C.muted[3])
	end
	b:SetScript("OnClick", function(self)
		M:ToggleTestItem(key, not TestSel(key))
		self:Refresh()
	end)
	b:SetScript("OnEnter", function(self)
		self.box.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
		if desc then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, -2)
			GameTooltip:AddLine(label, 1, 1, 1)
			Ink.TipLine(GameTooltip, desc, 0.56, 0.58, 0.61)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.box.bd:SetVertexColor(1, 1, 1, 0.3)
		GameTooltip:Hide()
	end)
	b.key = key
	b:Refresh()
	return b
end

function M:BuildTestPicker()
	if self.picker then return self.picker end
	local f = CreateFrame("Frame", "FOATestPicker", Ink.root)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetWidth(PK_COLS * PK_COLW + 28)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetCenter()
		local rx = Ink.root:GetCenter()
		local top = Ink.root:GetTop()
		if x and rx and top then Ink.db.testPickerPos = { x - rx, self:GetTop() - top } end
	end)
	f.bg = Ink:Round(f, "BACKGROUND", false, false)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(0.035, 0.04, 0.052, 0.95)
	f.bd = Ink:Round(f, "BORDER", false, true)
	f.bd:SetAllPoints()
	f.bd:SetVertexColor(1, 1, 1, 0.1)
	f.accent = f:CreateTexture(nil, "ARTWORK")
	f.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
	f.accent:SetSize(24, 2)
	f.accent:SetPoint("TOPLEFT", 16, -1)
	f.title = Ink:Text(f, F.bold, 13, C.text, "LEFT")
	f.title:SetPoint("TOPLEFT", 16, -13)
	f.title:SetText("FOA 테스트")
	f.count = Ink:Text(f, F.latin, 11, C.muted, "LEFT")
	f.count:SetPoint("LEFT", f.title, "RIGHT", 10, -1)
	f.hint = Ink:Text(f, F.sans, 10, C.dim, "LEFT")
	f.hint:SetPoint("LEFT", f.count, "RIGHT", 12, 0)
	f.hint:SetText("체크를 빼면 바로 빠져요 · 끌어서 옮기기")

	local function small(text, w, fn, primary)
		local b = Button(f, text, w, fn, primary)
		b:SetHeight(24)
		b.text:SetFont(F.semi, 11, "")
		return b
	end
	f.close = small("끝내기", 64, function() M:SetTest(false) end, true)
	f.close:SetPoint("TOPRIGHT", -12, -8)
	f.fold = small("접기", 52, function() M:FoldPicker(not Ink.db.testPickerFold) end)
	f.fold:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
	f.none = small("모두 끄기", 72, function() M:PickAll(false) end)
	f.none:SetPoint("RIGHT", f.fold, "LEFT", -6, 0)
	f.all = small("모두 켜기", 72, function() M:PickAll(true) end)
	f.all:SetPoint("RIGHT", f.none, "LEFT", -6, 0)

	local body = CreateFrame("Frame", nil, f)
	body:SetPoint("TOPLEFT", 0, -40)
	body:SetPoint("BOTTOMRIGHT")
	f.body = body
	f.checks = {}
	local y = 0
	local function section(title, items)
		local h = Ink:Text(body, F.semi, 10, C.muted, "LEFT")
		h:SetPoint("TOPLEFT", 16, -y)
		h:SetText(title)
		y = y + 18
		for i, it in ipairs(items) do
			local col = (i - 1) % PK_COLS
			local row = math.floor((i - 1) / PK_COLS)
			local c = PickCheck(body, it[2], it[1], it[3])
			c:SetPoint("TOPLEFT", 16 + col * PK_COLW, -(y + row * PK_ROW))
			f.checks[#f.checks + 1] = c
		end
		y = y + math.ceil(#items / PK_COLS) * PK_ROW + 10
	end
	local mods = {}
	for _, m in ipairs(TEST_MODS) do mods[#mods + 1] = { m[1], m[2] } end
	section("화면 요소", mods)
	if ns.FX then
		local fx = {}
		for _, d in ipairs(ns.FX.LIST) do fx[#fx + 1] = { "fx:" .. d[1], d[2], d[3] } end
		section("효과", fx)
	end
	f.fullH = 40 + y + 4
	f:Hide()
	self.picker = f
	return f
end

function M:UpdatePickerCount()
	local f = self.picker
	if not f then return end
	local on = 0
	for _, c in ipairs(f.checks) do if TestSel(c.key) then on = on + 1 end end
	f.count:SetText(on .. " / " .. #f.checks)
end

function M:FoldPicker(fold)
	Ink.db.testPickerFold = fold and true or nil
	local f = self.picker
	if not f then return end
	f.body:SetShown(not fold)
	f:SetHeight(fold and 40 or f.fullH)
	f.fold.text:SetText(fold and "펼치기" or "접기")
end

function M:PickAll(on)
	for _, c in ipairs(self.picker.checks) do
		if TestSel(c.key) ~= on then M:ToggleTestItem(c.key, on) end
		c:Refresh()
	end
end

function M:ShowTestPicker(show)
	if not show then
		if self.picker then self.picker:Hide() end
		return
	end
	local f = self:BuildTestPicker()
	f:ClearAllPoints()
	local pos = Ink.db.testPickerPos
	if pos then
		f:SetPoint("TOP", Ink.root, "TOP", pos[1], pos[2])
	else
		f:SetPoint("TOP", Ink.root, "TOP", 0, -84)
	end
	for _, c in ipairs(f.checks) do c:Refresh() end
	self:FoldPicker(Ink.db.testPickerFold)
	self:UpdatePickerCount()
	f:Show()
end

-------------------------------------------------------------------------------
-- 화면 위쪽 편집 도구 막대 (두 줄: 도구 / 선택한 요소)
-------------------------------------------------------------------------------
local function NumBox(parent, w)
	local b = CreateFrame("EditBox", nil, parent)
	b:SetSize(w, 24)
	b:SetAutoFocus(false)
	b:SetNumeric(false)
	b:SetFont(F.latin, 12, "")
	b:SetTextColor(C.text[1], C.text[2], C.text[3])
	b:SetJustifyH("CENTER")
	b.bg = Ink:Round(b, "BACKGROUND", true, false)
	b.bg:SetAllPoints()
	b.bg:SetVertexColor(1, 1, 1, 0.06)
	b.bd = Ink:Round(b, "BORDER", true, true)
	b.bd:SetAllPoints()
	b.bd:SetVertexColor(1, 1, 1, 0.12)
	b:SetScript("OnEditFocusGained", function(self) self.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.7); self:HighlightText() end)
	b:SetScript("OnEditFocusLost", function(self) self.bd:SetVertexColor(1, 1, 1, 0.12); M:UpdateFields() end)
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return b
end

-------------------------------------------------------------------------------
-- 편집 도구 (04 Dock): 아래 떠 있는 도구막대 + 고른 요소 칸(도구막대 바로 위) + 위 안내
--  도구막대: 자석 · 격자 · 거리 · 되돌리기 | 예시 솔로 · 파티 · 레이드 | 예시 표시 · 비율 · 배치 공유 · 기본 배치 · 완료
-------------------------------------------------------------------------------
local DARK = { 0.059, 0.067, 0.082 }
local INKC = { 0.067, 0.075, 0.094 }

local function ToolBtn(parent, icon, tip, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(48, 46)
	b.bg = Ink:Round(b, "BACKGROUND", false, false)
	b.bg:SetAllPoints()
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(Ink.icon(icon))
	b.icon:SetSize(19, 19)
	b.icon:SetPoint("CENTER")
	function b:SetActive(on)
		self.active = on
		local a = C.accent
		if on then
			self.bg:SetVertexColor(a[1], a[2], a[3], self.hot and 0.2 or 0.13)
			self.icon:SetVertexColor(a[1], a[2], a[3])
		else
			self.bg:SetVertexColor(1, 1, 1, self.hot and 0.07 or 0)
			local c = self.hot and C.text or C.soft
			self.icon:SetVertexColor(c[1], c[2], c[3])
		end
	end
	b:SetScript("OnEnter", function(self)
		self.hot = true
		self:SetActive(self.active)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(tip[1], 1, 1, 1)
		if tip[2] then Ink.TipLine(GameTooltip, tip[2], 0.56, 0.58, 0.61) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self)
		self.hot = nil
		self:SetActive(self.active)
		GameTooltip_Hide()
	end)
	b:SetScript("OnClick", onClick)
	b:SetActive(false)
	return b
end

local function FlatBtn(parent, text, style, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(46)
	b.bg = Ink:Round(b, "BACKGROUND", false, false)
	b.bg:SetAllPoints()
	b.text = Ink:Text(b, style == "primary" and F.bold or F.semi, 13, C.soft, "CENTER")
	b.text:SetPoint("CENTER")
	b.style = style
	function b:SetLabel(t)
		self.text:SetText(t)
		self:SetWidth(math.max(self.minW or 0, math.ceil(self.text:GetStringWidth() or 40) + 30))
	end
	function b:SetActive(on)
		self.active = on
		local a = C.accent
		if self.style == "primary" then
			self.bg:SetVertexColor(a[1], a[2], a[3], self.hot and 1 or 0.92)
			self.text:SetTextColor(INKC[1], INKC[2], INKC[3])
		elseif on then
			self.bg:SetVertexColor(a[1], a[2], a[3], self.hot and 0.2 or 0.13)
			self.text:SetTextColor(a[1], a[2], a[3])
		else
			self.bg:SetVertexColor(1, 1, 1, self.hot and 0.07 or 0)
			local c = self.hot and C.text or C.soft
			self.text:SetTextColor(c[1], c[2], c[3])
		end
	end
	b:SetScript("OnEnter", function(self) self.hot = true; self:SetActive(self.active) end)
	b:SetScript("OnLeave", function(self) self.hot = nil; self:SetActive(self.active) end)
	b:SetScript("OnClick", onClick)
	b:SetLabel(text)
	b:SetActive(false)
	return b
end

local function Panel(f, alpha)
	f.bg = Ink:Round(f, "BACKGROUND", false, false)
	f.bg:SetAllPoints()
	f.bg:SetVertexColor(DARK[1], DARK[2], DARK[3], alpha or 0.96)
	f.bd = Ink:Round(f, "BORDER", false, true)
	f.bd:SetAllPoints()
	f.bd:SetVertexColor(1, 1, 1, 0.1)
end

local function Sep(parent)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetTexture("Interface\\Buttons\\WHITE8X8")
	t:SetVertexColor(1, 1, 1, 0.1)
	t:SetSize(1, 28)
	return t
end

local PREVIEW = { { "solo", "솔로" }, { "party", "파티" }, { "raid", "레이드" } }

function M:BuildBar()
	local bar = CreateFrame("Frame", "FOAEditToolbar", Ink.root)
	bar:SetFrameStrata("FULLSCREEN_DIALOG")
	bar:SetHeight(64)
	bar:SetPoint("BOTTOM", Ink.root, "BOTTOM", 0, 34)
	bar:EnableMouse(true)
	bar:SetMovable(true)
	bar:SetClampedToScreen(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", bar.StartMoving)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- 옮긴 자리 기억 (가운데 기준 x, 바닥에서 y)
		local l, b, w = self:GetLeft(), self:GetBottom(), self:GetWidth()
		local rl, rb, rw = Ink.root:GetLeft(), Ink.root:GetBottom(), Ink.root:GetWidth()
		if l and b and rl and rb then
			local k = self:GetEffectiveScale() / Ink.root:GetEffectiveScale()
			Ink.db.editBarPos = { math.floor((l * k - rl) + w * k / 2 - rw / 2 + 0.5), math.floor(b * k - rb + 0.5) }
		end
	end)
	Panel(bar, 0.96)
	bar.shadow = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	bar.shadow:SetTexture(Ink.tex.glow)
	bar.shadow:SetPoint("TOPLEFT", -40, 24)
	bar.shadow:SetPoint("BOTTOMRIGHT", 40, -40)
	bar.shadow:SetVertexColor(0, 0, 0, 0.6)

	bar.magnet = ToolBtn(bar, "Magnet", { "자석", "다른 요소 · 화면 가운데에 가까우면 노란 선과 함께 착 붙어요. Alt 를 누른 채 끌면 자유롭게." }, function()
		Ink.db.editMagnet = (Ink.db.editMagnet == false) and true or false
		M:SyncButtons()
	end)
	bar.gridBtn = ToolBtn(bar, "Grid", { "격자", "격자를 보여 주고, 놓을 때 8칸에 맞춰요." }, function()
		Ink.db.editGrid = (Ink.db.editGrid == false) and true or false
		M:ShowGrid(Ink.db.editGrid ~= false)
		M:SyncButtons()
	end)
	bar.dist = ToolBtn(bar, "Ruler", { "거리 표시", "고른 요소에서 이웃까지 거리를 빨간 숫자로." }, function()
		Ink.db.editDist = (Ink.db.editDist == false) and true or false
		M:SyncButtons()
		M:ShowSelGaps()
	end)
	bar.undoBtn = ToolBtn(bar, "Undo", { "되돌리기", "Ctrl+Z" }, function() M:Undo() end)
	bar.sep1 = Sep(bar)

	-- 예시: 솔로 · 파티 · 레이드 (노란 받침이 미끄러짐)
	local pv = CreateFrame("Frame", nil, bar)
	pv:SetSize(3 + #PREVIEW * 66 + 3, 40)
	pv.bg = Ink:Round(pv, "BACKGROUND", false, false)
	pv.bg:SetAllPoints()
	pv.bg:SetVertexColor(1, 1, 1, 0.05)
	pv.pill = CreateFrame("Frame", nil, pv)
	pv.pill:SetSize(66, 34)
	pv.pill.bg = Ink:Round(pv.pill, "BACKGROUND", false, false)
	pv.pill.bg:SetAllPoints()
	pv.btns = {}
	for i, d in ipairs(PREVIEW) do
		local b = CreateFrame("Button", nil, pv)
		b:SetSize(66, 34)
		b:SetPoint("LEFT", 3 + (i - 1) * 66, 0)
		b:SetFrameLevel(pv.pill:GetFrameLevel() + 2)
		b.text = Ink:Text(b, F.semi, 13, C.soft, "CENTER")
		b.text:SetPoint("CENTER")
		b.text:SetText(d[2])
		b:SetScript("OnClick", function()
			M.testGroup = d[1]
			if not M.testing then M:SetTest(true) end
			local g = Ink.modules.Group
			if g and g.SetTest then pcall(g.SetTest, g, true) end
			M:SyncButtons()
		end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(d[1] == "solo" and "예시: 혼자" or (d[2] .. " 예시 프레임 보기"), 1, 1, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", GameTooltip_Hide)
		pv.btns[i] = b
	end
	bar.preview = pv
	bar.sep2 = Sep(bar)

	bar.test = ToolBtn(bar, "Eye", { "예시 표시", "파티 · 대상 · 시전바 같은 예시 프레임을 띄워요." }, function() M:SetTest(not M.testing) end)
	bar.aspect = FlatBtn(bar, "비율", nil, function()
		local cur = Ink.cdb.aspect or "auto"
		local i = 1
		for n, v in ipairs(ASPECT_CYCLE) do if v == cur then i = n end end
		Ink:SetAspect(ASPECT_CYCLE[i % #ASPECT_CYCLE + 1])
		M:SyncAll()
	end)
	bar.share = FlatBtn(bar, "배치 공유", nil, function() M:TogglePresets() end)
	bar.reset = FlatBtn(bar, "기본 배치", nil, function(self)
		if self.armed then
			self.armed = nil
			self:SetLabel("기본 배치")
			M:ResetAll()
		else
			self.armed = true
			self:SetLabel("한 번 더 누르면 초기화")
			M:LayoutBar()
			C_Timer.After(3, function()
				if self.armed then self.armed = nil; self:SetLabel("기본 배치"); M:LayoutBar() end
			end)
		end
	end)
	bar.done = FlatBtn(bar, "완료", "primary", function() M:SetEdit(false) end)
	bar.done.minW = 88
	bar.done:SetLabel("완료")

	-- 고른 요소 칸 (도구막대 바로 위)
	local insp = CreateFrame("Frame", nil, bar)
	insp:SetHeight(58)
	insp:SetPoint("BOTTOM", bar, "TOP", 0, 10)
	insp:EnableMouse(true)
	Panel(insp, 0.96)
	insp.mark = insp:CreateTexture(nil, "ARTWORK")
	insp.mark:SetTexture("Interface\\Buttons\\WHITE8X8")
	insp.mark:SetSize(7, 7)
	insp.mark:SetPoint("TOPLEFT", 18, -26)
	if insp.mark.SetRotation then insp.mark:SetRotation(math.rad(45)) end
	bar.insp = insp
	bar.selName = Ink:Text(insp, F.semi, 14, C.accent, "LEFT")
	bar.selName:SetPoint("LEFT", insp.mark, "RIGHT", 10, 0)
	bar.selName:SetWidth(170)
	bar.selName:SetWordWrap(false)
	local function label(text, anchor, x)
		local t = Ink:Text(insp, F.latin, 11, C.muted, "LEFT")
		t:SetPoint("LEFT", anchor, "RIGHT", x or 14, 0)
		t:SetText(text)
		return t
	end
	local xl = label("X", bar.selName, 6)
	bar.xBox = NumBox(insp, 64)
	bar.xBox:SetHeight(28)
	bar.xBox:SetPoint("LEFT", xl, "RIGHT", 7, 0)
	local yl = label("Y", bar.xBox, 12)
	bar.yBox = NumBox(insp, 64)
	bar.yBox:SetHeight(28)
	bar.yBox:SetPoint("LEFT", yl, "RIGHT", 7, 0)
	local function apply()
		local x, y = tonumber(bar.xBox:GetText()), tonumber(bar.yBox:GetText())
		bar.xBox:ClearFocus(); bar.yBox:ClearFocus()
		if x and y then M:Nudge(nil, nil, nil, x, y) end
	end
	bar.xBox:SetScript("OnEnterPressed", apply)
	bar.yBox:SetScript("OnEnterPressed", apply)
	bar.xBox:SetScript("OnTabPressed", function() bar.yBox:SetFocus() end)
	bar.yBox:SetScript("OnTabPressed", function() bar.xBox:SetFocus() end)
	local sl = label("크기", bar.yBox, 20)
	bar.minus = Button(insp, "−", 30, function() M:Nudge(nil, nil, -0.05) end)
	bar.minus:SetHeight(28)
	bar.minus:SetPoint("LEFT", sl, "RIGHT", 8, 0)
	bar.scaleTxt = Ink:Text(insp, F.latinB, 13, C.text, "CENTER")
	bar.scaleTxt:SetWidth(50)
	bar.scaleTxt:SetPoint("LEFT", bar.minus, "RIGHT", 2, 0)
	bar.plus = Button(insp, "+", 30, function() M:Nudge(nil, nil, 0.05) end)
	bar.plus:SetHeight(28)
	bar.plus:SetPoint("LEFT", bar.scaleTxt, "RIGHT", 2, 0)
	bar.one = Button(insp, "100%", 54, function()
		local p = M.sel and Ink:GetPos(M.sel)
		if p then M:Nudge(nil, nil, 1 - (p.s or 1)) end
	end)
	bar.one:SetHeight(28)
	bar.one:SetPoint("LEFT", bar.plus, "RIGHT", 6, 0)
	insp.hint = Ink:Text(insp, F.sans, 11, C.dim, "RIGHT")
	insp.hint:SetPoint("RIGHT", insp, "TOPRIGHT", -18, -29)
	insp.hint:SetText("휠 크기 · 우클릭 기본 위치")
	-- 고른 요소만의 조절 칸 (행동단축바 등)
	bar.optRow = CreateFrame("Frame", nil, insp)
	bar.optRow:SetPoint("TOPLEFT", 18, -58)
	bar.optRow:SetPoint("TOPRIGHT", -18, -58)
	bar.optRow:SetHeight(30)
	bar.optRow.line = bar.optRow:CreateTexture(nil, "ARTWORK")
	bar.optRow.line:SetColorTexture(1, 1, 1, 0.06)
	bar.optRow.line:SetHeight(1)
	bar.optRow.line:SetPoint("BOTTOMLEFT", bar.optRow, "TOPLEFT", -4, 2)
	bar.optRow.line:SetPoint("BOTTOMRIGHT", bar.optRow, "TOPRIGHT", 4, 2)
	bar.optRow:Hide()
	insp:Hide()

	-- 화살표 키 미세 이동 · Ctrl+Z 되돌리기 · ESC 완료 (입력 칸에 글자를 넣는 중엔 그대로)
	bar:EnableKeyboard(true)
	bar:SetPropagateKeyboardInput(true)
	bar:SetScript("OnKeyDown", function(self, key)
		if InCombatLockdown() then return end
		local step = IsShiftKeyDown() and 10 or 1
		local d = ({ LEFT = { -step, 0 }, RIGHT = { step, 0 }, UP = { 0, -step }, DOWN = { 0, step } })[key]
		if d and M.sel then
			self:SetPropagateKeyboardInput(false)
			M:Nudge(d[1], d[2])
		elseif key == "Z" and IsControlKeyDown() then
			self:SetPropagateKeyboardInput(false)
			M:Undo()
		elseif key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			if M.presetPop and M.presetPop:IsShown() then M.presetPop:Hide() else M:SetEdit(false) end
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	-- 위 안내
	-- 안내: 아무것도 안 골랐을 때 도구막대 바로 위 (고르면 그 자리에 고른 요소 칸이 올라온다)
	local hint = CreateFrame("Frame", nil, bar)
	hint:SetHeight(38)
	hint:SetPoint("BOTTOM", bar, "TOP", 0, 10)
	Panel(hint, 0.9)
	hint.dot = hint:CreateTexture(nil, "ARTWORK")
	hint.dot:SetTexture(Ink.tex.disc)
	hint.dot:SetSize(7, 7)
	hint.dot:SetPoint("LEFT", 16, 0)
	hint.dot:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
	hint.text = Ink:Text(hint, F.sans, 13, C.soft, "LEFT")
	hint.text:SetPoint("LEFT", hint.dot, "RIGHT", 10, 0)
	local sep = "  |cff5E636B·|r  "
	hint.text:SetText("|cffF3F2EE편집 모드|r" .. sep .. "끌어서 옮기기" .. sep .. "고른 뒤 방향키 1칸 · Shift 10칸" .. sep .. "Shift 끌기 한 방향 · Alt 자유" .. sep .. "Ctrl+Z 되돌리기" .. sep .. "ESC 완료")
	hint:SetWidth(math.ceil(hint.text:GetStringWidth() or 600) + 46)
	hint:Hide()
	self.hint = hint
	self.bar = bar
	self:LayoutBar()
end

-- 도구막대 버튼 배치 (글자 폭이 바뀌면 다시)
function M:LayoutBar()
	local bar = self.bar
	if not bar then return end
	local x = 9
	local function put(w, gap)
		w:ClearAllPoints()
		w:SetPoint("LEFT", bar, "LEFT", x, 0)
		x = x + w:GetWidth() + (gap or 4)
	end
	put(bar.magnet); put(bar.gridBtn); put(bar.dist); put(bar.undoBtn, 12)
	put(bar.sep1, 12)
	put(bar.preview, 12)
	put(bar.sep2, 12)
	put(bar.test, 4); put(bar.aspect, 2); put(bar.share, 2); put(bar.reset, 8); put(bar.done, 0)
	bar:SetWidth(x + 9)
end

function M:PaintPreview(animate)
	local bar = self.bar
	if not bar then return end
	local pv = bar.preview
	local cur = self.testing and (self.testGroup or "party") or "solo"
	local idx = 1
	for i, d in ipairs(PREVIEW) do if d[1] == cur then idx = i end end
	local a = C.accent
	pv.pill.bg:SetVertexColor(a[1], a[2], a[3], 1)
	for i, b in ipairs(pv.btns) do
		local c = (i == idx) and INKC or C.soft
		b.text:SetTextColor(c[1], c[2], c[3])
		b.text:SetFont(i == idx and F.bold or F.semi, Ink:BoostSize(13), "")
	end
	local tx = 3 + (idx - 1) * 66
	local fx = pv.pillX or tx
	local function place(v)
		pv.pillX = v
		pv.pill:ClearAllPoints()
		pv.pill:SetPoint("LEFT", pv, "LEFT", v, 0)
	end
	if fx ~= tx then
		Tw(pv, "pill", 0.5, "back", function(p) place(fx + (tx - fx) * p) end)
	else
		place(tx)
	end
end

-- 고른 요소 칸 크기 (조절 칸이 있으면 한 줄 더)
function M:SizeInspector(withOpts, optW)
	local insp = self.bar and self.bar.insp
	if not insp then return end
	insp:SetHeight(withOpts and 100 or 58)
	insp:SetWidth(math.max(800, (optW or 0) + 36))
end

-- 도구막대 자리: 옮겨 둔 자리가 있으면 거기, 없으면 화면 아래 가운데에 있는 요소(행동단축바 등) 바로 위
function M:BarSpot()
	local saved = Ink.db.editBarPos
	if type(saved) == "table" and saved[1] then return saved[1], saved[2] end
	local rw, rh = Ink.root:GetWidth() or 1920, Ink.root:GetHeight() or 1080
	local bw = self.bar:GetWidth() or 900
	local l, r = rw / 2 - bw / 2 - 20, rw / 2 + bw / 2 + 20
	local floor = 34
	for _, key in ipairs(Ink.moverOrder) do
		local x, y, w, h = Box(key)
		if x and x < r and x + w > l and y + h > rh - 300 then
			floor = math.max(floor, rh - y + 18)
		end
	end
	return 0, math.min(floor, rh * 0.42)
end

function M:ShowBar(on)
	if not self.bar then self:BuildBar() end
	local bar, hint = self.bar, self.hint
	if on then
		self:LayoutBar()
		local bx, by = self:BarSpot()
		bar:Show()
		bar:SetAlpha(0)
		Tw(bar, "in", 0.45, "back", function(p)
			bar:SetAlpha(math.min(1, p * 1.6))
			bar:ClearAllPoints()
			bar:SetPoint("BOTTOM", Ink.root, "BOTTOM", bx, by - 26 * (1 - p))
		end)
		hint:SetAlpha(0)
		hint:Show()
		Tw(hint, "a", 0.4, "out", function(p) hint:SetAlpha(p) end, nil, 0.15)
		self:UpdateFields()
	else
		bar:Hide()
	end
end

-------------------------------------------------------------------------------
-- UI 픽셀 맞춤 (엘브UI 자동 크기와 같은 원리)
--  화면 세로 픽셀 / 768 기준으로 UI 1칸이 실제 화면 픽셀 정수 배가 되는 크기를 고른다
--  → 블리자드 창과 테두리 선이 번지지 않고 또렷하게. FOA 화면 배치 크기는 그대로.
-------------------------------------------------------------------------------
function M:PixelScale()
	local _, ph = GetPhysicalScreenSize()
	if not ph or ph <= 0 then return end
	local base = 768 / ph
	local n = math.max(1, math.floor(1 / base + 0.0001))
	return base * n
end

function M:ApplyPixelPerfect()
	if not Ink.db.pixelPerfect or InCombatLockdown() then return end
	local s = self:PixelScale()
	if not s then return end
	local changed = false
	if s >= 0.64 and s <= 1 then
		if C_CVar.GetCVar("useUiScale") ~= "1" then pcall(C_CVar.SetCVar, "useUiScale", "1") end
		if math.abs((tonumber(C_CVar.GetCVar("uiScale")) or 0) - s) > 0.001 then
			pcall(C_CVar.SetCVar, "uiScale", tostring(s))
			changed = true
		end
	end
	if math.abs((UIParent:GetScale() or 1) - s) > 0.001 then
		UIParent:SetScale(s)
		changed = true
	end
	if changed then Ink:Relayout() end
end

function M:SetPixelPerfect(on)
	if InCombatLockdown() then
		print("|cffFFF468FOA|r 전투 중에는 UI 크기를 바꿀 수 없어요.")
		return
	end
	Ink.db.pixelPerfect = on
	if on then
		self:ApplyPixelPerfect()
		print(string.format("|cffFFF468FOA|r UI 픽셀 맞춤 켬 (UI 크기 %.3f)", self:PixelScale() or 1))
	else
		local cv = tonumber(C_CVar.GetCVar("uiScale")) or 1
		UIParent:SetScale(C_CVar.GetCVar("useUiScale") == "1" and cv or 1)
		Ink:Relayout()
		print("|cffFFF468FOA|r UI 픽셀 맞춤 끔")
	end
	self:SyncButtons()
end

-------------------------------------------------------------------------------
-- 그래픽 프리셋: 성능 / 균형 / 화질 (처음 바꿀 때 원래 값을 저장해 두고 "되돌리기")
-------------------------------------------------------------------------------
local GFX = {
	perf = {
		graphicsViewDistance = 3, graphicsEnvironmentDetail = 3, graphicsGroundClutter = 2, graphicsShadowQuality = 2,
		graphicsLiquidDetail = 1, graphicsParticleDensity = 3, graphicsSSAO = 1, graphicsDepthEffects = 1,
		graphicsComputeEffects = 1, graphicsOutlineMode = 2, graphicsSpellDensity = 3, graphicsProjectedTextures = 2,
		maxFPSBk = 30,
	},
	balanced = {
		graphicsViewDistance = 6, graphicsEnvironmentDetail = 6, graphicsGroundClutter = 5, graphicsShadowQuality = 4,
		graphicsLiquidDetail = 2, graphicsParticleDensity = 4, graphicsSSAO = 3, graphicsDepthEffects = 2,
		graphicsComputeEffects = 3, graphicsOutlineMode = 3, graphicsSpellDensity = 4, graphicsProjectedTextures = 2,
		maxFPSBk = 30,
	},
	quality = {
		graphicsViewDistance = 10, graphicsEnvironmentDetail = 10, graphicsGroundClutter = 10, graphicsShadowQuality = 6,
		graphicsLiquidDetail = 4, graphicsParticleDensity = 6, graphicsSSAO = 5, graphicsDepthEffects = 4,
		graphicsComputeEffects = 5, graphicsOutlineMode = 3, graphicsSpellDensity = 6, graphicsProjectedTextures = 2,
		maxFPSBk = 60,
	},
}
local GFX_NAME = { perf = "성능", balanced = "균형", quality = "화질" }

function M:ApplyGraphics(kind)
	if InCombatLockdown() then
		print("|cffFFF468FOA|r 전투 중에는 그래픽 설정을 바꿀 수 없어요.")
		return
	end
	if kind == "restore" then
		local b = Ink.db.gfxBackup
		if not b then
			print("|cffFFF468FOA|r 되돌릴 그래픽 설정이 없어요.")
			return
		end
		for k, v in pairs(b) do pcall(C_CVar.SetCVar, k, v) end
		Ink.db.gfxBackup, Ink.db.gfxPreset = nil, nil
		print("|cffFFF468FOA|r 그래픽 설정을 원래대로 되돌렸어요.")
		self:SyncButtons()
		return
	end
	local set = GFX[kind]
	if not set then return end
	-- 처음 한 번만 원래 값을 저장
	if not Ink.db.gfxBackup then
		Ink.db.gfxBackup = {}
		for k in pairs(GFX.quality) do
			local v = C_CVar.GetCVar(k)
			if v ~= nil then Ink.db.gfxBackup[k] = v end
		end
	end
	local n = 0
	for k, v in pairs(set) do
		if C_CVar.GetCVar(k) ~= nil and pcall(C_CVar.SetCVar, k, tostring(v)) then n = n + 1 end
	end
	Ink.db.gfxPreset = kind
	print(string.format("|cffFFF468FOA|r 그래픽 '%s' 프리셋 적용 (%d개 항목)", GFX_NAME[kind], n))
	self:SyncButtons()
end

-------------------------------------------------------------------------------
-- 배치 공유 · 프리셋 창 (편집 모드 "배치 공유" 버튼)
-------------------------------------------------------------------------------
local MAX_PRESETS = 8

function M:BuildPresets()
	local p = CreateFrame("Frame", nil, self.bar)
	p:SetSize(360, 150)
	p:SetPoint("BOTTOMRIGHT", self.bar.share, "TOPRIGHT", 0, 14)
	p:SetFrameStrata("FULLSCREEN_DIALOG")
	p:SetFrameLevel(self.bar:GetFrameLevel() + 40)
	p:EnableMouse(true)
	p.bg = Ink:Round(p, "BACKGROUND", false, false)
	p.bg:SetAllPoints()
	p.bg:SetVertexColor(0.05, 0.06, 0.08, 0.97)
	p.bd = Ink:Round(p, "BORDER", false, true)
	p.bd:SetAllPoints()
	p.bd:SetVertexColor(1, 1, 1, 0.14)
	p.title = Ink:Text(p, F.bold, 13, C.text, "LEFT")
	p.title:SetPoint("TOPLEFT", 14, -12)
	p.title:SetText("배치 공유 · 프리셋")

	p.shared = Button(p, "", 332, function()
		Ink.db.layoutShared = not Ink.db.layoutShared or nil
		if Ink.db.layoutShared then
			Ink:PushShared()
			print("|cffFFF468FOA|r 이 캐릭터 배치를 공용으로 저장했어요. 다른 캐릭터도 접속하면 같은 배치가 돼요.")
		end
		M:PaintPresets()
		M:SyncButtons()
	end)
	p.shared:SetHeight(28)
	p.shared:SetPoint("TOPLEFT", 14, -36)
	p.sharedDesc = Ink:Text(p, F.sans, 10, C.muted, "LEFT")
	p.sharedDesc:SetPoint("TOPLEFT", p.shared, "BOTTOMLEFT", 2, -5)
	p.sharedDesc:SetWidth(332)
	p.sharedDesc:SetWordWrap(true)
	p.sharedDesc:SetText("켜 두면 편집 모드에서 완료를 누를 때마다 공용으로 저장되고, 다른 캐릭터는 접속하면 이 배치로 바뀌어요. (위치 · 크기 · 행동단축바)")

	p.save = Button(p, "지금 배치를 프리셋으로 저장", 332, function()
		local list = Ink.db.layoutPresets or {}
		Ink.db.layoutPresets = list
		if #list >= MAX_PRESETS then
			print("|cffFFF468FOA|r 프리셋은 " .. MAX_PRESETS .. "개까지예요. 안 쓰는 걸 지우고 저장해 주세요.")
			return
		end
		local n = 1
		local used = {}
		for _, e in ipairs(list) do used[e.name] = true end
		while used["프리셋 " .. n] do n = n + 1 end
		list[#list + 1] = { name = "프리셋 " .. n, data = Ink:SnapshotLayout() }
		M:PaintPresets()
	end)
	p.save:SetHeight(28)
	p.save:SetPoint("TOPLEFT", p.sharedDesc, "BOTTOMLEFT", -2, -10)

	p.rows = {}
	for i = 1, MAX_PRESETS do
		local r = CreateFrame("Frame", nil, p)
		r:SetSize(332, 30)
		r:SetPoint("TOPLEFT", p.save, "BOTTOMLEFT", 0, -6 - (i - 1) * 32)
		r.name = Ink:Text(r, F.semi, 12, C.text, "LEFT")
		r.name:SetPoint("TOPLEFT", 4, -3)
		r.sub = Ink:Text(r, F.sans, 10, C.muted, "LEFT")
		r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
		r.del = Button(r, "삭제", 48, function()
			table.remove(Ink.db.layoutPresets, r.index)
			M:PaintPresets()
		end)
		r.del:SetHeight(24)
		r.del:SetPoint("RIGHT", 0, 0)
		r.load = Button(r, "불러오기", 72, function()
			local e = Ink.db.layoutPresets[r.index]
			if not e or InCombatLockdown() then return end
			Ink:ApplyLayoutData(e.data)
			Ink:PushShared()
			ReloadUI()
		end)
		r.load:SetHeight(24)
		r.load:SetPoint("RIGHT", r.del, "LEFT", -6, 0)
		p.rows[i] = r
	end
	p.empty = Ink:Text(p, F.sans, 11, C.muted, "LEFT")
	p.empty:SetPoint("TOPLEFT", p.save, "BOTTOMLEFT", 4, -12)
	p.empty:SetText("저장한 프리셋이 없어요. 불러오면 화면을 다시 불러와요.")
	self.presetPop = p
end

function M:PaintPresets()
	local p = self.presetPop
	if not p then return end
	local on = Ink.db.layoutShared and true or false
	p.shared.text:SetText(on and "모든 캐릭터 같은 배치: 켜짐" or "모든 캐릭터 같은 배치: 꺼짐")
	p.shared:SetActive(on)
	local list = Ink.db.layoutPresets or {}
	for i, r in ipairs(p.rows) do
		local e = list[i]
		r.index = i
		if e then
			r.name:SetText(e.name)
			local d = e.data or {}
			r.sub:SetText((d.from or "?") .. (d.at and ("  ·  " .. date("%m/%d %H:%M", d.at)) or ""))
			r:Show()
		else
			r:Hide()
		end
	end
	p.empty:SetShown(#list == 0)
	local rows = math.max(1, #list)
	p:SetHeight(36 + 28 + 40 + 28 + 10 + rows * 32 + 8)
end

function M:TogglePresets()
	if not self.presetPop then self:BuildPresets() end
	local p = self.presetPop
	p:SetShown(not p:IsShown())
	if p:IsShown() then self:PaintPresets() end
end

function M:ResetAll()
	if InCombatLockdown() then return end
	for _, key in ipairs(Ink.moverOrder) do ResetSize(Ink.movers[key]) end
	Ink:ResetPos()
	Ink:Relayout()
	local B = Ink.modules.Bags
	if B and B.frame and B.ApplyPos then B:ApplyPos() end
	self:SyncAll()
end

M.testGroup = "party"
function M:ToggleGroup()
	self.testGroup = (self.testGroup == "party") and "raid" or "party"
	if not self.testing then self:SetTest(true) end
	local g = Ink.modules.Group
	if g and g.SetTest then g:SetTest(true) end
	self:SyncButtons()
end

function M:SyncButtons()
	local bar = self.bar
	if bar then
		bar.magnet:SetActive(Ink.db.editMagnet ~= false)
		bar.gridBtn:SetActive(Ink.db.editGrid ~= false)
		bar.dist:SetActive(Ink.db.editDist ~= false)
		bar.undoBtn:SetActive(false)
		bar.undoBtn:SetAlpha(#self.undo > 0 and 1 or 0.4)
		bar.test:SetActive(self.testing and true or false)
		bar.share:SetActive(Ink.db.layoutShared and true or false)
		if not bar.reset.armed then bar.reset:SetLabel("기본 배치") end
		bar.aspect:SetLabel(AspectLabel())
		self:PaintPreview()
		self:LayoutBar()
	end
	if self.panel then
		self.panel.edit:SetActive(self.editing)
		self.panel.test:SetActive(self.testing)
		if self.panel.aspect then
			self.panel.aspect.text:SetText(AspectLabel())
			self.panel.pixel:SetActive(Ink.db.pixelPerfect and true or false)
			for k, b in pairs(self.panel.gfx) do b:SetActive(Ink.db.gfxPreset == k) end
		end
	end
end

local FONT_DESC = {
	foa = "FOA 기본 글꼴 (IBM Plex 한글 · Inter · Space Grotesk 숫자).",
	pretendard = "획이 굵어 작은 글자도 또렷해요. 1080p · 1440p 모니터나 윈도우에서 글자가 뭉개질 때 추천.",
	mubig = "무빅UI 글꼴. 숫자·영문은 Y 스포트라이트, 한글은 게임 글꼴 자리를 써서 무빅UI(세방고딕)를 깔아 둔 PC면 똑같이 보여요.",
}
local TIER_NAME = { ["1x"] = "1080p", q = "QHD", ["2x"] = "4K" }
local TIER_DESC = {
	["1x"] = "1080p · 1200p 모니터용 이미지 (FOA 1칸 = 화면 1픽셀).",
	q = "QHD(1440p)용: 아이콘·둥근 모서리를 1440p 에 맞춰 따로 그린 이미지로 바꾸고, 선과 테두리를 화면 픽셀에 딱 맞춰요.",
	["2x"] = "4K 고해상도 이미지 (FOA 1칸 = 화면 2픽셀).",
}
function M:SyncFontButton()
	local p = self.panel
	if not p or not p.font then return end
	local set = Ink.db.fontSet or "foa"
	p.font.text:SetText("글꼴: " .. (Ink.FONT_NAME[set] or set))
	p.font:SetActive(set ~= "foa")
	local desc = FONT_DESC[set] or ""
	if set == "mubig" then
		local f = Ink.mubigFile
		if f and f:find("FOA_Fonts", 1, true) then
			desc = desc .. "  |cff6FD39A직접 넣은 글꼴 사용 중|r"
		elseif f then
			desc = desc .. "  |cffFFB75AFOA_UI 폴더 안 글꼴 사용 중 · 애드온을 업데이트하면 지워지니 AddOns\\FOA_Fonts 폴더로 옮기세요|r"
		end
	end
	p.fontDesc:SetText("글꼴 · " .. desc)
	if p.chatFont then
		local CF = { set = "FOA 글꼴 따라감", game = "게임 기본", pretendard = "선명한 글꼴 (굵게)", mubig = "무빅 (세방고딕)" }
		local ck = Ink.db.chatFont or "set"
		local pick = Ink.db.chatFontPath
		if pick then
			local nm = pick:match("([^\\]+)%.[^.]+$") or pick
			p.chatFont.text:SetText("채팅 글꼴: " .. nm)
		else
			p.chatFont.text:SetText("채팅 글꼴: " .. (CF[ck] or ck))
		end
		p.chatFont:SetActive(pick ~= nil or ck ~= "set")
		p.chatLine:SetActive(Ink.db.chatOutline and true or false)
		local Q = Ink.modules.Quest
		if p.qSound and Q and Q.SOUND_NAME then
			local qk = Ink.db.questSound or "random"
			p.qSound.text:SetText("퀘스트 완료 소리: " .. (Q.SOUND_NAME[qk] or qk))
			p.qSound:SetActive(qk ~= "off")
		end
		p.chatDesc:SetText("채팅 · 바로 바뀌어요. 무빅은 글꼴 파일을 넣어 둔 경우에만 · 테두리를 켜면 밝은 배경에서도 또렷해요 · 채팅창 오른쪽 위 톱니바퀴로 글꼴을 미리 보며 고를 수 있어요 · 완료 소리는 누르면 미리 들려줘요")
	end
	local mode = Ink.db.renderMode or "auto"
	local auto = Ink.autoTier or "1x"
	local tier = mode == "auto" and auto or mode
	p.render.text:SetText("선명도: " .. (mode == "auto" and ("자동 (" .. TIER_NAME[auto] .. ")") or TIER_NAME[mode]))
	p.render:SetActive(mode ~= "auto")
	local w, h = GetPhysicalScreenSize()
	local d = "선명도 · " .. (TIER_DESC[tier] or "")
	if mode == "auto" then d = d .. string.format("  지금 화면 %d×%d", w or 0, h or 0) end
	p.renderDesc:SetText(d)
	local on = Ink.db.itemCompare ~= false
	local mode = Ink.cdb.scoreMode or "pve"
	p.compare.text:SetText("아이템 비교: " .. (not on and "끔" or (mode == "pvp" and "PvP" or "PvE")))
	p.compare:SetActive(on)
	local prof = ns.Score and ns.Score.forever and ns.Score:ProfileName() or nil
	p.compareDesc:SetText("아이템 비교 · " .. (not on and "꺼짐" or
		(prof and (prof .. " 기준 점수로 가방 · 퀘스트 보상에 화살표, 툴팁에 착용 대비 %") or "주 능력치 + 2차 능력치(전문화 BIS 비중) 점수로 가방 · 퀘스트 보상에 화살표, 툴팁에 착용 대비 % · 장신구는 BIS 여부")))
end

function M:NeedReload()
	if self.panel then
		self.panel.reload:Show()
		if self.panel.FitHeight then self.panel.FitHeight() end
	end
end

-------------------------------------------------------------------------------
-- 설정 창 (게임 메뉴 > 설정 > 애드온 > InkUI)
-------------------------------------------------------------------------------
function M:BuildPanel()
	-- 바깥 틀(블리자드 설정 칸에 등록) 안에 스크롤 영역 → 내용이 길어도 칸 밖으로 넘치지 않는다
	local outer = CreateFrame("Frame")
	outer.name = "FOA UI"
	outer:Hide()
	local sf = CreateFrame("ScrollFrame", nil, outer)
	sf:SetPoint("TOPLEFT", 0, -4)
	sf:SetPoint("BOTTOMRIGHT", -12, 4)
	local p = CreateFrame("Frame", nil, sf)
	p:SetSize(660, 900)
	sf:SetScrollChild(p)
	sf:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then p:SetWidth(w) end end)
	-- 얇은 스크롤 막대 (오른쪽)
	local track = outer:CreateTexture(nil, "ARTWORK")
	track:SetColorTexture(1, 1, 1, 0.05)
	track:SetWidth(3)
	track:SetPoint("TOPRIGHT", -4, -8)
	track:SetPoint("BOTTOMRIGHT", -4, 8)
	local thumb = outer:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7)
	thumb:SetWidth(3)
	local function UpdateThumb()
		local range = sf:GetVerticalScrollRange() or 0
		local h = track:GetHeight() or 0
		if range <= 1 or h <= 0 then track:Hide(); thumb:Hide(); return end
		track:Show(); thumb:Show()
		local view = sf:GetHeight()
		local th = math.max(24, h * view / (view + range))
		thumb:SetHeight(th)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", track, "TOP", 0, -(h - th) * (sf:GetVerticalScroll() / range))
	end
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, d)
		local range = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - d * 48)))
		UpdateThumb()
	end)
	sf:SetScript("OnScrollRangeChanged", function() UpdateThumb() end)
	-- 내용 높이: 가장 아래 요소까지 (글꼴이 늦게 불러와져도 맞게 열 때마다 다시 잰다)
	local function FitHeight()
		local top = p:GetTop()
		if not top then return end
		local bottom = top
		for _, r in ipairs({ p:GetRegions() }) do
			local b = r:IsShown() and r:GetBottom()
			if b and b < bottom then bottom = b end
		end
		for _, c in ipairs({ p:GetChildren() }) do
			local b = c:IsShown() and c:GetBottom()
			if b and b < bottom then bottom = b end
		end
		p:SetHeight(math.max(10, top - bottom + 24))
		UpdateThumb()
	end
	outer:SetScript("OnShow", function() C_Timer.After(0, FitHeight) end)
	p.FitHeight = FitHeight

	-- 제목: 기하 모노그램 마크 + FOA 도형 글자
	local brand, ui = Ink:Brand(p, 20)
	brand:SetPoint("TOPLEFT", 18, -16)
	local ver = Ink:Text(p, F.latin, 11, C.muted, "LEFT")
	ver:SetPoint("LEFT", ui, "RIGHT", 10, -1)
	ver:SetText("v" .. Ink.version .. "  ·  First of All")
	p.sheet = Button(p, "새 설정 창 열기", 150, function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		local S = Ink.modules.Sheet
		if S and S.Open then S:Open() end
	end, true)
	p.sheet:SetPoint("TOPRIGHT", p, "TOPRIGHT", -18, -12)
	local h1 = Ink:Text(p, F.semi, 11, C.muted, "LEFT")
	h1:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 2, -20)
	h1:SetText("배치")
	p.edit = Button(p, "편집 모드", 130, function()
		M:SetEdit(not M.editing)
		if M.editing and SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
	end)
	p.edit:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -10)
	p.test = Button(p, "테스트 모드", 130, function() M:SetTest(not M.testing) end)
	p.test:SetPoint("LEFT", p.edit, "RIGHT", 8, 0)
	p.reset = Button(p, "위치 초기화", 130, function() M:ResetAll() end)
	p.reset:SetPoint("LEFT", p.test, "RIGHT", 8, 0)
	p.kb = Button(p, "단축키 설정", 130, function() Ink:OpenQuickKeybind() end)
	p.kb:SetPoint("LEFT", p.reset, "RIGHT", 8, 0)

	-- 2줄: 화면 비율 / UI 픽셀 맞춤 / 그래픽 프리셋
	local h2 = Ink:Text(p, F.semi, 11, C.muted, "LEFT")
	h2:SetPoint("TOPLEFT", p.edit, "BOTTOMLEFT", 0, -16)
	h2:SetText("화면 · 그래픽")
	p.aspect = Button(p, "비율", 150, function()
		local cur = Ink.cdb.aspect or "auto"
		local list = { "auto", "16:10", "16:9", "21:9", "32:9" }
		local i = 1
		for n, v in ipairs(list) do if v == cur then i = n end end
		Ink:SetAspect(list[i % #list + 1])
		M:SyncButtons()
		if M.editing then M:SyncAll() end
	end)
	p.aspect:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -8)
	p.pixel = Button(p, "UI 픽셀 맞춤", 116, function() M:SetPixelPerfect(not Ink.db.pixelPerfect) end)
	p.pixel:SetPoint("LEFT", p.aspect, "RIGHT", 8, 0)
	p.gfx = {}
	local prev = p.pixel
	for _, g in ipairs({ { "perf", "성능" }, { "balanced", "균형" }, { "quality", "화질" }, { "restore", "되돌리기" } }) do
		local b = Button(p, g[2], g[1] == "restore" and 74 or 58, function() M:ApplyGraphics(g[1]) end)
		b:SetPoint("LEFT", prev, "RIGHT", g[1] == "perf" and 16 or 6, 0)
		p.gfx[g[1]] = b
		prev = b
	end
	p.gfxLabel = Ink:Text(p, F.sans, 10, C.dim, "LEFT")
	p.gfxLabel:SetPoint("BOTTOMLEFT", p.gfx.perf, "TOPLEFT", 2, 4)
	p.gfxLabel:SetText("그래픽 프리셋")

	-- 3줄: 글꼴 · 화면 선명도 (누를 때마다 다음 것, /reload 필요)
	local h3 = Ink:Text(p, F.semi, 11, C.muted, "LEFT")
	h3:SetPoint("TOPLEFT", p.aspect, "BOTTOMLEFT", 0, -16)
	h3:SetText("글자 · 화면 선명도 (바꾸면 /reload 필요)")
	local function Cycle(list, cur)
		local i = 1
		for n, v in ipairs(list) do if v == cur then i = n end end
		return list[i % #list + 1]
	end
	p.font = Button(p, "글꼴", 190, function()
		Ink.db.fontSet = Cycle(Ink.FONT_SETS, Ink.db.fontSet or "foa")
		M:SyncFontButton()
		M:NeedReload()
	end)
	p.font:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -8)
	p.render = Button(p, "선명도", 230, function()
		Ink.db.renderMode = Cycle({ "auto", "1x", "q", "2x" }, Ink.db.renderMode or "auto")
		M:SyncFontButton()
		M:NeedReload()
	end)
	p.render:SetPoint("LEFT", p.font, "RIGHT", 8, 0)
	p.compare = Button(p, "비교", 190, function()
		local cur = Ink.db.itemCompare == false and "off" or (Ink.cdb.scoreMode or "pve")
		local nxt = Cycle({ "pve", "pvp", "off" }, cur)
		Ink.db.itemCompare = nxt ~= "off"
		if nxt ~= "off" then Ink.cdb.scoreMode = nxt end
		if ns.Score then ns.Score:Invalidate() end
		M:SyncFontButton()
	end)
	p.compare:SetPoint("LEFT", p.render, "RIGHT", 8, 0)
	-- 설명은 버튼 아래 한 줄씩 (오른쪽 칸과 겹치지 않게 전체 폭으로)
	p.fontDesc = Ink:Text(p, F.sans, 11, C.dim, "LEFT")
	p.fontDesc:SetPoint("TOPLEFT", p.font, "BOTTOMLEFT", 2, -8)
	p.fontDesc:SetWidth(620)
	p.fontDesc:SetWordWrap(true)
	p.renderDesc = Ink:Text(p, F.sans, 11, C.dim, "LEFT")
	p.renderDesc:SetPoint("TOPLEFT", p.fontDesc, "BOTTOMLEFT", 0, -4)
	p.renderDesc:SetWidth(620)
	p.renderDesc:SetWordWrap(true)
	p.compareDesc = Ink:Text(p, F.sans, 11, C.dim, "LEFT")
	p.compareDesc:SetPoint("TOPLEFT", p.renderDesc, "BOTTOMLEFT", 0, -4)
	p.compareDesc:SetWidth(620)
	p.compareDesc:SetWordWrap(true)
	-- 채팅 글꼴 (바로 적용)
	p.chatFont = Button(p, "채팅 글꼴", 230, function()
		Ink.db.chatFont = Cycle({ "set", "game", "pretendard", "mubig" }, Ink.db.chatFont or "set")
		Ink.db.chatFontPath = nil -- 고르기 창에서 고른 글꼴은 풀기
		local bz = Ink.modules.Blizzard
		if bz and bz.ApplyChatFont then bz:ApplyChatFont() end
		M:SyncFontButton()
	end)
	p.chatFont:SetPoint("TOPLEFT", p.compareDesc, "BOTTOMLEFT", -2, -10)
	p.chatLine = Button(p, "글자 테두리", 130, function()
		Ink.db.chatOutline = not Ink.db.chatOutline or nil
		local bz = Ink.modules.Blizzard
		if bz and bz.ApplyChatFont then bz:ApplyChatFont() end
		M:SyncFontButton()
	end)
	p.chatLine:SetPoint("LEFT", p.chatFont, "RIGHT", 8, 0)
	-- 퀘스트 완료 소리 (누를 때마다 다음 소리 + 미리 듣기)
	p.qSound = Button(p, "완료 소리", 230, function()
		local Q = Ink.modules.Quest
		if not Q or not Q.SOUNDS then return end
		Ink.db.questSound = Cycle(Q.SOUNDS, Ink.db.questSound or "random")
		Q:PlayDoneSound()
		M:SyncFontButton()
	end)
	p.qSound:SetPoint("LEFT", p.chatLine, "RIGHT", 8, 0)
	p.chatDesc = Ink:Text(p, F.sans, 11, C.dim, "LEFT")
	p.chatDesc:SetPoint("TOPLEFT", p.chatFont, "BOTTOMLEFT", 2, -8)
	p.chatDesc:SetWidth(620)
	p.chatDesc:SetWordWrap(true)

	-- 두 칸으로: 왼쪽 = 화면 구성, 오른쪽 = 편의 기능 + 명령어
	local function Column(anchor, x, header, list)
		local h = Ink:Text(p, F.semi, 11, C.muted, "LEFT")
		h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, -26)
		h:SetText(header)
		local prev = h
		for i, it in ipairs(list) do
			local c = Check(p, it[1], it[2], it[3])
			c:SetWidth(300)
			c.desc:SetWidth(270)
			c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -10 or -6)
			prev = c
		end
		return prev
	end
	local left = Column(p.chatDesc, -2, "화면 구성 (바꾸면 /reload 필요)", {
		{ "파티 프레임", "FOA 파티 프레임을 씁니다.", "party" },
		{ "레이드 프레임", "FOA 레이드 프레임을 씁니다.", "raid" },
		{ "경험치 바", "얇은 FOA 경험치 바를 씁니다.", "xp" },
		{ "행동단축바", "FOA 행동단축바를 씁니다. 편집 모드에서 바마다 버튼 수 · 줄 · 크기 · 간격을 바꿀 수 있어요.", "actionBars" },
		{ "네임플레이트", "FOA 네임플레이트를 씁니다.", "plates" },
		{ "가방", "분류별로 정리되는 FOA 가방을 씁니다.", "bags" },
		{ "캐릭터 창", "캐릭터 창을 FOA 스타일로 꾸밉니다.", "charSheet" },
		{ "진영 메뉴", "왼쪽 위 진영 문양 메뉴를 씁니다.", "launcher" },
		{ "튜토리얼 끄기", "노란 안내 상자 · 화살표 · 도움말 말풍선을 숨깁니다.", "hideTutorials" },
		{ "화면 위 시계", "화면 위 가운데에 큰 시계. 클릭하면 서버 시간.", "clock" },
		{ "세계 지도 표시", "지도에 비행 지점(발견 · 미발견 색 구분), 들러 본 주요 NPC(여관 · 은행 · 경매장 · 우편함 · 훈련사 등), 지역별 도서관 책 목록.", "mapLayer" },
		{ "지도에 받을 수 있는 퀘스트 (포에버)", "지금 받을 수 있는 퀘스트를 지도에 느낌표로. 1~2레벨 뒤 퀘스트는 흐리게, 너무 낮은 퀘스트는 빼요. 클릭하면 길 안내.", "questMap" },
		{ "던전 전리품 · BIS", "지도 옆 보스별 전리품, 캐릭터 창 BIS 탭 (본섭 예시).", "dungeon" },
		{ "기본 창 / 글꼴 (실험)", "기본 창 껍데기와 글꼴 변경. 기본은 꺼짐.", "windows" },
	})
	local right = Column(p.chatDesc, 328, "편의 기능", {
		{ "지도에 낮은 퀘스트도", "회색(너무 낮은) 퀘스트도 지도에 보여 줘요. 지도에서 바로 반영돼요.", "questMapLow" },
		{ "퀘스트 완료 알림", "퀘스트 목표를 다 채우면 소리와 함께 화면 위에 잠깐 알림이 떠요.", "questToast" },
		{ "사거리 표시", "대상까지 거리를 작게 표시. 빨강 = 사거리 밖 · 노랑 = 끝자락 · 초록 = 안 · 주황 = 근접. 편집 모드에서 옮길 수 있어요.", "range" },
		{ "특성 가이드 (포에버)", "레벨업할 때 다음에 찍을 특성을 특성 창에서 강조하고, 포인트가 생기면 채팅으로 알려 줍니다.", "talentGuide" },
		{ "배울 기술 (포에버)", "마법책 옆에 지금 배울 수 있는 기술 · 다음 레벨 기술. 직업 상급자 창을 한 번 열면 비용까지.", "training" },
		{ "전문기술 안내 (포에버)", "전문기술 창 옆에 지금 구간에 만들 것 · 재료 · 숙련 오르는 제조법 · 배울 제조법.", "profGuide" },
		{ "툴팁에 경매장 가격", "경매장 창 위 \"가격 스캔\"으로 받은 최저 단가를 아이템 툴팁에 보여 줘요.", "ahTooltip" },
		{ "레벨업 BIS에 제작템 (포에버)", "만렙 전 BIS(레벨 최고템)에 던전 전리품과 함께 대장기술 · 가죽세공 · 재봉술 · 기계공학 · 마법부여 제작 장비도 넣어요. 경매장 가격을 알면 같이 보여 줘요.", "bisCrafts" },
		{ "BIS에 퀘스트 보상 (포에버)", "BIS 후보에 내 진영 · 직업이 받을 수 있는 퀘스트 보상 장비도 넣어요. 이미 끝낸 퀘스트는 빼고, 툴팁에 퀘스트 이름 · 주는 NPC · 위치를 보여 줘요.", "bisQuests" },
		{ "퀘스트 목록에 직업 퀘스트 (포에버)", "지금 받을 수 있는 내 직업 퀘스트와 다음에 열리는 직업 퀘스트를 목록 맨 위에. 받은 직업 퀘스트는 자동으로 추적해서 맨 위로. 클릭하면 길 안내.", "questClass" },
		{ "미니맵에 퀘스트 (포에버)", "받을 수 있는 퀘스트 · 보고할 퀘스트를 미니맵에. 범위 밖은 가까운 3개만 테두리에 작게.", "questMinimap" },
		{ "보고할 퀘스트 물음표", "다 끝낸 퀘스트의 보고 위치를 지도 · 미니맵에 물음표로.", "questTurnIn" },
		{ "지도 크게", "창으로 띄운 세계 지도를 1.3배로 크게 (기본은 원래 크기).", "mapScaleUp" },
		{ "지도 밝히기 (포에버)", "안 가 본 곳도 지역 지도를 다 보여 줘요. 가 본 곳은 밝게, 안 가 본 곳은 살짝 어둡게.", "mapReveal" },
		{ "경매장 자동 가격 스캔", "경매장에 들어가면 자동으로 전체 가격을 받아요 (15분마다).", "ahAuto" },
		{ "지도에 던전 입구", "지역 지도에만 던전 입구를 차원문 모양으로. 누르면 전리품 · 진행 경로.", "mapEntrances" },
		{ "던전 안 큰 던전 화면", "던전 안에서 지도를 열면 지도 대신 진행 경로 · 전리품 화면.", "dungeonBoard" },
		{ "잡동사니 자동 판매", "상인 창을 열면 회색 아이템을 팝니다.", "sellJunk" },
		{ "자동 수리", "상인 창을 열면 장비를 수리합니다.", "autoRepair" },
		{ "길드 자금으로 수리", "가능하면 길드 자금을 먼저 씁니다.", "guildRepair" },
		{ "미터기", "피해량 / 치유량 미터기를 씁니다.", "meter" },
		{ "위협 수준", "미터기 왼쪽에 어그로(위협) 미터를 붙입니다.", "threat" },
		{ "보스 알림", "보스 패턴 타이머와 경고를 FOA 디자인으로.", "bossMod" },
		{ "NPC 역할 아이콘", "상인 · 수리 · 경매장 · 은행 · 여관 등 NPC 머리 위에 아이콘.", "npcIcons" },
		{ "퀘스트 오브젝트 표시", "앞에 있는 줍기 · 부수기 퀘스트 물체 위에 노란 배지.", "questObjects" },
		{ "새 주문 자동 배치", "새로 배운 주문을 행동단축바 빈 칸에 넣습니다.", "autoPush" },
		{ "행동단축바 잠금", "실수로 기술이 빠지지 않게. Shift 를 누른 채 끌어야 빠져요. (바로 적용)", "barLock" },
		{ "전투 중 시계 · 메뉴 숨기기", "전투가 시작되면 위 시계와 진영 문양을 숨깁니다.", "combatHide" },
	})

	p.reload = Button(p, "지금 다시 불러오기 (/reload)", 220, function() ReloadUI() end, true)
	p.reload:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -16)
	p.reload:Hide()

	-- 효과 (애니메이션) 켜고 끄기: 바로 적용 (몇 개는 /reload)
	local hfx = Ink:Text(p, F.semi, 11, C.muted, "LEFT")
	hfx:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -62)
	hfx:SetText("효과 (테스트 모드에서 미리 볼 수 있어요)")
	local lastFx = hfx
	if ns.FX then
		for i, d in ipairs(ns.FX.LIST) do
			local key, label, desc, needReload = d[1], d[2], d[3], d[4]
			local c = CreateFrame("Button", nil, p)
			-- 왼쪽 칸 폭 안에서 두 줄로 (오른쪽 "편의 기능" 칸과 겹치지 않게)
			c:SetSize(150, 22)
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			c:SetPoint("TOPLEFT", hfx, "BOTTOMLEFT", col * 158, -10 - row * 26)
			c.box = CreateFrame("Frame", nil, c)
			c.box:SetSize(14, 14)
			c.box:SetPoint("LEFT")
			c.box.bd = Ink:Round(c.box, "BORDER", true, true)
			c.box.bd:SetAllPoints()
			c.box.bd:SetVertexColor(1, 1, 1, 0.3)
			c.box.fill = Ink:Round(c.box, "ARTWORK", true, false)
			c.box.fill:SetPoint("TOPLEFT", 3, -3)
			c.box.fill:SetPoint("BOTTOMRIGHT", -3, 3)
			c.box.fill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
			c.label = Ink:Text(c, F.semi, 12, C.text, "LEFT")
			c.label:SetPoint("LEFT", c.box, "RIGHT", 8, 0)
			c.label:SetWidth(126)
			c.label:SetWordWrap(false)
			c.label:SetText(label)
			local function refresh() c.box.fill:SetShown(ns.FX.on(key)) end
			c:SetScript("OnShow", refresh)
			c:SetScript("OnClick", function()
				ns.FX.set(key, not ns.FX.on(key))
				refresh()
				if needReload then M:NeedReload() end
			end)
			c:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
				GameTooltip:AddLine(label, 1, 1, 1)
				Ink.TipLine(GameTooltip, desc .. (needReload and "\n(바꾸면 /reload 필요)" or ""), 0.56, 0.58, 0.61)
				GameTooltip:Show()
			end)
			c:SetScript("OnLeave", GameTooltip_Hide)
			refresh()
			if col == 0 then lastFx = c end
		end
	end

	local h3 = Ink:Text(p, F.semi, 11, C.muted, "LEFT")
	h3:SetPoint("TOPLEFT", lastFx, "BOTTOMLEFT", 0, -22)
	h3:SetText("명령어")
	local cmds = Ink:Text(p, F.sans, 11, C.soft, "LEFT")
	cmds:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -8)
	cmds:SetSpacing(4)
	cmds:SetWordWrap(true)
	cmds:SetWidth(300)
	cmds:SetText("/foa 설정 창  ·  /foa edit 편집 모드\n/foa test 테스트  ·  /foa kb 단축키 설정\n/foa reset 위치 초기화  ·  /foa log 오류 기록\n/foa layout 배치 다시 적용  ·  /foa old 이 창")

	p:SetScript("OnShow", function() M:SyncButtons() end)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(outer, "FOA UI")
		Settings.RegisterAddOnCategory(cat)
		self.category = cat
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(outer)
	end
	self.panel = p
	self:SyncFontButton()
	self.panelOuter = outer
end

-- 설정 열기 = 새 설정 시트 (예전 블리자드 설정 칸은 /foa old)
function M:OpenPanel(cat)
	local S = Ink.modules.Sheet
	if S and S.Open then return S:Open(cat) end
	self:OpenLegacy()
end

function M:OpenLegacy()
	if self.category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(self.category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(self.panelOuter or self.panel)
	end
end

-------------------------------------------------------------------------------
-- ESC 게임 메뉴 안에 "FOA UI" 버튼 끼워 넣기 (엘브UI와 같은 방식)
--  블리자드 메뉴 함수(AddButton)로 넣으면 접속 종료·게임 종료 버튼이 오염될 수 있어서,
--  같은 모양의 버튼을 따로 만들고 메뉴가 배치를 마친 뒤 "매크로" 아래 자리를 벌려 끼운다.
local GAP = 35
local EXIT = {}
local function IsExit(text)
	if not next(EXIT) then
		for _, k in ipairs({ "LOGOUT", "LOG_OUT", "EXIT_GAME", "RETURN_TO_GAME" }) do
			if _G[k] then EXIT[_G[k]] = true end
		end
	end
	return text and EXIT[text]
end
local function Nudge(b, dy)
	local p, rel, rp, x, y = b:GetPoint(1)
	if p then b:SetPoint(p, rel, rp, x, (y or 0) + dy) end
end

function M:PlaceGameMenuButton()
	local gm, me = GameMenuFrame, self.gmButton
	if not (gm and me and gm.buttonPool) then return end
	local anchor, support
	for b in gm.buttonPool:EnumerateActive() do
		local text = b:GetText()
		if IsExit(text) then
			Nudge(b, -(GAP - 10))
		else
			Nudge(b, 10)
			if text == MACROS then anchor = b end
			if text == GAMEMENU_SUPPORT then support = b end
		end
	end
	anchor = anchor or support
	if not anchor then me:Hide() return end
	me:ClearAllPoints()
	me:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
	me:SetSize(anchor:GetWidth(), anchor:GetHeight())
	me:Show()
	gm:SetHeight(gm:GetHeight() + 10)
end

function M:BuildGameMenuButton()
	local gm = GameMenuFrame
	if not gm or self.gmButton or not gm.buttonPool then return end
	local ok, b = pcall(CreateFrame, "Button", "FOAGameMenuButton", gm, "MainMenuFrameButtonTemplate")
	if not ok or not b then return end
	b:SetSize(200, 35)
	-- 글자 대신 FOA 로고 묶음 (마크 + 도형 글자 + UI)
	b:SetText("")
	local brand = Ink:Brand(b, 12, C.text)
	brand:SetPoint("CENTER", 0, 0)
	b.brand = brand
	b:SetScript("OnClick", function()
		if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION) end
		if InCombatLockdown() then
			print("|cffFFF468FOA|r 전투가 끝난 뒤에 설정 창을 열 수 있어요.")
			return
		end
		HideUIPanel(GameMenuFrame)
		M:OpenPanel()
	end)
	self.gmButton = b
	hooksecurefunc(gm, "Layout", function() M:PlaceGameMenuButton() end)
end

function M:Init()
	C_Timer.After(0, function() pcall(M.ApplyPixelPerfect, M) end)
	-- 해상도 / UI 크기가 바뀌면 다시 맞춘다 (값이 같으면 아무것도 안 함)
	local e = CreateFrame("Frame")
	e:RegisterEvent("DISPLAY_SIZE_CHANGED")
	e:RegisterEvent("UI_SCALE_CHANGED")
	e:SetScript("OnEvent", function() C_Timer.After(0.2, function() pcall(M.ApplyPixelPerfect, M) end) end)
	self:BuildPanel()
	self:BuildGameMenuButton()
end

function M:CombatStart()
	if self.editing then
		for _, o in pairs(self.overlays) do o:Hide() end
		if self.bar then self.bar:Hide() end
		if self.grid then self.grid:Hide() end
		if self.ghost then self.ghost:Hide() end
		self.dragging = nil
		self:FxClear()
		self.pausedEdit = true
		self.editing = false
	end
end

function M:CombatEnd()
	if self.pausedEdit then
		self.pausedEdit = nil
		self:SetEdit(true)
	end
end

function M:PostLayout()
	if self.editing then
		for _, key in ipairs(Ink.moverOrder) do self:SyncOverlay(Ink.movers[key]) end
	end
end

-- 마우스 밑에 있는 화면 조각을 전부 알려 준다 (프레임 + 그 안의 그림/글자).
--  마우스를 받지 않는 그림도 잡으려고 모든 프레임을 훑는다. 작은 것부터 출력.
function M:WhatIsUnderMouse()
	local hits, seen = {}, {}
	local function nameOf(o)
		local n = o.GetDebugName and o:GetDebugName()
		if not n or n == "" then n = (o.GetName and o:GetName()) or "(이름 없음)" end
		return n
	end
	local function add(o, kind)
		if seen[o] then return end
		seen[o] = true
		local ok, over = pcall(o.IsMouseOver, o)
		if not ok or not over then return end
		local w, h = o:GetSize()
		if not w or w < 1 or h < 1 or w > 900 then return end
		local extra = ""
		if kind == "Texture" then
			local atlas = o.GetAtlas and o:GetAtlas()
			local tex = o.GetTexture and o:GetTexture()
			extra = "  " .. (atlas and ("atlas=" .. atlas) or ("tex=" .. tostring(tex)))
			if o:GetAlpha() == 0 then extra = extra .. " (투명)" end
		elseif kind == "FontString" then
			extra = "  \"" .. tostring(Ink.plain(o:GetText())) .. "\""
		else
			extra = "  " .. tostring(o:GetFrameStrata()) .. (o:IsMouseEnabled() and " 마우스O" or " 마우스X")
		end
		hits[#hits + 1] = { area = w * h, text = string.format("%s [%s] %dx%d%s", nameOf(o), kind, w, h, extra) }
	end
	local f = EnumerateFrames()
	while f do
		local okVis, vis = pcall(f.IsVisible, f)
		if okVis and vis and not (f.IsForbidden and f:IsForbidden()) then
			add(f, f:GetObjectType())
			local okR, regs = pcall(function() return { f:GetRegions() } end)
			if okR then
				for _, r in ipairs(regs) do
					if r.IsVisible and r:IsVisible() then add(r, r:GetObjectType()) end
				end
			end
		end
		f = EnumerateFrames(f)
	end
	table.sort(hits, function(a, b) return a.area < b.area end)
	print("|cffFFF468FOA|r 마우스 밑 (작은 것부터, 최대 15개):")
	for i = 1, math.min(15, #hits) do print("  " .. hits[i].text) end
	if GameTooltip:IsShown() and GameTooltipTextLeft1 then
		print("  툴팁: " .. tostring(GameTooltipTextLeft1:GetText()))
	end
end

SLASH_INKUI1 = "/foa"
SLASH_INKUI2 = "/ink"
SlashCmdList.INKUI = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "edit" or msg == "편집" then
		M:SetEdit(not M.editing)
	elseif msg == "test" or msg == "테스트" then
		M:SetTest(not M.testing)
	elseif msg == "reset" then
		M:ResetAll()
		print("|cffFFF468FOA|r 모든 위치를 기본값으로 되돌렸어요.")
	elseif msg == "debug" then
		print("|cffFFF468FOA|r 마지막 오라 오류: " .. tostring(Ink.auraErr or "없음"))
	elseif msg == "obj" or msg == "물체" then
		-- 지금 바라보는 상호작용 물체(소프트 타겟) 진단
		local P = Ink.modules.Plates
		local u = UnitExists and UnitExists("softinteract") and "softinteract" or nil
		print("|cffFFF468FOA|r 상호작용 대상: " .. (u and "있음" or "없음 (물체 쪽을 바라보고 가까이)") ..
			"  ·  SoftTargetInteract=" .. tostring(GetCVar and GetCVar("SoftTargetInteract")) ..
			"  ·  이름표=" .. tostring(u and C_NamePlate and C_NamePlate.GetNamePlateForUnit(u) ~= nil))
		if u and P and P.ObjDiag then print("|cffFFF468FOA|r " .. P:ObjDiag(u, "명령", nil)) end
		local d = Ink.db.objDiag or {}
		for i = math.max(1, #d - 4), #d do print("|cff8E939B" .. d[i] .. "|r") end
	elseif msg == "perf" or msg == "성능" then
		-- 게임 애드온 측정(있으면) + FOA 안쪽 처리별 시간 (지난번 /foa perf 이후)
		local P = C_AddOnProfiler
		if P and P.GetAddOnMetric and Enum.AddOnProfilerMetric then
			local E = Enum.AddOnProfilerMetric
			local function m(k) local ok, v = pcall(P.GetAddOnMetric, "FOA_UI", E[k]) return ok and v or nil end
			print(string.format("|cffFFF468FOA|r 게임 측정 · 최근 평균 %.2fms · 전투 평균 %.2fms · 최고 %.1fms · 5ms 넘은 횟수 %s",
				m("RecentAverageTime") or 0, m("EncounterAverageTime") or 0, m("PeakTime") or 0, tostring(m("CountTimeOver5Ms") or "?")))
		end
		local rows = {}
		for k, v in pairs(Ink.perf or {}) do rows[#rows + 1] = { k = k, v = v } end
		table.sort(rows, function(a, b) return a.v.total > b.v.total end)
		if #rows == 0 then print("|cffFFF468FOA|r 아직 측정된 게 없어요. 전투를 조금 한 뒤 다시 입력해 주세요.") end
		for i = 1, math.min(10, #rows) do
			local r = rows[i]
			print(string.format("  %d. %s · 합계 %.1fms (전투 %.1fms) · %d번 · 최대 %.2fms", i, r.k, r.v.total, r.v.combat, r.v.n, r.v.max))
		end
		Ink.perf = {}
	elseif msg == "where" or msg == "위치" then
		-- 던전 · 날개 판단 확인용: 게임이 주는 지도 번호 · 위치 · 인스턴스 번호 · 던전 찾기 번호 · FOA 판단
		local D = Ink.modules.Dungeon
		local ui, x, y
		if D and D.PlayerSpot then ui, x, y = D.PlayerSpot() end
		local name, _, _, _, _, _, _, id, _, lfg = GetInstanceInfo()
		local key, sure
		if D and D.MatchInstance then key, sure = D:MatchInstance() end
		print(string.format("|cffFFF468FOA|r 위치  지도 %s  ·  %s, %s  ·  인스턴스 %s (%s)  ·  던전 찾기 %s  ·  %s",
			tostring(ui), x and string.format("%.1f", x * 100) or "-", y and string.format("%.1f", y * 100) or "-",
			tostring(id), tostring(name), tostring(lfg), GetSubZoneText() or ""))
		print("  FOA 판단: " .. tostring(key) .. (key and (sure and "  (확실)" or "  (추측)") or ""))
	elseif msg == "taint" or msg == "taint on" or msg == "오염" or msg == "taint off" then
		-- 오염 추적: 게임이 "어느 줄에서 FOA 때문에 블리자드 실행이 오염됐는지"를 Logs\taint.log 에 직접 적는다
		local on = msg ~= "taint off"
		pcall(SetCVar, "taintLog", on and "1" or "0")
		local now = GetCVar and GetCVar("taintLog")
		if on then
			if now == "1" or now == "2" then
				print("|cffFFF468FOA|r 오염 추적을 켰어요 · 게임 폴더 Logs\\taint.log 에 기록돼요 · 다 보면 /foa taint off")
			else
				print("|cffFFF468FOA|r 애드온이 직접 켤 수 없는 설정이에요 · 채팅창에 /console taintLog 1 을 입력해 주세요")
			end
		else
			print("|cffFFF468FOA|r 오염 추적을 껐어요.")
		end
	elseif msg == "log clear" or msg == "log 지우기" then
		Ink:ClearErrors()
		print("|cffFFF468FOA|r 오류 · 막힌 동작 기록을 지웠어요.")
	elseif msg == "log" then
		-- 오류 기록 요약 (자세한 내용은 저장 파일 InkUIDB.errlog · /reload 해야 파일에 써진다)
		local L = Ink.db and Ink.db.errlog
		local list = {}
		for _, e in ipairs(L and L.list or {}) do list[#list + 1] = e end
		table.sort(list, function(a, b) return (a.lastT or 0) > (b.lastT or 0) end)
		if #list == 0 then
			print("|cffFFF468FOA|r 기록된 오류가 없어요.")
		else
			print("|cffFFF468FOA|r 오류 " .. #list .. "가지 (최근 순 8개 · 같은 오류는 횟수로 묶음):")
			for i = 1, math.min(8, #list) do
				local e = list[i]
				local col = (e.kind == "블리자드") and "8E939B" or "FF6B5E"
				print(string.format("|cff%s[%s] x%d|r %s |cff5E636B(마지막 %s · v%s)|r", col, e.kind or "?", e.n or 1,
					(e.msg or ""):gsub("\n.*", ""):sub(1, 140), e.last or "?", e.lastVer or e.ver or "?"))
			end
		end
		local bl = {}
		for fn, b in pairs(L and L.blocked or {}) do bl[#bl + 1] = { fn = fn, b = b } end
		table.sort(bl, function(a, b) return (a.b.lastT or 0) > (b.b.lastT or 0) end)
		if #bl > 0 then
			print("|cffFFF468FOA|r 막힌 동작 " .. #bl .. "가지 (최근 순 5개):")
			for i = 1, math.min(5, #bl) do
				local x = bl[i]
				print(string.format("|cff8E939B  %s x%d (전투 중 %d) · 마지막 %s|r", x.fn, x.b.n or 0, x.b.combat or 0, x.b.last or "?"))
			end
		end
		local enc = Ink.db.encLog
		if enc and #enc > 0 then
			print("|cffFFF468FOA|r 보스 이름이 안 맞은 전투 (최근 " .. math.min(#enc, 6) .. "개):")
			for i = math.max(1, #enc - 5), #enc do print("|cff8E939B" .. enc[i] .. "|r") end
		end
		print("|cff8E939B  /reload 하면 저장 파일에 기록돼요 · /foa log clear 로 지우기|r")
	elseif msg == "kb" or msg == "단축키" then
		Ink:OpenQuickKeybind()
	elseif msg == "layout" then
		Ink:Relayout()
		print("|cffFFF468FOA|r 배치를 다시 적용했어요.")
	elseif msg == "what" or msg == "뭐야" or msg == "찾기" then
		M:WhatIsUnderMouse()
	elseif msg == "old" or msg == "예전" then
		M:OpenLegacy()
	else
		local S = Ink.modules.Sheet
		local cat
		for _, c in ipairs(S and S.CATS or {}) do if c.id == msg then cat = msg end end
		if S and S.Toggle then S:Toggle(cat) else M:OpenPanel() end
	end
end
