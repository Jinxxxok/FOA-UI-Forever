-- InkUI · 유닛프레임 (플레이어 / 대상 / 대상의 대상 / 주시 대상)

local _, ns = ...
local Ink = ns.Ink
local M = Ink:Module("Units")
local F, C = Ink.font, Ink.c
local safe, plain = Ink.safe, Ink.plain

M.frames = {}

-------------------------------------------------------------------------------
-- 곡선 (secret 체력값을 비교하지 않고 색/퍼센트를 얻기 위함)
-------------------------------------------------------------------------------
local function BuildCurves()
	if M.lowCurve or not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return end
	local c = C_CurveUtil.CreateColorCurve()
	c:SetType(Enum.LuaCurveType.Step)
	c:AddPoint(0, CreateColor(C.red[1], C.red[2], C.red[3], 1))
	c:AddPoint(0.35, CreateColor(C.text[1], C.text[2], C.text[3], 1))
	M.lowCurve = c
end
ns.BuildLowCurve = function() BuildCurves(); return M.lowCurve end

local function HealthPercentText(unit)
	if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
		local ok, s = pcall(function()
			return string.format("%d", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
		end)
		if ok then return s end
	end
	local h, m = plain(UnitHealth(unit)), plain(UnitHealthMax(unit))
	if h and m and m > 0 then return string.format("%d", h / m * 100) end
	return ""
end
ns.HealthPercentText = HealthPercentText

-- 체력 35% 미만이면 빨강, 아니면 기본색
local function LowColor(unit)
	if M.lowCurve and UnitHealthPercent then
		local ok, col = pcall(UnitHealthPercent, unit, true, M.lowCurve)
		if ok and col then return col:GetRGB() end
	end
	local h, m = plain(UnitHealth(unit)), plain(UnitHealthMax(unit))
	if h and m and m > 0 and h / m < 0.35 then return C.red[1], C.red[2], C.red[3] end
	return C.text[1], C.text[2], C.text[3]
end
ns.LowColor = LowColor

-- 직업별 Ink 색. 블리자드 직업색을 바탕으로 하되 같은 직업의 자원(기력·분노·마나·격노…) 색과
-- 겹치는 경우엔 그 직업 분위기에 맞는 다른 색을 골랐다.
local CLASS_TINT = {
	WARRIOR = "D9A877", PALADIN = "F4A3C8", HUNTER = "A9D88B", ROGUE = "B9A4FF", PRIEST = "E4E8F2",
	DEATHKNIGHT = "E3626D", SHAMAN = "3FD3C8", MAGE = "86DDF2", WARLOCK = "A797FF", MONK = "3EE0A6",
	DRUID = "FF9547", DEMONHUNTER = "86E06C", EVOKER = "4FC1A6",
}
local tintCurves = {}
-- 체력과 상관없는 직업 Ink 색 (캐릭터 창 등)
function ns.ClassTint(class)
	local hex = class and CLASS_TINT[class]
	local col = hex and Ink.hex(hex) or C.text
	return col[1], col[2], col[3]
end
-- 직업 이름("ROGUE")으로 블리자드 공식 직업 색 (미터기처럼 직업을 한눈에 구분해야 하는 곳)
--  다른 애드온의 직업색 변경(CUSTOM_CLASS_COLORS)도 따른다.
local OFFICIAL = {
	WARRIOR = "C69B6D", PALADIN = "F48CBA", HUNTER = "AAD372", ROGUE = "FFF468", PRIEST = "FFFFFF",
	DEATHKNIGHT = "C41E3A", SHAMAN = "0070DD", MAGE = "3FC7EB", WARLOCK = "8788EE", MONK = "00FF98",
	DRUID = "FF7C0A", DEMONHUNTER = "A330C9", EVOKER = "33937F",
}
function ns.ClassColorOf(class)
	if class then
		local t = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
		if t and t.r then return t.r, t.g, t.b end
		local hex = OFFICIAL[class]
		if hex then
			local c = Ink.hex(hex)
			return c[1], c[2], c[3]
		end
	end
	return C.text[1], C.text[2], C.text[3]
end
function ns.PlayerTint(u)
	local _, class = UnitClass(u)
	class = plain(class)
	local hex = class and CLASS_TINT[class]
	local col = hex and Ink.hex(hex) or C.text
	if not (C_CurveUtil and UnitHealthPercent) then return col[1], col[2], col[3] end
	local c = tintCurves[hex or "x"]
	if not c then
		c = C_CurveUtil.CreateColorCurve()
		c:SetType(Enum.LuaCurveType.Step)
		c:AddPoint(0, CreateColor(C.red[1], C.red[2], C.red[3], 1))
		c:AddPoint(0.35, CreateColor(col[1], col[2], col[3], 1))
		tintCurves[hex or "x"] = c
	end
	local ok, res = pcall(UnitHealthPercent, u, true, c)
	if ok and res then return res:GetRGB() end
	return col[1], col[2], col[3]
end

local function ApplyColor(r, g, b, ...)
	for i = 1, select("#", ...) do
		local w = select(i, ...)
		if w then
			if w.SetTextColor then safe(w.SetTextColor, w, r, g, b)
			elseif w.SetStatusBarColor then safe(w.SetStatusBarColor, w, r, g, b) end
		end
	end
end

local function ClassColor(unit)
	local _, class = UnitClass(unit)
	class = plain(class)
	if class then
		local col = C_ClassColor and C_ClassColor.GetClassColor(class) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
		if col then return col.r, col.g, col.b end
	end
	return C.text[1], C.text[2], C.text[3]
end
ns.ClassColor = ClassColor

-- 대상 색: 플레이어는 직업색, NPC는 적대/중립/우호
local function UnitColor(unit)
	if plain(UnitIsPlayer(unit)) then return ClassColor(unit) end
	if plain(UnitIsTapDenied(unit)) then return 0.55, 0.57, 0.6 end
	local reaction = plain(UnitReaction(unit, "player"))
	if reaction then
		if reaction <= 3 then return C.red[1], C.red[2], C.red[3] end
		if reaction == 4 then return C.orange[1], C.orange[2], C.orange[3] end
		return C.green[1], C.green[2], C.green[3]
	end
	return C.red[1], C.red[2], C.red[3]
end

-------------------------------------------------------------------------------
-- 공용 생성기
-------------------------------------------------------------------------------
local function UnitButton(name, unit, w, h)
	local f = CreateFrame("Button", name, Ink.root, "SecureUnitButtonTemplate")
	f:SetSize(w, h)
	f.unit = unit
	f.realUnit = unit
	f:SetAttribute("unit", unit)
	f:SetAttribute("*type1", "target")
	f:SetAttribute("*type2", "togglemenu")
	f:RegisterForClicks("AnyUp")
	f:SetScript("OnEnter", function(self)
		if UnitFrame_OnEnter then UnitFrame_OnEnter(self) end
	end)
	f:SetScript("OnLeave", function(self)
		if UnitFrame_OnLeave then UnitFrame_OnLeave(self) end
	end)
	if unit ~= "player" then RegisterUnitWatch(f) end
	M.frames[unit] = f
	return f
end

local AURA_SIZE, AURA_GAP = 22, 3

local function AuraRow(parent, size, max)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(max * (size + AURA_GAP), size + 12)
	row.size, row.max, row.buttons = size, max, {}
	return row
end

local function AuraButton(row, i)
	local b = row.buttons[i]
	if b then return b end
	b = Ink:AuraButton(row, row.size)
	b:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (row.size + AURA_GAP), 0)
	b:EnableMouse(true)
	b:SetScript("OnEnter", function(self)
		if not self.auraInstanceID then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		safe(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, self.unit, self.auraInstanceID)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	row.buttons[i] = b
	return b
end
ns.AuraButton = AuraButton
ns.AuraRow = AuraRow

-- 해제 색 곡선 (oUF 방식: Step 곡선에 해제 종류 번호별 색)
local dispelCurve
local function DispelCurve()
	if dispelCurve or not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return dispelCurve end
	dispelCurve = C_CurveUtil.CreateColorCurve()
	dispelCurve:SetType(Enum.LuaCurveType.Step)
	for idx, col in pairs(Ink.dispel) do
		dispelCurve:AddPoint(idx, CreateColor(col[1], col[2], col[3], col[4] or 1))
	end
	return dispelCurve
end
ns.DispelCurve = DispelCurve

-- accent: 테두리를 해제 종류 색으로 칠할지
-- 오라 목록 읽기: 12.x 새 API(GetUnitAuras) → 슬롯 방식 → 순번 방식 순서로 시도
local function ReadAuras(unit, filter, max)
	local list
	if C_UnitAuras.GetUnitAuras then
		local ok, res = pcall(C_UnitAuras.GetUnitAuras, unit, filter, max)
		if ok and type(res) == "table" then list = res end
	end
	if not list and C_UnitAuras.GetAuraSlots then
		local ok = pcall(function()
			local slots = { C_UnitAuras.GetAuraSlots(unit, filter, max) }
			local l = {}
			for i = 2, #slots do
				local d = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
				if d then l[#l + 1] = d end
			end
			list = l
		end)
		if not ok then list = nil end
	end
	if not list and C_UnitAuras.GetAuraDataByIndex then
		local l = {}
		for i = 1, max do
			local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
			if not ok then l = nil break end
			if not d then break end
			l[#l + 1] = d
		end
		list = l
	end
	return list
end
ns.ReadAuras = ReadAuras

local function RenderAura(b, unit, data, colorByDispel)
	b.unit, b.auraInstanceID = unit, data.auraInstanceID
	b.icon:SetTexture(data.icon)
	local id = data.auraInstanceID
	local dur = id and C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(unit, id)
	if dur and b.cd.SetCooldownFromDurationObject then
		b.cd:SetCooldownFromDurationObject(dur)
		b.cd:Show()
	else
		local d, e = plain(data.duration), plain(data.expirationTime)
		if d and e and d > 0 then
			b.cd:SetCooldown(e - d, d)
			b.cd:Show()
		else
			b.cd:Hide()
		end
	end
	if id and C_UnitAuras.GetAuraApplicationDisplayCount then
		b.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit, id, 2, 99))
	else
		b.count:SetText("")
	end
	local colored = false
	if colorByDispel and id and C_UnitAuras.GetAuraDispelTypeColor and DispelCurve() then
		local col = C_UnitAuras.GetAuraDispelTypeColor(unit, id, dispelCurve)
		if col then
			b.skin.border:SetVertexColor(col:GetRGBA())
			colored = true
		end
	end
	if not colored then b.skin.border:SetVertexColor(1, 1, 1, 0.16) end
	b:Show()
end

-- 오라 줄 갱신. 칸 하나에서 오류가 나도 나머지는 그린다.
local function UpdateAuras(row, unit, filter, colorByDispel)
	local list = ReadAuras(unit, filter, row.max)
	if not list then
		Ink.auraErr = date("%H:%M:%S") .. " " .. tostring(unit) .. " " .. tostring(filter) .. " : 오라 목록을 못 읽음"
		return nil
	end
	local shown = 0
	local okLoop, loopErr = pcall(function()
		for _, data in ipairs(list) do
			if shown >= row.max then break end
			local b = AuraButton(row, shown + 1)
			local ok, err = pcall(RenderAura, b, unit, data, colorByDispel)
			if ok then
				shown = shown + 1
			else
				Ink.auraErr = date("%H:%M:%S") .. " " .. tostring(unit) .. " : " .. tostring(err)
			end
		end
	end)
	if not okLoop then Ink.auraErr = date("%H:%M:%S") .. " " .. tostring(unit) .. " loop: " .. tostring(loopErr) end
	for i = shown + 1, #row.buttons do row.buttons[i]:Hide() end
	return shown
end
ns.UpdateAuras = UpdateAuras

-------------------------------------------------------------------------------
-- 12.1 오라 컨테이너
--  12.1부터 애드온 코드는 전투 중(오라가 비공개일 때) 오라 목록을 직접 읽을 수 없다.
--  대신 블리자드 엔진이 오라를 골라 버튼에 그려 주는 AuraContainer 를 쓴다.
--  버튼 꾸미기는 initializeFrame(버튼이 만들어지는 순간) 안에서만 해야 한다.
--  그 뒤로 버튼 자체는 건드리지 않는다 (비공개 상황에서 거부됨).
--  컨테이너를 못 쓰는 클라이언트에서는 예전 방식(직접 읽기)으로 돌아간다.
-------------------------------------------------------------------------------
local function Call(obj, names, ...)
	for _, n in ipairs(names) do
		if obj[n] then return pcall(obj[n], obj, ...) end
	end
	return false
end

local function DispelTintStyle()
	local e = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	if e and e.PreserveAsset ~= nil then return e.PreserveAsset end
	local legacy = (Enum and Enum.CustomAuraButtonBorderStyle) or AuraButtonBorderStyle
	return legacy and legacy.Color
end

local function RegisterDispelTexture(btn, tex)
	local style = DispelTintStyle()
	local fn = btn.AddDispelTypeTexture or btn.SetAuraBorder
	if style == nil or not fn then return false end
	return pcall(fn, btn, tex, { style = style, showWhenHarmful = true, showWhenHelpful = false })
end

-- 버튼 하나 꾸미기 (Ink:AuraButton 과 같은 모양)
local function AuraInit(size, opts)
	return function(btn)
		pcall(btn.SetSize, btn, size, size)
		pcall(btn.SetMouseClickEnabled, btn, false)
		if opts.noMouse then pcall(btn.SetMouseMotionEnabled, btn, false) end

		local bg = Ink:Round(btn, "BACKGROUND", true, false, -8)
		bg:SetAllPoints()
		bg:SetVertexColor(0, 0, 0, 0.6)

		local icon = btn:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		if btn.CreateMaskTexture and icon.AddMaskTexture then
			local mask = btn:CreateMaskTexture()
			mask:SetTexture(Ink.tex.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(icon)
			icon:AddMaskTexture(mask)
		end

		local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
		cd:SetPoint("TOPLEFT", 1, -1)
		cd:SetPoint("BOTTOMRIGHT", -1, 1)
		cd:SetReverse(true)
		Ink:SkinCooldown(cd, true)
		if cd.SetCountdownFont then safe(cd.SetCountdownFont, cd, "InkUIFontAuraTimer") end
		if cd.SetCountdownAbbrevThreshold then safe(cd.SetCountdownAbbrevThreshold, cd, 600) end
		local cfs = cd.GetCountdownFontString and cd:GetCountdownFontString()
		if cfs then
			cfs:ClearAllPoints()
			cfs:SetPoint("TOP", btn, "BOTTOM", 0, -2)
			cfs:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		end
		if opts.noTimer then safe(cd.SetHideCountdownNumbers, cd, true) end

		local top = CreateFrame("Frame", nil, btn)
		top:SetAllPoints()
		top:SetFrameLevel(cd:GetFrameLevel() + 2)
		top:EnableMouse(false)
		local border = Ink:Round(top, "OVERLAY", true, true)
		border:SetAllPoints()
		border:SetVertexColor(1, 1, 1, 0.16)
		local tint = Ink:Round(top, "OVERLAY", true, true, 2)
		tint:SetAllPoints() -- 보이기/색은 엔진이 디버프 종류에 맞춰 정한다
		local count = Ink:Text(top, F.latinB, 9, C.text, "RIGHT")
		count:SetPoint("BOTTOMRIGHT", 1, 0)
		count:SetText("")

		pcall(btn.SetIcon, btn, icon)
		pcall(btn.SetDurationCooldown, btn, cd)
		pcall(btn.SetApplicationCount, btn, count, {})
		if opts.dispel ~= false then RegisterDispelTexture(btn, tint) end
	end
end

local SortMethod = function() return AuraContainerSortMethod and AuraContainerSortMethod.Default end
local SortDir = function() return AuraContainerSortDirection and AuraContainerSortDirection.Normal end

local function NewContainer(parent)
	if not (AnchorUtil and AnchorUtil.FlowDirection) then return nil end
	local ok, c = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	if not ok or not c or not c.AddAuraGroup then return nil end
	c:SetSize(1, 1)
	return c
end

local BoxMT = {}
BoxMT.__index = BoxMT

-- groups = { { key = "mine", filter = "HARMFUL|PLAYER" }, ... } 처음 것만 켜진 채로 시작
function ns.AuraBox(parent, size, max, opts)
	opts = opts or {}
	local box = setmetatable({ size = size, max = max, opts = opts }, BoxMT)
	box.groups = opts.groups or { { key = "all", filter = "HARMFUL" } }
	box.active = box.groups[1].key
	local c = NewContainer(parent)
	if c then
		local ok = pcall(function()
			local FD = AnchorUtil.FlowDirection
			local up = opts.growUp
			Call(c, { "SetFlowLayoutAnchorPoint", "SetAuraLayoutAnchorPoint" }, up and "BOTTOMLEFT" or "TOPLEFT")
			Call(c, { "SetFlowLayoutGrowthDirection", "SetAuraLayoutGrowthDirection" }, FD.Right, up and FD.Up or FD.Down)
			Call(c, { "SetFlowLayoutMaximumLineSize", "SetAuraLayoutRowWidth" }, max * (size + AURA_GAP) + 0.4)
			for i, g in ipairs(box.groups) do
				c:AddAuraGroup(g.key, g.filter, {
					maxFrameCount = (i == 1) and max or 0,
					sortMethod = SortMethod(),
					sortDirection = SortDir(),
					initializeFrame = AuraInit(size, opts),
					layout = { elementWidth = size, elementHeight = size, elementSpacing = AURA_GAP, lineSpacing = 12 },
				})
			end
			c:SetUnit("none")
		end)
		if ok then box.c = c else c:Hide() end
	end
	if not box.c then box.row = AuraRow(parent, size, max) end
	return box
end

function BoxMT:Frame() return self.c or self.row end
function BoxMT:SetPoint(...)
	local f = self:Frame()
	f:ClearAllPoints()
	f:SetPoint(...)
end
function BoxMT:SetShown(v) self:Frame():SetShown(v) end
function BoxMT:Hide() self:Frame():Hide() end
function BoxMT:Show() self:Frame():Show() end
function BoxMT:IsLive() return self.c ~= nil end

-- 어떤 줄(그룹)을 보일지 고른다 (예: 적 대상이면 내 디버프만)
function BoxMT:SetGroup(key)
	if self.active == key then return end
	self.active = key
	if not self.c then return end
	for _, g in ipairs(self.groups) do
		pcall(self.c.SetAuraGroupMaxFrameCount, self.c, g.key, g.key == key and self.max or 0)
	end
end

-- 유닛 연결 + 다시 읽기. force: 같은 유닛 토큰이라도 대상이 바뀌었을 때
function BoxMT:SetUnit(unit, force)
	unit = unit or "none"
	if self.c then
		if self.unit ~= unit then
			self.unit = unit
			pcall(self.c.SetUnit, self.c, unit)
			force = true
		end
		if force and unit ~= "none" then pcall(self.c.UpdateAllAuras, self.c) end
		return
	end
	self.unit = unit
	if unit == "none" then
		for _, b in ipairs(self.row.buttons) do b:Hide() end
		return
	end
	local filter
	for _, g in ipairs(self.groups) do if g.key == self.active then filter = g.filter end end
	UpdateAuras(self.row, unit, filter or "HARMFUL", self.opts.dispel ~= false)
end

-- 해제 가능한 디버프 감시: 걸리면 build 가 만든 텍스처들이 그 종류 색으로 보인다.
-- build(btn) 은 버튼의 자식 텍스처 목록을 돌려준다 (위치는 프레임 쪽에 맞춰도 된다).
function ns.DispelWatch(parent, build, level)
	local c = NewContainer(parent)
	if not c then return nil end
	local ok = pcall(function()
		c:SetPoint("CENTER", parent, "CENTER")
		if level then c:SetFrameLevel(level) end
		c:AddAuraSlot("dispel", "HARMFUL|RAID", {
			sortMethod = SortMethod(),
			sortDirection = SortDir(),
			initializeFrame = function(btn)
				pcall(btn.SetSize, btn, 1, 1)
				pcall(btn.SetPoint, btn, "CENTER", parent, "CENTER")
				pcall(btn.SetMouseClickEnabled, btn, false)
				pcall(btn.SetMouseMotionEnabled, btn, false)
				for _, tex in ipairs(build(btn)) do RegisterDispelTexture(btn, tex) end
			end,
		})
		c:SetUnit("none")
	end)
	if not ok then c:Hide() return nil end
	local w = { c = c }
	function w:SetUnit(unit, force)
		unit = unit or "none"
		if self.unit ~= unit then
			self.unit = unit
			pcall(c.SetUnit, c, unit)
			force = true
		end
		if force and unit ~= "none" then pcall(c.UpdateAllAuras, c) end
	end
	return w
end

-- 시전바 (secret 안전: DurationObject + SetTimerDuration)
local function CastBar(parent, w, barH, fillColor, nameColor)
	local cb = CreateFrame("Frame", nil, parent)
	cb:SetSize(w, 14 + 4 + barH)
	cb.name = Ink:Text(cb, F.semi, 11, nameColor or C.text, "LEFT")
	cb.name:SetPoint("TOPLEFT")
	cb.name:SetWidth(w - 50)
	cb.time = Ink:Text(cb, F.latin, 11, C.muted, "RIGHT")
	cb.time:SetPoint("TOPRIGHT")
	cb.bar = Ink:Bar(cb, w, barH, fillColor, { fillColor[1], fillColor[2], fillColor[3], 0.15 })
	cb.bar:SetPoint("TOPLEFT", 0, -18)
	cb.shield = cb.bar:CreateTexture(nil, "OVERLAY")
	cb.shield:SetAllPoints(cb.bar:GetStatusBarTexture())
	cb.shield:SetColorTexture(0.55, 0.58, 0.62, 1)
	cb.shield:SetAlpha(0)
	cb:Hide()
	cb:SetScript("OnUpdate", function(self)
		if self.preview then return end
		if self.dur then
			safe(function() self.time:SetFormattedText("%.1f", self.dur:GetRemainingDuration()) end)
		elseif self.endTime then
			local now = GetTime() * 1000
			self.bar:SetValue(now)
			self.time:SetFormattedText("%.1f", math.max(0, (self.endTime - now) / 1000))
		end
	end)
	return cb
end

local function CastUpdate(cb, unit)
	if not cb or cb.preview then return end
	local name, text, _, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(unit)
	local dur, dir
	local E = Enum.StatusBarTimerDirection
	if name then
		dur = UnitCastingDuration and UnitCastingDuration(unit)
		dir = E and E.ElapsedTime
	else
		name, text, _, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
		if name then
			dur = UnitChannelDuration and UnitChannelDuration(unit)
			dir = E and E.RemainingTime
		end
	end
	if not name then
		cb.dur, cb.endTime = nil, nil
		cb:Hide()
		return
	end
	cb.name:SetText(text or name)
	cb.dur, cb.endTime = nil, nil
	if dur and cb.bar.SetTimerDuration then
		local interp = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
		if not pcall(cb.bar.SetTimerDuration, cb.bar, dur, interp, dir) then
			pcall(cb.bar.SetTimerDuration, cb.bar, dur)
		end
		cb.dur = dur
	else
		local s, e = plain(startTime), plain(endTime)
		if s and e then
			cb.bar:SetMinMaxValues(s, e)
			cb.endTime = e
		end
	end
	if cb.shield.SetAlphaFromBoolean then
		safe(cb.shield.SetAlphaFromBoolean, cb.shield, notInterruptible, 1, 0)
	else
		cb.shield:SetAlpha(plain(notInterruptible) and 1 or 0)
	end
	cb:Show()
end
ns.CastUpdate = CastUpdate
ns.CastBar = CastBar

-------------------------------------------------------------------------------
-- 플레이어  (시안: 왼쪽에 이름/바/버프, 오른쪽에 큰 %)
-------------------------------------------------------------------------------
local P_COL, P_NUM = 258, 108
local P_W = P_COL + P_NUM + 16

function M:BuildPlayer()
	local f = UnitButton("InkUIPlayer", "player", P_W, 84)

	f.pct = Ink:Text(f, F.num, 56, C.text, "RIGHT")
	f.pct:SetPoint("TOPRIGHT", f, "TOPLEFT", P_COL + P_NUM, 8)
	f.pctSign = Ink:Text(f, F.num, 18, C.muted, "LEFT")
	f.pctSign:SetPoint("BOTTOMLEFT", f.pct, "BOTTOMRIGHT", 1, 9)
	f.pctSign:SetText("%")
	f.hpText = Ink:Text(f, F.sans, 11, C.muted, "RIGHT")
	f.hpText:SetPoint("TOPRIGHT", f, "TOPLEFT", P_COL + P_NUM + 14, -56)

	f.name = Ink:Text(f, F.bold, 14, C.text, "LEFT")
	f.name:SetPoint("TOPLEFT", 0, -2)
	f.name:SetWidth(P_COL - 70)
	f.badge = f:CreateTexture(nil, "OVERLAY")
	f.badge:SetSize(18, 18)
	f.badge:SetPoint("RIGHT", f, "TOPLEFT", P_COL, -10)
	f.level = Ink:Text(f, F.latinB, 12, C.soft, "RIGHT")
	f.level:SetPoint("RIGHT", f.badge, "LEFT", -4, 0)
	-- 이름 오른쪽: 전투 중(검) / 휴식 중(달) 표시
	f.status = f:CreateTexture(nil, "OVERLAY")
	f.status:SetSize(13, 13)
	f.status:Hide()

	f.hp = Ink:Bar(f, P_COL, 6, C.text)
	f.hp:SetPoint("TOPLEFT", 0, -30)

	f.auras = ns.AuraBox(f, AURA_SIZE, 10)
	f.auras:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -44)
	f.auraFilter = "HARMFUL"
	self.player = f
end

-------------------------------------------------------------------------------
-- 대상  (시안: 왼쪽에 큰 %, 오른쪽에 이름/바/자원/시전/디버프)
-------------------------------------------------------------------------------
local T_COL = 124
local T_W = T_COL + 260

function M:BuildTarget()
	local f = UnitButton("InkUITarget", "target", T_W, 120)
	local cw = T_W - T_COL

	f.pct = Ink:Text(f, F.num, 56, C.red, "LEFT")
	f.pct:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 8)
	f.pctSign = Ink:Text(f, F.num, 18, C.muted, "LEFT")
	f.pctSign:SetPoint("BOTTOMLEFT", f.pct, "BOTTOMRIGHT", 1, 9)
	f.pctSign:SetText("%")
	f.hpText = Ink:Text(f, F.sans, 11, C.muted, "LEFT")
	f.hpText:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -56)

	f.name = Ink:Text(f, F.bold, 14, C.text, "LEFT")
	f.name:SetPoint("TOPLEFT", T_COL, -2)
	f.name:SetWidth(cw - 90)
	f.badge = f:CreateTexture(nil, "OVERLAY")
	f.badge:SetSize(18, 18)
	f.badge:SetPoint("RIGHT", f, "TOPRIGHT", 0, -10)
	f.level = Ink:Text(f, F.latinB, 12, C.soft, "RIGHT")
	f.level:SetPoint("RIGHT", f.badge, "LEFT", -4, 0)

	f.hp = Ink:Bar(f, cw, 6, C.red)
	f.hp:SetPoint("TOPLEFT", T_COL, -30)

	f.power = Ink:Bar(f, cw - 72, 3, C.mana)
	f.power:SetPoint("TOPLEFT", T_COL, -44)
	f.powerText = Ink:Text(f, F.sans, 10, C.muted, "RIGHT")
	f.powerText:SetPoint("RIGHT", f, "TOPRIGHT", 0, -45.5)
	f.powerText:SetWidth(66)

	f.cast = CastBar(f, cw, 3, C.orange, C.orange)
	f.cast:SetPoint("TOPLEFT", T_COL, -54)

	-- 적이면 내가 건 디버프만, 아군이면 전부
	f.auras = ns.AuraBox(f, AURA_SIZE, 10, { groups = {
		{ key = "mine", filter = "HARMFUL|PLAYER" },
		{ key = "all", filter = "HARMFUL" },
	} })
	f.auras:SetPoint("TOPLEFT", f, "TOPLEFT", T_COL, -82)
	f.auraFilter = "HARMFUL|PLAYER"
	self.target = f
