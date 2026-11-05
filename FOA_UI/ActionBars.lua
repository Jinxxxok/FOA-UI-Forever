-- FOA UI · 행동단축바
--  블리자드 행동단축바 대신 FOA 가 직접 만든 바 (LibActionButton-1.0).
--  편집 모드에서 위치 · 버튼 수 · 한 줄 칸 수 · 버튼 크기 · 간격 · 빈칸 표시를 바 하나하나 조절한다.
--  태세 바 · 소환수 바는 블리자드 버튼을 그대로 쓰되 FOA 틀로 옮겨서 똑같이 조절한다.
--  처음 켤 때는 지금 블리자드 바 배치(위치 · 크기 · 줄 수)를 읽어서 그대로 이어받는다.

local ADDON, ns = ...
local Ink = ns.Ink
local C, F = Ink.c, Ink.font
local M = Ink:Module("Bars")
ns.Bars = M

local LAB = LibStub and LibStub("LibActionButton-1.0", true)

-- page: 이 바가 보여주는 행동 페이지 (1페이지 = 행동 칸 1~12)
-- bind: 블리자드 단축키 명령 (키 설정 창의 "행동 단축바 n번 칸")
-- blizz: 숨길 블리자드 바 / prefix: 그 바의 버튼 이름
local BARS = {
	{ key = "bar1", label = "행동단축바 1", page = 1, bind = "ACTIONBUTTON", blizz = { "MainActionBar", "MainMenuBar" }, prefix = "ActionButton", main = true },
	{ key = "bar2", label = "행동단축바 2", page = 6, bind = "MULTIACTIONBAR1BUTTON", blizz = { "MultiBarBottomLeft" }, prefix = "MultiBarBottomLeftButton" },
	{ key = "bar3", label = "행동단축바 3", page = 5, bind = "MULTIACTIONBAR2BUTTON", blizz = { "MultiBarBottomRight" }, prefix = "MultiBarBottomRightButton" },
	{ key = "bar4", label = "행동단축바 4", page = 3, bind = "MULTIACTIONBAR3BUTTON", blizz = { "MultiBarRight" }, prefix = "MultiBarRightButton" },
	{ key = "bar5", label = "행동단축바 5", page = 4, bind = "MULTIACTIONBAR4BUTTON", blizz = { "MultiBarLeft" }, prefix = "MultiBarLeftButton" },
	{ key = "bar6", label = "행동단축바 6", page = 13, bind = "MULTIACTIONBAR5BUTTON", blizz = { "MultiBar5" }, prefix = "MultiBar5Button", optional = true },
	{ key = "bar7", label = "행동단축바 7", page = 14, bind = "MULTIACTIONBAR6BUTTON", blizz = { "MultiBar6" }, prefix = "MultiBar6Button", optional = true },
	{ key = "bar8", label = "행동단축바 8", page = 15, bind = "MULTIACTIONBAR7BUTTON", blizz = { "MultiBar7" }, prefix = "MultiBar7Button", optional = true },
}
local EXTRA = {
	{ key = "stance", label = "태세 바", blizz = "StanceBar", prefix = "StanceButton", count = 10, bind = "SHAPESHIFTBUTTON" },
	{ key = "pet", label = "소환수 바", blizz = "PetActionBar", prefix = "PetActionButton", count = 10, bind = "BONUSACTIONBUTTON",
		vis = "[petbattle][vehicleui][overridebar][possessbar] hide; [@pet,exists] show; hide" },
}

-- 기본값 (블리자드 배치를 못 읽었을 때). 위치는 1920x1080 시안 기준
local W12 = 12 * 36 + 11 * 4
local DEF = {
	bar1 = { on = true, num = 12, per = 12, size = 36, gap = 4, grid = true, mode = "center", x = (1920 - W12) / 2, y = 1030 },
	bar2 = { on = true, num = 12, per = 12, size = 36, gap = 4, grid = true, mode = "center", x = (1920 - W12) / 2, y = 990 },
	bar3 = { on = true, num = 12, per = 12, size = 36, gap = 4, grid = true, mode = "center", x = (1920 - W12) / 2, y = 950 },
	bar4 = { on = false, num = 12, per = 1, size = 34, gap = 4, grid = true, mode = "right", x = 10, y = 330 },
	bar5 = { on = false, num = 12, per = 1, size = 34, gap = 4, grid = true, mode = "right", x = 48, y = 330 },
	bar6 = { on = false, num = 12, per = 1, size = 34, gap = 4, grid = true, mode = "right", x = 86, y = 330 },
	bar7 = { on = false, num = 12, per = 1, size = 34, gap = 4, grid = true, mode = "right", x = 124, y = 330 },
	bar8 = { on = false, num = 12, per = 1, size = 34, gap = 4, grid = true, mode = "right", x = 162, y = 330 },
	stance = { on = true, num = 10, per = 10, size = 28, gap = 4, mode = "center", x = (1920 - W12) / 2, y = 914 },
	pet = { on = true, num = 10, per = 10, size = 28, gap = 4, mode = "center", x = (1920 + W12) / 2 - (10 * 28 + 9 * 4), y = 914 },
}

