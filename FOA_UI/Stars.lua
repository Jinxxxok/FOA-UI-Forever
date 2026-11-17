-- FOA UI · 별자리 발동 효과
--  반응 기술(반격 · 제압 · 복수 …)이나 주문 강화(정신 집중 · 비전 포화 …)가 켜지면
--  캐릭터 양옆에 직업 별자리가 0.5초 안에 그어지고, 위에 기술 이름 + 남은 시간 게이지.
--  기술을 쓰면(강화 소모) 별빛이 캐릭터 쪽으로 빨려 들며 사라지고, 시간이 다 되면 스르륵 사라진다.
--  모양 · 좌표 · 시간은 시안 보드(1600×900 화면) 그대로 = ProcStarsData.lua. 게임에선 화면 높이 / 900 배.
--  감지: ① 게임의 주문 반짝임 (SPELL_ACTIVATION_OVERLAY_GLOW)  ② 반응 기술 사용 가능 여부 (0.1초)
--        ③ 몸의 강화 효과 (오라 번호 · 이름)  ④ 게임의 발동 그림 (SPELL_ACTIVATION_OVERLAY)
--  /foa 별자리 · /foa 별자리 마법사 · /foa 별자리 전체 · /foa 별자리 크기 0.9 · /foa 별자리 높이 20 · /foa 별자리 진단

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Stars")
local F = Ink.font
local plain = Ink.plain

local S = {}
ns.Stars = S

local TEX = "Interface\\AddOns\\FOA_UI\\Media\\Textures\\Stars\\"
local SERIF = "Interface\\AddOns\\FOA_UI\\Media\\Fonts\\StarSerif.ttf"
local KEY = "procStars"
local function FX_ON() return not ns.FX or ns.FX.on(KEY) end
local min, max, floor, sin, rad = math.min, math.max, math.floor, math.sin, math.rad

-------------------------------------------------------------------------------
-- 직업별 강조 대상
--  react : 조건이 맞을 때만 누를 수 있는 반응 기술 (사용 가능 여부 · 주문 반짝임)
--          dur = 누를 수 있는 시간(초). 0 = 시간 없음 (대상 체력 20% 아래 같은 상태 표시)
--  aura  : 몸에 붙는 강화 효과. dur = 오라 시간을 못 읽을 때 쓸 기본값 · stacks = 이만큼 쌓였을 때만
--  ids   : 클래식 번호 + 포에버 번호. 게임에서 이 번호의 이름을 읽어서 이름으로도 맞춘다
-------------------------------------------------------------------------------
local PROCS = {
	WARRIOR = {
		{ kind = "react", name = "제압", en = "Overpower", ids = { 7384, 7887, 11584, 11585 }, dur = 5 },
		{ kind = "react", name = "복수", en = "Revenge", ids = { 6572, 6574, 7379, 11600, 11601, 25288 }, dur = 5 },
		{ kind = "react", name = "마무리 일격", en = "Execute", ids = { 5308, 20658, 20660, 20661, 20662 }, dur = 0 },
		{ kind = "react", name = "승리의 돌진", en = "Victory Rush", ids = { 34428, 402927 }, dur = 20 },
	},
	PALADIN = {
		{ kind = "react", name = "천벌의 망치", en = "Hammer of Wrath", ids = { 24275, 24274, 24239 }, dur = 0 },
		{ kind = "aura", name = "빛의 주입", en = "Infusion of Light", ids = { 53672, 54149 }, dur = 15 },
	},
	HUNTER = {
		{ kind = "react", name = "살쾡이의 이빨", en = "Mongoose Bite", ids = { 1495, 14269, 14270, 14271 }, dur = 5 },
		{ kind = "react", name = "역습", en = "Counterattack", ids = { 19306, 20909, 20910 }, dur = 5 },
		{ kind = "aura", name = "신속한 처치", en = "Rapid Killing", ids = { 35098, 35099 }, dur = 20 },
	},
	ROGUE = {
		{ kind = "react", name = "반격", en = "Riposte", ids = { 14251 }, dur = 5 },
		{ kind = "aura", name = "무자비한 공격", en = "Remorseless Attacks", ids = { 14143, 14149 }, dur = 20 },
	},
	PRIEST = {
		{ kind = "aura", name = "타오르는 빛", en = "Searing Light", ids = {}, dur = 0 },
		{ kind = "aura", name = "내면의 집중", en = "Inner Focus", ids = { 14751 }, dur = 0 },
	},
	SHAMAN = {
		{ kind = "aura", name = "정신 집중", en = "Clearcasting", ids = { 16246 }, dur = 15 },
		{ kind = "aura", name = "소용돌이치는 무기", en = "Maelstrom Weapon", ids = { 53817 }, dur = 30, stacks = 5 },
	},
	MAGE = {
		{ kind = "aura", name = "정신 집중", en = "Clearcasting", ids = { 12536 }, dur = 15 },
		{ kind = "aura", name = "비전 포화", en = "Missile Barrage", ids = { 44401 }, dur = 15 },
		{ kind = "aura", name = "열기 상승", en = "Heating Up", ids = { 48107 }, dur = 20, stacks = 3 },
		{ kind = "aura", name = "서리의 손가락", en = "Fingers of Frost", ids = { 44544, 74396 }, dur = 15 },
	},
	WARLOCK = {
		{ kind = "aura", name = "어둠의 무아지경", en = "Shadow Trance", ids = { 17941 }, dur = 10 },
		{ kind = "aura", name = "대학살", en = "Decimation", ids = { 63165, 63167 }, dur = 10 },
	},
	DRUID = {
		{ kind = "aura", name = "정신 집중", en = "Clearcasting", ids = { 16870 }, dur = 15 },
		{ kind = "aura", name = "월식", en = "Eclipse", ids = { 48517, 48518 }, dur = 15 },
	},
}
S.PROCS = PROCS
local ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_KO = {
	["전사"] = "WARRIOR", ["성기사"] = "PALADIN", ["기사"] = "PALADIN", ["사냥꾼"] = "HUNTER", ["냥꾼"] = "HUNTER",
	["도적"] = "ROGUE", ["사제"] = "PRIEST", ["주술사"] = "SHAMAN", ["술사"] = "SHAMAN", ["마법사"] = "MAGE", ["법사"] = "MAGE",
	["흑마법사"] = "WARLOCK", ["흑마"] = "WARLOCK", ["드루이드"] = "DRUID", ["드루"] = "DRUID",
}