end

-------------------------------------------------------------------------------
-- 대상의 대상 / 주시 대상
-------------------------------------------------------------------------------
function M:BuildToT()
	local f = UnitButton("InkUITargetTarget", "targettarget", 140, 40)
	f.label = Ink:Text(f, F.sans, 10, C.muted, "LEFT")
	f.label:SetPoint("TOPLEFT")
	f.label:SetText("대상의 대상")
	f.name = Ink:Text(f, F.semi, 12, C.accent, "LEFT")
	f.name:SetPoint("TOPLEFT", 0, -15)
	f.name:SetWidth(140)
	f.hp = Ink:Bar(f, 140, 2, C.text)
	f.hp:SetPoint("TOPLEFT", 0, -34)
	local t = 0
	f:SetScript("OnUpdate", function(self, e)
		t = t + e
		if t < 0.2 then return end
		t = 0
		if UnitExists(self.unit) then M:UpdateUnit(self) end
	end)
	self.tot = f
end

function M:BuildFocus()
	local f = UnitButton("InkUIFocus", "focus", 166, 30)
	f.label = Ink:Text(f, F.sans, 12, C.muted, "LEFT")
	f.label:SetPoint("TOPLEFT", 0, -4)
	f.label:SetText("주시")
	f.name = Ink:Text(f, F.semi, 12, C.text, "LEFT")
	f.name:SetPoint("LEFT", f.label, "RIGHT", 4, 0)
	f.name:SetWidth(100)
	f.pct = Ink:Text(f, F.num, 18, C.red, "RIGHT")
	f.pct:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	f.hp = Ink:Bar(f, 166, 3, C.red)
	f.hp:SetPoint("TOPLEFT", 0, -24)
	self.focus = f