local function Settings(key)
	local db = Ink.cdb.bars
	db[key] = db[key] or {}
	local s, d = db[key], DEF[key]
	for k, v in pairs(d) do if s[k] == nil and k ~= "mode" and k ~= "x" and k ~= "y" then s[k] = v end end
	return s
end
M.Settings = Settings

-- 블리자드 바 숨기기: 부모만 숨김 틀로 (Hide/이벤트 끄기는 오염 위험이 있어 안 함)
local function HideBlizz(frame)
	if type(frame) == "string" then frame = _G[frame] end
	if not frame or frame.foaHidden then return end
	frame.foaHidden = true
	frame:SetParent(Ink.hidden)
	-- 화면 배치 관리자가 이 바 자리를 다시 잡지 않게 (전투 중 "막힌 동작" 줄이기)
	frame.ignoreFramePositionManager = true
	hooksecurefunc(frame, "SetParent", function(self, p)
		if p == Ink.hidden or self.foaReparent then return end
		local function again()
			if EditModeManagerFrame and EditModeManagerFrame:IsShown() then C_Timer.After(0.3, again) return end
			if InCombatLockdown() then M.pendingHide = true return end
			self.foaReparent = true
			self:SetParent(Ink.hidden)
			self.foaReparent = nil
		end
		C_Timer.After(0, again)
	end)
end

-------------------------------------------------------------------------------
-- 지금 블리자드 바 배치 읽기 (처음 한 번)
-------------------------------------------------------------------------------
local function RootBox(r)
	local l, t = r:GetLeft(), r:GetTop()
	local rl, rt = Ink.root:GetLeft(), Ink.root:GetTop()
	if not (l and t and rl and rt) then return end
	local k = r:GetEffectiveScale() / Ink.root:GetEffectiveScale()
	return l * k - rl, rt - t * k, r:GetWidth() * k, r:GetHeight() * k
end

