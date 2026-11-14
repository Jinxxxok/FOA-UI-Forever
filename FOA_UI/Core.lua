-- InkUI · Core
-- 모든 좌표는 1920x1080 시안 기준 픽셀. 루트 프레임을 화면 높이 1080 단위로 스케일해서 그대로 사용한다.

local ADDON, ns = ...
local Ink = {}
ns.Ink = Ink
_G.InkUI = Ink
Ink.version = "0.65.48"

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

-------------------------------------------------------------------------------
-- 글꼴 묶음 (설정 → 글꼴). 바꾸면 /reload.
--  foa        : 기본 (Plex 한글 + Inter + Space Grotesk 숫자)
--  pretendard : 선명한 글꼴. 획이 굵고 작은 크기에서도 덜 뭉개져서 1080p·1440p 윈도우에 권장
--  mubig      : 무빅UI 글꼴. 숫자·영문 = Y 스포트라이트 (KT 무료 글꼴, 같이 넣음)
--               한글 = 게임 기본 글꼴 자리(Fonts\2002.ttf). 무빅UI 를 설치하면 그 자리가
--               세방고딕으로 바뀌어 있어서 무빅UI 와 똑같이 보인다. (세방고딕은 재배포가 금지라 FOA 에 못 넣음)
--               AddOns\FOA_Fonts\MUBIG.ttf 가 있으면 한글은 그 파일을 쓴다.
-- 모듈들이 Ink.font 표를 그대로 들고 있으므로 표 안의 값만 바꾼다 (모듈 Init 전에).
-------------------------------------------------------------------------------
local PRET = MEDIA .. "Fonts\\Pretendard-"
local USER = "Interface\\AddOns\\FOA_Fonts\\"
Ink.FONT_SETS = { "foa", "pretendard", "mubig" }
Ink.FONT_NAME = { foa = "FOA 기본", pretendard = "선명한 글꼴", mubig = "무빅UI 글꼴" }

local probe
-- 글꼴 파일이 실제로 있는지 (없는 파일은 SetFont 가 실패한다)
function Ink:FontExists(path)
	if not probe then
		local holder = CreateFrame("Frame")
		probe = holder:CreateFontString(nil, "OVERLAY")
	end
	probe:SetFont(F.sans, 12, "")
	local ok = probe:SetFont(path, 12, "")
	if ok == false then return false end
	local cur = probe:GetFont()
	return cur ~= nil and cur:lower() == path:lower()
end

-- 사용자가 넣은 글꼴 찾기: FOA_Fonts 폴더 (업데이트해도 안 지워짐) → FOA_UI\Media\Fonts (업데이트하면 지워짐)
local USER_DIRS = { USER, MEDIA .. "Fonts\\" }
function Ink:FindUserFont(...)
	for _, dir in ipairs(USER_DIRS) do
		for i = 1, select("#", ...) do
			local base = select(i, ...)
			for _, ext in ipairs({ ".ttf", ".otf", ".TTF", ".OTF" }) do
				local p = dir .. base .. ext
				if self:FontExists(p) then return p end
			end
		end
	end
end

-- 기본값을 기억해 두고 묶음에 따라 덮어쓴다
local FONT_BASE = {}
for k, v in pairs(F) do FONT_BASE[k] = v end

function Ink:ApplyFontSet()
	for k, v in pairs(FONT_BASE) do F[k] = v end
	local set = self.db and self.db.fontSet or "foa"
	self.fontSetActive = "foa"
	if set == "pretendard" then
		F.sans = PRET .. "Medium.ttf"
		F.semi = PRET .. "SemiBold.ttf"
		F.bold = PRET .. "Bold.ttf"
		F.num = PRET .. "Regular.ttf"
		F.numR = PRET .. "Medium.ttf"
		F.latin = PRET .. "Medium.ttf"
		F.latinB = PRET .. "SemiBold.ttf"
		self.fontSetActive = "pretendard"
	elseif set == "mubig" then
		local ys = MEDIA .. "Fonts\\YSpotlight.ttf"
		-- 한글: 직접 넣은 무빅 · 세방고딕 파일 → 게임 Fonts 폴더의 2002 (무빅UI를 깔았으면 세방고딕)
		local kr = self:FindUserFont("MUBIG", "2002", "SEBANG Gothic Bold", "SEBANGGothicBold", "SebangGothicBold", "세방고딕")
		self.mubigFile = kr
		if not kr and self:FontExists("Fonts\\2002.ttf") then kr = "Fonts\\2002.ttf" end
		kr = kr or ys
		local krB = self:FindUserFont("MUBIG-Bold", "2002b", "2002B") or (kr == "Fonts\\2002.ttf" and self:FontExists("Fonts\\2002B.ttf") and "Fonts\\2002B.ttf") or kr
		F.sans, F.semi, F.bold = kr, krB, krB
		F.num, F.numR, F.latin, F.latinB = ys, ys, ys, ys
		self.fontSetActive = "mubig"
	end
	-- 저해상도: 아주 가는 숫자 글꼴(Light)은 작은 크기에서 뭉개지므로 Regular 로
	if self.fontSetActive == "foa" and self.lowRes then
		F.num = FONT_BASE.numR
	end
	-- 블리자드 위젯용 글꼴 오브젝트도 새 글꼴로
	if self.fo then
		for _, spec in pairs(self.foSpec or {}) do
			spec.obj:SetFont(F[spec.key], spec.size, spec.flags or "")
		end
	end
	self.damageFont = F.semi
	-- 무빅UI 는 머리 위 숫자도 게임 기본 자리(K_Damage)를 바꿔 쓰므로 그 자리를 그대로 쓴다
	if self.fontSetActive == "mubig" and self:FontExists("Fonts\\K_Damage.ttf") then self.damageFont = "Fonts\\K_Damage.ttf" end
	DAMAGE_TEXT_FONT = self.damageFont