end

-------------------------------------------------------------------------------
-- 갱신
-------------------------------------------------------------------------------
function M:UpdateHealth(f)
	local u = f.unit
	if not UnitExists(u) then return end
	safe(function()
		f.hp:SetMinMaxValues(0, UnitHealthMax(u))
		f.hp:SetValue(UnitHealth(u))
	end)
	local dead = plain(UnitIsDeadOrGhost(u))
	if f.pct then
		if dead then
			if not f.dead then M:BuildDead(f) end
			f.pct:Hide()
			if f.pctSign then f.pctSign:Hide() end
			local ghost = plain(UnitIsGhost(u))
			f.dead.word:SetText(ghost and "유령" or "사망")
			f.dead.tag:SetText(ghost and "GHOST" or "DEAD")
			f.dead:Show()
		else
			if f.dead then f.dead:Hide() end
			f.pct:Show()
			f.pct:SetText(HealthPercentText(u))
			if f.pctSign then f.pctSign:Show() end
		end
	end
	if f.hpText then
		local ok = pcall(function()
			f.hpText:SetText(Ink.Num(UnitHealth(u)) .. " / " .. Ink.Num(UnitHealthMax(u)))
		end)
		if not ok then f.hpText:SetText("") end
	end
	if dead then
		if f.hp then f.hp:SetValue(0) end
		return
	end
	if f == self.player then
		-- 플레이어는 직업별 Ink 색 (자원 색과 겹치지 않게 고른 색). 35% 미만은 빨강.
		ApplyColor(ns.PlayerTint(u), f.pct, f.hp)
	elseif f == self.tot then
		ApplyColor(LowColor(u), f.pct, f.hp)
	end
