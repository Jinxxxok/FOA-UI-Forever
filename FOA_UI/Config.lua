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
		M:NeedReload()
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

-- 놓을 때 맞춤:
--  1) 다른 요소 · 화면 가장자리에 가까우면 딱 붙인다 (행동단축바끼리는 버튼 간격만큼 띄워서 한 덩어리처럼)
--  2) 붙일 곳이 없는 방향은 8칸 격자에 맞춘다
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

local function IsBar(key)
	return key:match("^bar%d$") or key == "stance" or key == "pet"
end

local function BarGap(key)
	local b = ns.Bars
	if b and b.Settings and IsBar(key) then return b.Settings(key).gap or 0 end
	return 0
end

local function Snap(key)
	if Ink.db.editSnap == false then return end
	local m = Ink.movers[key]
	local x, y, w, h = Box(key)
	if not (m and x) then return end
	local rw, rh = Ink.root:GetWidth(), Ink.root:GetHeight()
	local bestX, bestY, dx, dy = nil, nil, MAGNET + 1, MAGNET + 1
	local function tryX(v) local d = math.abs(v - x) if d < dx then dx, bestX = d, v end end
	local function tryY(v) local d = math.abs(v - y) if d < dy then dy, bestY = d, v end end
	-- 화면 가장자리
	tryX(0); tryX(rw - w); tryY(0); tryY(rh - h)
	for _, other in ipairs(Ink.moverOrder) do
		if other ~= key then
			local ox, oy, ow, oh = Box(other)
			if ox then
				local pad = (IsBar(key) and IsBar(other)) and math.max(BarGap(key), BarGap(other)) or 0
				-- 세로로 겹치는 범위에 있을 때만 옆에 붙이고, 가로로 겹칠 때만 위아래로 붙인다
				local nearV = y < oy + oh + MAGNET and y + h > oy - MAGNET
				local nearH = x < ox + ow + MAGNET and x + w > ox - MAGNET
				if nearV then
					tryX(ox + ow + pad)          -- 오른쪽에 붙이기
					tryX(ox - w - pad)           -- 왼쪽에 붙이기
				end
				if nearH then
					tryY(oy + oh + pad)          -- 아래에 붙이기
					tryY(oy - h - pad)           -- 위에 붙이기
					tryX(ox)                     -- 왼쪽 끝 맞추기
					tryX(ox + ow - w)            -- 오른쪽 끝 맞추기
					tryX(ox + (ow - w) / 2)      -- 가운데 맞추기
				end
				if nearV then
					tryY(oy)                     -- 위쪽 끝 맞추기
					tryY(oy + oh - h)            -- 아래쪽 끝 맞추기
				end
			end
		end
	end
	if not bestX then bestX = math.floor(x / SNAP + 0.5) * SNAP end
	if not bestY then bestY = math.floor(y / SNAP + 0.5) * SNAP end
	local s = m.frame:GetScale() or 1
	m.frame:ClearAllPoints()
	m.frame:SetPoint("TOPLEFT", Ink.root, "TOPLEFT", bestX / s, -bestY / s)
end