-------------------------------------------------------------------------------
-- 색 (시안과 같은 계산: hi = 흰색 쪽으로 55% · c2 = 색상 -38° · 밝기 62% 이하)
-------------------------------------------------------------------------------
local function rgbOf(hex)
	local n = tonumber(hex, 16) or 0xFFFFFF
	return { floor(n / 65536) % 256 / 255, floor(n / 256) % 256 / 255, n % 256 / 255 }
end
local function lighten(c, f)
	return { c[1] + (1 - c[1]) * f, c[2] + (1 - c[2]) * f, c[3] + (1 - c[3]) * f }
end
local function shiftHue(c, deg)
	local r, g, b = c[1], c[2], c[3]
	local mx, mn = max(r, g, b), min(r, g, b)
	local l, s, h, d = (mx + mn) / 2, 0, 0, mx - mn
	if d > 0 then
		s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
		if mx == r then h = (g - b) / d + (g < b and 6 or 0)
		elseif mx == g then h = (b - r) / d + 2
		else h = (r - g) / d + 4 end
		h = h * 60
	end
	h = (h + deg + 360) % 360
	l = min(l, 0.62)
	local q = l < 0.5 and l * (1 + s) or l + s - l * s
	local p = 2 * l - q
	local function f(t)
		t = (t + 1) % 1
		if t < 1 / 6 then return p + (q - p) * 6 * t end
		if t < 1 / 2 then return q end
		if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
		return p
	end
	return { f(h / 360 + 1 / 3), f(h / 360), f(h / 360 - 1 / 3) }
end