end

-- 사망 표시: 큰 % 자리에 그대로 들어가도록 같은 정렬·같은 높이로
--   DEAD   (작은 빨간 영문)
--   사망   (회색 한글)
function M:BuildDead(f)
	local big = select(2, f.pct:GetFont()) >= 40
	local d = CreateFrame("Frame", nil, f)
	d:SetAllPoints(f.pct)
	local right = (f.pct:GetJustifyH() == "RIGHT")
	local just = right and "RIGHT" or "LEFT"
	d.tag = Ink:Text(d, F.latinB, big and 10 or 8, C.red, just)
	d.word = Ink:Text(d, F.semi, big and 26 or 12, C.muted, just)
	if big then
		-- 숫자(56px) 높이 안에서 세로 가운데쯤
		d.word:SetPoint(right and "RIGHT" or "LEFT", f.pct, right and "RIGHT" or "LEFT", right and 8 or 2, -6)
		d.tag:SetPoint(right and "BOTTOMRIGHT" or "BOTTOMLEFT", d.word, right and "TOPRIGHT" or "TOPLEFT", 0, 2)
		d.line = d:CreateTexture(nil, "ARTWORK")
		d.line:SetColorTexture(C.red[1], C.red[2], C.red[3], 0.6)
		d.line:SetSize(18, 1)
		d.line:SetPoint(right and "RIGHT" or "LEFT", d.tag, right and "LEFT" or "RIGHT", right and -6 or 6, 0)
	else
		d.tag:Hide()
		d.word:SetPoint(right and "RIGHT" or "LEFT", f.pct, right and "RIGHT" or "LEFT", 0, 0)
	end
	d:Hide()
	f.dead = d