-- 크기 조절 (미터기 · 채팅): 아래쪽 띠 = 높이, 오른쪽 아래 모서리 = 폭과 높이
--  끄는 동안 왼쪽 위 모서리는 그대로 두고 오른쪽 · 아래로 늘어난다
local function StartResize(m, o, both)
	if InCombatLockdown() or not m.resize then return end
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
		if Ink.db.editSnap ~= false then
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
	o:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then return end
		M:Select(m.key)
		self.dragging = true
		self:StartMoving()
		self:SetScript("OnUpdate", function()
			if InCombatLockdown() then return end
			m.frame:ClearAllPoints()
			m.frame:SetPoint("TOPLEFT", self, "TOPLEFT")
			M:UpdateFields()
		end)
	end)
	o:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetScript("OnUpdate", nil)
		self.dragging = nil
		if InCombatLockdown() then return end
		Snap(m.key)
		Ink:SavePos(m.key)
		Ink:Relayout()
		M:SyncAll()
	end)
	-- 우클릭: 이 요소만 기본 위치로
	o:SetScript("OnMouseUp", function(_, btn)
		if btn == "RightButton" and not InCombatLockdown() then
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
	if self.bar then self.bar.aspect.text:SetText(AspectLabel()) end
end

function M:Select(key)
	local old = self.sel
	self.sel = key
	if old then self:PaintOverlay(old) end
	if key then self:PaintOverlay(key) end
	self:UpdateFields()
end

-- 선택한 요소의 좌표 / 크기를 위쪽 막대에 표시
function M:UpdateFields()
	local bar = self.bar
	if not bar then return end
	local key = self.sel
	local m = key and Ink.movers[key]
	if not m then
		bar.selName:SetText("요소를 클릭해서 고르세요")
		bar.selName:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		for _, w in ipairs({ bar.xBox, bar.yBox }) do w:SetText(""); w:Disable() end
		bar.scaleTxt:SetText("—")
		self:SyncOpts()
		return
	end
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
		bar:SetHeight(92)
		return
	end
	row:Show()
	bar:SetHeight(134)
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
		if self.presetPop then self.presetPop:Hide() end
		pcall(Ink.PushShared, Ink)   -- 모든 캐릭터 같은 배치: 공용 배치로 저장
	end
	self:ShowBar(on)
	self:ShowGrid(on and Ink.db.editGrid ~= false)
	if on and not self.testing then self:SetTest(true) end
	if not on and self.testFromEdit then self:SetTest(false) end
	self:SyncButtons()
	if on then self:SyncAll() end
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

function M:ShowBar(on)
	if not self.bar then
		local bar = CreateFrame("Frame", nil, Ink.root)
		bar:SetFrameStrata("FULLSCREEN_DIALOG")
		bar:SetSize(980, 92)
		bar:SetPoint("TOP", Ink.root, "TOP", 0, -240)
		bar:EnableMouse(true)
		bar:SetMovable(true)
		bar:RegisterForDrag("LeftButton")
		bar:SetScript("OnDragStart", bar.StartMoving)
		bar:SetScript("OnDragStop", bar.StopMovingOrSizing)
		bar.bg = Ink:Round(bar, "BACKGROUND", false, false)
		bar.bg:SetAllPoints()
		bar.bg:SetVertexColor(0.05, 0.06, 0.08, 0.95)
		bar.bd = Ink:Round(bar, "BORDER", false, true)
		bar.bd:SetAllPoints()
		bar.bd:SetVertexColor(1, 1, 1, 0.12)
		bar.accent = bar:CreateTexture(nil, "ARTWORK")
		bar.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
		bar.accent:SetSize(24, 2)
		bar.accent:SetPoint("TOPLEFT", 16, -1)
		bar.title = Ink:Text(bar, F.bold, 13, C.text, "LEFT")
		bar.title:SetPoint("TOPLEFT", 16, -12)
		bar.title:SetText("FOA 편집 모드")
		bar.hint = Ink:Text(bar, F.sans, 10, C.muted, "LEFT")
		bar.hint:SetPoint("LEFT", bar.title, "RIGHT", 10, -1)
		bar.hint:SetText("드래그 · 휠 크기 · 우클릭 기본 · 방향키 1칸")

		-- 1줄: 도구 (오른쪽부터)
		bar.done = Button(bar, "완료", 64, function() M:SetEdit(false) end, true)
		bar.done:SetPoint("TOPRIGHT", -12, -8)
		bar.reset = Button(bar, "전체 초기화", 92, function() M:ResetAll() end)
		bar.reset:SetPoint("RIGHT", bar.done, "LEFT", -6, 0)
		bar.test = Button(bar, "예시 표시", 80, function() M:SetTest(not M.testing) end)
		bar.test:SetPoint("RIGHT", bar.reset, "LEFT", -6, 0)
		bar.group = Button(bar, "파티 예시", 80, function() M:ToggleGroup() end)
		bar.group:SetPoint("RIGHT", bar.test, "LEFT", -6, 0)
		bar.snap = Button(bar, "격자 맞춤", 80, function()
			Ink.db.editSnap = (Ink.db.editSnap == false) and true or false
			M:SyncButtons()
		end)
		bar.snap:SetPoint("RIGHT", bar.group, "LEFT", -6, 0)
		bar.gridBtn = Button(bar, "격자", 56, function()
			Ink.db.editGrid = (Ink.db.editGrid == false) and true or false
			M:ShowGrid(Ink.db.editGrid ~= false)
			M:SyncButtons()
		end)
		bar.gridBtn:SetPoint("RIGHT", bar.snap, "LEFT", -6, 0)
		bar.share = Button(bar, "배치 공유", 80, function() M:TogglePresets() end)
		bar.share:SetPoint("RIGHT", bar.gridBtn, "LEFT", -6, 0)

		-- 2줄: 선택한 요소
		bar.line = bar:CreateTexture(nil, "ARTWORK")
		bar.line:SetColorTexture(1, 1, 1, 0.06)
		bar.line:SetHeight(1)
		bar.line:SetPoint("TOPLEFT", 12, -46)
		bar.line:SetPoint("TOPRIGHT", -12, -46)
		bar.selName = Ink:Text(bar, F.semi, 12, C.accent, "LEFT")
		bar.selName:SetPoint("TOPLEFT", 16, -60)
		bar.selName:SetWidth(170)
		bar.selName:SetWordWrap(false)

		local function label(text, anchor, x)
			local t = Ink:Text(bar, F.latin, 11, C.muted, "LEFT")
			t:SetPoint("LEFT", anchor, "RIGHT", x or 14, 0)
			t:SetText(text)
			return t
		end
		local xl = label("X", bar.selName, 6)
		bar.xBox = NumBox(bar, 64)
		bar.xBox:SetPoint("LEFT", xl, "RIGHT", 6, 0)
		local yl = label("Y", bar.xBox, 12)
		bar.yBox = NumBox(bar, 64)
		bar.yBox:SetPoint("LEFT", yl, "RIGHT", 6, 0)
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
		bar.minus = Button(bar, "−", 28, function() M:Nudge(nil, nil, -0.05) end)
		bar.minus:SetHeight(24)
		bar.minus:SetPoint("LEFT", sl, "RIGHT", 8, 0)
		bar.scaleTxt = Ink:Text(bar, F.latinB, 12, C.text, "CENTER")
		bar.scaleTxt:SetWidth(48)
		bar.scaleTxt:SetPoint("LEFT", bar.minus, "RIGHT", 2, 0)
		bar.plus = Button(bar, "+", 28, function() M:Nudge(nil, nil, 0.05) end)
		bar.plus:SetHeight(24)
		bar.plus:SetPoint("LEFT", bar.scaleTxt, "RIGHT", 2, 0)
		bar.one = Button(bar, "100%", 52, function()
			local p = M.sel and Ink:GetPos(M.sel)
			if p then M:Nudge(nil, nil, 1 - (p.s or 1)) end
		end)
		bar.one:SetHeight(24)
		bar.one:SetPoint("LEFT", bar.plus, "RIGHT", 6, 0)

		-- 화면 비율 (자동 → 16:10 → 16:9 → 21:9 → 32:9)
		bar.aspect = Button(bar, "비율", 170, function()
			local cur = Ink.cdb.aspect or "auto"
			local i = 1
			for n, v in ipairs(ASPECT_CYCLE) do if v == cur then i = n end end
			Ink:SetAspect(ASPECT_CYCLE[i % #ASPECT_CYCLE + 1])
			M:SyncAll()
		end)
		bar.aspect:SetHeight(24)
		bar.aspect:SetPoint("RIGHT", -12, 0)
		bar.aspect:SetPoint("TOP", bar.line, "BOTTOM", 0, -9)

		-- 3줄: 선택한 요소만의 조절 칸 (있을 때만)
		bar.optRow = CreateFrame("Frame", nil, bar)
		bar.optRow:SetPoint("TOPLEFT", 16, -96)
		bar.optRow:SetPoint("TOPRIGHT", -12, -96)
		bar.optRow:SetHeight(28)
		bar.optRow.line = bar.optRow:CreateTexture(nil, "ARTWORK")
		bar.optRow.line:SetColorTexture(1, 1, 1, 0.06)
		bar.optRow.line:SetHeight(1)
		bar.optRow.line:SetPoint("BOTTOMLEFT", bar.optRow, "TOPLEFT", -4, 4)
		bar.optRow.line:SetPoint("BOTTOMRIGHT", bar.optRow, "TOPRIGHT", 0, 4)
		bar.optRow:Hide()

		-- 화살표 키로 미세 이동 (입력 칸에 글자를 넣는 중엔 그대로 둔다)
		bar:EnableKeyboard(true)
		bar:SetPropagateKeyboardInput(true)
		bar:SetScript("OnKeyDown", function(self, key)
			local step = IsShiftKeyDown() and 10 or 1
			local d = ({ LEFT = { -step, 0 }, RIGHT = { step, 0 }, UP = { 0, -step }, DOWN = { 0, step } })[key]
			if d and M.sel and not InCombatLockdown() then
				self:SetPropagateKeyboardInput(false)
				M:Nudge(d[1], d[2])
			else
				self:SetPropagateKeyboardInput(true)
			end
		end)
		self.bar = bar
	end
	self.bar:SetShown(on)
	if on then self:UpdateFields() end
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
	p:SetPoint("TOPRIGHT", self.bar.share, "BOTTOMRIGHT", 0, -6)
	p:SetFrameStrata("FULLSCREEN_DIALOG")
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
	if self.bar then
		self.bar.test:SetActive(self.testing)
		self.bar.group.text:SetText(self.testGroup == "raid" and "레이드 예시" or "파티 예시")
		self.bar.snap:SetActive(Ink.db.editSnap ~= false)
		self.bar.gridBtn:SetActive(Ink.db.editGrid ~= false)
		if self.bar.share then self.bar.share:SetActive(Ink.db.layoutShared and true or false) end
		self.bar.aspect.text:SetText(AspectLabel())
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
	cmds:SetText("/foa 설정 창  ·  /foa edit 편집 모드\n/foa test 테스트  ·  /foa kb 단축키 설정\n/foa reset 위치 초기화  ·  /foa log 오류 기록\n/foa layout 배치 다시 적용")

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

function M:OpenPanel()
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
	elseif msg == "log" then
		local bl = Ink.db.blockedLog
		if not bl or #bl == 0 then
			print("|cffFFF468FOA|r 막힌 동작 기록이 없어요.")
		else
			print("|cffFFF468FOA|r 막힌 동작 (최근 " .. math.min(#bl, 12) .. "개):")
			for i = math.max(1, #bl - 11), #bl do print("|cffFFF468FOA|r " .. bl[i]) end
		end
		local errs = Ink.db and Ink.db.errors
		if errs and #errs > 0 then
			print("|cffFFF468FOA|r 최근 오류 (최대 8개):")
			for i = math.max(1, #errs - 7), #errs do print("|cffFF6B5EFOA|r " .. errs[i]) end
		else
			print("|cffFFF468FOA|r 기록된 오류가 없어요.")
		end
	elseif msg == "kb" or msg == "단축키" then
		Ink:OpenQuickKeybind()
	elseif msg == "layout" then
		Ink:Relayout()
		print("|cffFFF468FOA|r 배치를 다시 적용했어요.")
	elseif msg == "what" or msg == "뭐야" or msg == "찾기" then
		M:WhatIsUnderMouse()
	else
		M:OpenPanel()
	end
end