end

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
-------------------------------------------------------------------------------
-- 화면 선명도: 모니터 실제 세로 픽셀로 "저해상도"인지 본다
--  FOA 1칸 = 실제 픽셀 (세로 픽셀 / 1080). 4K = 2픽셀, 1080p = 1픽셀.
--  저해상도에서는 작은 아이콘을 32px 전용 이미지로 바꾸고(덜 뭉개짐), 작은 글자를 한 단계 키운다.
-------------------------------------------------------------------------------
function Ink:DetectDensity()
	local ph = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize()) or 1080
	self.physH = ph
	self.lowRes = ph < 1700          -- 1080p / 1200p / 1440p / 1600p
	-- 작은 글자 키우기: 1080p·1200p 는 +1 (10 이하는 +2), 1440p·1600p 는 11 이하만 +1
	self.fontBoost = (ph < 1300) and 1 or 0
	self.fontBoostSmall = (ph < 1300) and 2 or (ph < 1700 and 1 or 0)
	-- FOA 1칸 = 몇 픽셀인지. 1080p = 1, 4K = 2 (딱 떨어져서 선명), QHD 1440p = 1.333 (소수라 번진다)
	local k = ph / 1080
	self.pxPerUnit = k
	self.px = 1 / k                    -- 실제 화면 1픽셀 = FOA 몇 칸
	-- 선명 렌더: 1칸이 정수 픽셀로 안 떨어지는 화면 (1200p · 1440p · 1600p)
	--  · 아이콘/원/둥근 모서리를 그 해상도에 맞춰 따로 그린 이미지(_q)로
	--  · 둥근 모서리는 이미지 1점 = 화면 1픽셀이 되게 축소해서 그린다
	--  · 모든 FOA 이미지를 화면 픽셀 격자에 붙이고, 1칸짜리 선은 정확히 1픽셀로
	--  설정 → 화면 선명도: 자동 / 1080p / QHD / 4K (자동이면 모니터 세로 픽셀로 고른다)
	local frac = math.abs(k - math.floor(k + 0.5)) > 0.03
	self.autoTier = (ph >= 1700) and "2x" or (frac and "q" or "1x")
	local mode = self.db and self.db.renderMode or "auto"
	self.renderTier = (mode == "1x" or mode == "q" or mode == "2x") and mode or self.autoTier
	self.crisp = self.renderTier == "q"
	local sfx = (self.renderTier == "q" and "_q") or (self.renderTier == "1x" and "_s") or ""
	self.tex.ring = MEDIA .. "Textures\\Ring" .. sfx
	self.tex.disc = MEDIA .. "Textures\\Disc" .. sfx
	-- 1080p · 1200p: 픽셀이 커서 회색 글자가 배경에 묻힌다 → 회색을 밝히고 그림자를 진하게
	if self.c and self.LowResPalette then self:LowResPalette(ph < 1300) end
end
Ink.icon = function(name)
	local t = Ink.renderTier
	return MEDIA .. "Icons\\" .. name .. ((t == "q" and "_q") or (t == "1x" and "_s") or "")
end

-- 화면 픽셀 단위로 맞춘 두께 (1칸 선 → 정확히 1픽셀)
function Ink:Px(size)
	if not self.crisp then return size end
	local n = math.max(1, math.floor(size * self.pxPerUnit + 0.5))
	return n * self.px
end

-- 선명 렌더: 프레임 아래 모든 이미지를 픽셀 격자에 붙이고, 1칸 두께 선은 1픽셀로
local crispDone = setmetatable({}, { __mode = "k" })
local function CrispRegion(r)
	if not crispDone[r] then
		crispDone[r] = true
		if r.SetSnapToPixelGrid then
			r:SetSnapToPixelGrid(true)
			r:SetTexelSnappingBias(0)
		end
	end
	if r.inkRoundScaled then return end
	local w, h = r:GetSize()
	local one = (h and math.abs(h - 1) < 0.01 and w and w > 2) and "h" or ((w and math.abs(w - 1) < 0.01 and h and h > 2) and "w")
	if not one then return end
	-- 이 이미지가 화면에서 1칸 = 몇 픽셀인지 (네임플레이트는 배율이 따로라 각자 계산)
	local ppu = r:GetEffectiveScale() * (Ink.physH or 1080) / 768
	if ppu <= 0 or math.abs(ppu - math.floor(ppu + 0.5)) < 0.03 then return end
	local u = math.max(1, math.floor(ppu + 0.5)) / ppu
	if one == "h" then r:SetHeight(u) else r:SetWidth(u) end
end
local function CrispWalk(f, depth)
	if depth > 40 then return end
	for _, r in ipairs({ f:GetRegions() }) do
		if r.IsObjectType and r:IsObjectType("Texture") then CrispRegion(r) end
	end
	for _, c in ipairs({ f:GetChildren() }) do CrispWalk(c, depth + 1) end
end
function Ink:CrispTree(f)
	if not self.crisp or not f or not f.GetRegions then return end
	pcall(CrispWalk, f, 0)
end
function Ink:CrispAll()
	if not self.crisp then return end
	self:CrispTree(self.root)
	for _, n in ipairs({ "FOADungeonLoot", "FOABisPanel", "FOAVignette" }) do self:CrispTree(_G[n]) end
end
pcall(Ink.DetectDensity, Ink)

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

-- 저해상도용 회색 (색 표는 여러 곳에서 같은 표를 들고 있으니 값만 바꾼다)
local PALETTE_LOW = { muted = hex("A6ABB3"), soft = hex("CACED4"), dim = hex("7C818A") }
local PALETTE_BASE = {}
Ink.shadowA = 0.75
function Ink:LowResPalette(on)
	for k, v in pairs(PALETTE_LOW) do
		local c = self.c[k]
		if not PALETTE_BASE[k] then PALETTE_BASE[k] = { c[1], c[2], c[3] } end
		local src = on and v or PALETTE_BASE[k]
		c[1], c[2], c[3] = src[1], src[2], src[3]
	end
	self.shadowA = on and 1 or 0.75
end

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
Ink.foSpec = {
	{ obj = Ink.fo.auraTimer, key = "sans", size = 9 },
	{ obj = Ink.fo.cdNumber, key = "semi", size = 12, flags = "OUTLINE" },
	{ obj = Ink.fo.cdNumberSmall, key = "semi", size = 10, flags = "OUTLINE" },
	{ obj = Ink.fo.cdTimer, key = "semi", size = 10 },
}

-------------------------------------------------------------------------------
-- 위젯 헬퍼
-------------------------------------------------------------------------------
function Ink:BoostSize(size)
	if not size then return size end
	if size <= 10 and (self.fontBoostSmall or 0) > 0 then return size + self.fontBoostSmall end
	if size <= 11 and self.lowRes and (self.fontBoostSmall or 0) > 0 then return size + 1 end
	if size <= 13 and (self.fontBoost or 0) > 0 then return size + self.fontBoost end
	return size
end