end

function M:UpdatePower(f)
	if not f.power then return end
	local u = f.unit
	local ptype = plain(UnitPowerType(u)) or 0
	local col = Ink.powerColor[ptype] or C.mana
	f.power:SetStatusBarColor(col[1], col[2], col[3])
	safe(function()
		f.power:SetMinMaxValues(0, UnitPowerMax(u, ptype))
		f.power:SetValue(UnitPower(u, ptype))
	end)
	local maxp = plain(UnitPowerMax(u, ptype))
	if maxp == 0 then
		f.power:Hide()
		f.powerText:SetText("")
		return
	end
	f.power:Show()
	local token = plain(select(2, UnitPowerType(u)))
	local label = (token and _G[token]) or ""
	local ok = pcall(function()
		if UnitPowerPercent and CurveConstants then
			f.powerText:SetText(string.format("%s %d%%", label, UnitPowerPercent(u, ptype, true, CurveConstants.ScaleTo100)))
		else
			f.powerText:SetText(string.format("%s %d", label, UnitPower(u, ptype)))
		end
	end)
	if not ok then f.powerText:SetText(label) end
	f.powerText:SetTextColor(col[1], col[2], col[3])
end

function M:UpdateInfo(f)
	local u = f.unit
	if not UnitExists(u) then return end
	f.name:SetText((UnitName(u)))
	if f == self.tot then f.name:SetTextColor(ClassColor(u)) end
	if f.level then
		local lvl = plain(UnitLevel(u))
		f.level:SetText((lvl and lvl > 0) and tostring(lvl) or "??")
		self:UpdateBadge(f)
	end
	if f == self.player then self:UpdateStatus() end
	if f == self.target or f == self.focus then
		local r, g, b = UnitColor(u)
		f.hp:SetStatusBarColor(r, g, b)
		if not plain(UnitIsDeadOrGhost(u)) then f.pct:SetTextColor(r, g, b) end
		f.name:SetAlpha(plain(UnitIsDeadOrGhost(u)) and 0.5 or 1)
	end
