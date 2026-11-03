-- InkUI · Core
-- 모든 좌표는 1920x1080 시안 기준 픽셀. 루트 프레임을 화면 높이 1080 단위로 스케일해서 그대로 사용한다.

local ADDON, ns = ...
local Ink = {}
ns.Ink = Ink
_G.InkUI = Ink
Ink.version = "0.18.1"

local MEDIA = "Interface\\AddOns\\FOA_UI\\Media\\"

Ink.font = {
	sans = MEDIA .. "Fonts\\PlexSansKR-Regular.ttf",
	semi = MEDIA .. "Fonts\\PlexSansKR-SemiBold.ttf",
	bold = MEDIA .. "Fonts\\PlexSansKR-Bold.ttf",
	mono = MEDIA .. "Fonts\\PlexMono-Regular.ttf",
	num = MEDIA .. "Fonts\\SpaceGrotesk-Light.ttf",
	numR = MEDIA .. "Fonts\\SpaceGrotesk-Regular.ttf",
	latin = MEDIA .. "Fonts\\Inter-Medium.ttf",
	latinB = MEDIA .. "Fonts\\Inter-SemiBold.ttf",
}
local F = Ink.font

Ink.tex = {
	white = "Interface\\Buttons\\WHITE8X8",
	seg = MEDIA .. "Textures\\Seg",
	segGlow = MEDIA .. "Textures\\SegGlow",
	glow = MEDIA .. "Textures\\Glow",
	logo = MEDIA .. "Textures\\Logo",          -- 기하 모노그램 마크 (원 + A)
	wordmark = MEDIA .. "Textures\\Wordmark",  -- F·O·A 도형 글자 (가로 3:1, 오른쪽 1/4은 여백)
	round = MEDIA .. "Textures\\RoundFill",
	roundBorder = MEDIA .. "Textures\\RoundBorder",
	round4 = MEDIA .. "Textures\\RoundFill4",
	roundBorder4 = MEDIA .. "Textures\\RoundBorder4",
	mask = MEDIA .. "Textures\\RoundMask",
	roleTank = MEDIA .. "Textures\\RoleTank",
	roleHealer = MEDIA .. "Textures\\RoleHealer",
	roleDps = MEDIA .. "Textures\\RoleDps",
	combat = MEDIA .. "Textures\\Combat",
	rest = MEDIA .. "Textures\\Rest",
	elite = MEDIA .. "Textures\\Elite",
	ring = MEDIA .. "Textures\\Ring",
	disc = MEDIA .. "Textures\\Disc",
}
Ink.icon = function(name) return MEDIA .. "Icons\\" .. name end

-- 데미지 글꼴 (머리 위에 뜨는 숫자). 접속할 때 읽히므로 바꾼 뒤엔 재접속해야 적용된다.
-- 빗나감/흡수 같은 한글도 나오므로 한글이 들어있는 굵은 글꼴을 쓴다.
-- 캐릭터를 바꿔 접속할 때 기본 UI가 값을 되돌리는 경우가 있어서, 불러오는 단계마다 다시 넣는다.
Ink.damageFont = Ink.font.semi
DAMAGE_TEXT_FONT = Ink.damageFont
function Ink:ApplyDamageFont()
	if DAMAGE_TEXT_FONT ~= self.damageFont then DAMAGE_TEXT_FONT = self.damageFont end
end

local function hex(h, a)
	return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end
Ink.hex = hex

Ink.c = {
	text = hex("F3F2EE"),
	muted = hex("8E939B"),
	soft = hex("B4B8BF"),
	dim = hex("5E636B"),
	red = hex("FF6B5E"),
	orange = hex("FFB75A"),
	gold = hex("E3C07A"),
	green = hex("6FD39A"),
	accent = hex("FFF468"),
	mana = hex("5B9BFF"),
	rage = hex("E5534B"),
	tank = hex("7FA8FF"),
	healer = hex("6FD39A"),
	dps = hex("FF8A80"),
	track = { 1, 1, 1, 0.08 },
	trackSoft = { 1, 1, 1, 0.06 },
	border = { 1, 1, 1, 0.10 },
}

Ink.powerColor = {
	[0] = hex("5B9BFF"), [1] = hex("E5534B"), [2] = hex("FF9A4D"), [3] = hex("FFF468"),
	[6] = hex("4FC3F7"), [8] = hex("8EB8FF"), [11] = hex("3FA7FF"), [13] = hex("B07CFF"),
	[17] = hex("C77DFF"), [18] = hex("C77DFF"),
}