function Ink:Text(parent, font, size, color, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	-- 저해상도(1080p)에서 아주 작은 글자는 한 단계 키워서 뭉개짐을 줄인다
	size = self:BoostSize(size)
	fs:SetFont(font, size, "")
	color = color or Ink.c.text
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetJustifyV("MIDDLE")
	fs:SetWordWrap(false)
	fs:SetShadowColor(0, 0, 0, self.shadowA or 0.75)
	fs:SetShadowOffset(1, -1)
	-- 줄바꿈 글자는 낱말 단위로 미리 끊는다 (게임은 한글을 글자 중간에서 끊어서 "상\n인"처럼 보이기 때문)
	local set = fs.SetText
	fs.SetText = function(f, t, ...)
		-- 비공개 값(이름 · 체력 등)은 절대 건드리지 않고, 줄바꿈 칸일 때만 · 실패하면 원래 글자 그대로
		if type(t) == "string" and f:CanWordWrap() and not (issecretvalue and issecretvalue(t)) then
			local ok, w = pcall(Ink.WrapFor, Ink, f, t)
			if ok and type(w) == "string" then t = w end
		end
		return set(f, t, ...)
	end
	return fs
end

-- 글자 폭을 재서 낱말(띄어쓰기) 단위로 줄을 나눈다. 한 낱말이 칸보다 길 때만 게임이 알아서 끊게 둔다
local wrapProbe
function Ink:WrapFor(fs, text)
	if not (fs.CanWordWrap and fs:CanWordWrap()) or #text <= 10 then return text end
	if not text:find(" ", 1, true) then return text end
	local W = fs:GetWidth()
	if not W or W <= 20 then return text end
	if not wrapProbe then
		local holder = CreateFrame("Frame")
		holder:Hide()
		wrapProbe = holder:CreateFontString(nil, "OVERLAY")
	end
	local font, size, flags = fs:GetFont()
	if not font then return text end
	wrapProbe:SetFont(font, size, flags or "")
	local function width(s) wrapProbe:SetText(s); return wrapProbe:GetStringWidth() or 0 end
	if width((text:gsub("\n", " "))) <= W then return text end
	local out = {}
	for para in (text .. "\n"):gmatch("(.-)\n") do
		local line
		for word in para:gmatch("%S+") do
			if not line then line = word
			else
				local cand = line .. " " .. word
				if width(cand) <= W - 1 then line = cand else out[#out + 1] = line; line = word end
			end
		end
		out[#out + 1] = line or ""
	end
	return table.concat(out, "\n")
end

-- 툴팁 줄: 너무 길면 낱말 단위로 미리 나눠서 (한글 기준 약 n글자) 깔끔하게
local function DispLen(s)
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "  ")
	local n = 0
	for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + ((#ch > 1) and 1 or 0.55) end
	return n
end
function Ink.TipWrap(text, n)
	if type(text) ~= "string" then return text end
	n = n or 30
	local out = {}
	for para in (text .. "\n"):gmatch("(.-)\n") do
		local line
		for word in para:gmatch("%S+") do
			if not line then line = word
			elseif DispLen(line .. " " .. word) <= n then line = line .. " " .. word
			else out[#out + 1] = line; line = word end
		end
		out[#out + 1] = line or ""
	end
	return table.concat(out, "\n")
end
function Ink.TipLine(tt, text, r, g, b)
	tt:AddLine(Ink.TipWrap(text), r, g, b)
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
	if Ink.crisp and t.SetScale then
		-- 선명 렌더: 이 해상도용으로 그린 모서리(_q)를 이미지 1점 = 화면 1픽셀로 그린다.
		-- 텍스처를 1/배율로 줄였으니 크기를 줄 때는 배율만큼 늘려서 넘긴다.
		t:SetTexture(file .. "_q")
		t:SetScale(Ink.px)
		t.inkRoundScaled = true
		local k = Ink.pxPerUnit
		local setSize, setW, setH = t.SetSize, t.SetWidth, t.SetHeight
		t.SetSize = function(self, w, h) setSize(self, w * k, (h or w) * k) end
		t.SetWidth = function(self, w) setW(self, w * k) end
		t.SetHeight = function(self, h) setH(self, h * k) end
		if t.SetTextureSliceMargins then
			local m = small and 7 or 11
			t:SetTextureSliceMargins(m, m, m, m)
			if Enum.UITextureSliceMode then t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
		end
		return t
	end
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
	size = self:Px(size or 1)
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
	self:SelectLayout()
end

-------------------------------------------------------------------------------
-- 화면 비율별 배치
--  높이는 항상 1080 기준. 가로는 비율에 따라 늘어난다 (16:9 = 1920, 21:9 ≈ 2520 …)
--  위치는 "왼쪽 가장자리 / 오른쪽 가장자리 / 가운데" 중 가까운 쪽에 붙여 저장하므로
--  다른 비율에서도 자연스럽게 따라간다. 32:9 는 양옆이 너무 멀어서 가운데 21:9 폭 안에 모은다.
-------------------------------------------------------------------------------
Ink.ASPECTS = { "16:10", "16:9", "21:9", "32:9" }
Ink.ASPECT_NAME = { ["16:10"] = "16:10 (맥북)", ["16:9"] = "16:9", ["21:9"] = "21:9 울트라와이드", ["32:9"] = "32:9 슈퍼 울트라와이드" }

function Ink:DetectAspect()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local r = (w and h and h > 0) and w / h or 16 / 9
	if r < 1.7 then return "16:10" end
	if r < 2.05 then return "16:9" end
	if r < 2.8 then return "21:9" end
	return "32:9"
end

-- 지금 쓰는 비율 (설정에서 고른 것, "자동"이면 화면에서 알아낸 것)
function Ink:ActiveAspect()
	local mode = self.cdb and self.cdb.aspect
	if mode and mode ~= "auto" then return mode end
	return self:DetectAspect()
end

-- 32:9 처럼 아주 넓은 화면은 가장자리 요소를 가운데 21:9 폭 안으로 모은다
local SAFE_W = { ["32:9"] = 1080 * 21 / 9 }
local function EdgeInset()
	local rw = root:GetWidth()
	local safe = SAFE_W[Ink.activeAspect or "16:9"]
	if not (rw and safe) or rw <= safe then return 0 end
	return (rw - safe) / 2
end
Ink.EdgeInset = EdgeInset

-------------------------------------------------------------------------------
-- 배치 공유 · 프리셋
--  배치 = 요소 위치(비율별) + 크기 + 행동단축바 설정 + 가방 위치 + 화면 비율
--  "모든 캐릭터 같은 배치"를 켜면 편집 모드를 마칠 때 계정 공용 배치에 저장하고,
--  다른 캐릭터는 접속할 때 공용 배치가 바뀌었으면 받아온다.
-------------------------------------------------------------------------------
function Ink:SnapshotLayout()
	local c = self.cdb
	if not c then return end
	local bars = c.bars and CopyTable(c.bars) or nil
	if bars then bars.blizzSeen = nil; bars.noAdopt = nil end
	return {
		layouts = CopyTable(c.layouts or {}),
		sizes = CopyTable(c.sizes or {}),
		bars = bars,
		bagPos = c.bagPos and CopyTable(c.bagPos) or nil,
		aspect = c.aspect,
		from = UnitName("player"),
		at = time(),
	}
end

function Ink:ApplyLayoutData(d)
	local c = self.cdb
	if not (c and d) then return end
	c.layouts = CopyTable(d.layouts or {})
	c.sizes = CopyTable(d.sizes or {})
	if d.bars then
		c.bars = CopyTable(d.bars)
		c.bars.blizzSeen = nil
		c.bars.noAdopt = true      -- 블리자드 설정의 단축바 켜기가 받아온 배치를 바꾸지 않게
		c.barsImported = true
		c.barsFix1, c.barsSizeFix = true, true
	end
	c.bagPos = d.bagPos and CopyTable(d.bagPos) or nil
	c.aspect = d.aspect
end

-- 지금 캐릭터 배치를 공용 배치로 올린다
function Ink:PushShared()
	if not (self.db and self.db.layoutShared) then return end
	local snap = self:SnapshotLayout()
	if not snap then return end
	snap.stamp = ((self.db.sharedLayout and self.db.sharedLayout.stamp) or 0) + 1
	self.db.sharedLayout = snap
	self.cdb.sharedStamp = snap.stamp
end

-- 접속할 때: 공용 배치가 이 캐릭터가 마지막으로 받은 것보다 새로우면 받아온다
function Ink:PullShared()
	local sh = self.db and self.db.layoutShared and self.db.sharedLayout
	if not sh or self.cdb.sharedStamp == sh.stamp then return end
	self:ApplyLayoutData(sh)
	self.cdb.sharedStamp = sh.stamp
end

function Ink:SelectLayout()
	if not self.cdb then return end
	local key = self:ActiveAspect()
	self.activeAspect = key
	self.cdb.layouts = self.cdb.layouts or {}
	self.cdb.layouts[key] = self.cdb.layouts[key] or {}
	self.pos = self.cdb.layouts[key]
end

-- 다른 비율에 저장된 위치가 없으면 16:9(기본) 위치를 빌려 쓴다 (가장자리 기준이라 그대로 맞는다)
function Ink:GetPos(key)
	local p = self.pos and self.pos[key]
	if p then return p end
	local base = self.cdb and self.cdb.layouts and self.cdb.layouts["16:9"]
	return base and base[key]
end

local function placeRaw(f, mode, x, y, scale)
	f:ClearAllPoints()
	local s = scale or 1
	local inset = EdgeInset()
	if mode == "left" or mode == "l" then
		f:SetPoint("TOPLEFT", root, "TOPLEFT", (inset + x) / s, -y / s)
	elseif mode == "right" or mode == "r" then
		f:SetPoint("TOPRIGHT", root, "TOPRIGHT", -(inset + x) / s, -y / s)
	elseif mode == "bottomleft" then
		f:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", (inset + x) / s, y / s)
	elseif mode == "bottomright" then
		f:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -(inset + x) / s, y / s)
	else
		f:SetPoint("TOPLEFT", root, "TOP", (x - 960) / s, -y / s)
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

-- 편집 모드 목록에서 빼기 (닫은 미터기 창 등)
function Ink:RemoveMovable(key)
	if not self.movers[key] then return end
	self.movers[key] = nil
	for i, k in ipairs(self.moverOrder) do
		if k == key then table.remove(self.moverOrder, i) break end
	end
	local cfg = self.modules.Config
	local o = cfg and cfg.overlays and cfg.overlays[key]
	if o then o:Hide(); cfg.overlays[key] = nil end
	if cfg and cfg.sel == key then cfg.sel = nil end
end

-- 창 크기 (편집 모드에서 끌어서 바꾼 크기 · 캐릭터별)
function Ink:GetSize(key, w, h)
	local t = self.cdb and self.cdb.sizes and self.cdb.sizes[key]
	if t then return t[1] or w, t[2] or h end
	return w, h
end

function Ink:SaveSize(key, w, h)
	if not self.cdb then return end
	self.cdb.sizes = self.cdb.sizes or {}
	self.cdb.sizes[key] = (w and h) and { math.floor(w + 0.5), math.floor(h + 0.5) } or nil
end

-- 크기 조절이 되는 요소인가 (블리자드 프레임을 붙이는 투명 앵커는 크기 조절 안 함)
function Ink:CanScale(key)
	local m = self.movers[key]
	return m and m.frame and not m.frame.inkAnchor and not m.noScale
end

-- 예전 형식(가운데 기준 x)을 가장자리 기준으로 바꾼다 (1920 시안 기준 왼쪽/가운데/오른쪽 3등분)
local function Convert(p, w)
	if p.a then return p end
	w = w or 0
	local cx = p.x + w / 2
	if cx < 640 then
		p.a = "l"
	elseif cx > 1280 then
		p.a, p.x = "r", math.floor(1920 - (p.x + w) + 0.5)
	else
		p.a = "c"
	end
	return p
end

function Ink:ApplyPos(key)
	local m = self.movers[key]
	if not m or not m.frame then return end
	if m.frame:IsProtected() and InCombatLockdown() then return end
	local p = self:GetPos(key)
	local s = (p and p.s and self:CanScale(key)) and p.s or 1
	if self:CanScale(key) and math.abs((m.frame:GetScale() or 1) - s) > 0.001 then
		pcall(m.frame.SetScale, m.frame, s)
	end
	if p then
		Convert(p, (m.w or m.frame:GetWidth() or 0) * s)
		placeRaw(m.frame, p.a, p.x, p.y, s)
	else
		placeRaw(m.frame, m.mode, m.x, m.y, s)
	end
end

-- 지금 위치를 화면 기준(시안 좌표)으로: 왼쪽 위 x, y / 너비, 높이
function Ink:FrameBox(key)
	local m = self.movers[key]
	if not m then return end
	local f = m.frame
	local l, t, r = f:GetLeft(), f:GetTop(), f:GetRight()
	local rl, rt = root:GetLeft(), root:GetTop()
	if not (l and t and r and rl and rt) then return end
	local k = f:GetEffectiveScale() / root:GetEffectiveScale()
	local w = m.w and m.w * (f:GetScale() or 1) or (r - l) * k
	return l * k - rl, rt - t * k, w
end

-- 현재 프레임 위치를 저장: 화면 3등분 중 어디에 있느냐에 따라 왼쪽 / 가운데 / 오른쪽 기준
function Ink:SavePos(key)
	local m = self.movers[key]
	if not m then return end
	local lx, y, w = self:FrameBox(key)
	if not lx then return end
	local rw = root:GetWidth()
	local inset = EdgeInset()
	local refW = rw - inset * 2
	local cx = lx + w / 2 - inset
	local old = self.pos and self.pos[key]
	local v = { y = math.floor(y + 0.5), s = old and old.s or (self:GetPos(key) or {}).s }
	if cx < refW / 3 then
		v.a, v.x = "l", math.floor(lx - inset + 0.5)
	elseif cx > refW * 2 / 3 then
		v.a, v.x = "r", math.floor(rw - inset - (lx + w) + 0.5)
	else
		v.a, v.x = "c", math.floor(lx - rw / 2 + 960 + 0.5)
	end
	self.pos[key] = v
	-- 계정에도 남겨서 새 캐릭터가 처음 접속할 때 이어받는다
	local aspect = self.activeAspect or "16:9"
	self.db.layouts = self.db.layouts or {}
	self.db.layouts[aspect] = self.db.layouts[aspect] or {}
	self.db.layouts[aspect][key] = CopyTable(v)
end

-- 크기(배율) 저장
function Ink:SetMoverScale(key, s)
	if not self:CanScale(key) then return end
	s = math.max(0.5, math.min(2, math.floor(s * 100 + 0.5) / 100))
	local p = self:GetPos(key)
	if not (self.pos and self.pos[key]) then
		self:SavePos(key)
	end
	p = self.pos[key]
	if p then p.s = s end
	self:ApplyPos(key)
	self:SavePos(key)
end

-- 위치 초기화는 지금 캐릭터 · 지금 비율만
function Ink:ResetPos(key)
	if not self.pos then return end
	if key then self.pos[key] = nil else wipe(self.pos) end
	if not key then self.cdb.bagPos = nil end
end

-- 비율 바꾸기 ("auto" / "16:10" / "16:9" / "21:9" / "32:9")
function Ink:SetAspect(mode)
	if InCombatLockdown() then return end
	self.cdb.aspect = mode
	self:Relayout()
end

-- 블리자드 프레임을 붙일 투명 앵커
function Ink:Anchor(w, h)
	local a = CreateFrame("Frame", nil, root)
	a:SetSize(w, h)
	a.inkAnchor = true
	return a
end

-- 블리자드 프레임을 앵커에 맞춘다 (스케일 차이를 보정해서 크기도 맞춤)
-- 성능 측정: 무거울 수 있는 처리마다 걸린 시간을 모아 둔다 (/foa perf)
--  debugprofilestop 는 밀리초 단위 타이머라 거의 공짜. 측정 결과는 /foa perf 로 보고 지운다
Ink.perf = {}
function Ink.Prof(name, fn, ...)
	local t0 = debugprofilestop and debugprofilestop()
	local ok, a, b, c = pcall(fn, ...)
	if t0 then
		local dt = debugprofilestop() - t0
		local p = Ink.perf[name]
		if not p then p = { n = 0, total = 0, max = 0, combat = 0 }; Ink.perf[name] = p end
		p.n, p.total = p.n + 1, p.total + dt
		if dt > p.max then p.max = dt end
		if InCombatLockdown() then p.combat = p.combat + dt end
	end
	if not ok and Ink.LogError then Ink:LogError(name .. ": " .. tostring(a)) end
	return a, b, c
end

-- 틀의 이벤트 · 매 프레임 처리를 측정으로 감싼다 (이미 걸린 스크립트를 감싸므로 SetScript 뒤에 부른다)
function Ink.ProfFrame(f, name)
	if not f then return end
	for _, kind in ipairs({ "OnEvent", "OnUpdate" }) do
		local h = f:GetScript(kind)
		if h then
			local label = name .. (kind == "OnUpdate" and " (반복)" or "")
			f:SetScript(kind, function(...) Ink.Prof(label, h, ...) end)
		end
	end
end

-- 확인 창 (FOA 모양): 블리자드 StaticPopup 을 애드온 코드로 띄우면 그 창이 오염돼서
--  나중에 같은 창을 쓰는 블리자드 확인(은행 칸 사기 등)이 "FOA_UI 가 차단되었습니다"로 막힌다 → 우리 창을 따로 쓴다
function Ink:Confirm(title, sub, okText, onOK, danger)
	local a = self.confirmBox
	if not a then
		a = CreateFrame("Frame", "FOAConfirm", Ink.root)
		a:SetSize(340, 96)
		a:SetFrameStrata("DIALOG")
		a:EnableMouse(true)
		a:Hide()
		a.bg = Ink:Round(a, "BACKGROUND", false, false)
		a.bg:SetAllPoints()
		a.bg:SetVertexColor(0.04, 0.045, 0.06, 0.97)
		a.bd = Ink:Round(a, "BORDER", false, true)
		a.bd:SetAllPoints()
		a.title = Ink:Text(a, Ink.font.semi, 13, Ink.c.text, "LEFT")
		a.title:SetPoint("TOPLEFT", 16, -14)
		a.title:SetWidth(308)
		a.sub = Ink:Text(a, Ink.font.sans, 11, Ink.c.muted, "LEFT")
		a.sub:SetPoint("TOPLEFT", a.title, "BOTTOMLEFT", 0, -5)
		a.sub:SetWidth(308)
		local function btn(primary)
			local b = CreateFrame("Button", nil, a)
			b:SetSize(96, 26)
			b.bg = Ink:Round(b, "BACKGROUND", true, false)
			b.bg:SetAllPoints()
			b.t = Ink:Text(b, Ink.font.semi, 12, Ink.c.soft, "CENTER")
			b.t:SetPoint("CENTER")
			b.primary = primary
			b.paint = function(hot)
				if b.primary then
					local c = a.danger and Ink.c.red or Ink.c.accent
					b.bg:SetVertexColor(c[1], c[2], c[3], hot and 1 or 0.88)
					b.t:SetTextColor(0.067, 0.075, 0.094)
				else
					b.bg:SetVertexColor(1, 1, 1, hot and 0.1 or 0.05)
				end
			end
			b:SetScript("OnEnter", function() b.paint(true) end)
			b:SetScript("OnLeave", function() b.paint(false) end)
			return b
		end
		a.yes = btn(true)
		a.yes:SetPoint("BOTTOMRIGHT", -12, 12)
		a.yes:SetScript("OnClick", function() a:Hide(); if a.onOK then pcall(a.onOK) end end)
		a.no = btn(false)
		a.no:SetPoint("RIGHT", a.yes, "LEFT", -6, 0)
		a.no.t:SetText("취소")
		a.no:SetScript("OnClick", function() a:Hide() end)
		-- 30초 동안 답이 없으면 닫는다 (키보드는 잡지 않는다: 전투 중 이동 키를 먹지 않게)
		a:SetScript("OnShow", function(self)
			if self.timer then self.timer:Cancel() end
			self.timer = C_Timer.NewTimer and C_Timer.NewTimer(30, function() self:Hide() end)
		end)
		self.confirmBox = a
	end
	a.danger, a.onOK = danger, onOK
	a.title:SetText(title or "")
	a.sub:SetText(sub or "")
	a.yes.t:SetText(okText or "확인")
	local c = danger and Ink.c.red or Ink.c.accent
	a.bd:SetVertexColor(c[1], c[2], c[3], 0.5)
	a.yes.paint(false); a.no.paint(false)
	a:SetHeight(math.max(96, 70 + (a.sub:GetStringHeight() or 14)))
	a:ClearAllPoints()
	a:SetPoint("TOP", Ink.root, "TOP", 0, -180)
	a:Show()
	return a
end

-- 세계 지도 열기 (원하는 지역으로)
--  애드온 코드에서 WorldMapFrame:SetMapID · OpenWorldMap · 퀘스트 상세 열기를 바로 부르면 그때 만들어지는
--  지도 표시(핀)가 전부 FOA 로 오염돼서, 나중에 전투 중 지도가 핀을 다시 쓸 때
--  SetPassThroughButtons · SetPropagateMouseClicks 가 막혔다.
--  C_Map.OpenWorldMap 은 게임이 직접 "지도 열기" 이벤트를 보내 블리자드 코드가 깨끗한 상태로 열어 준다.
function Ink:OpenMap(mapID)
	if not mapID then return end
	if C_Map and C_Map.OpenWorldMap then
		return pcall(C_Map.OpenWorldMap, mapID)
	end
	-- 옛 클라이언트: 전투 중에는 열지 않는다 (오염된 핀이 전투 중에 막히지 않게)
	if InCombatLockdown() then return end
	if OpenWorldMap then return pcall(OpenWorldMap, mapID) end
end

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
-- 끈 블리자드 틀 기록은 FOA 안쪽 표에만 (블리자드 틀에 값을 써 넣으면 그 틀을 읽는 블리자드 코드가 오염된다)
local inkDisabled = setmetatable({}, { __mode = "k" })
local inkReparenting = setmetatable({}, { __mode = "k" })
function Ink:Disable(frame, keepEvents)
	if type(frame) == "string" then frame = _G[frame] end
	if type(frame) ~= "table" or not frame.IsProtected or inkDisabled[frame] then return end
	if frame:IsProtected() and InCombatLockdown() then
		pendingDisable[frame] = keepEvents or false
		return
	end
	inkDisabled[frame] = true
	if not keepEvents then frame:UnregisterAllEvents() end
	Ink.safe(frame.Hide, frame)
	frame:SetParent(hiddenParent)
	hooksecurefunc(frame, "SetParent", function(self, p)
		if p ~= hiddenParent and not inkReparenting[self] then
			local function again()
				if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
					C_Timer.After(0.25, again)
					return
				end
				if InCombatLockdown() and self:IsProtected() then
					pendingDisable[self] = true
					return
				end
				inkReparenting[self] = true
				self:SetParent(hiddenParent)
				inkReparenting[self] = nil
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

-- 창 옮기기: 빈 곳을 끌어서 옮기고 위치는 기준 창(host)의 오른쪽 위 기준으로 기억 · 오른쪽 클릭하면 기본 자리
function Ink:MakeDraggable(f, key, host)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		if InCombatLockdown() and self:IsProtected() then return end
		self.foaMoving = true
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self.foaMoving = nil
		local h = host or self:GetParent()
		if not (h and self:GetLeft() and h:GetRight()) then return end
		local s, hs = self:GetEffectiveScale(), h:GetEffectiveScale()
		local dx = self:GetLeft() * s / hs - h:GetRight()
		local dy = self:GetTop() * s / hs - h:GetTop()
		Ink.db.panelPos = Ink.db.panelPos or {}
		Ink.db.panelPos[key] = { math.floor(dx + 0.5), math.floor(dy + 0.5) }
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", h, "TOPRIGHT", Ink.db.panelPos[key][1], Ink.db.panelPos[key][2])
	end)
	f:SetScript("OnMouseUp", function(self, btn)
		if btn ~= "RightButton" or not IsShiftKeyDown() then return end
		if Ink.db.panelPos then Ink.db.panelPos[key] = nil end
		if self.foaResetPos then self:foaResetPos() end
	end)
end

function Ink:PanelPoint(f, key, host, dx, dy)
	local pos = Ink.db.panelPos and Ink.db.panelPos[key]
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", host, "TOPRIGHT", pos and pos[1] or dx, pos and pos[2] or dy)
end

function Ink:Module(name)
	local m = { name = name }
	table.insert(self.modules, m)
	self.modules[name] = m
	return m
end

-------------------------------------------------------------------------------
-- 오류 기록 (나중에 저장 파일만 보고 원인을 찾을 수 있게 정리해 둔다)
--  저장 위치: WTF\Account\<계정>\SavedVariables\FOA_UI.lua → InkUIDB.errlog
--  · 같은 오류는 한 칸에 모아서 횟수 · 처음/마지막 시각만 늘린다 (한 오류가 도배돼도 다른 오류가 밀려나지 않게)
--  · 칸마다: 종류(FOA 코드 / FOA 오염 / 블리자드) · 메시지 · 호출 경로 · 지역 변수(FOA 오류만) · 버전 · 지역 · 전투/인스턴스
--  · 접속마다 세션 한 줄 (FOA 버전 · 게임 빌드) → 어느 버전에서 난 오류인지
--  · 막힌 동작(ADDON_ACTION_BLOCKED)도 함수별로 횟수만 모은다
--  · 저장 파일은 /reload · 접속 종료 때 기록된다 (게임이 튕기면 그 세션 기록은 안 남는다)
--  · 접속 전(저장 자료를 읽기 전)에 난 오류도 잠깐 들고 있다가 접속하면 옮긴다
-------------------------------------------------------------------------------
local ERR_MAX, BLOCK_MAX = 60, 40
local errIndex, pendingErr, errSaidThisSession = nil, {}, false

local function ErrCtx()
	local ok, s = pcall(function()
		local z = GetRealZoneText and GetRealZoneText() or ""
		local _, it = IsInInstance()
		return z .. ((it and it ~= "none") and (" [" .. it .. "]") or "") .. (InCombatLockdown() and " (전투 중)" or "")
	end)
	return ok and s or "?"
end

local function ErrLog()
	local db = Ink.db
	if not db then return end
	local L = db.errlog
	if type(L) ~= "table" or L.v ~= 1 then
		L = { v = 1, sessions = {}, list = {}, blocked = {} }
		db.errlog = L
		errIndex = nil
	end
	if not errIndex then
		errIndex = {}
		for _, e in ipairs(L.list) do if e.sig then errIndex[e.sig] = e end end
	end
	return L
end

-- 오류 문장 → 같은 오류끼리 묶는 열쇠 (주소 · 횟수 같은 바뀌는 값은 뺀다)
local function ErrSig(m)
	m = m:gsub("Interface/AddOns/", ""):gsub("0x%x+", "0x"):gsub("\n.*", "")
	return m:sub(1, 200)
end

local function ErrKind(m, st)
	if m:find("tainted by 'FOA_UI'", 1, true) or m:find("Lua Taint: FOA_UI", 1, true) then return "FOA 오염" end
	if m:find("FOA_UI", 1, true) or (st and st:find("FOA_UI/", 1, true)) then return "FOA" end
	return "블리자드"
end

local function ErrPrune(L)
	-- 넘치면: 블리자드 오류 중 오래된 것부터, 그다음 아무거나 오래된 것
	while #L.list > ERR_MAX do
		local pick, pickT
		for i, e in ipairs(L.list) do
			if e.kind == "블리자드" and (not pickT or (e.lastT or 0) < pickT) then pick, pickT = i, e.lastT or 0 end
		end
		if not pick then
			for i, e in ipairs(L.list) do
				if not pickT or (e.lastT or 0) < pickT then pick, pickT = i, e.lastT or 0 end
			end
		end
		local e = table.remove(L.list, pick)
		if e and errIndex then errIndex[e.sig] = nil end
	end
end

local function ErrRecord(m, st, loc, forceKind)
	m = tostring(m)
	local L = ErrLog()
	if not L then
		if #pendingErr < 20 then pendingErr[#pendingErr + 1] = { m, st, loc, date("%m-%d %H:%M:%S"), forceKind } end
		return
	end
	local sig = ErrSig(m)
	local now, t = date("%m-%d %H:%M:%S"), time()
	local e = errIndex[sig]
	if e then
		e.n = (e.n or 1) + 1
		e.last, e.lastT, e.lastVer, e.lastCtx = now, t, Ink.version, ErrCtx()
		return e
	end
	local kind = forceKind or ErrKind(m, st)
	st = st and st:gsub("Interface/AddOns/", ""):gsub("Interface\\AddOns\\", "") or nil
	e = {
		sig = sig, kind = kind, msg = m:sub(1, 700), n = 1,
		first = now, last = now, lastT = t, ver = Ink.version, lastVer = Ink.version,
		ctx = ErrCtx(), session = #L.sessions,
		stack = st and st:sub(1, 1600) or nil,
		locals = (kind ~= "블리자드" and loc) and loc:sub(1, 900) or nil,
	}
	L.list[#L.list + 1] = e
	errIndex[sig] = e
	ErrPrune(L)
	-- FOA 쪽 오류는 접속마다 한 번만 채팅에 알린다 (도배 방지)
	if kind ~= "블리자드" and not errSaidThisSession then
		errSaidThisSession = true
		print("|cffFF6B5EFOA|r 오류가 생겨서 기록해 뒀어요 · /foa log 로 볼 수 있어요 (/reload 하면 저장 파일에도 남아요)")
	end
	return e
end

-- 모듈 코드에서 pcall 로 잡은 오류 (오류 처리기를 거치지 않는 것)
function Ink:LogError(msg)
	local st = debugstack and debugstack(2, 10, 3) or nil
	pcall(ErrRecord, tostring(msg), st, nil, "FOA")
end

-- 막힌 동작: 함수별로 횟수 · 마지막 시각 · 전투 중 횟수
function Ink:LogBlocked(fn, event)
	local L = ErrLog()
	if not L then return end
	fn = tostring(fn or "?")
	local b = L.blocked[fn]
	if not b then
		b = { n = 0, combat = 0, first = date("%m-%d %H:%M:%S"), ver = Ink.version }
		L.blocked[fn] = b
		local cnt, oldK, oldT = 0, nil, nil
		for k, v in pairs(L.blocked) do
			cnt = cnt + 1
			if k ~= fn and (not oldT or (v.lastT or 0) < oldT) then oldK, oldT = k, v.lastT or 0 end
		end
		if cnt > BLOCK_MAX and oldK then L.blocked[oldK] = nil end
	end
	b.n = b.n + 1
	if InCombatLockdown() then b.combat = b.combat + 1 end
	b.last, b.lastT, b.ctx, b.kind = date("%m-%d %H:%M:%S"), time(), ErrCtx(), (event or ""):gsub("ADDON_ACTION_", "")
end

-- 접속: 세션 한 줄 · 접속 전에 난 오류 옮기기 · 예전 형식 기록 정리
function Ink:StartErrorSession()
	local L = ErrLog()
	if not L then return end
	local build = select(4, GetBuildInfo())
	L.sessions[#L.sessions + 1] = { t = date("%m-%d %H:%M:%S"), ver = Ink.version, build = build }
	while #L.sessions > 20 do table.remove(L.sessions, 1) end
	local pend = pendingErr
	pendingErr = {}
	for _, p in ipairs(pend) do
		local e = ErrRecord(p[1], p[2], p[3], p[5])
		if e then e.first = p[4] .. " (접속 전)" end
	end
	Ink.db.errors, Ink.db.blockedLog = nil, nil
end

function Ink:ClearErrors()
	if Ink.db then Ink.db.errlog = nil end
	errIndex = nil
	ErrLog()
end

-- 게임의 오류 처리기에 끼어든다: 원래 처리기(블리자드 오류 창 · 다른 오류 애드온)는 그대로 부른다
do
	local mine, orig
	-- 오류가 난 함수의 지역 변수 (C 함수 층은 비어 있어서 몇 층 위까지 본다)
	local function Locals()
		if not debuglocals then return nil end
		for lv = 3, 6 do
			local ok, s = pcall(debuglocals, lv)
			if ok and type(s) == "string" and s ~= "" then return s end
		end
	end
	-- 숨겨 둔 블리자드 기본 단축바 버튼의 "비밀 값" 쿨다운 오류인가
	--  FOA 단축바를 쓰면 블리자드 1~8번 바는 숨긴 채 남는데, 실행이 한 번 꼬이면(레벨업 뒤 등)
	--  그 숨은 버튼들이 전투 중 쿨다운을 그릴 때마다 오류를 낸다. 보이지도 않는 버튼이라 기능엔 영향이 없다.
	local function HiddenBarNoise(msg)
		if type(msg) ~= "string" or (Ink.db and Ink.db.actionBars == false) then return false end
		if not msg:find("Secret values are only allowed during untainted execution", 1, true) then return false end
		return msg:find("Blizzard_ActionBar/", 1, true) ~= nil or msg:find("Blizzard_GamepadActionBars/", 1, true) ~= nil
	end
	-- 처음 한 번만: 전투가 끝나면 채팅에 알림 (/reload 하면 깨끗해진다)
	local noted
	local function NoteBarNoise()
		if noted then return end
		noted = true
		local function say()
			print("|cffFFF468FOA|r 숨겨 둔 블리자드 기본 단축바에 오류가 생겨서 오류 창은 막아 뒀어요 · FOA 단축바는 정상이에요 · 깨끗하게 하려면 전투 밖에서 /reload")
		end
		if InCombatLockdown() then
			local f = CreateFrame("Frame")
			f:RegisterEvent("PLAYER_REGEN_ENABLED")
			f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); say() end)
		else
			say()
		end
	end
	-- 블리자드가 나중에 오류 처리기를 갈아 끼우면 FOA 기록이 빠지므로, 접속 · 화면 전환 때 다시 씌운다
	function Ink:HookErrors()
		if not (geterrorhandler and seterrorhandler) then return end
		local cur = geterrorhandler()
		if cur == mine then return end
		orig = cur
		mine = function(msg, ...)
			local st = debugstack and debugstack(2, 14, 4) or nil
			local loc
			if type(msg) == "string" and (msg:find("FOA_UI", 1, true) or (st and st:find("FOA_UI", 1, true))) then loc = Locals() end
			pcall(ErrRecord, msg, st, loc)
			-- 숨은 블리자드 단축바 소음은 기록만 하고 오류 창에는 띄우지 않는다
			if HiddenBarNoise(msg) then
				pcall(NoteBarNoise)
				return
			end
			if orig then return orig(msg, ...) end
		end
		seterrorhandler(mine)
	end
	Ink:HookErrors()
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
	self:CrispAll()
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
	autoPush = true,
	clock = true,
	questObjects = true,
	questSparkle = true,  -- 퀘스트 물체 배지 반짝임
	itemCountTip = true,  -- 툴팁에 가방 · 은행 · 다른 캐릭터 보유 개수
	oneTouchFish = true,  -- 원터치 낚시 (낚싯대를 들었을 때만)
	speedyLoot = true,    -- 빠른 자동 줍기
	tracker = true,       -- 현황 아이콘 (전문기술 · 무기 숙련 · 평판)
	unitPortrait = false, -- 플레이어 · 대상 초상화 (기본 끔)
	bossSound = true,     -- 보스 시전 경고 소리
	gearPopup = true,     -- 장비 칸 오른쪽 클릭: 업그레이드 후보 · 추천 마법부여
	gearSlotRank = true,  -- 아이템 툴팁에 칸 순위 (지금 레벨 최고템 = 100)
	gearToast = true,     -- 최고 장비 · 큰 업그레이드 획득 알림
	trackerWeapons = true,
	trackerReps = true,
	combatHide = true,
	dungeon = true,
	actionBars = true,
	itemCompare = true,
	talentGuide = true,
	training = true,
	profGuide = true,
	ahTooltip = true,
	mapEntrances = true,
	mapFieldTrainers = true,
	mapZoneLevel = true,
	mmArcane = true,      -- 아케인 미니맵 (금세공 모서리 · 나침반 띠 · 아래 지역 정보)
	mmSigil = true,       -- 미니맵 뒤 마법진
	mmRibbon = true,      -- 미니맵 위 나침반 띠
	mmSoftEdge = true,    -- 미니맵 가장자리 번짐
	mapReveal = true,
	questMinimap = true,
	questTurnIn = true,
	ahAuto = true,
	dungeonBoard = true,
	range = true,
	questToast = true,
	mapLayer = true,
	questMap = true,
	questClass = true,
	bisCrafts = true,
	bisQuests = true,
	bisWorld = true,
	barLock = true,
	mapScaleUp = false,
}
Ink.defaults = defaults

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

-- 선명 렌더: 파티/레이드 칸은 인원이 바뀔 때 새로 생기므로 그때 다시 훑는다
local crispEv = CreateFrame("Frame")
crispEv:RegisterEvent("GROUP_ROSTER_UPDATE")
crispEv:SetScript("OnEvent", function()
	if not Ink.crisp or Ink.crispQueued then return end
	Ink.crispQueued = true
	C_Timer.After(1, function() Ink.crispQueued = nil; Ink:CrispAll() end)
end)
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		-- 원인 추적용: InkUI 때문에 막힌 동작이 있으면 어떤 함수인지 남긴다
		if arg1 == ADDON then
			Ink.blocked = Ink.blocked or {}
			local line = (arg2 or "?") .. " · " .. date("%H:%M:%S") .. (InCombatLockdown() and " (전투 중)" or "") .. (IsInInstance() and " (인스턴스)" or "")
			table.insert(Ink.blocked, line)
			-- 다음 접속 때도 볼 수 있게 저장 (함수별 횟수 · 오류 기록과 같은 곳)
			pcall(Ink.LogBlocked, Ink, arg2, event)
			-- FOA 가 숨겨 둔 블리자드 행동단축바를 블리자드가 전투 중에 다시 배치하려다 막힌 것은
			-- 화면에 영향이 없으니 채팅에는 안 띄운다 (/foa log 에는 남김)
			local fn = tostring(arg2)
			-- 지도 표시(핀)의 "오른쪽 클릭 통과" 설정이 막힌 것도 화면에 영향이 없다 (퀘스트 상세를 FOA 목록에서 연 뒤 전투 중 지도를 열 때)
			if fn:find("SetPassThroughButtons") or fn:find("SetPropagateMouseClicks") then return end
			-- 블리자드 게임패드 행동단축바(GamepadMainActionBarFrame…)도 같은 경우: 패드를 안 쓰면 화면에 없는 바다
			if fn:find("^MultiBar") or fn:find("^MainActionBar") or fn:find("^MainMenuBar[:%.]") or fn:find("^StanceBar") or fn:find("^PetActionBar")
				or fn:find("^ActionButton%d") or fn:find("^StanceButton") or fn:find("^PetActionButton") or fn:find("^MultiCastActionBar")
				or fn:find("^Gamepad") then
				return
			end
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
		pcall(Ink.HookErrors, Ink)
		Ink:ApplyDamageFont()
		pcall(Ink.DetectDensity, Ink)
		InkUIDB = InkUIDB or {}
		Ink.db = InkUIDB
		pcall(Ink.StartErrorSession, Ink)
		-- 캐릭터별 배치 (편집 모드 위치 · 가방 위치), 화면 비율마다 따로
		--  처음 접속한 캐릭터는 마지막으로 편집한 배치를 복사해서 시작한다
		InkUICharDB = InkUICharDB or {}
		Ink.cdb = InkUICharDB
		if not Ink.cdb.layouts then
			if Ink.cdb.pos then
				-- 예전 저장(한 벌) → 16:9 배치로
				Ink.cdb.layouts = { ["16:9"] = Ink.cdb.pos }
			elseif Ink.db.layouts then
				Ink.cdb.layouts = CopyTable(Ink.db.layouts)
			else
				Ink.cdb.layouts = { ["16:9"] = CopyTable(Ink.db.pos or {}) }
			end
			if not Ink.cdb.bagPos and Ink.db.bagPos then Ink.cdb.bagPos = CopyTable(Ink.db.bagPos) end
		end
		Ink.cdb.pos = nil
		if not Ink.db.layouts and Ink.db.pos then Ink.db.layouts = { ["16:9"] = CopyTable(Ink.db.pos) } end
		Ink.db.pos = nil
		Ink:SelectLayout()
		for k, v in pairs(defaults) do
			if Ink.db[k] == nil then Ink.db[k] = v end
		end
		-- 모든 캐릭터 같은 배치: 공용 배치를 받아오고 비율별 위치를 다시 고른다
		if pcall(Ink.PullShared, Ink) then Ink:SelectLayout() end
		pcall(Ink.DetectDensity, Ink)
		pcall(Ink.ApplyFontSet, Ink)
		Ink:UpdateScale()
		callAll("Init")
		C_Timer.After(0.5, function() Ink:CrispAll() end)
		if EditModeManagerFrame then
			hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
				C_Timer.After(0.2, function() Ink:Relayout() end)
			end)
		end
		print("|T" .. Ink.tex.logo .. ":14:14|t |cffFFF468FOA|r " .. Ink.version .. " 로드됨 · /foa 로 설정 열기")
	elseif event == "PLAYER_ENTERING_WORLD" then
		pcall(Ink.HookErrors, Ink)
		Ink:Relayout()
		C_Timer.After(1, function() Ink:Relayout() end)
		callAll("Refresh")
	elseif event == "PLAYER_REGEN_ENABLED" then
		for f, keep in pairs(pendingDisable) do
			pendingDisable[f] = nil
			if inkDisabled[f] then
				inkReparenting[f] = true
				f:SetParent(hiddenParent)
				inkReparenting[f] = nil
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