end

-- 레벨 옆 표시: 플레이어면 직업 아이콘, NPC면 정예(금) / 희귀(은) 표시
local CLASS_FALLBACK = "Interface\\TargetingFrame\\UI-Classes-Circles"
local function HasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

function M:UpdateBadge(f)
	local u, b = f.unit, f.badge
	if not b then return end
	b:SetVertexColor(1, 1, 1, 1)
	b:SetTexCoord(0, 1, 0, 1)
	if plain(UnitIsPlayer(u)) then
		local _, class = UnitClass(u)
		class = plain(class)
		if class then
			-- 배경 없는 카툰풍 직업 문장 (파티 찾기 창의 직업 아이콘)
			local cartoon = "groupfinder-icon-class-" .. class:lower()
			local crest = "GarrMission_ClassIcon-" .. (class == "DEATHKNIGHT" and "DeathKnight" or class == "DEMONHUNTER" and "DemonHunter" or (class:sub(1, 1) .. class:sub(2):lower()))
			if HasAtlas(cartoon) then
				b:SetAtlas(cartoon)
			elseif HasAtlas(crest) then
				b:SetAtlas(crest)
			elseif HasAtlas("classicon-" .. class:lower()) then
				b:SetAtlas("classicon-" .. class:lower())
			elseif CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
				b:SetTexture(CLASS_FALLBACK)
				b:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
			end
			b:Show()
			return
		end
	end
	local cls = plain(UnitClassification(u))
	local gold = (cls == "elite" or cls == "worldboss")
	local silver = (cls == "rare" or cls == "rareelite")
	if gold or silver then
		local atlas = gold and "nameplates-icon-elite-gold" or "nameplates-icon-elite-silver"
		if HasAtlas(atlas) then
			b:SetAtlas(atlas)
		else
			b:SetTexture(Ink.tex.elite)
			if gold then b:SetVertexColor(C.gold[1], C.gold[2], C.gold[3]) else b:SetVertexColor(0.8, 0.83, 0.9) end
		end
		b:Show()
	else
		b:Hide()
	end