local function ReadBlizz(prefix, frame, count)
	if not frame then return end
	local shown = {}
	for i = 1, count do
		local b = _G[prefix .. i]
		if b and b:IsShown() and b:IsVisible() then
			local x, y, w = RootBox(b)
			if x then shown[#shown + 1] = { x = x, y = y, w = w } end
		end
	end
	if #shown == 0 then return { on = false } end
	local minX, minY = math.huge, math.huge
	local cols, rows = {}, {}
	for _, b in ipairs(shown) do
		minX, minY = math.min(minX, b.x), math.min(minY, b.y)
		cols[math.floor(b.x / 4 + 0.5)] = true
		rows[math.floor(b.y / 4 + 0.5)] = true
	end
	local nc, nr = 0, 0
	for _ in pairs(cols) do nc = nc + 1 end
	for _ in pairs(rows) do nr = nr + 1 end
	local size = shown[1].w
	local gap = 4
	if #shown > 1 then
		local d = math.max(math.abs(shown[2].x - shown[1].x), math.abs(shown[2].y - shown[1].y))
		gap = math.max(0, math.min(12, math.floor(d - size + 0.5)))
	end
	return {
		on = true, num = #shown, per = math.max(1, nc),
		size = math.max(20, math.min(64, math.floor(size + 0.5))), gap = gap,
		x = minX, y = minY,
	}
end

function M:ImportBlizzard()
	local out = {}
	for _, d in ipairs(BARS) do
		local frame
		for _, n in ipairs(d.blizz) do frame = frame or _G[n] end
		local ok, r = pcall(ReadBlizz, d.prefix, frame, 12)
		if ok and r then out[d.key] = r end
	end
	for _, d in ipairs(EXTRA) do
		local ok, r = pcall(ReadBlizz, d.prefix, _G[d.blizz], d.count)
		if ok and r and r.on then r.num = d.count; out[d.key] = r end
	end
	return out
end

-------------------------------------------------------------------------------
-- 바 만들기
-------------------------------------------------------------------------------
local function MainDriver()
	local s = ""
	if GetOverrideBarIndex then s = s .. "[overridebar] " .. GetOverrideBarIndex() .. "; " end
	if GetVehicleBarIndex then s = s .. "[vehicleui][possessbar] " .. GetVehicleBarIndex() .. "; " end
	if GetTempShapeshiftBarIndex then s = s .. "[shapeshift] " .. GetTempShapeshiftBarIndex() .. "; " end
	s = s .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
	s = s .. "[bonusbar:5] 11; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; 1"
	return s
end

local function ButtonConfig(d, i, s)
	return {
		outOfRangeColoring = "button",
		tooltip = "enabled",
		showGrid = s.grid ~= false,
		colors = { range = { 0.85, 0.25, 0.22 }, mana = { 0.45, 0.55, 1 } },
		hideElements = { macro = true, hotkey = false, equipped = false, border = true, borderIfEmpty = true },
		keyBoundTarget = d.bind .. i,
		flyoutDirection = "UP",
		actionButtonUI = d.main and true or false,
		text = {
			hotkey = { font = { font = F.latinB, size = 11, flags = "OUTLINE" }, color = { 0.92, 0.92, 0.92 },
				position = { anchor = "TOPRIGHT", relAnchor = "TOPRIGHT", offsetX = -4, offsetY = -4 }, justifyH = "RIGHT" },
			count = { font = { font = F.latinB, size = 11, flags = "OUTLINE" }, color = { 1, 1, 1 },
				position = { anchor = "BOTTOMRIGHT", relAnchor = "BOTTOMRIGHT", offsetX = -3, offsetY = 3 }, justifyH = "RIGHT" },
			macro = { font = { font = F.sans, size = 9, flags = "OUTLINE" }, color = { 1, 1, 1 },
				position = { anchor = "BOTTOM", relAnchor = "BOTTOM", offsetX = 0, offsetY = 2 }, justifyH = "CENTER" },
		},
	}
end

local function Skin(b, small)
	local bz = Ink.modules.Blizzard
	if bz and bz.SkinActionButton then pcall(bz.SkinActionButton, b, small) end
end

function M:BuildBar(d)
	local s = Settings(d.key)
	local h = CreateFrame("Frame", "FOA" .. d.key:gsub("^%l", string.upper), Ink.root, "SecureHandlerStateTemplate")
	h:SetSize(10, 10)
	h:SetFrameStrata("LOW")
	d.header = h
	d.buttons = {}
	for i = 1, 12 do
		local b = LAB:CreateButton(i, h:GetName() .. "Button" .. i, h, ButtonConfig(d, i, s))
		b:SetSize(s.size or 36, s.size or 36) -- 효과(쿨 끝 고리) 크기가 처음 크기를 따라가므로 먼저
		if d.main then
			for p = 1, 18 do b:SetState(p, "action", (p - 1) * 12 + i) end
		end
		b:SetState(0, "action", (d.page - 1) * 12 + i)
		b.foaCmd = d.bind .. i
		d.buttons[i] = b
		Skin(b)
	end
	if d.main then
		h:SetAttribute("_onstate-page", [[
			self:SetAttribute("state", newstate)
			control:ChildUpdate("state", newstate)
		]])
		RegisterStateDriver(h, "page", MainDriver())
	end
	Ink:Movable(d.key, d.label, h, DEF[d.key].mode, DEF[d.key].x, DEF[d.key].y)
	Ink.movers[d.key].opts = self:Options(d)
end

-- 태세 · 소환수 바: 블리자드 버튼을 FOA 틀로 옮긴다 (블리자드가 버튼 상태는 계속 관리)
function M:BuildExtra(d)
	local blizzBar = _G[d.blizz]
	if not blizzBar then return end
	local h = CreateFrame("Frame", "FOA" .. d.key:gsub("^%l", string.upper) .. "Bar", Ink.root, "SecureHandlerStateTemplate")
	h:SetSize(10, 10)
	h:SetFrameStrata("LOW")
	d.header = h
	d.buttons = {}
	for i = 1, d.count do
		local b = _G[d.prefix .. i]
		if b then
			b.foaCmd = d.bind .. i
			d.buttons[i] = b
			Skin(b, true)
		end
	end
	if Ink.cdb.barsImported then HideBlizz(blizzBar) end
	-- 블리자드가 버튼 자리를 다시 잡으면 FOA 배치로 되돌린다
	for _, fn in ipairs({ "UpdateGridLayout", "Layout", "UpdateLayout" }) do
		if type(blizzBar[fn]) == "function" then
			hooksecurefunc(blizzBar, fn, function() M:QueueLayout(d) end)
		end
	end
	Ink:Movable(d.key, d.label, h, DEF[d.key].mode, DEF[d.key].x, DEF[d.key].y)
	Ink.movers[d.key].opts = self:Options(d)
end

-------------------------------------------------------------------------------
-- 배치
-------------------------------------------------------------------------------
function M:LayoutBar(d)
	local h = d.header
	if not h then return end
	if InCombatLockdown() then self.pendingLayout = true return end
	-- 처음 켤 때 블리자드 배치를 읽기 전까지는 FOA 바를 숨겨 두고 태세 · 소환수 버튼도 안 옮긴다
	if not Ink.cdb.barsImported then
		if not d.count then h:Hide() end
		return
	end
	local s = Settings(d.key)
	local total = #d.buttons
	local n = math.max(1, math.min(s.num or total, total))
	-- 태세 바: 배운 태세 · 형상 수만큼만 (없으면 바를 숨긴다 · 빈칸만 남지 않게)
	local forms
	if d.key == "stance" then
		forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
		n = math.max(1, math.min(n, forms))
	end
	local per = math.max(1, math.min(s.per or n, n))
	local size, gap = s.size or 36, s.gap or 4
	local rows = math.ceil(n / per)
	h:SetSize(per * size + (per - 1) * gap, rows * size + (rows - 1) * gap)
	for i, b in ipairs(d.buttons) do
		if b:GetParent() ~= h then b:SetParent(h) end
		b:ClearAllPoints()
		if i <= n then
			local r, c = math.floor((i - 1) / per), (i - 1) % per
			b:SetSize(size, size)
			b:SetPoint("TOPLEFT", h, "TOPLEFT", c * (size + gap), -r * (size + gap))
			b.foaHidden = nil
			if not d.count then b:Show() end -- 태세 · 소환수 칸은 블리자드가 보일지 정한다
		else
			b:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
			b.foaHidden = true
			b:Hide()
		end
	end
	if d.vis then
		if s.on == false then
			UnregisterStateDriver(h, "visibility")
			h:Hide()
		else
			RegisterStateDriver(h, "visibility", d.vis)
		end
	elseif s.on == false or forms == 0 then
		h:Hide()
	else
		h:Show()
	end
	-- 아이콘 크기가 바뀌면 쿨다운 숫자 · 효과 크기도 맞춘다
	if d.cfgDirty then
		d.cfgDirty = nil
		for i, b in ipairs(d.buttons) do
			if b.UpdateConfig and d.bind then b:UpdateConfig(ButtonConfig(d, i, s)) end
		end
	end
end

function M:QueueLayout(d)
	if self.layingOut then return end
	self.layingOut = true
	C_Timer.After(0, function()
		self.layingOut = nil
		self:LayoutAll()
	end)
end

function M:LayoutAll()
	for _, d in ipairs(self.list or {}) do self:LayoutBar(d) end
end

-- 게임 설정(ESC → 설정 → 행동 단축바)에서 "행동 단축바 2~8"을 켜고 끄면 FOA 바도 따라간다.
--  블리자드 값이 바뀐 순간만 따라가고, FOA 편집 모드에서 바꾼 값은 그대로 둔다.
local function BlizzBarShown(n)
	-- 이 파일의 Settings 는 FOA 설정 함수라서 블리자드 설정 표는 _G 에서 꺼낸다
	local BS = _G.Settings
	if type(BS) ~= "table" or not BS.GetValue then return nil end
	local ok, v = pcall(BS.GetValue, "PROXY_SHOW_ACTIONBAR_" .. n)
	if ok and v ~= nil then return v and true or false end
end

-- 2 · 3번 바를 1번 바와 같은 크기 · 간격으로 맞추고, 1번 바 바로 위에 차례로 쌓는다.
--  (처음 FOA 바로 바꿀 때 꺼져 있던 바는 기본 크기 36이라 1번 바와 달라진다)
function M:MatchBar1(keys)
	if InCombatLockdown() then return end
	local b1 = Settings("bar1")
	for _, key in ipairs(keys) do
		-- 바로 아래 바: 3번은 2번이 켜져 있으면 2번 위, 아니면 1번 위
		local prev = (key == "bar3" and Settings("bar2").on ~= false) and "bar2" or "bar1"
		local s = Settings(key)
		s.size, s.gap, s.sized = b1.size, b1.gap, true
		local d
		for _, x in ipairs(self.list or {}) do if x.key == key then d = x end end
		if d then
			d.cfgDirty = true
			self:LayoutBar(d)
			local lx, top = Ink:FrameBox(prev)
			if lx and d.header then
				local h = d.header:GetHeight()
				d.header:ClearAllPoints()
				d.header:SetPoint("TOPLEFT", Ink.root, "TOPLEFT", lx, -(top - h - (b1.gap or 4)))
				Ink:SavePos(key)
				Ink:ApplyPos(key)
			end
		end
	end
end

function M:SyncBlizzToggles()
	if not Ink.cdb.barsImported then return end
	local seen = Ink.cdb.bars.blizzSeen or {}
	local changed, any, adopted
	for n = 2, 8 do
		local v = BlizzBarShown(n)
		local key = "bar" .. n
		if v ~= nil and DEF[key] then
			any = true
			local s = Settings(key)
			if seen[n] == nil then
				-- 처음 보는 값: 블리자드 설정에서 켜 둔 바는 FOA 에서도 켠다 (끄지는 않는다)
				--  공용 배치 · 프리셋을 받아온 직후에는 받아온 그대로 둔다
				if v and s.on == false and not Ink.cdb.bars.noAdopt then
					s.on = true; changed = true
					if n <= 3 then adopted = adopted or {}; adopted[#adopted + 1] = key end
				end
			elseif seen[n] ~= v then
				s.on = v
				changed = true
			end
			seen[n] = v
		end
	end
	if any then Ink.cdb.bars.blizzSeen = seen; Ink.cdb.bars.noAdopt = nil end
	if changed then
		self:LayoutAll()
		for _, d in ipairs(self.list) do Ink:ApplyPos(d.key) end
		if adopted then self:MatchBar1(adopted) end
		if Ink.modules.Config and Ink.modules.Config.SyncOpts then pcall(Ink.modules.Config.SyncOpts, Ink.modules.Config) end
	end
	return any
end

-- 블리자드가 숨긴 태세 · 소환수 버튼(쓸 수 없는 칸)은 블리자드 판단대로 둔다
-- (LayoutBar 의 Show 는 행동 버튼에만)

-------------------------------------------------------------------------------
-- 편집 모드 옵션 (선택한 바 아래 줄에 나오는 조절 칸)
-------------------------------------------------------------------------------
function M:Options(d)
	local function get(k) return function() return Settings(d.key)[k] end end
	local function set(k, cfg)
		return function(v)
			if InCombatLockdown() then return end
			Settings(d.key)[k] = v
			if k == "size" or k == "gap" then Settings(d.key).sized = true end
			if cfg then d.cfgDirty = true end
			M:LayoutBar(d)
			Ink:ApplyPos(d.key)
			if k == "on" or k == "num" then M:UpdateBindings() end
		end
	end
	local max = #(d.buttons or {}) > 0 and #d.buttons or (d.count or 12)
	local o = {
		{ kind = "toggle", label = "켜기", get = function() return Settings(d.key).on ~= false end,
			set = function(v)
				set("on")(v)
				-- 처음 켜는 2 · 3번 바는 1번 바 크기에 맞춰서 1번 바 위에 놓는다
				if v and (d.key == "bar2" or d.key == "bar3") and not Settings(d.key).sized then M:MatchBar1({ d.key }) end
			end },
		{ kind = "step", label = "버튼 수", get = get("num"), set = set("num"), min = 1, max = max, step = 1 },
		{ kind = "step", label = "한 줄", get = get("per"), set = set("per"), min = 1, max = max, step = 1 },
		{ kind = "step", label = "크기", get = get("size"), set = set("size", true), min = 20, max = 64, step = 1 },
		{ kind = "step", label = "간격", get = get("gap"), set = set("gap"), min = 0, max = 16, step = 1 },
	}
	if d.bind and not d.count then
		o[#o + 1] = { kind = "toggle", label = "빈칸 표시", get = function() return Settings(d.key).grid ~= false end,
			set = function(v) set("grid", true)(v) end }
	end
	return o
end

-------------------------------------------------------------------------------
-- 단축키: 블리자드 명령(ACTIONBUTTON1 …)에 걸린 키를 FOA 버튼으로 돌린다
-------------------------------------------------------------------------------
function M:UpdateBindings()
	if InCombatLockdown() then self.pendingBind = true return end
	self.pendingBind = nil
	local owner = self.bindOwner
	ClearOverrideBindings(owner)
	for _, d in ipairs(BARS) do
		if d.header and Settings(d.key).on ~= false then
			local n = Settings(d.key).num or 12
			for i, b in ipairs(d.buttons) do
				if i <= n then
					for _, key in ipairs({ GetBindingKey(d.bind .. i) }) do
						SetOverrideBindingClick(owner, false, key, b:GetName(), "LeftButton")
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- FOA 단축키 설정 모드: 버튼 위에 마우스를 올리고 키를 누르면 그 칸에 연결
--  (블리자드 빠른 단축키 창은 블리자드 버튼만 알아서, FOA 바용으로 따로)
-------------------------------------------------------------------------------
local MODS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1, LMETA = 1, RMETA = 1 }
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function KeyString(key)
	if MODS[key] then return end
	local s = ""
	if IsAltKeyDown() then s = s .. "ALT-" end
	if IsControlKeyDown() then s = s .. "CTRL-" end
	if IsShiftKeyDown() then s = s .. "SHIFT-" end
	if IsMetaKeyDown and IsMetaKeyDown() then s = s .. "META-" end
	return s .. key
end

function M:Bind(cmd, key)
	if InCombatLockdown() or not cmd then return end
	if key then
		SetBinding(key, cmd)
	else
		for _, k in ipairs({ GetBindingKey(cmd) }) do SetBinding(k) end
	end
	SaveBindings(GetCurrentBindingSet())
end

function M:KeybindOverlay(b)
	if b.foaKB then return b.foaKB end
	local o = CreateFrame("Button", nil, b)
	o:SetAllPoints()
	o:SetFrameLevel(b:GetFrameLevel() + 20)
	o:EnableMouse(true)
	o:EnableMouseWheel(true)
	o:RegisterForClicks("AnyUp")
	o.hl = Ink:Round(o, "OVERLAY", b:GetWidth() < 34, true)
	o.hl:SetAllPoints()
	o.hl:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
	o.hl:Hide()
	o:SetScript("OnEnter", function(self)
		M.kbHover = b
		self.hl:Show()
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("단축키 설정", C.accent[1], C.accent[2], C.accent[3])
		local keys = { GetBindingKey(b.foaCmd) }
		GameTooltip:AddLine(#keys > 0 and ("지금: " .. table.concat(keys, ", ")) or "지금: 없음", 1, 1, 1)
		GameTooltip:AddLine("키를 누르면 연결 · ESC 또는 오른쪽 클릭으로 지우기", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	o:SetScript("OnLeave", function(self)
		if M.kbHover == b then M.kbHover = nil end
		self.hl:Hide()
		GameTooltip:Hide()
	end)
	o:SetScript("OnClick", function(self, btn)
		if btn == "RightButton" then M:Bind(b.foaCmd)
		elseif MOUSE[btn] then M:Bind(b.foaCmd, KeyString(MOUSE[btn])) end
		self:GetScript("OnEnter")(self)
	end)
	o:SetScript("OnMouseWheel", function(self, delta)
		M:Bind(b.foaCmd, KeyString(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
		self:GetScript("OnEnter")(self)
	end)
	b.foaKB = o
	return o
end

function M:SetKeybindMode(on, force)
	if InCombatLockdown() and not force then return end
	self.kbOn = on and true or nil
	if not self.kbFrame then
		local k = CreateFrame("Frame", "FOAKeybindMode", UIParent)
		k:SetFrameStrata("FULLSCREEN_DIALOG")
		k:SetSize(700, 46)
		k:SetPoint("TOP", UIParent, "TOP", 0, -120)
		k.bg = Ink:Round(k, "BACKGROUND", false, false)
		k.bg:SetAllPoints()
		k.bg:SetVertexColor(0.05, 0.06, 0.08, 0.95)
		k.bd = Ink:Round(k, "BORDER", false, true)
		k.bd:SetAllPoints()
		k.bd:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.6)
		k.text = Ink:Text(k, F.semi, 13, C.text, "CENTER")
		k.text:SetPoint("CENTER", 0, 0)
		k.text:SetText("단축키 설정 · 버튼에 마우스를 올리고 키를 누르세요 · 올린 채 ESC = 지우기 · 바깥에서 ESC = 끝")
		k.text:ClearAllPoints()
		k.text:SetPoint("CENTER", -34, 0)
		-- 마우스로도 끝낼 수 있게 (버튼 위에서 ESC 는 지우기라서)
		k.done = CreateFrame("Button", nil, k)
		k.done:SetSize(56, 26)
		k.done:SetPoint("RIGHT", -10, 0)
		k.done.bg = Ink:Round(k.done, "BACKGROUND", true, false)
		k.done.bg:SetAllPoints()
		k.done.bg:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.18)
		k.done.t = Ink:Text(k.done, F.semi, 12, C.accent, "CENTER")
		k.done.t:SetPoint("CENTER")
		k.done.t:SetText("완료")
		k.done:SetScript("OnClick", function() M:SetKeybindMode(false) end)
		k:EnableKeyboard(true)
		k:SetPropagateKeyboardInput(false)
		k:SetScript("OnKeyDown", function(self, key)
			local b = M.kbHover
			-- ESC: 버튼 위에 마우스가 있으면 그 칸 단축키 지우기, 아니면 설정 끝내기
			if key == "ESCAPE" then
				if b then
					M:Bind(b.foaCmd)
					if b.foaKB then b.foaKB:GetScript("OnEnter")(b.foaKB) end
				else
					M:SetKeybindMode(false)
				end
				return
			end
			local ks = KeyString(key)
			if b and ks then
				M:Bind(b.foaCmd, ks)
				if b.foaKB then b.foaKB:GetScript("OnEnter")(b.foaKB) end
			end
		end)
		self.kbFrame = k
	end
	self.kbFrame:SetShown(on)
	for _, d in ipairs(self.list or {}) do
		for _, b in ipairs(d.buttons or {}) do
			if on then self:KeybindOverlay(b):Show() elseif b.foaKB then b.foaKB:Hide() end
		end
	end
	local bz = Ink.modules.Blizzard
	if bz and bz.SetKeybindMode then bz:SetKeybindMode(on) end
end

-------------------------------------------------------------------------------
function M:Active()
	return self.on and true or false
end

function M:Init()
	if Ink.db.actionBars == false or not LAB then return end
	self.on = true
	self.bindOwner = CreateFrame("Frame")
	Ink.cdb.bars = Ink.cdb.bars or {}
	self.list = {}
	for _, d in ipairs(BARS) do
		local exists
		for _, n in ipairs(d.blizz) do exists = exists or _G[n] end
		if exists or not d.optional then
			self:BuildBar(d)
			self.list[#self.list + 1] = d
		end
	end
	for _, d in ipairs(EXTRA) do
		self:BuildExtra(d)
		if d.header then self.list[#self.list + 1] = d end
	end
	-- 예전 버전에서 새 캐릭터 1번 바가 꺼진 채로 저장된 경우 되살리기 (한 번만)
	if Ink.cdb.barsImported and not Ink.cdb.barsFix1 then
		Ink.cdb.barsFix1 = true
		local b1 = Ink.cdb.bars.bar1
		if b1 and b1.on == false then b1.on = true end
	end
	if Ink.cdb.barsImported then
		self:HideAllBlizz()
	else
		-- 처음 켤 때: 블리자드 편집 모드 배치가 다 잡힌 뒤에 읽어서 이어받는다.
		-- 그때까지는 FOA 바를 숨겨 두고 블리자드 바를 그대로 쓴다.
		C_Timer.After(3, function() M:FirstImport() end)
	end
	self:LayoutAll()
	for _, d in ipairs(self.list) do Ink:ApplyPos(d.key) end
	if Ink.cdb.barsImported then self:UpdateBindings() end
	-- 블리자드 설정 값이 늦게 잡힐 수 있어서 접속 직후 몇 번 더 본다
	local tries = 0
	local function retry()
		tries = tries + 1
		if InCombatLockdown() then M.pendingSync = true
		elseif not M:SyncBlizzToggles() and tries < 10 then C_Timer.After(2, retry) end
	end
	retry()
	C_Timer.After(5, function() if InCombatLockdown() then M.pendingSync = true else M:SyncBlizzToggles() end end)
	-- 예전 버전: 나중에 켠 2 · 3번 바가 기본 크기(36)로 남아 1번 바와 크기가 다른 경우 한 번 맞춘다
	C_Timer.After(7, function()
		if not Ink.cdb.barsImported or Ink.cdb.barsSizeFix or InCombatLockdown() then return end
		Ink.cdb.barsSizeFix = true
		local b1 = Settings("bar1")
		if b1.size == 36 and b1.gap == 4 then return end
		local keys = {}
		for _, key in ipairs({ "bar2", "bar3" }) do
			local s = Settings(key)
			if s.on ~= false and not s.sized and s.size == 36 and s.gap == 4 then keys[#keys + 1] = key end
		end
		if #keys > 0 then M:MatchBar1(keys) end
	end)
	if MultiActionBar_Update then
		hooksecurefunc("MultiActionBar_Update", function()
			C_Timer.After(0, function()
				if InCombatLockdown() then M.pendingSync = true else M:SyncBlizzToggles() end
			end)
		end)
	end

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("UPDATE_BINDINGS")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	ev:RegisterEvent("PET_BAR_UPDATE")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			if M.kbOn then M:SetKeybindMode(false, true) end
		elseif event == "UPDATE_BINDINGS" then
			if Ink.cdb.barsImported then M:UpdateBindings() end
		elseif event == "PLAYER_REGEN_ENABLED" then
			if M.pendingImport then M.pendingImport = nil; M:FirstImport() end
			if M.pendingSync then M.pendingSync = nil; M:SyncBlizzToggles() end
			if M.pendingBind then M:UpdateBindings() end
			if M.pendingLayout then M.pendingLayout = nil; M:LayoutAll() end
			if M.pendingHide then M.pendingHide = nil; M:HideAllBlizz() end
		else
			M:QueueLayout()
		end
	end)
end

function M:HideAllBlizz()
	for _, d in ipairs(BARS) do
		-- 이름 후보 중 처음 있는 것 하나만 (MainActionBar 가 있으면 MainMenuBar 는 다른 틀일 수 있다)
		local f
		for _, n in ipairs(d.blizz) do f = f or _G[n] end
		if f and d.header then
			if f.foaHidden then
				if f:GetParent() ~= Ink.hidden then f.foaReparent = true; f:SetParent(Ink.hidden); f.foaReparent = nil end
			else
				HideBlizz(f)
			end
		end
	end
	for _, d in ipairs(EXTRA) do
		local f = _G[d.blizz]
		if f and not f.foaHidden then
			HideBlizz(f)
		elseif f and f:GetParent() ~= Ink.hidden then
			f.foaReparent = true; f:SetParent(Ink.hidden); f.foaReparent = nil
		end
	end
end

function M:FirstImport()
	if Ink.cdb.barsImported then return end
	if InCombatLockdown() then self.pendingImport = true return end
	-- 새 캐릭터 첫 접속(시작 영상 · 로딩)에는 블리자드 바가 아직 안 보여서 "전부 꺼짐"으로 읽힌다.
	-- 화면이 보이고 1번 바 버튼이 잡힐 때까지 기다렸다가 읽고, 끝내 못 읽으면 기본 배치로.
	self.importTries = (self.importTries or 0) + 1
	local ok, imported = pcall(self.ImportBlizzard, self)
	if not ok then imported = {} end
	local mainOK = imported.bar1 and imported.bar1.on
	if (not UIParent:IsVisible() or not mainOK) and self.importTries < 20 then
		C_Timer.After(3, function() M:FirstImport() end)
		return
	end
	if not mainOK then imported = {} end
	if imported.bar1 then imported.bar1.on = true end -- 1번 바는 절대 끄지 않는다
	for key, r in pairs(imported) do
		local s = Settings(key)
		for _, k in ipairs({ "on", "num", "per", "size", "gap" }) do if r[k] ~= nil then s[k] = r[k] end end
		if r.size then s.sized = true end
	end
	Ink.cdb.barsImported = true
	self:HideAllBlizz()
	self:LayoutAll()
	-- 이어받은 위치를 저장 위치로 (이미 FOA 위치가 있으면 그대로)
	for _, d in ipairs(self.list) do
		local r = imported[d.key]
		if r and r.x and not Ink:GetPos(d.key) then
			d.header:ClearAllPoints()
			d.header:SetPoint("TOPLEFT", Ink.root, "TOPLEFT", r.x, -r.y)
			Ink:SavePos(d.key)
		end
		Ink:ApplyPos(d.key)
	end
	self:UpdateBindings()
	self:SyncBlizzToggles()
	print("|cffFFF468FOA|r 행동단축바를 FOA 바로 바꿨어요. 지금 블리자드 배치를 그대로 가져왔고, /foa → 편집 모드에서 바마다 조절할 수 있어요.")
end

function M:PostLayout()
	if self.on then self:LayoutAll() end
end