-- 해제 종류 색 (마법 / 저주 / 질병 / 독 / 출혈)
Ink.dispel = {
	[0] = { 0, 0, 0, 0 },
	[1] = hex("5B9BFF"), [2] = hex("B07CFF"), [3] = hex("C9A26A"), [4] = hex("5BAE7A"),
	[9] = hex("FF6B5E"), [11] = hex("FF6B5E"),
}

-- 한국어 클라이언트에서도 1.2k / 3.4m 형식으로 줄인다 (secret 값에도 안전)
Ink.abbrev = { breakpointData = {
	{ breakpoint = 1e9, abbreviation = "b", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
	{ breakpoint = 1e6, abbreviation = "m", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
	{ breakpoint = 1e5, abbreviation = "k", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
} }

-- 숫자 표기: 10만 미만은 1,234 처럼 쉼표, 그 이상은 123.4k / 1.2m (secret 이면 블리자드 축약)
function Ink.Num(v)
	local p = Ink.plain(v)
	if p then
		if p < 1e5 and BreakUpLargeNumbers then return BreakUpLargeNumbers(p) end
		return Ink.Abbrev(p)
	end
	return Ink.Abbrev(v)
end

function Ink.Abbrev(v)
	local ok, s = pcall(AbbreviateNumbers, v, Ink.abbrev)
	if ok and s then return s end
	ok, s = pcall(AbbreviateNumbers, v)
	if ok and s then return s end
	return ""
end

-------------------------------------------------------------------------------
-- 안전 호출 / secret 값 처리
-------------------------------------------------------------------------------
local issecret = _G.issecretvalue or function() return false end
Ink.issecret = issecret

function Ink.safe(fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
end

function Ink.plain(v)
	if v == nil or issecret(v) then return nil end
	return v
end

-------------------------------------------------------------------------------
-- 폰트 오브젝트 (블리자드 위젯에 SetFontObject 로 넘길 때 사용)
-------------------------------------------------------------------------------
local function FontObj(name, file, size, flags)
	local f = CreateFont(name)
	f:SetFont(file, size, flags or "")
	f:SetShadowColor(0, 0, 0, 0.8)
	f:SetShadowOffset(1, -1)
	return f
end
Ink.fo = {
	auraTimer = FontObj("InkUIFontAuraTimer", F.sans, 9),
	cdNumber = FontObj("InkUIFontCooldown", F.semi, 12, "OUTLINE"),
	cdNumberSmall = FontObj("InkUIFontCooldownSmall", F.semi, 10, "OUTLINE"),
	cdTimer = FontObj("InkUIFontCdTimer", F.semi, 10),
}

-------------------------------------------------------------------------------
-- 위젯 헬퍼
-------------------------------------------------------------------------------
function Ink:Text(parent, font, size, color, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(font, size, "")
	color = color or Ink.c.text
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetJustifyV("MIDDLE")
	fs:SetWordWrap(false)
	fs:SetShadowColor(0, 0, 0, 0.75)
	fs:SetShadowOffset(1, -1)
	return fs
end

function Ink:Bar(parent, w, h, color, trackColor)
	local sb = CreateFrame("StatusBar", nil, parent)
	sb:SetSize(w, h)
	sb:SetStatusBarTexture(Ink.tex.white)
	color = color or Ink.c.text
	sb:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
	sb.bg = sb:CreateTexture(nil, "BACKGROUND")
	sb.bg:SetAllPoints()
	local t = trackColor or Ink.c.track
	sb.bg:SetColorTexture(t[1], t[2], t[3], t[4] or 1)
	sb:SetMinMaxValues(0, 1)
	sb:SetValue(0)
	return sb
end

-- 9-slice 둥근 텍스처 (크기와 상관없이 모서리가 유지된다)
function Ink:Round(parent, layer, small, isBorder, sub)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
	local file = isBorder and (small and Ink.tex.roundBorder4 or Ink.tex.roundBorder) or (small and Ink.tex.round4 or Ink.tex.round)
	t:SetTexture(file)
	if t.SetTextureSliceMargins then
		local m = small and 5 or 8
		t:SetTextureSliceMargins(m, m, m, m)
		if Enum.UITextureSliceMode then t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
	end
	return t
end

-- 1px 각진 테두리
function Ink:Border(frame, color, size)
	size = size or 1
	color = color or Ink.c.border
	local b = frame.inkBorder
	if not b then
		b = {}
		for i = 1, 4 do b[i] = frame:CreateTexture(nil, "OVERLAY", nil, 7) end
		frame.inkBorder = b
	end
	b[1]:ClearAllPoints(); b[1]:SetPoint("TOPLEFT"); b[1]:SetPoint("TOPRIGHT"); b[1]:SetHeight(size)
	b[2]:ClearAllPoints(); b[2]:SetPoint("BOTTOMLEFT"); b[2]:SetPoint("BOTTOMRIGHT"); b[2]:SetHeight(size)
	b[3]:ClearAllPoints(); b[3]:SetPoint("TOPLEFT"); b[3]:SetPoint("BOTTOMLEFT"); b[3]:SetWidth(size)
	b[4]:ClearAllPoints(); b[4]:SetPoint("TOPRIGHT"); b[4]:SetPoint("BOTTOMRIGHT"); b[4]:SetWidth(size)
	for i = 1, 4 do b[i]:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
	return b
end

-- 아이콘 칸 공통 스킨: 둥근 바탕 + 둥근 마스크 아이콘 + 둥근 테두리
function Ink:IconSkin(holder, icon, small)
	if holder.inkSkin then return holder.inkSkin end
	local s = {}
	s.bg = Ink:Round(holder, "BACKGROUND", small, false, -8)
	s.bg:SetAllPoints()
	s.bg:SetVertexColor(1, 1, 1, 0.04)
	if icon and icon.AddMaskTexture and holder.CreateMaskTexture then
		s.mask = holder:CreateMaskTexture()
		s.mask:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		s.mask:SetAllPoints(icon)
		icon:AddMaskTexture(s.mask)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	local top = CreateFrame("Frame", nil, holder)
	top:SetAllPoints()
	top:SetFrameLevel(holder:GetFrameLevel() + 4)
	s.top = top
	s.border = Ink:Round(top, "OVERLAY", small, true)
	s.border:SetAllPoints()
	s.border:SetVertexColor(1, 1, 1, 0.12)
	holder.inkSkin = s
	return s
end

function Ink:SkinCooldown(cd, small)
	if not cd then return end
	Ink.safe(cd.SetSwipeTexture, cd, small and Ink.tex.round4 or Ink.tex.round)
	Ink.safe(cd.SetSwipeColor, cd, 0, 0, 0, 0.62)
	Ink.safe(cd.SetDrawEdge, cd, false)
	Ink.safe(cd.SetDrawBling, cd, false)
	if cd.SetCountdownFont then Ink.safe(cd.SetCountdownFont, cd, small and "InkUIFontCooldownSmall" or "InkUIFontCooldown") end
end

-- 오라 아이콘 (아이콘 + 스와이프 + 아래쪽 남은 시간 + 중첩)
function Ink:AuraButton(parent, size)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(size, size)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.skin = Ink:IconSkin(b, b.icon, true)
	b.skin.bg:SetVertexColor(0, 0, 0, 0.6)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetPoint("TOPLEFT", 1, -1)
	b.cd:SetPoint("BOTTOMRIGHT", -1, 1)
	b.cd:SetReverse(true)
	Ink:SkinCooldown(b.cd, true)
	if b.cd.SetCountdownFont then Ink.safe(b.cd.SetCountdownFont, b.cd, "InkUIFontAuraTimer") end
	if b.cd.SetCountdownAbbrevThreshold then Ink.safe(b.cd.SetCountdownAbbrevThreshold, b.cd, 600) end
	local fs = b.cd.GetCountdownFontString and b.cd:GetCountdownFontString()
	if fs then
		fs:ClearAllPoints()
		fs:SetPoint("TOP", b, "BOTTOM", 0, -2)
		fs:SetTextColor(Ink.c.muted[1], Ink.c.muted[2], Ink.c.muted[3])
	end
	b.count = Ink:Text(b.skin.top, F.latinB, 9, Ink.c.text, "RIGHT")
	b.count:SetPoint("BOTTOMRIGHT", 1, 0)
	b:Hide()
	return b
end

-- 테스트 모드 애니메이션용 반복 타이머
local tickers = {}
function Ink:Loop(key, fn)
	if tickers[key] then tickers[key]:Cancel(); tickers[key] = nil end
	if fn then tickers[key] = C_Timer.NewTicker(0.05, fn) end
end

-------------------------------------------------------------------------------
-- 루트 프레임과 좌표계
-------------------------------------------------------------------------------
local root = CreateFrame("Frame", "InkUIRoot", UIParent)
root:SetAllPoints(UIParent)
root:SetFrameStrata("LOW")
Ink.root = root

local hiddenParent = CreateFrame("Frame", "InkUIHidden", UIParent)
hiddenParent:SetAllPoints(UIParent)
hiddenParent:Hide()
Ink.hidden = hiddenParent

function Ink:UpdateScale()
	if InCombatLockdown() then
		self.pendingScale = true
		return
	end
	self.pendingScale = nil
	local h = UIParent:GetHeight()
	if h and h > 0 then root:SetScale(h / 1080) end
end

local function placeRaw(f, mode, x, y)
	f:ClearAllPoints()
	if mode == "left" then
		f:SetPoint("TOPLEFT", root, "TOPLEFT", x, -y)
	elseif mode == "right" then
		f:SetPoint("TOPRIGHT", root, "TOPRIGHT", -x, -y)
	elseif mode == "bottomleft" then
		f:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", x, y)
	elseif mode == "bottomright" then
		f:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -x, y)
	else
		f:SetPoint("TOPLEFT", root, "TOP", x - 960, -y)
	end
end

function Ink:Place(f, x, y) placeRaw(f, "center", x, y) end
function Ink:PlaceLeft(f, x, y) placeRaw(f, "left", x, y) end
function Ink:PlaceRight(f, right, y) placeRaw(f, "right", right, y) end
function Ink:PlaceBottomLeft(f, x, bottom) placeRaw(f, "bottomleft", x, bottom) end

-------------------------------------------------------------------------------
-- 이동 가능한 요소 (편집 모드용 등록 + 저장 위치 적용)
-------------------------------------------------------------------------------
Ink.movers = {}
Ink.moverOrder = {}

-- key: 저장 키, label: 편집 모드 표시 이름, frame: 실제 프레임, mode/x/y: 기본 위치
function Ink:Movable(key, label, frame, mode, x, y, w, h)
	local m = self.movers[key]
	if not m then
		m = { key = key }
		self.movers[key] = m
		table.insert(self.moverOrder, key)
	end
	m.label, m.frame, m.mode, m.x, m.y, m.w, m.h = label, frame, mode, x, y, w, h
	self:ApplyPos(key)
	return m
end

function Ink:ApplyPos(key)
	local m = self.movers[key]
	if not m or not m.frame then return end
	if m.frame:IsProtected() and InCombatLockdown() then return end
	local p = self.cdb and self.cdb.pos and self.cdb.pos[key]
	if p then
		placeRaw(m.frame, "center", p.x, p.y)
	else
		placeRaw(m.frame, m.mode, m.x, m.y)
	end
end

-- 현재 프레임 위치를 시안 좌표(화면 가운데 기준)로 저장
function Ink:SavePos(key)
	local m = self.movers[key]
	if not m then return end
	local f = m.frame
	local l, t = f:GetLeft(), f:GetTop()
	local rl, rt, rw = root:GetLeft(), root:GetTop(), root:GetWidth()
	if not (l and t and rl and rt and rw) then return end
	local k = f:GetEffectiveScale() / root:GetEffectiveScale()
	local x = l * k - (rl + rw / 2) + 960
	local y = rt - t * k
	local v = { x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
	-- 이 캐릭터 배치에 저장 + "마지막 배치"로도 남겨서 새 캐릭터가 처음 접속할 때 이어받는다
	self.cdb.pos = self.cdb.pos or {}
	self.cdb.pos[key] = v
	self.db.pos = self.db.pos or {}
	self.db.pos[key] = { x = v.x, y = v.y }
end

-- 위치 초기화는 지금 캐릭터만
function Ink:ResetPos(key)
	if not self.cdb.pos then return end
	if key then self.cdb.pos[key] = nil else wipe(self.cdb.pos) end
	if not key then self.cdb.bagPos = nil end
end

-- 블리자드 프레임을 붙일 투명 앵커
function Ink:Anchor(w, h)
	local a = CreateFrame("Frame", nil, root)
	a:SetSize(w, h)
	return a
end

-- 블리자드 프레임을 앵커에 맞춘다 (스케일 차이를 보정해서 크기도 맞춤)
function Ink:Fit(frame, anchor, point, w, h)
	if not frame then return end
	if frame.IsProtected and frame:IsProtected() and InCombatLockdown() then return end
	Ink.safe(function()
		frame:ClearAllPoints()
		frame:SetPoint(point, anchor, point)
		if w then
			local k = root:GetEffectiveScale() / frame:GetEffectiveScale()
			frame:SetSize(w * k, (h or w) * k)
		end
	end)
end

-------------------------------------------------------------------------------
-- 블리자드 프레임 숨기기
-------------------------------------------------------------------------------
-- 완전히 끄기: 이벤트 해제 + 숨김 부모로 이동 (클릭도 막힘). 전투 중이면 전투 후 처리
local pendingDisable = {}
function Ink:Disable(frame, keepEvents)
	if type(frame) == "string" then frame = _G[frame] end
	if type(frame) ~= "table" or not frame.IsProtected or frame.inkDisabled then return end
	if frame:IsProtected() and InCombatLockdown() then
		pendingDisable[frame] = keepEvents or false
		return
	end
	frame.inkDisabled = true
	if not keepEvents then frame:UnregisterAllEvents() end
	Ink.safe(frame.Hide, frame)
	frame:SetParent(hiddenParent)
	hooksecurefunc(frame, "SetParent", function(self, p)
		if p ~= hiddenParent and not self.inkReparenting then
			local function again()
				if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
					C_Timer.After(0.25, again)
					return
				end
				if InCombatLockdown() and self:IsProtected() then
					pendingDisable[self] = true
					return
				end
				self.inkReparenting = true
				self:SetParent(hiddenParent)
				self.inkReparenting = nil
			end
			C_Timer.After(0, again)
		end
	end)
end

-- 보이지만 않게: 투명 + 마우스 끄기 (부모 변경이 위험한 프레임용)
local hiddenAlpha = {}
function Ink:Fade(frame)
	if type(frame) == "string" then frame = _G[frame] end
	if not frame or hiddenAlpha[frame] then return end
	hiddenAlpha[frame] = true
	frame:SetAlpha(0)
	hooksecurefunc(frame, "SetAlpha", function(self, a)
		if a and a > 0 then self:SetAlpha(0) end
	end)
	if frame.EnableMouse and not (frame:IsProtected() and InCombatLockdown()) then
		Ink.safe(frame.EnableMouse, frame, false)
	end
end

local hideHooked = {}
function Ink:KeepHidden(frame)
	if type(frame) == "string" then frame = _G[frame] end
	-- 진짜 화면 프레임만 (같은 이름의 일반 테이블도 있다)
	if type(frame) ~= "table" or not frame.GetObjectType or not frame.IsProtected or not frame.Hide then return end
	if frame:IsProtected() then
		Ink:Fade(frame)
		return
	end
	frame:Hide()
	if not hideHooked[frame] then
		hideHooked[frame] = true
		hooksecurefunc(frame, "Show", function(self) self:Hide() end)
	end
end

-------------------------------------------------------------------------------
-- 모듈 / 이벤트
-------------------------------------------------------------------------------
Ink.modules = {}
-- FOA 로고 묶음: [마크] [FOA 도형 글자] [UI]
--  h = "FOA" 글자 텍스처 높이. 돌려주는 값: 묶음 프레임, "UI" 글자
function Ink:Brand(parent, h, uiColor)
	local f = CreateFrame("Frame", nil, parent)
	local L = math.floor(h * 1.35 + 0.5)
	local gap = math.max(3, math.floor(h * 0.32 + 0.5))
	f.logo = f:CreateTexture(nil, "ARTWORK")
	f.logo:SetTexture(self.tex.logo)
	f.logo:SetSize(L, L)
	f.logo:SetPoint("LEFT", 0, 0)
	f.word = f:CreateTexture(nil, "ARTWORK")
	f.word:SetTexture(self.tex.wordmark)
	f.word:SetTexCoord(0, 0.75, 0, 1)
	f.word:SetSize(h * 3, h)
	f.word:SetPoint("LEFT", f.logo, "RIGHT", gap, 0)
	local c = uiColor or self.c.muted
	f.ui = self:Text(f, self.font.latin, math.floor(h * 0.95 + 0.5), c, "LEFT")
	f.ui:SetPoint("LEFT", f.word, "RIGHT", gap, 0)
	f.ui:SetText("UI")
	f:SetSize(L + gap + h * 3 + gap + h * 1.2, L)
	return f, f.ui
end

function Ink:Module(name)
	local m = { name = name }
	table.insert(self.modules, m)
	self.modules[name] = m
	return m
end

-- 오류 기록 (SavedVariables 에 최근 30개 저장 → /reload 후 파일에서 확인 가능)
function Ink:LogError(msg)
	if not Ink.db then return end
	Ink.db.errors = Ink.db.errors or {}
	table.insert(Ink.db.errors, date("%m-%d %H:%M:%S") .. " " .. tostring(msg))
	while #Ink.db.errors > 30 do table.remove(Ink.db.errors, 1) end
end

local function callAll(method, ...)
	for _, m in ipairs(Ink.modules) do
		if m[method] then
			local ok, err = pcall(m[method], m, ...)
			if not ok then
				print("|cffFF6B5EFOA|r " .. m.name .. "." .. method .. ": " .. tostring(err))
				Ink:LogError(m.name .. "." .. method .. ": " .. tostring(err))
			end
		end
	end
end
Ink.CallAll = callAll

function Ink:Relayout()
	if InCombatLockdown() then
		self.pendingLayout = true
		return
	end
	self.pendingLayout = nil
	self:UpdateScale()
	callAll("Layout")
	for _, key in ipairs(self.moverOrder) do self:ApplyPos(key) end
	callAll("PostLayout")
end

local defaults = {
	party = true,
	raid = true,
	xp = true,
	plates = true,
	bags = true,
	charSheet = true,
	windows = false,
	launcher = true,
	sellJunk = true,
	autoRepair = true,
	guildRepair = true,
	meter = true,
	threat = true,
	bossMod = true,
	npcIcons = true,
	hideTutorials = true,
}

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		-- 원인 추적용: InkUI 때문에 막힌 동작이 있으면 어떤 함수인지 남긴다
		if arg1 == ADDON then
			Ink.blocked = Ink.blocked or {}
			table.insert(Ink.blocked, (arg2 or "?") .. " · " .. date("%H:%M:%S") .. (InCombatLockdown() and " (전투 중)" or ""))
			-- 같은 동작은 30초에 한 번만 알린다 (채팅창 도배 방지)
			Ink.blockedSaid = Ink.blockedSaid or {}
			local key, now = tostring(arg2), GetTime()
			if not Ink.blockedSaid[key] or now - Ink.blockedSaid[key] > 30 then
				Ink.blockedSaid[key] = now
				print("|cffFF6B5EFOA|r 막힌 동작: " .. key .. "  (/foa log 로 기록 보기)")
			end
		end
		return
	end
	if event == "ADDON_LOADED" then
		Ink:ApplyDamageFont()
		return
	end
	if event == "PLAYER_LOGIN" then
		Ink:ApplyDamageFont()
		InkUIDB = InkUIDB or {}
		Ink.db = InkUIDB
		Ink.db.pos = Ink.db.pos or {}
		-- 캐릭터별 배치 (편집 모드 위치 · 가방 위치)
		--  처음 접속한 캐릭터는 마지막으로 편집한 배치를 복사해서 시작한다
		InkUICharDB = InkUICharDB or {}
		Ink.cdb = InkUICharDB
		if not Ink.cdb.pos then
			Ink.cdb.pos = CopyTable(Ink.db.pos)
			if Ink.db.bagPos then Ink.cdb.bagPos = CopyTable(Ink.db.bagPos) end
		end
		for k, v in pairs(defaults) do
			if Ink.db[k] == nil then Ink.db[k] = v end
		end
		Ink:UpdateScale()
		callAll("Init")
		if EditModeManagerFrame then
			hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
				C_Timer.After(0.2, function() Ink:Relayout() end)
			end)
		end
		print("|T" .. Ink.tex.logo .. ":14:14|t |cffFFF468FOA|r " .. Ink.version .. " 로드됨 · /foa 로 설정 열기")
	elseif event == "PLAYER_ENTERING_WORLD" then
		Ink:Relayout()
		C_Timer.After(1, function() Ink:Relayout() end)
		callAll("Refresh")
	elseif event == "PLAYER_REGEN_ENABLED" then
		for f, keep in pairs(pendingDisable) do
			pendingDisable[f] = nil
			if f.inkDisabled then
				f.inkReparenting = true
				f:SetParent(hiddenParent)
				f.inkReparenting = nil
			else
				Ink:Disable(f, keep)
			end
		end
		if Ink.pendingScale or Ink.pendingLayout then Ink:Relayout() end
		callAll("CombatEnd")
	elseif event == "PLAYER_REGEN_DISABLED" then
		callAll("CombatStart")
	else
		C_Timer.After(0.3, function() Ink:Relayout() end)
	end
end)