end

-- 이름 오른쪽 상태 아이콘 (전투 > 휴식)
function M:UpdateStatus()
	local f = self.player
	if not f then return end
	local s = f.status
	if InCombatLockdown() or UnitAffectingCombat("player") then
		s:SetTexture(Ink.tex.combat)
		s:SetVertexColor(C.red[1], C.red[2], C.red[3])
	elseif IsResting() then
		s:SetTexture(Ink.tex.rest)
		s:SetVertexColor(0.62, 0.66, 1)
	else
		s:Hide()
		return
	end
	self:PlaceStatus()
	s:Show()
	-- 접속 직후엔 글꼴이 늦게 불러와져 글자 폭이 작게 잡힌다 → 잠시 뒤 한 번 더 맞춘다
	if not self.statusRetry then
		self.statusRetry = true
		C_Timer.After(0.5, function() M:PlaceStatus() end)
		C_Timer.After(2, function() M:PlaceStatus(); M.statusRetry = nil end)
	end
end

function M:PlaceStatus()
	local f = self.player
	if not f or not f.status then return end
	local w = f.name:GetStringWidth() or 0
	if issecretvalue and issecretvalue(w) then w = f.name:GetWidth() end
	f.status:ClearAllPoints()
	f.status:SetPoint("LEFT", f.name, "LEFT", math.min(w, f.name:GetWidth()) + 6, 0)
end

function M:UpdateUnit(f)
	if not f or not UnitExists(f.unit) then return end
	self:UpdateInfo(f)
	self:UpdateHealth(f)
	self:UpdatePower(f)
	if f.auras then self:UpdateDebuffs(f, true) end
	if f.cast then CastUpdate(f.cast, f.unit) end
end