-------------------------------------------------------------------------------
-- 시간 곡선
-------------------------------------------------------------------------------
local function clamp(x) return x < 0 and 0 or (x > 1 and 1 or x) end
local function lerp(a, b, t) return a + (b - a) * t end
local function smooth(x) x = clamp(x) return x * x * (3 - 2 * x) end
local function outQ(x) x = 1 - clamp(x) return 1 - x * x * x * x end         -- cubic-bezier(.2,.8,.2,1) 근사
-- 키프레임: { {위치, 값...}, ... } 사이를 부드럽게
local function kf(frames, p, i)
	for k = 2, #frames do
		local b = frames[k]
		if p <= b[1] then
			local a = frames[k - 1]
			return lerp(a[i], b[i], smooth((p - a[1]) / (b[1] - a[1])))
		end
	end
	return frames[#frames][i]
end
local TWINKLE = { { 0, 0.78 }, { 0.4, 1 }, { 0.65, 0.62 }, { 1, 0.78 } }
local function twinkle(t, period)
	if t <= 0 then return 0.78 end
	return kf(TWINKLE, (t % period) / period, 2)
end
local MOTE_KF = {
	{ dur = 4.6, { 0, 0, 0, 0 }, { 0.25, 10, -18, 1 }, { 0.5, 3, -40, 0.45 }, { 0.75, -9, -58, 1 }, { 1, 0, -80, 0 } },
	{ dur = 3.9, { 0, 0, 0, 0 }, { 0.3, -12, -16, 1 }, { 0.6, -4, -44, 0.5 }, { 1, 9, -72, 0 } },
	{ dur = 5.2, { 0, 0, 0, 0 }, { 0.2, 6, -10, 0.9 }, { 0.55, 14, -36, 0.35 }, { 1, 4, -64, 0 } },
}
-- 양옆 배경이 펼쳐지는 시각: 눈금 g0 · 은하수 n0 · 별밭 s0 · 숨쉬기 시작 d2
local SIDES = {
	{ x = 400, flip = false, g0 = 0, n0 = 0.02, s0 = 0.04, d2 = 0.8 },
	{ x = 900, flip = true, g0 = 0.03, n0 = 0.05, s0 = 0.07, d2 = 0.85 },
}

-------------------------------------------------------------------------------
-- 화면
-------------------------------------------------------------------------------
local V = { heroes = {}, minors = {}, lines = {}, labels = {}, caps = {}, motes = {}, pips = {} }
S.V = V

local function Tex(parent, layer, sub, file, blend)
	local t = parent:CreateTexture(nil, layer, nil, sub)
	t:SetTexture(file)
	t:SetBlendMode(blend or "ADD")
	return t
end
local function Col(t, c, a) t:SetVertexColor(c[1], c[2], c[3], a or 1) end
local function At(t, ov, x, y) t:ClearAllPoints() t:SetPoint("CENTER", ov, "TOPLEFT", x, -y) end

local function Create()
	if V.holder then return end
	local h = CreateFrame("Frame", "FOAStars", UIParent)
	h:SetSize(2, 2)
	h:SetFrameStrata("BACKGROUND")
	h:SetFrameLevel(2)
	h:EnableMouse(false)
	h:Hide()
	V.holder = h

	-- 효과 판: 시안 1600×900 좌표 그대로. (800, 400) = 캐릭터 = holder 가운데
	local ov = CreateFrame("Frame", nil, h)
	ov:SetSize(1600, 900)
	ov:SetPoint("TOPLEFT", h, "CENTER", -800, 400)
	V.ov = ov

	V.spill = Tex(ov, "BACKGROUND", -8, TEX .. "Spill")
	V.spill:SetSize(800, 460)
	At(V.spill, ov, 800, 390)
	V.flash = Tex(ov, "BACKGROUND", -7, TEX .. "Spill")
	V.flash:SetSize(560, 360)
	At(V.flash, ov, 800, 400)
	V.wind = Tex(ov, "BACKGROUND", -7, TEX .. "Ring")
	At(V.wind, ov, 800, 390)

	V.sides = {}
	for i, sd in ipairs(SIDES) do
		local f = CreateFrame("Frame", nil, ov)
		f:SetSize(300, 480)
		f:SetPoint("TOPLEFT", ov, "TOPLEFT", sd.x, -150)
		local o = { f = f, sd = sd }
		o.haze = Tex(f, "BACKGROUND", -4, TEX .. "Haze")
		o.field = Tex(f, "BACKGROUND", -3, TEX .. "Field")
		o.grat = Tex(f, "BACKGROUND", -2, TEX .. "Grat")
		for _, t in ipairs({ o.haze, o.field, o.grat }) do
			t:SetPoint("TOPLEFT", f, "TOPLEFT")
			t:SetWidth(300)
		end
		V.sides[i] = o
	end

	-- 떠오르는 불씨 16 (시안 MOTES 와 같은 자리 · 주기)
	for i = 0, 15 do
		local side = (i % 2 == 0) and -1 or 1
		local x = 800 + side * (200 + (i * 37) % 160)
		local y = 230 + (i * 53) % 360
		local s = 3 + (i * 3) % 4
		local t = Tex(ov, "ARTWORK", 1, TEX .. "Ember")
		t:SetSize(s, s)
		V.motes[i + 1] = { t = t, x = x, y = y + s / 2, kf = MOTE_KF[(i % 3) + 1], dl = 1.0 + (i * 0.43) % 4, white = (i % 2 == 0) }
	end
	-- 유성 둘 (머리 시작점 · 방향 · 이동 · 주기 · 시작)
	V.meteors = {}
	for _, m in ipairs({ { 680, 118.75, -162, -230, 75, 8, 3.4 }, { 920, 132.75, -18, 230, 75, 9.5, 6.4 } }) do
		local t = Tex(ov, "ARTWORK", 2, TEX .. "Meteor")
		t:SetSize(150, 3)
		t:SetRotation(rad(m[3]))
		local a = rad(-m[3])                                  -- 화면(아래로 +) 기준 머리 방향
		V.meteors[#V.meteors + 1] = { t = t, hx = m[1], hy = m[2], ux = math.cos(a), uy = math.sin(a), dx = m[4], dy = m[5], per = m[6], dl = m[7] }
	end

	-- 위: 기술 이름 · 쌓임 · 남은 시간
	local lab = CreateFrame("Frame", nil, h)
	lab:SetSize(420, 80)
	V.lab = lab
	lab.glow = Tex(lab, "BACKGROUND", 0, TEX .. "Spill")
	lab.name = lab:CreateFontString(nil, "OVERLAY")
	lab.name:SetFont(F.bold, 23, "")
	lab.name:SetShadowColor(0, 0, 0, 0.65)
	lab.name:SetShadowOffset(0, -2)
	lab.name:SetPoint("TOP", lab, "TOP", 0, 0)
	lab.glow:SetPoint("CENTER", lab.name, "CENTER", 0, 0)
	lab.l = lab:CreateTexture(nil, "ARTWORK")
	lab.r = lab:CreateTexture(nil, "ARTWORK")
	for _, t in ipairs({ lab.l, lab.r }) do t:SetTexture("Interface\\Buttons\\WHITE8X8") t:SetSize(64, 1) end
	lab.l:SetPoint("RIGHT", lab.name, "LEFT", -16, 0)
	lab.r:SetPoint("LEFT", lab.name, "RIGHT", 16, 0)
	lab.bar = CreateFrame("Frame", nil, lab)
	lab.bar:SetSize(200, 2)
	lab.bar.bg = lab.bar:CreateTexture(nil, "BACKGROUND")
	lab.bar.bg:SetAllPoints()
	lab.bar.bg:SetColorTexture(1, 1, 1, 0.12)
	lab.bar.fill = lab.bar:CreateTexture(nil, "ARTWORK")
	lab.bar.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
	lab.bar.fill:SetPoint("TOPLEFT")
	lab.bar.fill:SetPoint("BOTTOMLEFT")
	lab.bar.head = Tex(lab.bar, "OVERLAY", 0, TEX .. "Spill")
	lab.bar.head:SetSize(12, 12)
	lab.bar.core = Tex(lab.bar, "OVERLAY", 1, TEX .. "DotHot")
	lab.bar.core:SetSize(9, 9)
	for _, t in ipairs({ lab.bar.head, lab.bar.core }) do t:SetPoint("CENTER", lab.bar.fill, "RIGHT", 0, 0) end

	h:SetScript("OnUpdate", function(_, el) S.Frame(el) end)
end

-- 직업 모양을 판에 올린다 (영역은 직업이 바뀌어도 다시 쓴다)
local function Bind(cls)
	local D = ns.PROC_STARS and ns.PROC_STARS[cls]
	if not D then return false end
	local ov = V.ov
	local c = rgbOf(D.color)
	V.c, V.hi, V.c2 = c, lighten(c, 0.55), shiftHue(c, -38)
	V.D, V.cls = D, cls

	for i, d in ipairs(D.h) do
		local o = V.heroes[i]
		if not o then
			o = { ring = Tex(ov, "ARTWORK", 3, TEX .. "Ring"), star = Tex(ov, "ARTWORK", 5, TEX .. "Hero"), hot = Tex(ov, "OVERLAY", 3, TEX .. "HeroHot") }
			V.heroes[i] = o
		end
		o.d = d
		At(o.ring, ov, d[1], d[2])
		At(o.star, ov, d[1], d[2])
		At(o.hot, ov, d[1], d[2])
		Col(o.ring, V.hi)
		Col(o.star, c)
		o.ring:Show() o.star:Show() o.hot:Show()
	end
	for i = #D.h + 1, #V.heroes do local o = V.heroes[i] o.d = nil o.ring:Hide() o.star:Hide() o.hot:Hide() end

	for i, d in ipairs(D.m) do
		local o = V.minors[i]
		if not o then
			o = { star = Tex(ov, "ARTWORK", 4, TEX .. "Dot"), hot = Tex(ov, "OVERLAY", 2, TEX .. "DotHot") }
			V.minors[i] = o
		end
		o.d = d
		At(o.star, ov, d[1], d[2])
		At(o.hot, ov, d[1], d[2])
		Col(o.star, V.hi)
		o.star:Show() o.hot:Show()
	end
	for i = #D.m + 1, #V.minors do local o = V.minors[i] o.d = nil o.star:Hide() o.hot:Hide() end

	local n = 0
	for _, d in ipairs(D.l) do
		if (d[3] - d[1]) ^ 2 + (d[4] - d[2]) ^ 2 >= 1 then         -- 별 사이가 너무 붙은 선(성단 안)은 건너뛴다
			n = n + 1
			local o = V.lines[n]
			if not o then
				o = { ln = ov:CreateLine(nil, "BORDER", nil, 1) }
				o.ln:SetTexture(TEX .. "Line")
				o.ln:SetBlendMode("ADD")
				o.ln:SetThickness(10)
				V.lines[n] = o
			end
			o.d = d
			o.ln:SetStartPoint("TOPLEFT", ov, d[1], -d[2])
			o.ln:SetEndPoint("TOPLEFT", ov, d[1], -d[2])
			Col(o.ln, V.hi)
			o.ln:Show()
		end
	end
	for i = n + 1, #V.lines do V.lines[i].d = nil V.lines[i].ln:Hide() end

	local all = {}
	for _, d in ipairs(D.g) do all[#all + 1] = { d = d } end
	for _, d in ipairs(D.c) do all[#all + 1] = { cap = d } end
	for i, a in ipairs(all) do
		local fs = V.labels[i]
		if not fs then
			fs = ov:CreateFontString(nil, "OVERLAY")
			fs:SetWordWrap(false)
			fs:SetShadowColor(0, 0, 0, 0.55)
			fs:SetShadowOffset(1, -1)
			V.labels[i] = fs
		end
		fs:ClearAllPoints()
		if a.d then
			local d = a.d
			if not fs:SetFont(SERIF, d[7], "") then fs:SetFont(F.latin, d[7], "") end
			fs:SetText(d[4])
			fs:SetWidth(d[3] + 24)
			if d[6] == "R" then
				fs:SetJustifyH("RIGHT")
				fs:SetPoint("TOPRIGHT", ov, "TOPLEFT", d[1] + d[3], -d[2])
			else
				fs:SetJustifyH("LEFT")
				fs:SetPoint("TOPLEFT", ov, "TOPLEFT", d[1], -d[2])
			end
			fs.x, fs.y, fs.dl, fs.cap, fs.r = d[1], d[2], d[5], nil, d[6] == "R"
		else
			local d = a.cap
			if not fs:SetFont(F.latinB, 10, "") then fs:SetFont(F.sans, 10, "") end
			fs:SetText((d[3]:gsub("(.)", "%1 "):gsub(" $", "")))   -- 글자 사이 띄움 (시안 .34em)
			fs:SetWidth(240)
			fs:SetJustifyH("CENTER")
			fs:SetPoint("TOP", ov, "TOPLEFT", d[1] + 100, -d[2])
			fs.x, fs.y, fs.dl, fs.cap, fs.r = d[1] + 100, d[2], d[4], true, nil
		end
		fs:SetTextColor(V.hi[1], V.hi[2], V.hi[3])
		fs:Show()
	end
	for i = #all + 1, #V.labels do V.labels[i]:Hide() end

	Col(V.spill, c)
	Col(V.flash, c)
	Col(V.wind, c)
	for _, o in ipairs(V.sides) do
		Col(o.haze, V.c2)
		o.field:SetVertexColor(1, 1, 1)
		Col(o.grat, V.hi)
	end
	for _, m in ipairs(V.motes) do
		if m.white then m.t:SetVertexColor(1, 1, 1) else Col(m.t, c) end
	end
	local lab = V.lab
	lab.name:SetFont(F.bold, 23, "")
	Col(lab.glow, c, 0.32)
	pcall(lab.l.SetGradient, lab.l, "HORIZONTAL", CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], 1))
	pcall(lab.r.SetGradient, lab.r, "HORIZONTAL", CreateColor(c[1], c[2], c[3], 1), CreateColor(c[1], c[2], c[3], 0))
	if not pcall(lab.bar.fill.SetGradient, lab.bar.fill, "HORIZONTAL", CreateColor(c[1], c[2], c[3], 0.55), CreateColor(c[1], c[2], c[3], 1)) then
		lab.bar.fill:SetVertexColor(c[1], c[2], c[3], 1)
	end
	Col(lab.bar.head, c, 0.9)
	return true
end

-------------------------------------------------------------------------------
-- 프레임마다: 시안의 CSS 애니메이션을 그대로 계산
-------------------------------------------------------------------------------
local function Reveal(t, o, delay, dur, flip)
	local p = smooth((V.t - delay) / dur)
	if p <= 0.002 then t:Hide() return end
	t:Show()
	t:SetHeight(480 * p)
	if flip then t:SetTexCoord(1, 0, 0, p) else t:SetTexCoord(0, 1, 0, p) end
end

local function Pips(n)
	local lab = V.lab
	for i = 1, max(n, #V.pips) do
		local p = V.pips[i]
		if i <= n then
			if not p then
				p = lab:CreateTexture(nil, "OVERLAY")
				p:SetTexture("Interface\\Buttons\\WHITE8X8")
				p:SetRotation(rad(45))
				V.pips[i] = p
			end
			p:ClearAllPoints()
			p:SetPoint("CENTER", lab.name, "BOTTOM", (i - (n + 1) / 2) * 14, -14)
			Col(p, V.hi)
			p:Show()
		elseif p then
			p:Hide()
		end
	end
end

function S.Frame()
	local now = GetTime()
	local t = now - V.t0
	V.t = t
	local ov, lab = V.ov, V.lab
	local alpha, boost, labA, labY, labS = 1, 0, 1, 0, 1

	if V.ending == "consume" then
		local p = (now - V.tEnd) / 0.32
		if p >= 1 then S.Finish() return end
		local e = smooth(p)
		local sc
		if e < 0.28 then local k = e / 0.28 sc, boost = 1 + 0.015 * k, k
		else local k = (e - 0.28) / 0.72 sc, alpha, boost = 1.015 - 0.115 * k, 1 - k, 1 - k end
		ov:SetScale(V.base * sc)
		local q = clamp((now - V.tEnd) / 0.22)
		labA, labY, labS = 1 - q, 6 * q, 1 - 0.04 * q
	elseif V.ending == "fade" then
		local p = (now - V.tEnd) / 0.6
		if p >= 1 then S.Finish() return end
		alpha = 1 - smooth(p)
		labA = 1 - smooth(p / 0.85)
	else
		alpha = clamp(t / 0.1)
		local q = outQ((t - 0.08) / 0.25)
		labA, labY = q, 8 * (1 - q)                 -- 위에서 8 내려와 자리 잡음
		if (t - 0.08) < 0 then labA = 0 end
	end
	ov:SetAlpha(alpha)

	-- 바탕 빛 · 섬광 · 퍼지는 고리
	local br = (t < 0.8) and lerp(1, 0.55, smooth((t - 0.35) / 0.45)) or lerp(0.55, 0.95, (sin((t - 0.8) / 4.8 * 2 * math.pi - math.pi / 2) + 1) / 2)
	V.spill:SetAlpha(0.12 * clamp(t / 0.35) * br * (1 + 1.6 * boost))
	local fp = (t - 0.12) / 0.6
	V.flash:SetAlpha(0.55 * ((fp <= 0 or fp >= 1) and 0 or (fp < 0.18 and fp / 0.18 * 0.4 or 0.4 * (1 - (fp - 0.18) / 0.82))) + 0.25 * boost)
	if t > 1 then
		local w = ((t - 1) % 4.8) / 4.8
		V.wind:SetSize(420 * lerp(0.1, 1.5, w), 420 * lerp(0.1, 1.5, w))
		V.wind:SetAlpha(w < 0.1 and 0.26 * w / 0.1 or (w < 0.8 and lerp(0.26, 0.1, (w - 0.1) / 0.7) or lerp(0.1, 0, (w - 0.8) / 0.2)))
	else
		V.wind:SetAlpha(0)
	end

	-- 양옆: 눈금 · 은하수 · 별밭이 위에서 아래로 펼쳐진다
	for _, o in ipairs(V.sides) do
		local sd = o.sd
		Reveal(o.haze, o, sd.n0, 0.32, sd.flip)
		Reveal(o.field, o, sd.s0, 0.32, sd.flip)
		Reveal(o.grat, o, sd.g0, 0.25, sd.flip)
		local hz = (t < sd.d2) and 0.55 * clamp((t - sd.n0) / 0.32) or kf({ { 0, 0.45 }, { 0.5, 0.62 }, { 1, 0.45 } }, ((t - sd.d2) % 5) / 5, 2)
		o.haze:SetAlpha(hz)
		o.field:SetAlpha(0.9 * twinkle(t - sd.d2, 3.4))
		o.grat:SetAlpha(0.5)
	end

	-- 선: 별에서 별로 실제로 그어진다
	for _, o in ipairs(V.lines) do
		local d = o.d
		if not d then break end
		local p = d[6] > 0 and clamp((t - d[5]) / d[6]) or (t >= d[5] and 1 or 0)
		if p <= 0 then
			o.ln:SetAlpha(0)
		else
			o.ln:SetAlpha(0.82)
			o.ln:SetEndPoint("TOPLEFT", ov, lerp(d[1], d[3], p), -lerp(d[2], d[4], p))
		end
	end

	-- 큰 별: 고리가 퍼지며 점화 → 반짝
	for _, o in ipairs(V.heroes) do
		local d = o.d
		if not d then break end
		local s, rt = d[3], t - d[4]
		local rp = rt / 0.55
		if rp <= 0 or rp >= 1 then o.ring:SetAlpha(0)
		else
			local e = outQ(rp)
			local rs = floor(s * 1.35) * lerp(0.1, 1, e)
			o.ring:SetSize(rs, rs)
			o.ring:SetAlpha(rp < 0.12 and rp / 0.12 or 1 - (rp - 0.12) / 0.88)
		end
		local hp = rt / 0.3
		local sc, rot, a
		if hp <= 0 then sc, rot, a = 0.15, -12, 0
		elseif hp >= 1 then sc, rot, a = 1, 0, 1
		else
			local e = outQ(hp)
			if e < 0.45 then local k = e / 0.45 sc, rot, a = lerp(0.15, 1.35, k), lerp(-12, 2, k), k
			else local k = (e - 0.45) / 0.55 sc, rot, a = lerp(1.35, 1, k), lerp(2, 0, k), 1 end
		end
		local z = max(1, s * sc)
		o.star:SetSize(z, z)
		o.hot:SetSize(z, z)
		o.star:SetRotation(rad(-rot))
		o.hot:SetRotation(rad(-rot))
		o.star:SetAlpha(a * (t >= d[4] + 0.35 and twinkle(t - d[4] - 0.35, d[5]) or 1))
		o.hot:SetAlpha(a)
	end

	-- 작은 별: 톡 켜졌다가 반짝
	for _, o in ipairs(V.minors) do
		local d = o.d
		if not d then break end
		local p = (t - d[4]) / 0.18
		local sc, a
		if p <= 0 then sc, a = 0.2, 0
		elseif p >= 1 then sc, a = 1, 1
		else
			local e = outQ(p)
			if e < 0.55 then sc, a = lerp(0.2, 1.35, e / 0.55), e / 0.55 else sc, a = lerp(1.35, 1, (e - 0.55) / 0.45), 1 end
		end
		local z = max(1, d[3] * sc)
		o.star:SetSize(z, z)
		o.hot:SetSize(z, z)
		o.star:SetAlpha(a * (t >= d[4] + 0.35 and twinkle(t - d[4] - 0.35, d[5]) or 1))
		o.hot:SetAlpha(a)
	end

	-- 글자: 아래에서 살짝 올라오며
	for _, fs in ipairs(V.labels) do
		if not fs:IsShown() then break end
		if fs.cap then
			fs:SetAlpha(0.62 * clamp((t - fs.dl) / 0.5))
		else
			local q = clamp((t - fs.dl) / 0.2)
			fs:SetAlpha(0.82 * q)
			fs:ClearAllPoints()
			if fs.r then fs:SetPoint("TOPRIGHT", ov, "TOPLEFT", fs.x + (fs:GetWidth() - 24), -fs.y - 3 * (1 - q))
			else fs:SetPoint("TOPLEFT", ov, "TOPLEFT", fs.x, -fs.y - 3 * (1 - q)) end
		end
	end

	-- 불씨 · 유성
	for _, m in ipairs(V.motes) do
		local mt = t - m.dl
		if mt <= 0 then m.t:SetAlpha(0)
		else
			local k = m.kf
			local p = (mt % k.dur) / k.dur
			m.t:ClearAllPoints()
			m.t:SetPoint("CENTER", ov, "TOPLEFT", m.x + kf(k, p, 2), -(m.y + kf(k, p, 3)))
			m.t:SetAlpha(kf(k, p, 4))
		end
	end
	for _, m in ipairs(V.meteors) do
		local mt = t - m.dl
		local p = mt > 0 and (mt % m.per) / m.per or 1
		if p >= 0.12 then m.t:SetAlpha(0)
		else
			local e = p / 0.12
			local hx, hy = m.hx + m.dx * e, m.hy + m.dy * e
			m.t:ClearAllPoints()
			m.t:SetPoint("CENTER", ov, "TOPLEFT", hx - 75 * m.ux, -(hy - 75 * m.uy))
			m.t:SetAlpha(p < 0.03 and p / 0.03 or 1 - (p - 0.03) / 0.09)
		end
	end

	-- 위 이름표 · 게이지
	lab:SetAlpha(labA)
	lab:SetScale(V.base * labS)
	lab:ClearAllPoints()
	lab:SetPoint("TOP", V.holder, "CENTER", 0, (400 - 92 + labY) / labS)
	local e = V.cur
	if e and e.exp and e.dur and e.dur > 0 then
		local f = clamp((e.exp - now) / e.dur)
		lab.bar:Show()
		lab.bar.fill:SetWidth(max(0.5, 200 * f))
	else
		lab.bar:Hide()
	end
	for i, p in ipairs(V.pips) do
		if p:IsShown() then
			local q = clamp((t - 0.55 - (i - 1) * 0.07) / 0.22)
			p:SetAlpha(q)
			p:SetSize(7 * lerp(0.2, 1, q), 7 * lerp(0.2, 1, q))
		end
	end
end

local function Layout()
	local db = Ink.db and Ink.db.stars or {}
	local k = (UIParent:GetHeight() or 1080) / 900
	V.base = k * (db.scale or 1)
	V.holder:ClearAllPoints()
	V.holder:SetPoint("CENTER", UIParent, "CENTER", 0, (50 + (db.y or 0)) * k)
	V.ov:SetScale(V.base)
end

local function SetCur(e)
	V.cur = e
	local lab = V.lab
	lab.name:SetText(e.label or "")
	local w = lab.name:GetStringWidth() or 60
	lab.glow:SetSize(w + 120, 50)
	Pips(e.need or 0)
	local dy = (e.need and e.need > 0) and -32 or -14
	lab.bar:ClearAllPoints()
	lab.bar:SetPoint("TOP", lab.name, "BOTTOM", 0, dy)
end

function S.Start(e)
	Create()
	local cls = e.cls or S.class
	if V.cls ~= cls and not Bind(cls) then return end
	Layout()
	V.t0, V.ending, V.t = GetTime(), nil, 0
	SetCur(e)
	V.holder:Show()
	S.Frame()
	V.shown = true
end

function S.End(consume)
	if not V.shown or V.ending then return end
	V.ending = consume and "consume" or "fade"
	V.tEnd = GetTime()
end

function S.Finish()
	V.holder:Hide()
	V.ov:SetScale(V.base or 1)
	V.ov:SetAlpha(1)
	V.shown, V.ending, V.cur = false, nil, nil
	S.Update()
end

-------------------------------------------------------------------------------
-- 감지
-------------------------------------------------------------------------------
local active = {}           -- 켜진 강조: 열쇠 → { label, srcs, t0, exp, dur, need, aura, cls, d }
local defs = {}
local lastEnd               -- 마지막으로 꺼진 강조가 소모였는지
local auraDirty = true
S.active = active

local function Log(kind, id, name)
	Ink.db.starsLog = Ink.db.starsLog or {}
	local l = Ink.db.starsLog
	l[#l + 1] = string.format("%s %s %s %s", date("%m-%d %H:%M:%S"), kind, tostring(id or "-"), tostring(name or "-"))
	while #l > 40 do table.remove(l, 1) end
end

local function SpellName(id)
	if not id then return nil end
	if C_Spell and C_Spell.GetSpellName then
		local ok, v = pcall(C_Spell.GetSpellName, id)
		if ok and plain(v) then return plain(v) end
	end
	if GetSpellInfo then
		local ok, v = pcall(GetSpellInfo, id)
		if ok and plain(v) then return plain(v) end
	end
end

local function Known(id)
	if IsPlayerSpell then
		local ok, v = pcall(IsPlayerSpell, id)
		if ok and plain(v) then return true end
	end
	if IsSpellKnown then
		local ok, v = pcall(IsSpellKnown, id)
		if ok and plain(v) then return true end
	end
	return false
end

local function Prepare()
	local _, cls = UnitClass("player")
	S.class = cls
	wipe(defs)
	local ko = (GetLocale and GetLocale() or "koKR") == "koKR"
	local book = ns.CLASS_SPELL_IDS and ns.CLASS_SPELL_IDS[cls]
	for i, src in ipairs(PROCS[cls] or {}) do
		local d = { kind = src.kind, dur = src.dur or 0, stacks = src.stacks, key = cls .. i, names = {}, ids = {} }
		d.names[src.name] = true
		d.names[src.en] = true
		local seen = {}
		for _, id in ipairs(src.ids) do d.ids[#d.ids + 1] = id seen[id] = true end
		if book and d.kind == "react" then           -- 포에버 단계별 번호 (배우는 레벨 순)
			local extra = {}
			for k, id in pairs(book) do
				local lv, nm = k:match("^(%d+):(.+)$")
				if nm == src.name and not seen[id] then extra[#extra + 1] = { tonumber(lv), id } seen[id] = true end
			end
			table.sort(extra, function(a, b) return a[1] < b[1] end)
			for _, x in ipairs(extra) do d.ids[#d.ids + 1] = x[2] end
		end
		for _, id in ipairs(d.ids) do
			local n = SpellName(id)
			if n then d.names[n] = true end
		end
		d.label = ko and src.name or (SpellName(d.ids[1]) or src.en)
		defs[#defs + 1] = d
	end
	S.Resolve()
end

function S.Resolve()
	for _, d in ipairs(defs) do
		if d.kind == "react" then
			d.cast = nil
			for _, id in ipairs(d.ids) do if Known(id) then d.cast = id end end
			if not d.cast and C_Spell and C_Spell.GetSpellInfo then
				local ok, info = pcall(C_Spell.GetSpellInfo, d.label)
				if ok and type(info) == "table" and plain(info.spellID) then d.cast = plain(info.spellID) end
			end
		end
	end
end

local function DefByName(name)
	if not name then return nil end
	for _, d in ipairs(defs) do if d.names[name] then return d end end
end

local function Activate(key, src, o)
	local now = GetTime()
	local e = active[key]
	if not e then
		e = { srcs = {}, t0 = now, label = o.label, aura = o.aura, cls = o.cls, d = o.d }
		active[key] = e
		if o.exp then e.exp, e.dur = o.exp, o.dur
		elseif o.win and o.win > 0 then e.exp, e.dur = now + o.win, o.win end
		e.need = o.need
		e.srcs[src] = true
		S.Update()
		return
	end
	e.srcs[src] = true
	if o.exp and o.exp ~= e.exp then e.exp, e.dur = o.exp, o.dur end
end

local function Deactivate(key, src, consumed)
	local e = active[key]
	if not e then return end
	if src then e.srcs[src] = nil else wipe(e.srcs) end
	if next(e.srcs) then return end
	active[key] = nil
	local now = GetTime()
	lastEnd = consumed or (e.exp and e.dur and e.dur > 0 and e.exp - now > 0.4) or false
	S.Update()
end

function S.Update()
	local best
	for _, e in pairs(active) do
		if not best or (e.aura and not best.aura) or ((e.aura and true or false) == (best.aura and true or false) and e.t0 > best.t0) then best = e end
	end
	if not best then
		if V.shown then S.End(lastEnd) end
		return
	end
	if not V.shown or V.ending then
		if V.ending then V.holder:Hide() V.shown, V.ending = false, nil end
		S.Start(best)
	elseif V.cur ~= best then
		if (best.cls or S.class) ~= V.cls then S.Start(best) else SetCur(best) end
	end
end

-- 반응 기술: 0.1초마다 "지금 누를 수 있나"
local function Usable(id)
	local fn = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
	if not (fn and id) then return false end
	local ok, u, nm = pcall(fn, id)
	if not ok then return false end
	return plain(u) == true or plain(nm) == true
end

local function Poll()
	local now = GetTime()
	for _, d in ipairs(defs) do
		if d.kind == "react" and d.cast then
			local on = Usable(d.cast)
			if not on then
				d.sup, d.since = nil, nil
				Deactivate(d.key, "poll")
			elseif not d.sup or now > d.sup then
				d.sup = nil
				d.since = d.since or now
				-- 시간 창이 있는 기술이 30초 넘게 계속 "누를 수 있음"이면 반응 기술이 아니라고 보고 무시
				if d.dur > 0 and now - d.since > 30 then
					Deactivate(d.key, "poll")
				else
					Activate(d.key, "poll", { label = d.label, win = d.dur, d = d })
				end
			end
		end
	end
end

-- 강화 효과: 몸의 오라
local function FindAura(d)
	local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if get then
		for _, id in ipairs(d.ids) do
			local ok, a = pcall(get, id)
			if ok and type(a) == "table" then return a end
		end
	end
	local list = ns.ReadAuras and ns.ReadAuras("player", "HELPFUL", 40)
	if list then
		for _, a in ipairs(list) do
			local n = plain(a.name)
			if n and d.names[n] then return a end
		end
	end
end

local function ScanAuras()
	auraDirty = false
	for _, d in ipairs(defs) do
		if d.kind == "aura" then
			local a = FindAura(d)
			local st = a and plain(a.applications) or 0
			if a and (not d.stacks or (st or 0) >= d.stacks) then
				local exp, dur = plain(a.expirationTime), plain(a.duration)
				if not (exp and exp > 0 and dur and dur > 0) then exp, dur = nil, nil end
				Activate(d.key, "aura", { label = d.label, aura = true, exp = exp, dur = dur, win = d.dur, need = d.stacks, d = d })
			else
				Deactivate(d.key, "aura")
			end
		end
	end
end

-- 게임의 주문 반짝임 · 발동 그림 (포에버가 직접 정해 둔 발동)
function S.Glow(id, show)
	id = plain(id)
	if not id then return end
	local name = SpellName(id)
	if show then Log("glow+", id, name) end
	local d = DefByName(name)
	local key = d and d.key or ("g" .. id)
	if show then
		if d and d.kind == "react" and d.sup and GetTime() < d.sup then return end
		Activate(key, "glow", { label = d and d.label or name, win = d and d.dur or 0, aura = d and d.kind == "aura", d = d })
	else
		Deactivate(key, "glow")
	end
end

function S.Overlay(id, show)
	id = plain(id)
	if not show and not id then
		for k, e in pairs(active) do if e.srcs.ovl then Deactivate(k, "ovl") end end
		return
	end
	if not id then return end
	local name = SpellName(id)
	if show then Log("ovl+", id, name) end
	local d = DefByName(name)
	local key = d and d.key or ("o" .. id)
	if show then
		local exp, dur
		local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
		if ok and type(a) == "table" then
			exp, dur = plain(a.expirationTime), plain(a.duration)
			if not (exp and exp > 0 and dur and dur > 0) then exp, dur = nil, nil end
		end
		Activate(key, "ovl", { label = d and d.label or name, aura = true, exp = exp, dur = dur, win = d and d.dur or 0, need = d and d.stacks, d = d })
	else
		Deactivate(key, "ovl")
	end
end

-- 기술을 썼다 → 그 강조는 소모 (빨려 들며 사라짐)
function S.Cast(id)
	id = plain(id)
	local name = SpellName(id)
	if not name then return end
	for k, e in pairs(active) do
		local d = e.d
		if d and d.kind == "react" and d.dur > 0 and d.names[name] then
			d.sup = GetTime() + 8                            -- 같은 창에서 다시 켜지지 않게 (누를 수 없게 되면 풀림)
			Deactivate(k, nil, true)
		end
	end
end

function S.ClearReal()
	for k in pairs(active) do if k ~= "test" then active[k] = nil end end
	lastEnd = false
	S.Update()
end

-------------------------------------------------------------------------------
-- 미리 보기 · 명령
-------------------------------------------------------------------------------
local testToken = 0
function S.Preview(cls, i, life, consumeAfter)
	cls = cls or S.class or "ROGUE"
	local list = PROCS[cls]
	if not list or not (ns.PROC_STARS and ns.PROC_STARS[cls]) then return end
	local p = list[((i or 1) - 1) % #list + 1]
	testToken = testToken + 1
	local tok = testToken
	active.test = nil
	local dur = life or ((p.dur and p.dur > 0) and p.dur or 7)
	local now = GetTime()
	local label = ((GetLocale and GetLocale() or "koKR") == "koKR") and p.name or p.en
	active.test = { srcs = { test = true }, t0 = now, label = label, aura = true, cls = cls, need = p.stacks,
		exp = (p.dur and p.dur > 0) and now + p.dur or nil, dur = (p.dur and p.dur > 0) and p.dur or nil }
	if V.shown then V.holder:Hide() V.shown, V.ending = false, nil end
	S.Update()
	C_Timer.After(dur, function()
		if testToken == tok and active.test then Deactivate("test", nil, consumeAfter and true or false) end
	end)
end

function S.Use()
	if active.test then Deactivate("test", nil, true) return true end
end

function S.Demo(n)
	S.Preview(nil, n, 6, n % 2 == 0)
end

function S.Stop()
	testToken = testToken + 1
	active.test = nil
	if V.holder then V.holder:Hide() V.shown, V.ending, V.cur = false, nil, nil end
	S.Update()
end

local function Say(s) print("|cffFFF468FOA|r " .. s) end

function S.Diag()
	Say(string.format("별자리 · 직업 %s · 효과 %s · 크기 %.2f · 높이 %d", tostring(S.class), FX_ON() and "켜짐" or "꺼짐",
		Ink.db.stars.scale or 1, Ink.db.stars.y or 0))
	for _, d in ipairs(defs) do
		local st
		if d.kind == "react" then st = "주문 " .. tostring(d.cast or "모름") .. (d.cast and (Usable(d.cast) and " · 누를 수 있음" or " · 대기") or "")
		else st = FindAura(d) and "오라 있음" or "오라 없음" end
		local nm = {}
		for n in pairs(d.names) do nm[#nm + 1] = n end
		Say(string.format("  %s (%s) · %s · 이름 %s", d.label, d.kind == "react" and "반응" or "강화", st, table.concat(nm, "/")))
	end
	local l = Ink.db.starsLog or {}
	if #l > 0 then Say("최근 게임 발동 신호:") end
	for i = max(1, #l - 7), #l do print("|cff8E939B  " .. l[i] .. "|r") end
end

local allToken = 0
function S.Slash(arg)
	arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local db = Ink.db.stars
	local cmd, rest = arg:match("^(%S*)%s*(.-)$")
	if cmd == "크기" or cmd == "size" then
		local v = tonumber(rest)
		if v then db.scale = max(0.4, min(1.6, v)) end
		Say(string.format("별자리 크기 %.2f (기본 1 · 0.4~1.6)", db.scale or 1))
		S.Preview(V.cls ~= S.class and V.cls or nil, 1, 6)
	elseif cmd == "높이" or cmd == "y" or cmd == "height" then
		local v = tonumber(rest)
		if v then db.y = max(-300, min(300, floor(v + 0.5))) end
		Say(string.format("별자리 높이 %d (기본 0 · 위로 +, 아래로 -)", db.y or 0))
		S.Preview(V.cls ~= S.class and V.cls or nil, 1, 6)
	elseif cmd == "초기화" or cmd == "reset" then
		db.scale, db.y = 1, 0
		Say("별자리 크기 · 높이를 기본으로 되돌렸어요.")
		S.Preview(nil, 1, 6)
	elseif cmd == "사용" or cmd == "use" then
		if not S.Use() then Say("지금 미리 보기가 없어요. /foa 별자리 로 먼저 띄워 주세요.") end
	elseif cmd == "끄기" or cmd == "off" or cmd == "켜기" or cmd == "on" then
		local on = (cmd == "켜기" or cmd == "on")
		if ns.FX then ns.FX.set(KEY, on) end
		Say("별자리 발동 효과 " .. (on and "켜짐" or "꺼짐"))
	elseif cmd == "진단" or cmd == "diag" then
		S.Diag()
	elseif cmd == "전체" or cmd == "all" then
		allToken = allToken + 1
		local tok = allToken
		Say("9개 직업 별자리를 차례로 띄워요 (직업마다 3초 · 끝에 '사용'처럼 빨려 들어감).")
		for i, cls in ipairs(ORDER) do
			C_Timer.After((i - 1) * 3.4, function()
				if allToken ~= tok then return end
				S.Preview(cls, 1, 2.9, true)
				Say(string.format("%d/9 %s", i, cls))
			end)
		end
	elseif cmd == "" or tonumber(cmd) then
		V.pick = (tonumber(cmd) or (V.pick or 0) + 1)
		S.Preview(nil, V.pick)
	else
		local cls = CLASS_KO[cmd] or (PROCS[cmd:upper()] and cmd:upper())
		if cls then
			S.Preview(cls, tonumber(rest) or 1)
		else
			Say("/foa 별자리 [직업|전체|사용|크기 0.9|높이 20|초기화|진단|끄기|켜기]")
		end
	end
end

-------------------------------------------------------------------------------
local function HideBlizzardOverlay(on)
	local f = _G.SpellActivationOverlayFrame
	if f and f.SetAlpha then pcall(f.SetAlpha, f, on and 0 or 1) end
end

function M:Init()
	Ink.db.stars = Ink.db.stars or {}
	Prepare()
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "SPELL_ACTIVATION_OVERLAY_SHOW",
		"SPELL_ACTIVATION_OVERLAY_HIDE", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "LEARNED_SPELL_IN_TAB",
		"PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
	pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
		if event == "UNIT_AURA" then
			auraDirty = true
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			if FX_ON() then pcall(S.Cast, a3) end
		elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
			if FX_ON() then pcall(S.Glow, a1, event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") end
		elseif event == "SPELL_ACTIVATION_OVERLAY_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
			if FX_ON() then pcall(S.Overlay, a1, event == "SPELL_ACTIVATION_OVERLAY_SHOW") end
		elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DEAD" then
			if event == "PLAYER_ENTERING_WORLD" then pcall(Prepare) end
			S.ClearReal()
			auraDirty = true
			HideBlizzardOverlay(FX_ON())
		elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
			if V.shown then Layout() end
		else
			pcall(S.Resolve)
		end
	end)
	C_Timer.NewTicker(0.1, function()
		if not FX_ON() then return end
		local ok, err = pcall(Poll)
		if not ok then Ink:LogError("Stars.Poll: " .. tostring(err)) end
		if auraDirty then
			ok, err = pcall(ScanAuras)
			if not ok then Ink:LogError("Stars.Aura: " .. tostring(err)) end
		end
		-- 게임 신호만 있고 꺼짐 신호가 안 온 강조는 시간 + 1초 뒤 정리
		local now = GetTime()
		for k, e in pairs(active) do
			if k ~= "test" and e.exp and now > e.exp + 1 and not e.srcs.poll and not e.srcs.aura then Deactivate(k, nil, false) end
		end
	end)
	if ns.FX then
		ns.FX.onToggle[KEY] = function(on)
			HideBlizzardOverlay(on)
			if not on then S.ClearReal() end
		end
	end
end