-- 디버프만 표시. 테두리는 디버프 종류(마법/저주/질병/독) 색.
-- 적 대상은 내가 건 디버프만, 아군 대상은 전부.
function M:UpdateDebuffs(f, force)
	local u = f.unit
	local box = f.auras
	if #box.groups > 1 then
		box:SetGroup(plain(UnitCanAttack("player", u)) and "mine" or "all")
	end
	box:SetUnit(UnitExists(u) and u or "none", force)
end

function M:UpdateAll()
	for _, f in pairs(self.frames) do self:UpdateUnit(f) end
end

-------------------------------------------------------------------------------
-- 테스트 모드: 대상 / 대상의 대상 / 주시 대상을 내 캐릭터로 띄워 본다
-------------------------------------------------------------------------------
function M:SetTest(on)
	if InCombatLockdown() then return end
	self.testing = on
	for _, f in ipairs({ self.target, self.tot, self.focus }) do
		if on then
			UnregisterUnitWatch(f)
			f.unit = "player"
			f:SetAttribute("unit", "player")
			f:Show()
			self:UpdateUnit(f)
		else
			f.unit = f.realUnit
			f:SetAttribute("unit", f.realUnit)
			RegisterUnitWatch(f)
			self:UpdateUnit(f)
		end
	end
	if self.target.cast then
		local cb = self.target.cast
		if on then
			cb.preview = true
			cb.name:SetText("화염구")
			cb.bar:SetMinMaxValues(0, 3)
			cb:Show()
			local t0 = GetTime()
			Ink:Loop("targetCast", function()
				local e = (GetTime() - t0) % 4
				if e > 3 then cb:SetAlpha(0) return end
				cb:SetAlpha(1)
				cb.bar:SetValue(e)
				cb.time:SetFormattedText("%.1f", 3 - e)
			end)
		else
			Ink:Loop("targetCast", nil)
			cb.preview = nil
			cb:SetAlpha(1)
			CastUpdate(cb, "target")
		end
	end
end

-------------------------------------------------------------------------------
-- 초기화 / 이벤트
-------------------------------------------------------------------------------
function M:Init()
	BuildCurves()
	self:BuildPlayer()
	self:BuildTarget()
	self:BuildToT()
	self:BuildFocus()

	Ink:Movable("player", "플레이어", self.player, "center", 388, 790)
	Ink:Movable("target", "대상", self.target, "center", 1150, 790)
	Ink:Movable("tot", "대상의 대상", self.tot, "center", 1580, 802)
	Ink:Movable("focus", "주시 대상", self.focus, "center", 180, 776)

	-- 기본 유닛프레임 끄기 (숨김 부모로 이동 → 보이지도, 클릭되지도 않음)
	for _, n in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame" }) do
		local fr = _G[n]
		if fr then
			Ink:Disable(fr)
			for _, k in ipairs({ "healthbar", "manabar", "spellbar", "totFrame", "BuffFrame", "AurasFrame", "PetFrame" }) do
				if fr[k] and fr[k].UnregisterAllEvents then fr[k]:UnregisterAllEvents() end
			end
		end
	end
	for _, n in ipairs({ "AlternatePowerBar", "MonkStaggerBar", "EvokerEbonMightBar", "DemonHunterSoulFragmentsBar" }) do
		if _G[n] and _G[n].UnregisterAllEvents then _G[n]:UnregisterAllEvents() end
	end
	if TargetFrameSpellBar then TargetFrameSpellBar:UnregisterAllEvents() end
	if FocusFrameSpellBar then FocusFrameSpellBar:UnregisterAllEvents() end

	local e = CreateFrame("Frame")
	self.eventFrame = e
	for _, ev in ipairs({
		"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
		"UNIT_AURA", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION",
		"PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_TARGET",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING",
		"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
		"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
		"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
	}) do
		e:RegisterEvent(ev)
	end
	e:SetScript("OnEvent", function(_, event, unit)
		if M.testing then
			if unit == "player" then M:UpdateAll() end
			if event:find("^UNIT_") then return end
		end
		if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_UPDATE_RESTING" then
			M:UpdateStatus()
			return
		elseif event == "PLAYER_TARGET_CHANGED" then
			M:UpdateUnit(M.target)
			M:UpdateUnit(M.tot)
			return
		elseif event == "PLAYER_FOCUS_CHANGED" then
			M:UpdateUnit(M.focus)
			return
		elseif event == "UNIT_TARGET" then
			if unit == "target" then M:UpdateUnit(M.tot) end
			return
		end
		local f = unit and M.frames[unit]
		if not f then return end
		if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
			M:UpdateHealth(f)
		elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
			M:UpdatePower(f)
		elseif event == "UNIT_AURA" then
			-- 컨테이너는 엔진이 알아서 갱신한다
			if f.auras and not f.auras:IsLive() then M:UpdateDebuffs(f) end
		elseif event:find("^UNIT_SPELLCAST") then
			if f.cast then CastUpdate(f.cast, unit) end
		else
			M:UpdateInfo(f)
		end
	end)
end

function M:Refresh()
	self:UpdateAll()
end

-- 디버프 이벤트를 놓치는 경우가 있어(대상을 다시 잡아야 보이던 문제) 0.25초마다 한 번씩 확인
do
	local t = 0
	local ticker = CreateFrame("Frame")
	ticker:SetScript("OnUpdate", function(_, e)
		t = t + e
		if t < 0.25 then return end
		t = 0
		if M.testing or not M.target then return end
		for _, f in ipairs({ M.player, M.target, M.focus }) do
			if f and f.auras and not f.auras:IsLive() and UnitExists(f.unit) then M:UpdateDebuffs(f) end
		end
	end)
end
